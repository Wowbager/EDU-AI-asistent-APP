import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/course_model.dart';
import '../core/media/lesson_image_cache.dart';
import '../core/elo/elo_engine.dart';
import '../core/elo/gpf_vector_shape.dart';
import '../core/elo/task_difficulty.dart';
import '../core/evaluation/ai_answer_evaluator.dart';
import '../core/evaluation/expected_answer.dart';
import '../core/evaluation/gaming_filter.dart';
import '../core/gamification/achievement_evaluator.dart';
import '../data/repositories/open_answer_repository.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/bookmark_provider.dart';
import '../core/services/work_time_tracker.dart';
import '../core/providers/practice_providers.dart';
import '../models/chat_models.dart';
import 'chat_detail_page.dart';
import '../core/sync/sync_queue.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/user_course_repository.dart';
import '../widgets/answer_photo_picker.dart';
import '../widgets/block_step_engine.dart';
import '../models/step_navigation.dart';
import '../core/utils/ai_context_sanitizer.dart';
import 'quiz_page.dart';
import 'course_quiz_launch.dart';
import '../core/strings/app_strings.dart';
import 'lesson_detail/lesson_header.dart';
import 'lesson_detail/lesson_nav.dart';
import 'lesson_detail/mentor_sheet.dart';
import 'lesson_detail/card_container.dart';
import 'lesson_detail/action_button_row.dart';
import 'lesson_detail/legacy_cards.dart';
import 'lesson_detail/content_block_cards.dart';
import 'lesson_detail/atomic_cards.dart';
import 'package:eduai/core/util/silent_log.dart';
import '../core/layout/breakpoints.dart';
import '../widgets/detail_shell.dart';
import '../widgets/progress_ring_card.dart';
import '../core/util/shell_route.dart';

/// Lesson Detail Page displaying lesson content blocks
class LessonDetailPage extends ConsumerStatefulWidget {
  final Course course;
  final Lesson lesson;
  final int lessonIndex;
  final String? userCourseId; // Optional: for progress tracking
  final String? initialBlockId; // Jump directly to this block on open

  const LessonDetailPage({
    super.key,
    required this.course,
    required this.lesson,
    required this.lessonIndex,
    this.userCourseId,
    this.initialBlockId,
  });

  @override
  ConsumerState<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends ConsumerState<LessonDetailPage> {
  // Support both old LessonBlock and new ContentBlock formats
  late List<LessonBlock> _legacyBlocks;
  late List<ContentBlock> _contentBlocks;
  late bool _useContentBlocks;

  late ScrollController _scrollController;
  late final WorkTimeTracker _workTimeTracker;
  late List<GlobalKey> _cardKeys;
  int _currentBlockIndex = 0;
  int _lastRestoredBlockIndex = -1;

  // Track if this was the last lesson and course is now completed
  bool _courseCompleted = false;

  /// [widget.course] with lesson statuses updated once this lesson is
  /// completed (BR-CPX4N9). The rail's progress card and lesson list read it,
  /// and it is what the next lesson opens with.
  Course? _courseOverride;

  Course get _course => _courseOverride ?? widget.course;

  // Track pending save operations so we can await them before pop
  Future<void>? _pendingSave;
  bool _isPopping = false;

  /// Safely pop: await any pending DB writes first so the parent page reads fresh data.
  Future<void> _safePop([dynamic result]) async {
    if (_isPopping) return;
    _isPopping = true;
    if (_pendingSave != null) {
      await _pendingSave;
    }
    // Flush any in-memory progress (step_progress, completed blocks) that
    // hasn't been persisted yet — e.g. when a display block's deferred
    // onBlockCompleted callback was missed because the user popped early.
    await _saveProgress();
    // Trigger sync so progress reaches the server without waiting for periodic timer.
    ref.read(syncServiceProvider).sync();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  // Quiz progress caches for exercise and quiz launches
  final QuizProgress _exerciseProgress = QuizProgress();
  final QuizProgress _kvizProgress = QuizProgress();

  // TextEditingControllers for free-text quiz inputs (keyed by block index)
  final Map<int, TextEditingController> _textControllers = {};

  // AI grading verdicts for atomic open answers, by block index (BR-FFVVYR).
  // A missing entry means the answer was graded by local string comparison.
  final Map<int, AiEvaluationResult> _aiResults = {};

  // Block index currently out for AI grading, or null. Drives the spinner and
  // guards against a second submission while the call is in flight.
  int? _evaluatingIndex;

  // ─── Photographed answers + retry (BR-P745Q8), by block index ─────────────

  /// Why the last evaluation produced nothing. Present means the student is
  /// looking at a retry, and the block stays unanswered.
  final Map<int, AiEvaluationFailure> _evaluationFailures = {};

  /// Photos picked but not yet uploaded. Kept across a failed evaluation so a
  /// retry does not make the student take the picture again.
  final Map<int, PickedAnswerPhoto> _pickedPhotos = {};

  /// Handles issued by the upload endpoint.
  final Map<int, String> _photoNames = {};

  final Set<int> _uploadingPhotoIndexes = {};

  /// The evaluation asked for a better picture. Distinct from a failure: it
  /// produced feedback, the photo just could not be read.
  final Set<int> _unreadablePhotoIndexes = {};

  // Step progress for step-based blocks (blockId → StepProgressData)
  final Map<String, StepProgressData> _stepProgress = {};

  // Whether saved progress has been loaded from DB (blocks rendering before this)
  bool _progressLoaded = false;

  // Tracks blocks that have been answered/evaluated but not yet confirmed (user must tap checkmark)
  final Set<int> _answeredBlocks = {};

  // Debounces the progress save while the user is typing an open-question
  // answer, so an in-progress draft survives leaving/reloading the lesson
  // (BR-A7AHKR) without hammering the DB on every keystroke.
  Timer? _openAnswerSaveDebounce;

  // Tracks how many times a block has been reset via cross-block jump.
  // Used as part of the BlockStepEngine key to force State recreation.
  final Map<String, int> _blockResetCounter = {};

  // Per-step bookmark/like/dislike state for display blocks.
  // Key: blockId → set of stepIds that have the action active.
  final Map<String, Set<String>> _bookmarkedSteps = {};
  final Map<String, Set<String>> _likedSteps = {};
  final Map<String, Set<String>> _dislikedSteps = {};

  // Block-level activity timestamps: blockId → opened_at ISO8601
  final Map<String, String> _blockTimestamps = {};

  // blockId → confirmed_at ISO8601: when the block's answer was submitted.
  // With opened_at it is the pair the gaming filter reads, live in _updateElo
  // and later in the admin ELO backfill (BR-3N79C3).
  final Map<String, String> _blockConfirmedAt = {};

  // Tracks hint/help usage per block index for ELO score penalty.
  // 0 = no hint, 1 = hint shown, 2 = help (detailed explanation) shown.
  final Map<int, int> _hintUsage = {};

  // Detailed hint/help tracking per block ID for progress persistence.
  // Keys: blockId → {hint_count, help_count, hint_first_ts, help_first_ts, hint_last_ts, help_last_ts}
  final Map<String, Map<String, dynamic>> _hintHelpTracking = {};

  // Tracks ELO interaction timestamps per block index.
  final Map<int, Map<String, dynamic>> _blockTimestampData = {};

  // Cvičení filtering: completed blocks across all lessons + quiz, and user-removed default_practice blocks
  Set<String> _allCompletedBlockIds = {};
  Set<String> _removedPracticeBlocks = {};

  /// Derive export mode from course export_type field
  ExportMode get _exportMode {
    switch (widget.course.exportType) {
      case 'exercise_v2':
        return ExportMode.exerciseV2;
      case 'quiz_v2':
        return ExportMode.quizV2;
      default:
        return ExportMode.courseV2;
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Track active work time while this lesson is open (BR-9SAH2R). Keep the
    // tracker instance — dispose() must not touch `ref` (Riverpod throws
    // "Cannot use ref after the widget was disposed", which used to abort the
    // rest of dispose).
    _workTimeTracker = ref.read(workTimeTrackerProvider);
    _workTimeTracker.setLocation(
      courseId: widget.course.id,
      lessonId: widget.lesson.id,
      context: 'lesson',
    );

    // Keep the course's pictures on the device while online, so this lesson
    // and the ones not opened yet still have them offline (BR-BX9AA4). The
    // dashboard opens lessons without passing through the course page.
    unawaited(LessonImageCache.instance.prefetch(widget.course.imageUrls));

    // Try to load blocks from course JSON (v2 format)
    if (widget.course.hasBlockV2Data) {
      _contentBlocks = widget.course.getBlocksForLesson(widget.lesson.id);
      _useContentBlocks = _contentBlocks.isNotEmpty;
    } else {
      _contentBlocks = [];
      _useContentBlocks = false;
    }

    // Fallback to legacy blocks if no v2 blocks available
    if (!_useContentBlocks) {
      _legacyBlocks = widget.lesson.blocks.map((block) => block).toList();
    } else {
      _legacyBlocks = [];
    }

    // Create GlobalKeys for each card
    final blockCount = _useContentBlocks ? _contentBlocks.length : _legacyBlocks.length;
    _cardKeys = List.generate(blockCount, (index) => GlobalKey());

    // Find first incomplete block (will be updated after loading saved progress)
    if (_useContentBlocks) {
      _currentBlockIndex = _contentBlocks.indexWhere((b) => !b.isCompleted);
      for (int i = 0; i < _contentBlocks.length; i++) {
      }
    } else {
      _currentBlockIndex = _legacyBlocks.indexWhere((b) => !b.isCompleted);
    }
    if (_currentBlockIndex == -1) {
      _currentBlockIndex = 0;
    }

    // Override with initialBlockId if provided (cross-lesson jump target)
    if (widget.initialBlockId != null && _useContentBlocks) {
      final jumpIndex = _contentBlocks.indexWhere((b) => b.blockId == widget.initialBlockId);
      if (jumpIndex >= 0) {
        _currentBlockIndex = jumpIndex;
      }
    }

    // Record opened_at for the first visible block
    if (_useContentBlocks && _currentBlockIndex < _contentBlocks.length) {
      _blockTimestamps[_contentBlocks[_currentBlockIndex].blockId] =
          DateTime.now().toUtc().toIso8601String();
    }

    // Load saved progress after frame, then apply fallback for corrupted data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSavedProgress();
      _applyCompletedLessonFallback();
    });
  }

  /// Get the total number of blocks
  int get _blockCount => _useContentBlocks ? _contentBlocks.length : _legacyBlocks.length;

  @override
  void dispose() {
    // Via the cached instance — `ref` must not be used in dispose() (Riverpod
    // throws, aborting the rest of this method).
    _workTimeTracker.clearLocation();
    _openAnswerSaveDebounce?.cancel();
    _scrollController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _allBlocksCompleted {
    if (_useContentBlocks) {
      return _contentBlocks.every((b) => b.isCompleted);
    }
    return _legacyBlocks.every((b) => b.isCompleted);
  }

  int get _completedCount {
    if (_useContentBlocks) {
      return _contentBlocks.where((b) => b.isCompleted).length;
    }
    return _legacyBlocks.where((b) => b.isCompleted).length;
  }

  bool get _isLastLesson {
    return widget.lessonIndex >= widget.course.lessons.length - 1;
  }

  Future<void> _confirmBlock(int index, {int earnedXp = 0, double scoreKoef = 1.0}) async {
    if (index != _currentBlockIndex) {
      return;
    }

    // The answer-submit moment. It is saved as the block's confirmed_at and
    // also fills the ts_bubble_open → ts_answer_submit pair, which the step
    // engine never reports — so the ELO log finally carries a time-on-task.
    if (_useContentBlocks && index >= 0 && index < _contentBlocks.length) {
      final blockId = _contentBlocks[index].blockId;
      final submittedAt = DateTime.now().toUtc();
      _blockConfirmedAt[blockId] = submittedAt.toIso8601String();
      final openedAt = DateTime.tryParse(_blockTimestamps[blockId] ?? '');
      final ts = _blockTimestampData.putIfAbsent(index, () => {});
      ts['ts_bubble_open'] ??= openedAt?.millisecondsSinceEpoch;
      ts['ts_answer_submit'] ??= submittedAt.millisecondsSinceEpoch;
    }

    // Wrong atomic answer → seed a Practice (Cvičení) card before advancing.
    // V2 step blocks handle this via BlockStepEngine's onWrongAnswer callback.
    // Both end up behind the same `seedsPracticeOnWrong` type gate, so an
    // atomic block (always display/question) only reaches the deck through a
    // manual bookmark or default_practice — see BR-TF9ZKD.
    if (_useContentBlocks && index >= 0 && index < _contentBlocks.length) {
      final block = _contentBlocks[index];
      if (block.isAtomicFormat &&
          block.isQuestionBlock &&
          _atomicAnswerIsWrong(block, index)) {
        _autoBookmarkOnWrong(index);
      }
    }

    setState(() {
      if (_useContentBlocks) {
        _contentBlocks[index] = _contentBlocks[index].copyWith(isCompleted: true);
      } else {
        _legacyBlocks[index] = _legacyBlocks[index].copyWith(isCompleted: true);
      }

      if (index < _blockCount - 1) {
        _currentBlockIndex = index + 1;
        // Record opened_at for newly revealed block
        if (_useContentBlocks) {
          _blockTimestamps.putIfAbsent(
            _contentBlocks[index + 1].blockId,
            () => DateTime.now().toUtc().toIso8601String(),
          );
        }
        // Scroll to next block after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBlock(index + 1);
        });
      } else {
      }
    });

    // Check if all blocks are completed BEFORE saving (since _allBlocksCompleted uses current state)
    final allCompleted = _allBlocksCompleted;

    // Track the save operation so PopScope can await it before allowing navigation
    final saveFuture = _doSaveAndMark(allCompleted, earnedXp: earnedXp, scoreKoef: scoreKoef, blockIndex: index);
    _pendingSave = saveFuture;
    await saveFuture;
  }

  /// Performs the actual DB writes for block confirmation.
  /// XP award runs AFTER _saveProgress to avoid a race condition where
  /// _awardBlockXp's read-modify-write overwrites _saveProgress's data.
  Future<void> _doSaveAndMark(bool allCompleted, {int earnedXp = 0, double scoreKoef = 1.0, int? blockIndex}) async {
    // Save progress locally - MUST await to avoid race condition
    await _saveProgress();

    // Award XP AFTER progress is persisted so the read-modify-write in
    // _awardBlockXp sees the freshly-saved completed_blocks.
    if (earnedXp > 0) {
      await _awardBlockXp(earnedXp);
    }

    // Update ELO profile for adaptive learning (runs on blocks with GPF vectors)
    if (blockIndex != null) {
      // Apply hint/help penalty to score:
      // hint used → cap at 0.75, help used → cap at 0.5
      final hintLevel = _hintUsage[blockIndex] ?? 0;
      double adjustedScore = scoreKoef;
      if (hintLevel >= 2) {
        adjustedScore = adjustedScore.clamp(0.0, 0.5);
      } else if (hintLevel >= 1) {
        adjustedScore = adjustedScore.clamp(0.0, 0.75);
      }
      await _updateElo(blockIndex, adjustedScore);
    }

    // Check if this was the last block - mark lesson complete
    // This must run AFTER _saveProgress completes so it reads fresh data
    if (allCompleted) {
      await _markLessonAsCompleted();
    }

    // Sync after each block so progress is recoverable on refresh/device switch
    ref.read(syncServiceProvider).sync();
  }

  /// Award XP for a completed block.
  /// Applies course hard cap + daily soft cap via the repository.
  /// MUST be called AFTER _saveProgress to avoid overwriting progress data.
  Future<void> _awardBlockXp(int rawXp) async {
    if (rawXp <= 0 || widget.userCourseId == null) return;
    final user = ref.read(activeUserProvider).valueOrNull;
    if (user == null) return;

    final repository = ref.read(userCourseRepositoryProvider);
    final statsRepo = ref.read(userStatsRepositoryProvider);

    try {
      // Re-read fresh progressData AFTER _saveProgress has persisted
      final userCourse = await repository.getUserCourseById(widget.userCourseId!);
      final progressData = userCourse?.progressData ?? {};
      final courseXpEarned = progressData['xp_earned'] as int? ?? 0;

      final effectiveXp = await statsRepo.awardXp(
        userId: user.id,
        rawXp: rawXp,
        courseXpEarned: courseXpEarned,
        courseMaxXp: widget.course.maxXp,
      );

      if (effectiveXp > 0) {
        // Update course-level XP tracking in progressData
        await repository.updateProgress(
          id: widget.userCourseId!,
          progressData: {
            ...progressData,
            'xp_earned': courseXpEarned + effectiveXp,
          },
        );
      }
    } catch (e, st) { silentLog('lesson_detail_page', e, st); }
  }

  /// Calculate time-on-task in milliseconds from bubble open to answer submit.
  int? _calculateTimeOnTask(int blockIndex) {
    final open = _blockTimestampData[blockIndex]?['ts_bubble_open'] as int?;
    final submit = _blockTimestampData[blockIndex]?['ts_answer_submit'] as int?;
    if (open != null && submit != null) return submit - open;
    return null;
  }

  /// Update the student's ELO profile after completing a block.
  /// Only runs for content blocks that have GPF relation + ELO vectors.
  Future<void> _updateElo(int blockIndex, double score) async {

    if (!_useContentBlocks) {
      return;
    }
    if (blockIndex < 0 || blockIndex >= _contentBlocks.length) {
      return;
    }

    final block = _contentBlocks[blockIndex];
    final relationVector = block.gpf?.relationVector;
    final eloVector = block.gpf?.eloVector;

    // Skip blocks without GPF vectors (display-only blocks)
    if (relationVector == null || relationVector.isEmpty) {
      return;
    }
    if (eloVector == null || eloVector.isEmpty) {
      return;
    }

    final user = ref.read(activeUserProvider).valueOrNull;
    if (user == null) {
      return;
    }

    // Read up front: the catch below can run after the page is gone.
    final eloFailureReporter = ref.read(eloFailureReporterProvider);
    final courseId = widget.course.id;

    try {
      final eloRepo = ref.read(eloRepositoryProvider);
      final syncQueue = ref.read(syncQueueProvider);

      // Get or create the student's ELO profile
      final profile = await eloRepo.getOrCreateProfile(user.id);

      // Cast relation_vector from nullable doubles to non-nullable (engine expects List<double>)
      // and fit every vector to the 35-slot GPF shape the engine insists on
      // (see gpf_vector_shape.dart).
      final castRelation = fitGpfVector(
        relationVector.map((e) => e ?? 0.0).toList(),
        0.0,
      );

      // The server's calibrated difficulty where it has one, the content's
      // elsewhere. The task half of the result is discarded: the server is
      // the only writer of D and its counts (BR-697NCA).
      final taskElo = await eloRepo.effectiveTaskElo(block.blockId, eloVector);
      final profilEloBefore = fitGpfVector(profile.profilElo, null);

      // Pilot 2 gaming rule, as in the quiz: an answer submitted under the
      // threshold after the block was shown is a guess and moves neither the
      // ratings nor the counters (BR-3N79C3).
      final gamed = isGamingLessonAttempt(
        openedAt: _blockTimestamps[block.blockId],
        confirmedAt: _blockConfirmedAt[block.blockId],
      );

      // Run the ELO engine
      final result = EloEngine.updateTask(
        profilElo: profilEloBefore,
        profilPocet: fitGpfVector(profile.profilPocet, 0),
        relationVector: castRelation,
        eloVector: taskElo,
        itemPocet: List<int>.filled(kGpfDimensions, 0),
        score: score,
        skipEloUpdate: gamed,
      );

      if (result.updatedIndices.isEmpty) {
        return;
      }

      // Persist updated profile locally
      await eloRepo.saveProfile(user.id, result.profilElo, result.profilPocet);

      // Enqueue profile sync (UPDATE — the profile already exists on server or will be created by pull)
      await syncQueue.enqueue(
        tableName: 'user_elo_profiles',
        recordId: profile.id,
        operation: SyncOperation.update,
        payload: {
          'profil_elo': result.profilElo,
          'profil_pocet': result.profilPocet,
        },
      );

      // Enqueue interaction log (CREATE). Its id doubles as the server's
      // idempotency key, so a re-sent answer never moves D twice.
      final interactionId = const Uuid().v4();

      // Resolve opened/confirmed timestamps for the ELO export.
      // - opened_at: when the block was first revealed (already tracked).
      // - confirmed_at: when the answer was submitted (ts_answer_submit ms epoch).
      //   Falls back to "now" if the submit timestamp wasn't captured.
      final openedIso = _blockTimestamps[block.blockId];
      final submitMs = _blockTimestampData[blockIndex]?['ts_answer_submit'] as int?;
      final confirmedIso = (submitMs != null
              ? DateTime.fromMillisecondsSinceEpoch(submitMs, isUtc: true)
              : DateTime.now().toUtc())
          .toIso8601String();
      final timeOnTaskMs = _calculateTimeOnTask(blockIndex);

      await syncQueue.enqueue(
        tableName: 'elo_interactions',
        recordId: interactionId,
        operation: SyncOperation.create,
        payload: {
          'block_id': block.blockId,
          'course_id': widget.course.id,
          'source': 'lesson',
          'score': score,
          'help_used': (_hintUsage[blockIndex] ?? 0) >= 2,
          'hint_used': (_hintUsage[blockIndex] ?? 0) >= 1,
          'profil_elo_snapshot': result.profilElo,
          ...taskCalibrationFields(
            clientUuid: interactionId,
            profilEloBefore: profilEloBefore,
            eloVectorUsed: taskElo,
          ),
          'updated_indices': result.updatedIndices,
          'elo_config_version': result.configVersion,
          'ts_bubble_open': _blockTimestampData[blockIndex]?['ts_bubble_open'],
          'ts_answer_click': _blockTimestampData[blockIndex]?['ts_answer_click'],
          'ts_answer_submit': submitMs,
          'attempt_count': _blockTimestampData[blockIndex]?['attempt_count'] ?? 0,
          'time_on_task_ms': timeOnTaskMs,
          if (openedIso != null) 'opened_at': openedIso,
          'confirmed_at': confirmedIso,
          if (timeOnTaskMs != null) 'duration_ms': timeOnTaskMs,
        },
      );

    } catch (e, st) {
      silentLog('lesson_detail_page', e, st);
      // silentLog is silent in release builds, and a block whose vectors the
      // engine rejects would stop moving ELO unnoticed (BR-S9SVNM).
      unawaited(eloFailureReporter.report(
        source: 'lesson',
        courseId: courseId,
        blockId: block.blockId,
        error: e,
        stackTrace: st,
        relationVector: relationVector,
        eloVector: eloVector,
      ));
    }
  }

  /// Mark the current lesson as completed and update progress
  Future<void> _markLessonAsCompleted() async {
    if (widget.userCourseId == null) return;

    try {
      final repository = ref.read(userCourseRepositoryProvider);
      final userCourse = await repository.getUserCourseById(widget.userCourseId!);
      if (userCourse == null) return;

      // Get existing progress data
      final existingProgress = userCourse.progressData;
      final lessonsProgress = Map<String, dynamic>.from(
        existingProgress['lessons'] as Map<String, dynamic>? ?? {},
      );

      // Check if this is the first completion (for trophy)
      final previousLessonData = lessonsProgress[widget.lesson.id] as Map<String, dynamic>?;
      final wasAlreadyCompleted = previousLessonData?['is_completed'] == true;

      // Mark this lesson as completed in progress data
      final lessonProgress = Map<String, dynamic>.from(
        previousLessonData ?? {},
      );
      lessonProgress['is_completed'] = true;
      lessonProgress['completed_at'] = DateTime.now().toIso8601String();
      lessonsProgress[widget.lesson.id] = lessonProgress;

      // Count total completed lessons
      int completedLessonsCount = 0;
      for (final entry in lessonsProgress.entries) {
        final data = entry.value as Map<String, dynamic>?;
        if (data?['is_completed'] == true) {
          completedLessonsCount++;
        }
      }

      // Calculate overall progress percentage
      final totalLessons = widget.course.lessons.length;
      final progressPercent = totalLessons > 0
          ? ((completedLessonsCount / totalLessons) * 100).round()
          : 0;


      await repository.updateProgress(
        id: widget.userCourseId!,
        progressPercent: progressPercent,
        completedLessons: completedLessonsCount,
        progressData: {
          ...existingProgress,
          'lessons': lessonsProgress,
        },
      );

      // The course page re-reads this only once the student leaves the
      // lesson; until then the rail and the next lesson go by this copy.
      if (mounted) {
        setState(() {
          _courseOverride = _course.withLessonProgress(
            lessonsProgress: lessonsProgress,
            completedLessons: completedLessonsCount,
            // updateProgress flips the course to completed at 100 %.
            isCompleted: progressPercent >= 100 ||
                userCourse.status == UserCourseStatus.completed,
          );
        });
      }

      // Also mark the lesson as completed in the user_progress table
      // so it syncs as is_completed=true via POST /api/user/progress.
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user != null) {
        final progressRepo = ref.read(userProgressRepositoryProvider);
        await progressRepo.markLessonCompleted(
          userId: user.id,
          courseId: widget.course.id,
          lessonId: widget.lesson.id,
          progressData: lessonProgress,
        );

        // Award trophy on first lesson completion
        if (!wasAlreadyCompleted) {
          final statsRepo = ref.read(userStatsRepositoryProvider);
          await statsRepo.awardTrophy(user.id);
        }

        // Seed FSRS practice cards for this lesson's default_practice
        // blocks (no-op for blocks that already have a card).
        try {
          final createdCards =
              await ref.read(practiceRepositoryProvider).createCardsFromLesson(
                    userId: user.id,
                    courseId: widget.course.id,
                    lessonId: widget.lesson.id,
                    blocks: widget.course.getBlocksForLesson(widget.lesson.id),
                  );
          // Cards are written straight to Drift; the practice queue providers
          // are plain (cached) FutureProviders, so without this the dashboard
          // count and the practice quiz keep showing the stale pre-lesson value
          // until the next reload. Invalidate so they recompute now. (BR-7R5NFZ)
          if (createdCards > 0) {
            ref.invalidate(practiceQueueProvider);
            // The practice picker reads the cards itself (BR-27AEMT).
            ref.invalidate(practiceScopeProvider);
          }
        } catch (e, st) {
          silentLog('lesson_detail_page:seed_cards', e, st);
        }
      }
      // Force-sync so progress reaches the server immediately
      // instead of waiting for the 15-min periodic timer.
      ref.read(syncServiceProvider).sync();

      // Check for newly earned achievements
      _checkAchievements();
    } catch (e, st) { silentLog('lesson_detail_page', e, st); }
  }

  /// Check achievements after lesson completion or XP award.
  /// Loads config + user stats, runs evaluator, persists new achievements.
  void _checkAchievements() {
    final user = ref.read(activeUserProvider).valueOrNull;
    if (user == null) return;

    () async {
      try {
        final configRepo = ref.read(gamificationConfigRepositoryProvider);
        final config = await configRepo.getConfig();
        if (config == null) return;

        final db = ref.read(appDatabaseProvider);
        final statsRepo = ref.read(userStatsRepositoryProvider);
        final syncQueue = ref.read(syncQueueProvider);

        // Gather current stats
        final stats = await statsRepo.getOrCreateUserStats(user.id);

        // Get already earned IDs
        final earned = await db.getEarnedAchievements(user.id);
        final earnedIds = earned.map((a) => a.achievementId).toSet();

        // Count completed lessons/courses/quizzes from user_courses
        final userCourses = await db.getUserCourses(user.id);
        int lessonsCompleted = 0;
        int coursesCompleted = 0;
        int quizzesCompleted = 0;
        for (final uc in userCourses) {
          lessonsCompleted += uc.completedLessons;
          if (uc.status == 'completed') coursesCompleted++;
          // Count quizzes from progressData
          try {
            final pd = uc.progressDataJson;
            if (pd.isNotEmpty && pd != '{}') {
              final data = Map<String, dynamic>.from(
                  (pd is String ? _tryDecodeJson(pd) : pd) as Map);
              if (data['quiz_completed'] == true) quizzesCompleted++;
            }
          } catch (e, st) { silentLog('lesson_detail_page', e, st); }
        }

        // Evaluate
        final newlyEarned = AchievementEvaluator.evaluate(
          config: config,
          alreadyEarned: earnedIds,
          totalXp: stats.xpPoints,
          streakDays: stats.streakDays,
          lessonsCompleted: lessonsCompleted,
          coursesCompleted: coursesCompleted,
          quizzesCompleted: quizzesCompleted,
          level: stats.level,
        );

        if (newlyEarned.isEmpty) return;

        // Persist and enqueue sync for each
        final now = DateTime.now();
        int totalXpReward = 0;
        int totalCoinReward = 0;
        for (final achievementId in newlyEarned) {
          final localId = 'ach-${now.microsecondsSinceEpoch}-$achievementId';
          final inserted = await db.insertAchievement(
            id: localId,
            userId: user.id,
            achievementId: achievementId,
            earnedAt: now,
          );
          if (inserted) {
            await syncQueue.enqueue(
              tableName: 'user_achievements',
              recordId: localId,
              operation: SyncOperation.create,
              payload: {
                'achievement_id': achievementId,
                'earned_at': now.toIso8601String(),
              },
            );
          }

          // Sum XP and coin rewards from earned achievements
          final def = config.allAchievements.where((a) => a.id == achievementId).firstOrNull;
          if (def != null && def.xpReward > 0) {
            totalXpReward += def.xpReward;
          }
          if (def != null && def.coinReward > 0) {
            totalCoinReward += def.coinReward;
          }
        }

        // Update achievements count in user_stats
        final totalEarned = earnedIds.length + newlyEarned.length;
        await db.updateUserStats(
          id: stats.id,
          achievementsCount: totalEarned,
        );

        // Award XP rewards from newly earned achievements
        if (totalXpReward > 0) {
          await statsRepo.awardXp(
            userId: user.id,
            rawXp: totalXpReward,
            courseXpEarned: 0,
            courseMaxXp: null,
          );
        }

        // And their EDUX coins (BR-HK9828). Uncapped on purpose: the XP caps
        // exist to stop one marathon session from levelling an account, and an
        // achievement is earned once either way.
        if (totalCoinReward > 0) {
          await statsRepo.awardCoins(
            userId: user.id,
            amount: totalCoinReward,
          );
        }
      } catch (e, st) { silentLog('lesson_detail_page', e, st); }
    }();
  }

  static dynamic _tryDecodeJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Navigate to the next lesson or back to course if this is the last one
  Future<void> _navigateToNextLesson() async {
    // Wait for pending save (_markLessonAsCompleted) to finish before
    // navigating — otherwise is_completed never gets written to DB.
    if (_pendingSave != null) await _pendingSave;

    final nextLessonIndex = widget.lessonIndex + 1;
    final totalLessons = widget.course.lessons.length;

    if (nextLessonIndex >= totalLessons) {
      if (widget.course.onlyOnce) {
        // only_once course: go back to dashboard
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      // This was the last lesson - show course completed state with Cvičení/Kvíz buttons
      if (mounted) {
        setState(() {
          _courseCompleted = true;
        });
      }
      return;
    }

    // Get the next lesson
    final nextLesson = _course.lessons[nextLessonIndex];

    // Update current lesson index in database
    if (widget.userCourseId != null) {
      try {
        final repository = ref.read(userCourseRepositoryProvider);
        await repository.updateProgress(
          id: widget.userCourseId!,
          currentLessonIndex: nextLessonIndex,
        );
      } catch (e, st) { silentLog('lesson_detail_page', e, st); }
    }

    if (mounted) {
      // Replace current page with next lesson
      Navigator.pushReplacement(
        context,
        shellPageRoute(
          context,
          builder: (context) => LessonDetailPage(
            course: _course,
            lesson: nextLesson,
            lessonIndex: nextLessonIndex,
            userCourseId: widget.userCourseId,
          ),
        ),
      );
    }
  }

  /// Scroll to bring a specific block to the top of the screen.
  /// Uses RenderAbstractViewport.getOffsetToReveal for precise positioning.
  /// Two-phase: if the block isn't laid out yet (ListView.builder laziness),
  /// first jump to maxScrollExtent to force it to render, then refine.
  void _scrollToBlock(int blockIndex) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (blockIndex >= _cardKeys.length) {
      return;
    }

    // Phase 1: if the target block hasn't been built yet by the lazy
    // ListView.builder, jump to maxScrollExtent to force layout, then retry.
    if (_cardKeys[blockIndex].currentContext == null) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBlockImpl(blockIndex);
      });
      return;
    }

    _scrollToBlockImpl(blockIndex);
  }

  void _scrollToBlockImpl(int blockIndex) {
    if (!mounted || !_scrollController.hasClients) return;
    if (blockIndex >= _cardKeys.length) return;
    if (_cardKeys[blockIndex].currentContext == null) return;

    final renderObject = _cardKeys[blockIndex].currentContext!.findRenderObject();
    if (renderObject == null) return;

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;

    final revealedOffset = viewport.getOffsetToReveal(renderObject, 0.0);
    // Subtract a small gap so the block isn't flush against the top
    final targetOffset = (revealedOffset.offset - 8).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// Save lesson progress locally
  Future<void> _saveProgress() async {
    // Don't save until saved progress has been loaded — otherwise we'd
    // overwrite existing progress with a blank slate.
    if (!_progressLoaded) {
      return;
    }

    // Build progress data: which blocks are completed + user answers
    final completedBlockIds = <String>[];
    final blockAnswers = <String, String>{}; // blockId -> answer/selectedOptionId

    final blockFeedback = <String, Map<String, bool>>{};

    if (_useContentBlocks) {
      for (final block in _contentBlocks) {
        if (block.isCompleted) {
          completedBlockIds.add(block.blockId);
        }
        // Save user's answer/selection if any
        if (block.selectedOptionId != null) {
          blockAnswers[block.blockId] = block.selectedOptionId!;
        }
        // Save likes/dislikes
        if (block.isLiked || block.isDisliked) {
          blockFeedback[block.blockId] = {
            'isLiked': block.isLiked,
            'isDisliked': block.isDisliked,
          };
        }
      }
      // Keep Cvičení-relevant completed set fresh with this lesson's blocks
      _allCompletedBlockIds = {..._allCompletedBlockIds, ...completedBlockIds.map((e) => e)};
    }


    // Save to UserCourseRepository if we have a userCourseId
    // Note: We don't update progressPercent here - that's only updated in _markLessonAsCompleted
    // based on completed lessons, not individual blocks within a lesson
    if (widget.userCourseId != null) {
      try {
        final repository = ref.read(userCourseRepositoryProvider);

        // Build step_progress map for step-based blocks.
        // Apply hint/help penalty to bestScoreKoef so admin / ELO see the
        // assistance-adjusted score, not the raw correctness:
        //   help used → cap 0.5, hint used → cap 0.75.
        final stepProgressJson = <String, dynamic>{};
        for (final entry in _stepProgress.entries) {
          final blockId = entry.key;
          final spJson = entry.value.toJson();
          final tracking = _hintHelpTracking[blockId];
          if (tracking != null) {
            final helpCount = tracking['help_count'] as int? ?? 0;
            final hintCount = tracking['hint_count'] as int? ?? 0;
            final raw = (spJson['bestScoreKoef'] as num?)?.toDouble() ?? 1.0;
            if (helpCount >= 1) {
              spJson['bestScoreKoef'] = raw.clamp(0.0, 0.5);
            } else if (hintCount >= 1) {
              spJson['bestScoreKoef'] = raw.clamp(0.0, 0.75);
            }
          }
          stepProgressJson[blockId] = spJson;
        }

        // Get existing progress data and merge — MUST preserve keys like
        // is_completed / completed_at that _markLessonAsCompleted sets.
        final userCourse = await repository.getUserCourseById(widget.userCourseId!);
        final existingProgress = userCourse?.progressData ?? {};
        final lessonsProgress = Map<String, dynamic>.from(
          existingProgress['lessons'] as Map<String, dynamic>? ?? {},
        );
        final existingLessonProgress = Map<String, dynamic>.from(
          lessonsProgress[widget.lesson.id] as Map<String, dynamic>? ?? {},
        );

        // Build block_timestamps combining opened_at from state + confirmed_at from completed blocks
        final blockTimestampsJson = <String, Map<String, String>>{};
        // Merge any existing saved timestamps first (from existingLessonProgress)
        final existingTs = existingLessonProgress['block_timestamps'] as Map<String, dynamic>?;
        if (existingTs != null) {
          for (final e in existingTs.entries) {
            final m = e.value as Map<String, dynamic>?;
            if (m != null) {
              blockTimestampsJson[e.key] = {
                if (m['opened_at'] != null) 'opened_at': m['opened_at'] as String,
                if (m['confirmed_at'] != null) 'confirmed_at': m['confirmed_at'] as String,
              };
            }
          }
        }
        // Overlay current session's opened_at (putIfAbsent to not overwrite earlier opens)
        for (final e in _blockTimestamps.entries) {
          blockTimestampsJson.putIfAbsent(e.key, () => {});
          blockTimestampsJson[e.key]!.putIfAbsent('opened_at', () => e.value);
        }
        // Set confirmed_at for completed blocks (putIfAbsent — don't overwrite).
        // The recorded submit time, not the save time: the ELO backfill reruns
        // the gaming filter on this pair and must see what _updateElo saw.
        for (final blockId in completedBlockIds) {
          blockTimestampsJson.putIfAbsent(blockId, () => {});
          blockTimestampsJson[blockId]!.putIfAbsent(
            'confirmed_at',
            () => _blockConfirmedAt[blockId] ?? DateTime.now().toUtc().toIso8601String(),
          );
        }

        // Merge new data into existing lesson progress (preserves is_completed, completed_at, etc.)
        final lessonProgress = {
          ...existingLessonProgress,
          'lesson_id': widget.lesson.id,
          'completed_blocks': completedBlockIds,
          'block_answers': blockAnswers,
          'current_block_index': _currentBlockIndex,
          if (stepProgressJson.isNotEmpty) 'step_progress': stepProgressJson,
          if (blockFeedback.isNotEmpty) 'block_feedback': blockFeedback,
          if (blockTimestampsJson.isNotEmpty) 'block_timestamps': blockTimestampsJson,
          if (_hintHelpTracking.isNotEmpty) 'hint_help_usage': _hintHelpTracking,
        };
        lessonsProgress[widget.lesson.id] = lessonProgress;

        // Set status to in_progress if user just started working (was downloaded)
        final newStatus = userCourse?.status == UserCourseStatus.downloaded
            ? UserCourseStatus.inProgress
            : null;

        await repository.updateProgress(
          id: widget.userCourseId!,
          status: newStatus,
          currentLessonIndex: widget.lessonIndex,
          progressData: {
            ...existingProgress,
            'lessons': lessonsProgress,
            if (_removedPracticeBlocks.isNotEmpty)
              'removed_practice_blocks': _removedPracticeBlocks.toList(),
          },
        );

        // Also persist step_progress + block_feedback to user_progress table
        // so they sync via POST /api/user/progress as well.
        final user = ref.read(activeUserProvider).valueOrNull;
        final hasProgressData = stepProgressJson.isNotEmpty ||
            blockFeedback.isNotEmpty ||
            blockTimestampsJson.isNotEmpty ||
            _hintHelpTracking.isNotEmpty;
        if (user != null && hasProgressData) {
          final progressRepo = ref.read(userProgressRepositoryProvider);
          await progressRepo.mergeProgressData(
            userId: user.id,
            courseId: widget.course.id,
            lessonId: widget.lesson.id,
            dataToMerge: {
              if (stepProgressJson.isNotEmpty) 'step_progress': stepProgressJson,
              if (blockFeedback.isNotEmpty) 'block_feedback': blockFeedback,
              // Sync block timings + hint/help/assistant opens to user_progress
              // too — the admin Postup tab reads user_progress, not user_courses
              // (BR-BBK5FP). deepMergeProgressData passes these keys through.
              if (blockTimestampsJson.isNotEmpty) 'block_timestamps': blockTimestampsJson,
              if (_hintHelpTracking.isNotEmpty) 'hint_help_usage': _hintHelpTracking,
            },
          );
        }
      } catch (e, st) { silentLog('lesson_detail_page', e, st); }
    }
  }

  /// Load saved progress from database
  Future<void> _loadSavedProgress() async {
    if (widget.userCourseId == null) {
      if (mounted) setState(() => _progressLoaded = true);
      return;
    }

    try {
      final repository = ref.read(userCourseRepositoryProvider);
      final userCourse = await repository.getUserCourseById(widget.userCourseId!);
      if (userCourse == null) {
        if (mounted) setState(() => _progressLoaded = true);
        return;
      }

      final lessonsProgress = userCourse.progressData['lessons'] as Map<String, dynamic>?;
      if (lessonsProgress == null) {
        if (mounted) setState(() => _progressLoaded = true);
        return;
      }

      // Extract completed block IDs across all lessons + quiz for Cvičení filtering
      _allCompletedBlockIds = Course.extractCompletedBlockIds(userCourse.progressData);

      // Extract removed default_practice blocks
      final removedRaw = userCourse.progressData['removed_practice_blocks'] as List<dynamic>?;
      _removedPracticeBlocks = removedRaw?.map((e) => e as String).toSet() ?? <String>{};

      final lessonProgress = lessonsProgress[widget.lesson.id] as Map<String, dynamic>?;
      if (lessonProgress == null) {
        if (mounted) setState(() => _progressLoaded = true);
        return;
      }

      final completedBlockIds = (lessonProgress['completed_blocks'] as List<dynamic>?)
          ?.map((id) => id as String)
          .toSet() ?? {};

      // Load saved answers (block_answers can be [] if empty instead of {})
      final blockAnswersRaw = lessonProgress['block_answers'];
      final blockAnswers = (blockAnswersRaw is Map<String, dynamic>)
          ? blockAnswersRaw.map((key, value) => MapEntry(key, value as String))
          : <String, String>{};

      // Load step progress for step-based blocks (can be [] if empty)
      final stepProgressVal = lessonProgress['step_progress'];
      if (stepProgressVal is Map<String, dynamic>) {
        for (final entry in stepProgressVal.entries) {
          if (entry.value is Map<String, dynamic>) {
            _stepProgress[entry.key] = StepProgressData.fromJson(entry.value as Map<String, dynamic>);
          }
        }
      }

      // Load saved block feedback (likes/dislikes) (can be [] if empty)
      final blockFeedbackVal = lessonProgress['block_feedback'];
      final blockFeedback = blockFeedbackVal is Map<String, dynamic> ? blockFeedbackVal : null;

      // Mark completed blocks and restore answers
      if (_useContentBlocks) {
        setState(() {
          for (int i = 0; i < _contentBlocks.length; i++) {
            final block = _contentBlocks[i];
            final savedAnswer = blockAnswers[block.blockId];

            // Restore completion state
            final isCompleted = completedBlockIds.contains(block.blockId);

            // Restore likes/dislikes
            bool isLiked = block.isLiked;
            bool isDisliked = block.isDisliked;
            if (blockFeedback != null) {
              final fb = blockFeedback[block.blockId] as Map<String, dynamic>?;
              if (fb != null) {
                isLiked = fb['isLiked'] as bool? ?? false;
                isDisliked = fb['isDisliked'] as bool? ?? false;
              }
            }

            // Restore block-level bookmark from BookmarkNotifier or default_practice
            final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
            final isBookmarked = bookmarkNotifier.isBookmarked(widget.course.id, block.blockId)
                || (block.defaultPractice && !_removedPracticeBlocks.contains(block.blockId));

            // Restore step-level bookmarks for this block
            final stepBookmarks = <String>{};
            for (final step in block.steps) {
              if (bookmarkNotifier.isBookmarked(widget.course.id, '${block.blockId}:${step.stepId}')) {
                stepBookmarks.add(step.stepId);
              }
            }
            if (stepBookmarks.isNotEmpty) {
              _bookmarkedSteps[block.blockId] = stepBookmarks;
            }

            // Restore step-level likes/dislikes from block_feedback
            if (blockFeedback != null) {
              final stepLikes = <String>{};
              final stepDislikes = <String>{};
              for (final step in block.steps) {
                final compositeKey = '${block.blockId}:${step.stepId}';
                final fb = blockFeedback[compositeKey] as Map<String, dynamic>?;
                if (fb != null) {
                  if (fb['isLiked'] == true) stepLikes.add(step.stepId);
                  if (fb['isDisliked'] == true) stepDislikes.add(step.stepId);
                }
              }
              if (stepLikes.isNotEmpty) _likedSteps[block.blockId] = stepLikes;
              if (stepDislikes.isNotEmpty) _dislikedSteps[block.blockId] = stepDislikes;
            }

            // Update block with saved state
            _contentBlocks[i] = block.copyWith(
              isCompleted: isCompleted,
              selectedOptionId: savedAnswer,
              isLiked: isLiked,
              isDisliked: isDisliked,
              isBookmarked: isBookmarked,
            );

            // If there's a saved answer, set up TextEditingController for free-text inputs
            if (savedAnswer != null) {
              _textControllers[i] ??= TextEditingController();
              _textControllers[i]!.text = savedAnswer;
            }
          }
          // Fallback: also mark blocks completed if step_progress says
          // isBlockCompleted=true but the block wasn't in completedBlockIds
          // (happens when user popped before onBlockCompleted fired).
          for (int i = 0; i < _contentBlocks.length; i++) {
            if (!_contentBlocks[i].isCompleted) {
              final sp = _stepProgress[_contentBlocks[i].blockId];
              if (sp != null && sp.isBlockCompleted) {
                _contentBlocks[i] = _contentBlocks[i].copyWith(isCompleted: true);
              }
            }
          }
          // Update current block index to first incomplete
          _currentBlockIndex = _contentBlocks.indexWhere((b) => !b.isCompleted);
          if (_currentBlockIndex == -1) _currentBlockIndex = _contentBlocks.length - 1;
          // Track the highest index of a block restored from saved progress
          // so we can show blocks up to that point even if _currentBlockIndex < them
          for (int i = _contentBlocks.length - 1; i >= 0; i--) {
            if (_contentBlocks[i].isCompleted) {
              _lastRestoredBlockIndex = i;
              break;
            }
          }
          // Restore previously saved block timestamps
          final savedTimestamps = lessonProgress['block_timestamps'] as Map<String, dynamic>?;
          if (savedTimestamps != null) {
            for (final entry in savedTimestamps.entries) {
              final ts = entry.value as Map<String, dynamic>?;
              if (ts != null && ts['opened_at'] != null) {
                _blockTimestamps[entry.key] = ts['opened_at'] as String;
              }
            }
          }

          // Restore hint/help/assistant tracking so new opens ACCUMULATE across
          // lesson re-entries instead of overwriting prior occurrences on save
          // (BR-BBK5FP — "výskyty a časy").
          final savedHintHelp = lessonProgress['hint_help_usage'] as Map<String, dynamic>?;
          if (savedHintHelp != null) {
            for (final entry in savedHintHelp.entries) {
              final v = entry.value;
              if (v is Map) {
                _hintHelpTracking[entry.key] = Map<String, dynamic>.from(v);
              }
            }
          }

          // Set opened_at for the current block if not already tracked
          if (_currentBlockIndex < _contentBlocks.length) {
            final bid = _contentBlocks[_currentBlockIndex].blockId;
            _blockTimestamps.putIfAbsent(bid, () => DateTime.now().toUtc().toIso8601String());
          }

          _progressLoaded = true;
        });

        // Scroll after layout settles (postFrameCallback ensures layout is done,
        // then delay lets images/media load before measuring positions)
        if (_currentBlockIndex > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted || !_scrollController.hasClients) return;
              _scrollToBlock(_currentBlockIndex);
            });
          });
        }
      } else {
        setState(() => _progressLoaded = true);
      }
    } catch (e) {
      if (mounted) setState(() => _progressLoaded = true);
    }
  }

  /// Fallback: when the lesson is marked completed at the course level but
  /// individual block completion data is missing (corrupted progress), mark
  /// all blocks as done and scroll to the last one.
  void _applyCompletedLessonFallback() {
    if (!mounted || !_useContentBlocks) return;
    if (widget.lesson.status != LessonStatus.completed) return;

    final allDone = _contentBlocks.every((b) => b.isCompleted);
    if (allDone) return; // Already correctly restored — nothing to do

    setState(() {
      for (int i = 0; i < _contentBlocks.length; i++) {
        _contentBlocks[i] = _contentBlocks[i].copyWith(isCompleted: true);
      }
      _currentBlockIndex = _contentBlocks.length - 1;
    });

    // Scroll to last block after images settle
    Future.delayed(const Duration(milliseconds: 500), () {
      _scrollToBlock(_currentBlockIndex);
    });
  }

  /// Auto-bookmark an exercise block on wrong answer so it lands in Cvičení
  /// (same effect as manual bookmark). No-op for already-bookmarked blocks
  /// or non-exercise types.
  void _autoBookmarkOnWrong(int index) {
    if (!_useContentBlocks) return;
    if (index < 0 || index >= _contentBlocks.length) return;
    final block = _contentBlocks[index];
    if (!block.type.seedsPracticeOnWrong) return;
    if (block.isBookmarked) return;

    final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
    setState(() {
      _contentBlocks[index] = block.copyWith(isBookmarked: true);
      _removedPracticeBlocks.remove(block.blockId);
    });
    bookmarkNotifier.addBookmark(
      widget.course.id,
      _contentBlocks[index],
      lessonId: widget.lesson.id,
    );
  }

  /// True when an atomic question block was answered incorrectly, based on the
  /// single selected option id (multiple_choice/true_false) or typed text (open).
  /// Multi-select questions aren't tracked via selectedOptionId → treated as not-wrong.
  bool _atomicAnswerIsWrong(ContentBlock block, int index) {
    final q = block.atomicQuestion;
    if (q == null) return false;
    final answer = block.selectedOptionId;
    if (answer == null || answer.isEmpty) return false;
    if (q.isOpen) {
      // An AI-graded answer already has a verdict; re-running the string
      // comparison here would bookmark correct answers as wrong.
      final ai = _aiResults[index];
      if (ai != null) return !ai.isCorrect;
      final correct = q.correctAnswer?.trim().toLowerCase() ?? '';
      return answer.trim().toLowerCase() != correct;
    }
    if (q.allowMultiple) return false;
    final correctIds = q.options.where((o) => o.isCorrect).map((o) => o.id).toList();
    if (correctIds.isEmpty) return false;
    return !correctIds.contains(answer);
  }

  void _toggleBookmark(int index) {
    final bookmarkNotifier = ref.read(bookmarkProvider.notifier);

    setState(() {
      if (_useContentBlocks) {
        final block = _contentBlocks[index];
        final newBookmarkState = !block.isBookmarked;

        _contentBlocks[index] = block.copyWith(
          isBookmarked: newBookmarkState,
        );

        // Track removal/restoration of default_practice blocks for Cvičení filtering
        if (block.defaultPractice) {
          if (!newBookmarkState) {
            _removedPracticeBlocks.add(block.blockId);
          } else {
            _removedPracticeBlocks.remove(block.blockId);
          }
        }

        // Save to provider for access from course page
        if (newBookmarkState) {
          bookmarkNotifier.addBookmark(widget.course.id, _contentBlocks[index], lessonId: widget.lesson.id);
        } else {
          bookmarkNotifier.removeBookmark(widget.course.id, block.blockId);
        }
      } else {
        final block = _legacyBlocks[index];
        _legacyBlocks[index] = block.copyWith(
          isBookmarked: !block.isBookmarked,
        );
        // Note: Legacy blocks don't support quiz mode
      }
    });
  }

  void _toggleLike(int index) {
    final wasLiked = _useContentBlocks
        ? _contentBlocks[index].isLiked
        : _legacyBlocks[index].isLiked;
    final blockId = _useContentBlocks
        ? _contentBlocks[index].blockId
        : _legacyBlocks[index].id;

    setState(() {
      if (_useContentBlocks) {
        _contentBlocks[index] = _contentBlocks[index].copyWith(
          isLiked: !_contentBlocks[index].isLiked,
          isDisliked: false,
        );
      } else {
        _legacyBlocks[index] = _legacyBlocks[index].copyWith(
          isLiked: !_legacyBlocks[index].isLiked,
          isDisliked: false,
        );
      }
    });

    // Only enqueue when toggling ON
    if (!wasLiked) {
      _enqueueFeedback(blockId: blockId, type: 'like');
    }

    // Persist to user_progress table for sync
    _persistBlockFeedback(blockId: blockId, isLiked: !wasLiked, isDisliked: false);
  }

  void _toggleDislike(int index) {
    final wasDisliked = _useContentBlocks
        ? _contentBlocks[index].isDisliked
        : _legacyBlocks[index].isDisliked;
    final blockId = _useContentBlocks
        ? _contentBlocks[index].blockId
        : _legacyBlocks[index].id;

    setState(() {
      if (_useContentBlocks) {
        _contentBlocks[index] = _contentBlocks[index].copyWith(
          isDisliked: !_contentBlocks[index].isDisliked,
          isLiked: false,
        );
      } else {
        _legacyBlocks[index] = _legacyBlocks[index].copyWith(
          isDisliked: !_legacyBlocks[index].isDisliked,
          isLiked: false,
        );
      }
    });

    // Only enqueue when toggling ON
    if (!wasDisliked) {
      _enqueueFeedback(blockId: blockId, type: 'dislike');
    }

    // Persist to user_progress table for sync
    _persistBlockFeedback(blockId: blockId, isLiked: false, isDisliked: !wasDisliked);
  }

  // ─── Per-step action toggles (for display blocks) ──────────

  void _toggleStepBookmark(int blockIndex, String stepId) {
    final block = _contentBlocks[blockIndex];
    final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
    final compositeId = '${block.blockId}:$stepId';

    final set = _bookmarkedSteps.putIfAbsent(block.blockId, () => {});
    final wasBookmarked = set.contains(stepId);

    setState(() {
      if (wasBookmarked) {
        set.remove(stepId);
      } else {
        set.add(stepId);
      }
    });

    if (!wasBookmarked) {
      // Find the actual step to store its content (not a bare shell)
      final step = block.steps.cast<BlockStep?>().firstWhere(
        (s) => s!.stepId == stepId,
        orElse: () => null,
      );
      final stepBlock = ContentBlock(
        blockId: compositeId,
        type: block.type,
        content: step?.htmlContent ?? step?.displayText,
        atomicImage: step?.image,
        atomicVideo: step?.video,
      );
      bookmarkNotifier.addBookmark(widget.course.id, stepBlock, lessonId: widget.lesson.id);
    } else {
      bookmarkNotifier.removeBookmark(widget.course.id, compositeId);
    }
  }

  void _toggleStepLike(int blockIndex, String stepId) {
    final block = _contentBlocks[blockIndex];
    final compositeId = '${block.blockId}:$stepId';

    final likeSet = _likedSteps.putIfAbsent(block.blockId, () => {});
    final dislikeSet = _dislikedSteps.putIfAbsent(block.blockId, () => {});
    final wasLiked = likeSet.contains(stepId);

    setState(() {
      if (wasLiked) {
        likeSet.remove(stepId);
      } else {
        likeSet.add(stepId);
        dislikeSet.remove(stepId);
      }
    });

    if (!wasLiked) {
      _enqueueFeedback(blockId: compositeId, type: 'like');
    }
    _persistBlockFeedback(blockId: compositeId, isLiked: !wasLiked, isDisliked: false);
  }

  void _toggleStepDislike(int blockIndex, String stepId) {
    final block = _contentBlocks[blockIndex];
    final compositeId = '${block.blockId}:$stepId';

    final likeSet = _likedSteps.putIfAbsent(block.blockId, () => {});
    final dislikeSet = _dislikedSteps.putIfAbsent(block.blockId, () => {});
    final wasDisliked = dislikeSet.contains(stepId);

    setState(() {
      if (wasDisliked) {
        dislikeSet.remove(stepId);
      } else {
        dislikeSet.add(stepId);
        likeSet.remove(stepId);
      }
    });

    if (!wasDisliked) {
      _enqueueFeedback(blockId: compositeId, type: 'dislike');
    }
    _persistBlockFeedback(blockId: compositeId, isLiked: false, isDisliked: !wasDisliked);
  }

  /// Persist block feedback (like/dislike) to user_progress table for server sync.
  void _persistBlockFeedback({
    required String blockId,
    required bool isLiked,
    required bool isDisliked,
  }) {
    final user = ref.read(activeUserProvider).valueOrNull;
    if (user == null || widget.userCourseId == null) return;

    final progressRepo = ref.read(userProgressRepositoryProvider);
    progressRepo.saveBlockState(
      userId: user.id,
      courseId: widget.course.id,
      lessonId: widget.lesson.id,
      blockId: blockId,
      isLiked: isLiked,
    );
  }

  /// Enqueue content feedback to the sync queue for server submission.
  ///
  /// [flushNow] runs a sync straight away instead of waiting for the periodic
  /// timer. The mentor sheet passes false: its question is enqueued in the same
  /// breath as the chat POST, and a full sync (pushes, eight pulls, practice
  /// reconciliation) competing with the answer the student is waiting for buys
  /// nothing — the sync that fires on the answer's last token flushes it a few
  /// seconds later (BR-M7EQY8).
  Future<void> _enqueueFeedback({
    required String blockId,
    required String type,
    String? message,
    bool flushNow = true,
  }) async {
    final syncQueue = ref.read(syncQueueProvider);
    final recordId = '${widget.course.id}_${blockId}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await syncQueue.enqueue(
        tableName: 'content_feedback',
        recordId: recordId,
        operation: SyncOperation.create,
        payload: {
          'course_id': widget.course.id,
          'block_id': blockId,
          'lesson_id': widget.lesson.id,
          'type': type,
          if (message != null) 'message': message,
        },
      );

      // Trigger sync immediately so feedback is sent without waiting for periodic timer.
      if (flushNow) {
        final syncService = ref.read(syncServiceProvider);
        syncService.sync();
      }
    } catch (e, st) { silentLog('lesson_detail_page', e, st); }
  }

  /// Open AI chat with context about the current block.
  /// Used by go_to: "CHAT"/"LECTURE" and the hint sheet "Zeptat se AI" button.
  void _openChatWithContext(int index, {String? studentMessage}) {
    final block = _useContentBlocks ? _contentBlocks[index] : null;
    final courseName = widget.course.title;
    final lessonName = widget.lesson.title;

    // BlockStepEngine owns the real step index internally and only mirrors it
    // into _stepProgress; the ContentBlock's own currentStepIndex stays frozen
    // at 0. Pass the live index in so the context describes the step the
    // student is actually on, not an earlier one (BR-J43MA4).
    // The task context goes to the model as a hidden message, so it is built
    // without a closing request; the student's own question opens the visible
    // transcript instead of the whole blob (BR-NAH3TR).
    final contextMessage = buildLessonChatContext(
      block: block,
      courseName: courseName,
      lessonName: lessonName,
      liveStepIndex:
          block == null ? null : _stepProgress[block.blockId]?.currentStepIndex,
      includeClosingPrompt: false,
    );

    // Navigate to chat with pre-filled context
    Navigator.push(
      context,
      shellPageRoute(
        context,
        builder: (_) => ChatDetailPage(
          sessionId: '', // empty = create new session
          sessionTitle: lessonName.isNotEmpty ? lessonName : courseName,
          persona: ChatPersona.mathMentor,
          initialContext: contextMessage,
          initialQuestion: (studentMessage != null &&
                  studentMessage.trim().isNotEmpty)
              ? studentMessage.trim()
              : null,
        ),
      ),
    );
  }

  /// Open the mentor sheet for the block at [index], scoped to [stepId].
  ///
  /// [stepId] is the step whose "?" was tapped — BlockStepEngine reports it,
  /// because the block's own step cursor stays frozen at 0 and would answer
  /// with the first step's hint (or the block's shared one) whatever step the
  /// student is on (BR-JHDNB3). Null for atomic blocks, which have no steps.
  void _showHintDialog(int index, [String? stepId]) {
    final block = _useContentBlocks ? _contentBlocks[index] : null;
    if (block == null || !block.hasHintForStep(stepId)) return;

    final practiceUnavailable =
        practiceOptionUnavailable(block: block, course: widget.course);

    showMentorSheet(
      context: context,
      block: block,
      stepId: stepId,
      buildAiContext: () => buildLessonChatContext(
        block: block,
        courseName: widget.course.title,
        lessonName: widget.lesson.title,
        liveStepIndex: _stepProgress[block.blockId]?.currentStepIndex,
        includeClosingPrompt: false,
      ),
      onShown: () {
        // Track hint usage for ELO score penalty (max of previous value)
        final prev = _hintUsage[index] ?? 0;
        if (prev < 1) _hintUsage[index] = 1;

        // Detailed hint tracking with timestamps and counters
        final blockId = block.blockId;
        final now = DateTime.now().toUtc().toIso8601String();
        _hintHelpTracking.putIfAbsent(blockId, () => {});
        final tracking = _hintHelpTracking[blockId]!;
        tracking['hint_count'] = (tracking['hint_count'] as int? ?? 0) + 1;
        tracking['hint_first_ts'] ??= now;
        tracking['hint_last_ts'] = now;
        // One entry per open so the admin postup timeline can show every
        // occurrence + its time (BR-BBK5FP), not just first/last.
        final hintEvents = (tracking['hint_events'] as List?)?.cast<String>() ?? <String>[];
        hintEvents.add(now);
        tracking['hint_events'] = hintEvents;
      },
      onSavePractice: practiceUnavailable
          ? null
          : () {
              // Actually save the bookmark for practice. Ask the notifier rather
              // than the block flag — `isBookmarked` is also true for
              // default_practice blocks, which would skip the write (BR-FEQ97Q).
              // The sheet hides the option in that case, so this is a
              // duplicate-row guard only.
              final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
              final currentBlock = _contentBlocks[index];
              if (!bookmarkNotifier.isBookmarked(
                  widget.course.id, currentBlock.blockId)) {
                bookmarkNotifier.addBookmark(widget.course.id, currentBlock,
                    lessonId: widget.lesson.id);
              }
              setState(() {
                _contentBlocks[index] = currentBlock.copyWith(isBookmarked: true);
                // Mirrors _toggleBookmark: re-adding must undo an earlier
                // removal, otherwise the block stays filtered out of Cvičení.
                _removedPracticeBlocks.remove(currentBlock.blockId);
              });
              _saveProgress();
            },
      onEscalateToHelp: () {
        // Escalate hint usage to "help" level for ELO penalty
        _hintUsage[index] = 2;
        // Detailed help tracking
        final helpNow = DateTime.now().toUtc().toIso8601String();
        final t = _hintHelpTracking[block.blockId] ?? {};
        t['help_count'] = (t['help_count'] as int? ?? 0) + 1;
        t['help_first_ts'] ??= helpNow;
        t['help_last_ts'] = helpNow;
        final helpEvents = (t['help_events'] as List?)?.cast<String>() ?? <String>[];
        helpEvents.add(helpNow);
        t['help_events'] = helpEvents;
        _hintHelpTracking[block.blockId] = t;
      },
      onAskMentor: (question, {required isFirst}) {
        // Track assistant opens for the admin postup timeline (BR-BBK5FP).
        // Every question counts; the conversation now happens inside the sheet
        // rather than on a pushed chat page.
        final blockId = block.blockId;
        final now = DateTime.now().toUtc().toIso8601String();
        final t = _hintHelpTracking[blockId] ?? {};
        t['assistant_count'] = (t['assistant_count'] as int? ?? 0) + 1;
        t['assistant_first_ts'] ??= now;
        t['assistant_last_ts'] = now;
        final assistantEvents = (t['assistant_events'] as List?)?.cast<String>() ?? <String>[];
        assistantEvents.add(now);
        t['assistant_events'] = assistantEvents;
        _hintHelpTracking[blockId] = t;

        // The opening question doubles as block feedback, exactly like the
        // "Upřesni svůj dotaz" form it replaces. Follow-ups are ordinary chat.
        if (isFirst) {
          _enqueueFeedback(
            blockId: blockId,
            type: 'question',
            message: question,
            flushNow: false,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.widthClass == WidthClass.compact) {
      return ContentWidth(
        maxWidth: ContentWidth.reading,
        child: _buildPage(context),
      );
    }
    // Wide: shell chrome, the existing lesson column in the middle, and a rail
    // carrying course progress, the AI-help prompt and the lesson list.
    return DetailShell(
      backLabel: widget.course.title,
      onBack: () => _safePop(),
      child: _buildWidePage(context),
    );
  }

  Widget _buildWidePage(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const pad = 32.0;
        final withRail = hasSideRail(constraints.maxWidth - pad * 2);

        return Padding(
          padding: const EdgeInsets.fromLTRB(pad, 8, pad, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The phone page verbatim — it already owns the header, the
              // block list and the completion nav.
              Expanded(child: _buildPage(context, showHeader: false)),
              if (withRail) ...[
                const SizedBox(width: 24),
                SizedBox(
                  width: _railWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildLessonRail(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, {bool showHeader = true}) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // System back pressed — await pending saves before popping
        await _safePop();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
            children: [
              // Fixed header at top
              if (showHeader)
                LessonHeader(
                  courseTitle: widget.course.title,
                  lessonTitle: widget.lesson.title,
                  lessonIndex: widget.lessonIndex,
                  xpReward: widget.lesson.xpReward,
                  completedCount: _completedCount,
                  blockCount: _blockCount,
                  onBack: () => _safePop(),
                ),
              // Scrollable content
              Expanded(
                child: Stack(
                  children: [
                !_progressLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : _blockCount == 0
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '📚',
                                style: TextStyle(fontSize: 64),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.lessonEmptyTitle,
                                style: AppTextStyles.cardTitle(),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppStrings.lessonEmptyMessage,
                                style: AppTextStyles.body(color: AppColors.primaryDark64),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          24,
                          16,
                          MediaQuery.of(context).size.height * 0.6,
                        ),
                        // Render blocks up to the current unlock frontier, but
                        // also include any blocks restored from a previous
                        // cross-block jump (they appear completed or locked).
                        itemCount: _allBlocksCompleted
                            ? _blockCount
                            : (_lastRestoredBlockIndex >= 0
                                ? max(_currentBlockIndex + 1, _lastRestoredBlockIndex + 2)
                                    .clamp(0, _blockCount)
                                : _currentBlockIndex + 1),
                        itemBuilder: (context, index) {
                          final isCompleted = _useContentBlocks
                              ? _contentBlocks[index].isCompleted
                              : _legacyBlocks[index].isCompleted;
                          final isLocked = index > _currentBlockIndex && !isCompleted;
                          final isCurrent = index == _currentBlockIndex;

                          return Padding(
                                key: _cardKeys[index],
                                padding: EdgeInsets.only(bottom: index < _blockCount - 1 ? 16 : 0),
                                child: _buildBlockCard(index, isLocked, isCurrent),
                          );
                        },
                      ),
                    // Bottom action bar (shown when all blocks completed)
                    Builder(builder: (context) {
                      return const SizedBox.shrink();
                    }),
                    if (_allBlocksCompleted && _blockCount > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Builder(builder: (context) {
                          final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
                          final hasExerciseBlocks =
                              widget.course.getDefaultPracticeBlocks(
                                completedBlockIds: _allCompletedBlockIds,
                                removedBlockIds: _removedPracticeBlocks,
                              ).isNotEmpty ||
                              bookmarkNotifier.hasBookmarksForCourse(widget.course.id);
                          final hasQuestions = widget.course.getAllQuestionBlocks().isNotEmpty;
                          return LessonNav(
                            courseCompleted: _courseCompleted,
                            isLastLesson: _isLastLesson,
                            hasExerciseBlocks: hasExerciseBlocks,
                            hasQuestions: hasQuestions,
                            onNextLesson: _navigateToNextLesson,
                            onCviceni: _navigateToCviceni,
                            onKviz: _navigateToKviz,
                            onBackToCourse: () => _safePop(true),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
    ),
    );
  }

  Widget _buildBlockCard(int index, bool isLocked, bool isCurrent) {
    Widget cardContent;

    if (_useContentBlocks) {
      // Use new ContentBlock format
      cardContent = _buildContentBlockCard(index, isCurrent);
    } else {
      // Use legacy LessonBlock format
      final block = _legacyBlocks[index];

      switch (block.type) {
        case LessonBlockType.image:
          cardContent = _buildImageCard(index, isCurrent);
          break;
        case LessonBlockType.video:
          cardContent = _buildVideoCard(index, isCurrent);
          break;
        case LessonBlockType.keyConcepts:
          cardContent = _buildKeyConceptsCard(index, isCurrent);
          break;
        case LessonBlockType.quiz:
          cardContent = _buildQuizCard(index, isCurrent);
          break;
        case LessonBlockType.text:
        default:
          cardContent = _buildTextCard(index, isCurrent);
          break;
      }
    }

    // Apply blur effect for locked blocks
    if (isLocked) {
      return ClipRRect(
        borderRadius: AppDecorations.radiusXL,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }

  /// Build a card for ContentBlock (v2 format)
  Widget _buildContentBlockCard(int index, bool isCurrent) {
    final block = _contentBlocks[index];


    // Handle atomic format blocks (v2 format - no steps)
    if (block.isAtomicFormat) {
      if (block.isQuestionBlock) {
        return _buildAtomicQuestionCard(index, isCurrent, block);
      } else {
        return _buildAtomicDisplayCard(index, isCurrent, block);
      }
    }

    // V2 step-based blocks → delegate to BlockStepEngine
    if (block.hasV2Steps) {
      final resetGen = _blockResetCounter[block.blockId] ?? 0;
      return BlockStepEngine(
        key: ValueKey('${block.blockId}_$resetGen'),
        block: block,
        exportMode: _exportMode,
        hideEvaluation: _exportMode == ExportMode.quizV2 && !widget.course.quizEvaluate,
        isCurrent: isCurrent,
        isCompleted: block.isCompleted,
        onBlockCompleted: ({int earnedXp = 0, double scoreKoef = 1.0, String? mark, DateTime? tsBubbleOpen, DateTime? tsAnswerClick, DateTime? tsAnswerSubmit, int attemptCount = 0}) {
          _blockTimestampData[index] = {
            'ts_bubble_open': tsBubbleOpen?.millisecondsSinceEpoch,
            'ts_answer_click': tsAnswerClick?.millisecondsSinceEpoch,
            'ts_answer_submit': tsAnswerSubmit?.millisecondsSinceEpoch,
            'attempt_count': attemptCount,
          };
          _confirmBlock(index, earnedXp: earnedXp, scoreKoef: scoreKoef);
        },
        onCrossBlockNavigate: (blockId) => _navigateToBlock(blockId),
        onChatRequested: () => _openChatWithContext(index),
        onStepProgress: (progress) => _saveStepProgress(index, progress),
        savedProgress: _stepProgress[block.blockId],
        // Block-level actions (exercise/question blocks)
        onBookmarkToggle: () => _toggleBookmark(index),
        onLikeToggle: () => _toggleLike(index),
        onDislikeToggle: () => _toggleDislike(index),
        onWrongAnswer: () => _autoBookmarkOnWrong(index),
        openAnswerScore: widget.course.openAnswerScore,
        showAnswerStatus: widget.course.quizEvaluate,
        onOpenAnswerEvaluated: (event) => unawaited(
          ref.read(openAnswerRepositoryProvider).record(
                attemptId: event.attemptId,
                courseId: widget.course.id,
                lessonId: widget.lesson.id,
                blockId: event.blockId,
                stepId: event.stepId,
                answerText: event.answerText,
                photoName: event.photoName,
                isCorrect: event.isCorrect,
                failed: event.failed,
                evaluatedByAi: event.evaluatedByAi,
                aiScore: event.aiScore,
                aiFeedback: event.aiFeedback,
                aiModel: event.aiModel,
                feedback: event.feedbackParts,
                criteriaScores: event.criteriaScores,
                gradingBasis: event.gradingBasis,
                promptVersion: event.promptVersion,
              ),
        ),
        // The engine decides which steps offer a hint and reports the step id —
        // it is the only holder of the live step index (BR-JHDNB3).
        onHintRequested: (stepId) => _showHintDialog(index, stepId),
        isBookmarked: block.isBookmarked,
        isLiked: block.isLiked,
        isDisliked: block.isDisliked,
        // Per-step actions (display blocks — each step independently actionable)
        onStepBookmarkToggle: (stepId) => _toggleStepBookmark(index, stepId),
        onStepLikeToggle: (stepId) => _toggleStepLike(index, stepId),
        onStepDislikeToggle: (stepId) => _toggleStepDislike(index, stepId),
        bookmarkedStepIds: _bookmarkedSteps[block.blockId] ?? const {},
        likedStepIds: _likedSteps[block.blockId] ?? const {},
        dislikedStepIds: _dislikedSteps[block.blockId] ?? const {},
      );
    }

    // Legacy step-based format (old step types: display, evaluation, etc.)
    BlockStep? displayStep;
    BlockStep? evaluationStep;

    for (final step in block.steps) {
      if (step.isDisplayStep && displayStep == null) {
        displayStep = step;
      } else if (step.isEvaluationStep && evaluationStep == null) {
        evaluationStep = step;
      }
    }

    // If we have an evaluation step, render it as a quiz
    if (evaluationStep != null) {
      return _buildContentBlockQuizCard(index, isCurrent, displayStep, evaluationStep);
    }

    // Otherwise render the display content
    if (displayStep != null) {
      // Check if it has key concepts
      if (displayStep.content?.keyConcepts != null &&
          displayStep.content!.keyConcepts!.isNotEmpty) {
        return _buildContentBlockKeyConceptsCard(index, isCurrent, displayStep);
      }

      // Check if it has image/emoji
      if (displayStep.content?.imageUrl != null ||
          displayStep.content?.imageEmoji != null) {
        return _buildContentBlockImageCard(index, isCurrent, displayStep);
      }

      // Check if it has video (explicit video field or content videoUrl)
      if (displayStep.video != null || displayStep.content?.videoUrl != null) {
        return _buildContentBlockVideoCard(index, isCurrent, displayStep);
      }

      // Default to text card
      return _buildContentBlockTextCard(index, isCurrent, displayStep);
    }

    // Fallback: empty block
    return LessonCardContainer(
      children: [
        Text(
          block.displayTitle,
          style: AppTextStyles.cardTitle(),
        ),
        const SizedBox(height: 24),
        _buildActionButtonsRowForContentBlock(index, isCurrent),
      ],
    );
  }

  /// Navigate to a specific block by ID (for cross-block jumps).
  /// When jumping backward, resets all blocks from the target through
  /// the current position so the user must redo them.
  Future<void> _navigateToBlock(String blockId) async {
    final targetIndex = _contentBlocks.indexWhere((b) => b.blockId == blockId);
    if (targetIndex < 0) {
      // Cross-lesson jump: find which lesson contains this block
      final target = widget.course.findLessonForBlock(blockId);
      if (target == null) {
        return;
      }
      // Save current lesson's progress before jumping to another lesson
      await _saveProgress();
      final targetLesson = _course.lessons[target.lessonIndex];
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        shellPageRoute(
          context,
          builder: (context) => LessonDetailPage(
            course: _course,
            lesson: targetLesson,
            lessonIndex: target.lessonIndex,
            userCourseId: widget.userCourseId,
            initialBlockId: blockId,
          ),
        ),
      );
      return;
    }

    // Determine the range of blocks to reset.
    // Backward jump: reset target through current (inclusive).
    // Forward jump: only reset the target block itself.
    final resetFrom = targetIndex;
    final resetTo = targetIndex < _currentBlockIndex
        ? _currentBlockIndex
        : targetIndex;

    for (int i = resetFrom; i <= resetTo; i++) {
      final bid = _contentBlocks[i].blockId;
      _stepProgress.remove(bid);
      _contentBlocks[i] = _contentBlocks[i].copyWith(
        isCompleted: false,
        selectedOptionId: null,
      );
      _blockResetCounter[bid] = (_blockResetCounter[bid] ?? 0) + 1;
    }

    setState(() {
      _currentBlockIndex = targetIndex;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToBlock(targetIndex);
    });
  }

  /// Save step progress for a step-based block
  void _saveStepProgress(int index, StepProgressData progress) {
    _stepProgress[progress.blockId] = progress;
  }

  Widget _buildAtomicDisplayCard(
          int index, bool isCurrent, ContentBlock block) =>
      LessonAtomicDisplayCard(
        block: block,
        actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent),
      );

  Widget _buildAtomicQuestionCard(
      int index, bool isCurrent, ContentBlock block) {
    final question = block.atomicQuestion;
    final isOpen = question != null && question.isOpen;
    final openInput = isOpen
        ? _buildOpenQuestionInput(index, block, question)
        : null;
    // Open questions persist a draft into selectedOptionId as the user types
    // (BR-A7AHKR), so confirm is gated on the answer being checked/evaluated —
    // not on there being any text. Choice questions still gate on a selection.
    final canConfirm = isOpen
        ? _answeredBlocks.contains(index)
        : block.selectedOptionId != null;
    return LessonAtomicQuestionCard(
      block: block,
      question: question,
      isAnswered: _answeredBlocks.contains(index),
      evaluate: widget.course.quizEvaluate,
      openInput: openInput,
      actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent,
          canConfirm: canConfirm),
      onOptionSelected: (optionId) =>
          _handleAtomicOptionSelected(index, optionId),
    );
  }

  Widget _buildOpenQuestionInput(
      int index, ContentBlock block, AtomicQuestion question) {
    // Seed the controller from the persisted draft so a typed-but-not-yet
    // confirmed answer survives leaving/reloading the lesson (BR-A7AHKR).
    _textControllers[index] ??=
        TextEditingController(text: block.selectedOptionId ?? '');
    final controller = _textControllers[index]!;
    final userAnswer = controller.text.trim();
    final isAnswered =
        _answeredBlocks.contains(index) || block.isCompleted;
    // An AI verdict, when present, overrides the exact-match comparison —
    // which accepts any variant listed on its own line (BR-RBUR29).
    final ai = _aiResults[index];
    final isCorrect = ai?.isCorrect ??
        matchesExpectedAnswer(userAnswer, question.correctAnswer);
    return LessonAtomicOpenQuestionInput(
      controller: controller,
      question: question,
      userAnswer: userAnswer,
      isAnswered: isAnswered,
      isCorrect: isCorrect,
      showEvaluation: widget.course.quizEvaluate,
      feedback: ai?.feedback,
      aiFeedback: ai?.feedbackText,
      isEvaluating: _evaluatingIndex == index,
      // Photo + retry wiring for AI-evaluated open answers (BR-P745Q8).
      pickedPhoto: _pickedPhotos[index],
      uploadedPhotoName: _photoNames[index],
      isUploadingPhoto: _uploadingPhotoIndexes.contains(index),
      photoUnreadable: _unreadablePhotoIndexes.contains(index),
      evaluationFailure: _evaluationFailures[index],
      onPhotoPicked: (photo) => setState(() {
        _pickedPhotos[index] = photo;
        _photoNames.remove(index);
        _unreadablePhotoIndexes.remove(index);
      }),
      onPhotoRemoved: () => setState(() {
        _pickedPhotos.remove(index);
        _photoNames.remove(index);
        _unreadablePhotoIndexes.remove(index);
      }),
      onRetryEvaluation: () =>
          unawaited(_checkOpenAnswerWithAi(index, block, question, userAnswer)),
      onChanged: () => _onOpenAnswerChanged(index),
      onCheckAnswer: () => _checkOpenAnswer(index, block, question),
    );
  }

  /// Persist an in-progress open-question draft as the user types (BR-A7AHKR).
  ///
  /// The draft is mirrored into `selectedOptionId` (which `_saveProgress`
  /// persists as `block_answers`) so it is restored on the next lesson open,
  /// and the DB write is debounced to avoid a round-trip per keystroke. The
  /// confirm checkmark stays gated on `_answeredBlocks` — see
  /// `_buildAtomicQuestionCard` — so a draft never lets the student skip the
  /// "Zkontrolovat" (check/AI-eval) step.
  void _onOpenAnswerChanged(int index) {
    final controller = _textControllers[index];
    if (controller == null) return;
    setState(() {
      _contentBlocks[index] =
          _contentBlocks[index].copyWith(selectedOptionId: controller.text);
    });
    _openAnswerSaveDebounce?.cancel();
    _openAnswerSaveDebounce = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_saveProgress()),
    );
  }

  /// Check open answer and mark block as completed.
  ///
  /// Every open answer goes through the API first (BR-N26ACB) — `ai_evaluation`
  /// only decides whether the student sees the AI's feedback or a plain
  /// right/wrong with the solution. When the AI cannot be reached the answer
  /// is compared with the expected one instead.
  void _checkOpenAnswer(int index, ContentBlock block, AtomicQuestion question) {
    if (_evaluatingIndex != null) return;

    final controller = _textControllers[index];
    if (controller == null) {
      return;
    }

    final userAnswer = controller.text.trim();
    final hasPhoto = _pickedPhotos[index] != null || _photoNames[index] != null;
    if (userAnswer.isEmpty && !hasPhoto) {
      return;
    }

    unawaited(_checkOpenAnswerWithAi(index, block, question, userAnswer));
  }

  Future<void> _checkOpenAnswerWithAi(
    int index,
    ContentBlock block,
    AtomicQuestion question,
    String userAnswer,
  ) async {
    setState(() {
      _evaluatingIndex = index;
      _evaluationFailures.remove(index);
    });

    final evaluator = ref.read(aiAnswerEvaluatorProvider);

    // Upload an attached photo first. A failed upload is not fatal — the answer
    // may also have text, and the picked file stays so a retry needs no new
    // picture.
    String? photoName = _photoNames[index];
    if (question.allowPhoto && _pickedPhotos[index] != null && photoName == null) {
      setState(() => _uploadingPhotoIndexes.add(index));
      final uploaded = await evaluator.uploadPhoto(
        bytes: _pickedPhotos[index]!.bytes,
        filename: _pickedPhotos[index]!.filename,
        courseId: widget.course.id,
      );
      if (!mounted) return;
      setState(() {
        _uploadingPhotoIndexes.remove(index);
        if (uploaded != null) _photoNames[index] = uploaded.name;
      });
      photoName = uploaded?.name;
    }

    final outcome = await evaluator.evaluate(
      question: block.content ?? '',
      studentAnswer: userAnswer,
      photoName: photoName,
      help: block.atomicHelp,
      solution: question.solution,
      correctAnswer: question.correctAnswer,
      criteria: question.aiCriteria,
      criteriaList: question.aiCriteriaList,
    );

    if (!mounted) return;
    setState(() => _evaluatingIndex = null);

    // The student may have moved on while the call was in flight.
    if (_answeredBlocks.contains(index)) return;

    if (!outcome.isSuccess) {
      // Offline, or the AI gave nothing back: grade by comparison with the
      // expected answer instead (BR-N26ACB), `ai_evaluation` on or off. The
      // student gets right/wrong and the solution, never the expected answer.
      if (userAnswer.isNotEmpty) {
        setState(() => _aiResults.remove(index));
        _applyOpenAnswer(index, block, question, userAnswer,
            photoName: photoName);
        return;
      }
      // A photo on its own has nothing to compare. The block stays unanswered
      // so the student can try again, but the attempt is still recorded — a
      // failure a teacher cannot see is a failure nobody fixes.
      setState(() => _evaluationFailures[index] = outcome.failure!);
      _recordOpenAnswer(index, block, question, userAnswer,
          photoName: photoName, failed: true);
      return;
    }

    setState(() {
      _aiResults[index] = outcome.result!;
      if (outcome.result!.photoUnreadable) _unreadablePhotoIndexes.add(index);
    });
    _applyOpenAnswer(index, block, question, userAnswer, photoName: photoName);
  }

  void _applyOpenAnswer(
    int index,
    ContentBlock block,
    AtomicQuestion question,
    String userAnswer, {
    String? photoName,
  }) {
    // Store the answer and mark block as answered (shows result + solution)
    // The user must then tap the checkmark to confirm and advance.
    setState(() {
      _contentBlocks[index] = _contentBlocks[index].copyWith(
        selectedOptionId: userAnswer,
      );
      _answeredBlocks.add(index);
    });

    // Flush the checked answer now rather than waiting on the typing debounce,
    // so it survives leaving the lesson before confirming the block (BR-A7AHKR).
    _openAnswerSaveDebounce?.cancel();
    unawaited(_saveProgress());

    _recordOpenAnswer(index, block, question, userAnswer, photoName: photoName);
  }

  /// Queue the attempt so a teacher can read what the student wrote.
  ///
  /// Goes through the sync queue, not a direct post: an answer given offline
  /// used to vanish, which is the one case an offline-first app exists for.
  void _recordOpenAnswer(
    int index,
    ContentBlock block,
    AtomicQuestion question,
    String userAnswer, {
    String? photoName,
    bool failed = false,
  }) {
    final ai = _aiResults[index];
    final isCorrect = failed
        ? false
        : ai?.isCorrect ??
            matchesExpectedAnswer(userAnswer, question.correctAnswer);

    unawaited(ref.read(openAnswerRepositoryProvider).record(
          // Fresh id per submission, so a retry appends an attempt instead of
          // overwriting the one that failed.
          attemptId: OpenAnswerRepository.newAttemptId(),
          courseId: widget.course.id,
          lessonId: widget.lesson.id,
          blockId: block.blockId,
          answerText: userAnswer,
          photoName: photoName,
          isCorrect: isCorrect,
          failed: failed,
          evaluatedByAi: !failed && ai != null,
          aiScore: failed ? null : ai?.score,
          aiFeedback: failed ? null : ai?.feedbackText,
          aiModel: failed ? null : ai?.model,
          feedback: failed ? null : ai?.feedback?.toJson(),
          criteriaScores: failed ? const [] : (ai?.criteriaScores ?? const []),
          promptVersion: failed ? null : ai?.promptVersion,
          gradingBasis: OpenAnswerRepository.gradingBasisFor(
            question: block.content ?? '',
            expectedAnswer: question.correctAnswer,
            solution: question.solution,
            criteria: question.aiCriteriaList,
          ),
        ));
  }

  /// Handle option selection for atomic question blocks
  void _handleAtomicOptionSelected(int blockIndex, String optionId) {
    setState(() {
      _contentBlocks[blockIndex] = _contentBlocks[blockIndex].copyWith(
        selectedOptionId: optionId,
      );
    });
  }

  Widget _buildContentBlockTextCard(
          int index, bool isCurrent, BlockStep step) =>
      LessonContentTextCard(
        step: step,
        actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent),
      );

  Widget _buildContentBlockImageCard(
          int index, bool isCurrent, BlockStep step) =>
      LessonContentImageCard(
        step: step,
        actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent),
      );

  Widget _buildContentBlockVideoCard(
          int index, bool isCurrent, BlockStep step) =>
      LessonContentVideoCard(
        step: step,
        actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent),
      );

  Widget _buildContentBlockKeyConceptsCard(
          int index, bool isCurrent, BlockStep step) =>
      LessonContentKeyConceptsCard(
        step: step,
        actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent),
      );

  Widget _buildContentBlockQuizCard(
    int index,
    bool isCurrent,
    BlockStep? displayStep,
    BlockStep evaluationStep,
  ) {
    final block = _contentBlocks[index];
    final selectedId = block.selectedOptionId;
    final config = evaluationStep.evaluationConfig;
    final options = config?.options ?? [];
    final isFreetextQuiz = options.isEmpty &&
        (config?.type == 'exact_match' || config?.type == 'free_text');

    if (isFreetextQuiz) {
      _textControllers[index] ??=
          TextEditingController(text: selectedId ?? '');
    }

    return LessonContentQuizCard(
      block: block,
      displayStep: displayStep,
      evaluationStep: evaluationStep,
      freetextController: isFreetextQuiz ? _textControllers[index] : null,
      actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent,
          canConfirm: selectedId != null),
      onFreetextChanged: (value) {
        setState(() {
          _contentBlocks[index] =
              block.copyWith(selectedOptionId: value);
        });
        _saveProgress();
      },
      onOptionSelected: (optionId) {
        setState(() {
          _contentBlocks[index] = block.copyWith(selectedOptionId: optionId);
        });
        _saveProgress();
      },
    );
  }

  /// Action buttons row for ContentBlock
  Widget _buildActionButtonsRowForContentBlock(int index, bool isCurrent,
      {bool canConfirm = true}) {
    return LessonContentActionButtonsRow(
      block: _contentBlocks[index],
      isCurrent: isCurrent,
      canConfirm: canConfirm,
      isAnswered: _answeredBlocks.contains(index),
      onBookmark: () => _toggleBookmark(index),
      onLike: () => _toggleLike(index),
      onDislike: () => _toggleDislike(index),
      // Legacy/atomic cards are not driven by BlockStepEngine, so the block's
      // own cursor is the only step they have — the same one the row's
      // `block.hasHint` gate reads.
      onShowHint: () =>
          _showHintDialog(index, _contentBlocks[index].currentStep?.stepId),
      onMarkAnswered: () => setState(() => _answeredBlocks.add(index)),
      onConfirm: () => _confirmBlock(index),
    );
  }

  Widget _buildActionButtonsRow(int index, bool isCurrent,
      {bool showConfirm = true}) {
    return LessonLegacyActionButtonsRow(
      block: _legacyBlocks[index],
      isCurrent: isCurrent,
      showConfirm: showConfirm,
      onBookmark: () => _toggleBookmark(index),
      onLike: () => _toggleLike(index),
      onDislike: () => _toggleDislike(index),
      onConfirm: () => _confirmBlock(index),
    );
  }

  Widget _buildTextCard(int index, bool isCurrent) =>
      LessonLegacyTextCard(
        block: _legacyBlocks[index],
        actionRow: _buildActionButtonsRow(index, isCurrent),
      );

  Widget _buildImageCard(int index, bool isCurrent) =>
      LessonLegacyImageCard(
        block: _legacyBlocks[index],
        actionRow: _buildActionButtonsRow(index, isCurrent),
      );

  Widget _buildVideoCard(int index, bool isCurrent) =>
      LessonLegacyVideoCard(
        block: _legacyBlocks[index],
        actionRow: _buildActionButtonsRow(index, isCurrent),
      );

  Widget _buildKeyConceptsCard(int index, bool isCurrent) =>
      LessonLegacyKeyConceptsCard(
        block: _legacyBlocks[index],
        actionRow: _buildActionButtonsRow(index, isCurrent),
      );

  Widget _buildQuizCard(int index, bool isCurrent) {
    final block = _legacyBlocks[index];
    return LessonLegacyQuizCard(
      block: block,
      actionRow: _buildActionButtonsRow(index, isCurrent),
      onOptionSelected: (optionId) {
        setState(() {
          _legacyBlocks[index] = block.copyWith(selectedOptionId: optionId);
        });
      },
    );
  }

  /// Navigate to Cvičení (default_practice + bookmarked blocks)
  void _navigateToCviceni() {
    final bookmarkNotifier = ref.read(bookmarkProvider.notifier);

    // Hydrate bookmarks with full block data (handles step-level bookmarks
    // that may have been loaded from DB without content after app restart)
    final allBlocks = <ContentBlock>[];
    for (final lesson in widget.course.lessons) {
      allBlocks.addAll(widget.course.getBlocksForLesson(lesson.id));
    }
    bookmarkNotifier.hydrateForCourse(widget.course.id, allBlocks);

    final exerciseBlocks = widget.course.getExerciseBlocks(
      bookmarkNotifier.getBookmarksForCourse(widget.course.id),
      completedBlockIds: _allCompletedBlockIds,
      removedBlockIds: _removedPracticeBlocks,
    );

    if (exerciseBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bookmark_border, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.courseNoBookmarks,
                  style: AppTextStyles.body(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Reset progress so each Cvičení session starts fresh
    _exerciseProgress.reset();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(
          questionBlocks: exerciseBlocks,
          courseTitle: widget.course.title,
          courseId: widget.course.id,
          progress: _exerciseProgress,
          onlyOnce: widget.course.onlyOnce,
          evaluate: true,
          isExercise: true,
        ),
      ),
    );
  }

  /// Navigate to Kvíz — ten ELO-matched questions, like the global quiz
  /// (BR-WRMW7W); see [courseQuizBlocks].
  Future<void> _navigateToKviz() async {
    final questionBlocks =
        await courseQuizBlocks(ref, widget.course, _kvizProgress);
    if (!mounted) return;

    if (questionBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.courseNoQuestions,
            style: AppTextStyles.body(),
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(
          questionBlocks: questionBlocks,
          courseTitle: widget.course.title,
          courseId: widget.course.id,
          progress: _kvizProgress,
          onlyOnce: widget.course.onlyOnce,
        ),
      ),
    );
  }

  // ── Wide layout rail ──────────────────────────────────────────────────

  /// Width of the lesson page's right-hand rail.
  static const double _railWidth = 340;

  /// How many lessons the rail lists before "show all".
  static const int _railLessonLimit = 3;

  /// Expanded state of the rail's lesson list.
  bool _railShowAllLessons = false;

  List<Widget> _buildLessonRail() {
    final lessons = _course.lessons;
    final done =
        lessons.where((l) => l.status == LessonStatus.completed).length;

    return [
      ProgressRingCard(
        lessonsDone: done,
        lessonsTotal: lessons.length,
        hintOverride: AppStrings.courseTrophyHint,
        showBar: true,
        trailingIcon: Icons.emoji_events_outlined,
        // The lesson's reward, which used to live in the header's badge.
        xpLabel: widget.lesson.xpReward > 0
            ? '+${widget.lesson.xpReward} XP'
            : null,
      ),
      const SizedBox(height: 16),
      _buildAiHelpCard(),
      const SizedBox(height: 16),
      _buildRailLessonList(lessons),
    ];
  }

  Widget _buildAiHelpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.lessonAiHelpTitle, style: AppTextStyles.heading4()),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/skins_bg.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppStrings.lessonAiHelpQuestion,
                        style: AppTextStyles.bodySemiBold()),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.lessonAiHelpBody,
                      style: AppTextStyles.bodySmall(
                          color: AppColors.primaryDark64),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            // Same entry point the in-block "ask AI" action uses, so the chat
            // opens with this lesson's context attached.
            onTap: () => _openChatWithContext(
              _currentBlockIndex.clamp(0, (_blockCount - 1).clamp(0, 9999)),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppDecorations.radiusM,
              ),
              child: Text(
                AppStrings.lessonAiHelpButton,
                textAlign: TextAlign.center,
                style: AppTextStyles.actionSmall(color: AppColors.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailLessonList(List<Lesson> lessons) {
    if (lessons.isEmpty) return const SizedBox.shrink();

    final collapsed =
        !_railShowAllLessons && lessons.length > _railLessonLimit;
    final shown =
        collapsed ? lessons.take(_railLessonLimit).toList() : lessons;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${AppStrings.lessonFallbackName(widget.lessonIndex + 1)}: '
            '${widget.lesson.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heading4(),
          ),
          if (_blockCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _completedCount / _blockCount,
                      minHeight: 6,
                      backgroundColor: AppColors.progressTrack,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.progressFill),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_completedCount/$_blockCount',
                  style: AppTextStyles.meta(color: AppColors.primaryDark64),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < shown.length; i++) ...[
            _buildRailLessonRow(shown[i], i),
            if (i < shown.length - 1) const SizedBox(height: 8),
          ],
          if (lessons.length > _railLessonLimit) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () =>
                  setState(() => _railShowAllLessons = !_railShowAllLessons),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: AppDecorations.radiusM,
                  border: Border.all(color: AppColors.primaryDark12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      collapsed
                          ? AppStrings.courseShowAllLessons(lessons.length)
                          : AppStrings.courseShowFewerLessons,
                      style: AppTextStyles.actionSmall(),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      collapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: AppColors.primaryDark64,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRailLessonRow(Lesson lesson, int index) {
    final isCurrent = index == widget.lessonIndex;
    final isDone = lesson.status == LessonStatus.completed;
    final isLocked = lesson.status == LessonStatus.locked && !isCurrent;

    return GestureDetector(
      // Replaces the route rather than stacking lessons, matching
      // [_navigateToNextLesson].
      onTap: isLocked || isCurrent ? null : () => _openLesson(lesson, index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: AppDecorations.radiusM,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: AppTextStyles.badge(
                    color:
                        isCurrent ? AppColors.surface : AppColors.primaryDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySemiBold(),
                  ),
                  Text(
                    AppStrings.courseQuestionsCount(lesson.questionCount),
                    style: AppTextStyles.meta(color: AppColors.primaryDark64),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isDone)
              Icon(Icons.check_circle, size: 20, color: AppColors.success)
            else if (isLocked)
              Icon(Icons.lock_outline,
                  size: 18, color: AppColors.primaryDark48),
          ],
        ),
      ),
    );
  }

  /// Open another lesson of this course from the rail.
  Future<void> _openLesson(Lesson lesson, int index) async {
    if (_pendingSave != null) await _pendingSave;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      shellPageRoute(
        context,
        builder: (context) => LessonDetailPage(
          course: _course,
          lesson: lesson,
          lessonIndex: index,
          userCourseId: widget.userCourseId,
        ),
      ),
    );
  }
}

/// Builds the pre-filled AI-chat context for a lesson [block], scoped to the
/// step the student is currently on.
///
/// [liveStepIndex] is the real step index reported by BlockStepEngine (mirrored
/// via StepProgressData). The block's own `currentStepIndex` is unreliable here
/// (it stays frozen at 0), so we align it from the live value before reading any
/// step-scoped context. Without this alignment a multi-step block — e.g. an
/// answered MCQ step followed by the current open question — leaked the earlier
/// step's question/options/hint into the AI context (BR-J43MA4).
///
/// Kept as a pure top-level function so the context assembly is unit-testable
/// independently of the widget tree.
String buildLessonChatContext({
  required ContentBlock? block,
  required String courseName,
  required String lessonName,
  required int? liveStepIndex,
  String? studentMessage,
  bool includeClosingPrompt = true,
}) {
  // Align the block's step cursor with the engine's live position.
  if (block != null && block.steps.isNotEmpty && liveStepIndex != null) {
    block.currentStepIndex = liveStepIndex.clamp(0, block.steps.length - 1);
  }

  // Step-scoped hint/help now resolve against the aligned currentStepIndex.
  final hint = sanitizeAiContext(block?.currentHint ?? '');
  final help = sanitizeAiContext(block?.currentHelp ?? '');

  // Collect the task text for the current step. Include preceding display /
  // setup steps (they frame the question and were already shown), but skip
  // other evaluation steps — those are separately answered questions whose text
  // must not leak into the context for the step the student is on.
  String blockContent = '';
  if (block != null) {
    if (block.steps.isNotEmpty) {
      final curIdx = block.currentStepIndex;
      final stepTexts = <String>[];
      for (var i = 0; i < block.steps.length && i <= curIdx; i++) {
        final step = block.steps[i];
        if (i != curIdx && step.isEvaluationStep) continue;
        if (step.displayText.isNotEmpty) stepTexts.add(step.displayText);
      }
      blockContent = stepTexts.join('\n');
    } else {
      blockContent = block.displayContent;
    }
  }
  // Drop media links before the 400-char budget is measured, so a long image
  // URL can no longer crowd out the task statement itself (BR-KFHPAR).
  blockContent = sanitizeAiContext(blockContent);

  // For question blocks, include the options for the CURRENT question only.
  String questionInfo = '';
  if (block?.atomicQuestion != null) {
    final q = block!.atomicQuestion!;
    final optionTexts =
        q.options.map((o) => '- ${sanitizeAiContext(o.label)}').join('\n');
    if (optionTexts.isNotEmpty) {
      questionInfo = AppStrings.chatContextQuestionWithOptions(optionTexts);
    }
  } else {
    // V2 step-based question — options come from the current step, not from
    // whichever earlier step happened to have some.
    final cfg = block?.currentStep?.evaluationConfig;
    if (cfg != null) {
      final opts =
          cfg.options.map((o) => '- ${sanitizeAiContext(o.label)}').join('\n');
      if (opts.isNotEmpty) {
        questionInfo = AppStrings.chatContextQuestionWithOptions(opts);
      }
    }
  }

  // Build a natural help request message.
  final contextParts = <String>[
    lessonName.isNotEmpty
        ? AppStrings.chatContextHelpIntroLesson(courseName, lessonName)
        : AppStrings.chatContextHelpIntro(courseName),
    '',
    if (blockContent.isNotEmpty)
      AppStrings.chatContextHelpTaskContent(
          blockContent.length > 400 ? '${blockContent.substring(0, 400)}...' : blockContent),
    if (questionInfo.isNotEmpty) questionInfo,
    if (hint.isNotEmpty) AppStrings.chatContextHelpHint(hint),
    if (help.isNotEmpty) AppStrings.chatContextHelpDetail(help),
    '',
    // The mentor sheet sends the student's question as its own visible message,
    // so it asks for the context without a closing request tacked on.
    if (!includeClosingPrompt)
      ''
    else if (studentMessage != null && studentMessage.isNotEmpty)
      AppStrings.chatContextStudentQuery(studentMessage)
    else
      AppStrings.chatContextFallbackPrompt,
  ];
  return contextParts
      .where((s) => s.isNotEmpty || contextParts.indexOf(s) == 1)
      .join('\n');
}
