import 'dart:convert';
import 'dart:math' show max;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_model.dart';
import '../core/elo/elo_engine.dart';
import '../core/gamification/achievement_evaluator.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/bookmark_provider.dart';
import '../core/providers/practice_providers.dart';
import '../models/chat_models.dart';
import 'chat_detail_page.dart';
import '../core/sync/sync_queue.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/user_course_repository.dart';
import '../widgets/block_step_engine.dart';
import '../models/step_navigation.dart';
import 'quiz_page.dart';
import '../core/strings/app_strings.dart';
import 'lesson_detail/lesson_header.dart';
import 'lesson_detail/lesson_nav.dart';
import 'lesson_detail/hint_sheet.dart';
import 'lesson_detail/card_container.dart';
import 'lesson_detail/action_button_row.dart';
import 'lesson_detail/legacy_cards.dart';
import 'lesson_detail/content_block_cards.dart';
import 'lesson_detail/atomic_cards.dart';
import 'package:eduai/core/util/silent_log.dart';

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
  late List<GlobalKey> _cardKeys;
  int _currentBlockIndex = 0;
  int _lastRestoredBlockIndex = -1;

  // Track if this was the last lesson and course is now completed
  bool _courseCompleted = false;

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

  // Step progress for step-based blocks (blockId → StepProgressData)
  final Map<String, StepProgressData> _stepProgress = {};

  // Whether saved progress has been loaded from DB (blocks rendering before this)
  bool _progressLoaded = false;

  // Tracks blocks that have been answered/evaluated but not yet confirmed (user must tap checkmark)
  final Set<int> _answeredBlocks = {};

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

    // Track active work time while this lesson is open (BR-9SAH2R).
    ref.read(workTimeTrackerProvider).setLocation(
          courseId: widget.course.id,
          lessonId: widget.lesson.id,
          context: 'lesson',
        );

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
    ref.read(workTimeTrackerProvider).clearLocation();
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

    // Wrong atomic answer → seed a Practice (Cvičení) card before advancing.
    // V2 step blocks handle this via BlockStepEngine's onWrongAnswer callback.
    if (_useContentBlocks && index >= 0 && index < _contentBlocks.length) {
      final block = _contentBlocks[index];
      if (block.isAtomicFormat &&
          block.isQuestionBlock &&
          _atomicAnswerIsWrong(block)) {
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

    try {
      final eloRepo = ref.read(eloRepositoryProvider);
      final syncQueue = ref.read(syncQueueProvider);

      // Get or create the student's ELO profile
      final profile = await eloRepo.getOrCreateProfile(user.id);

      // Cast relation_vector from nullable doubles to non-nullable (engine expects List<double>)
      final castRelation = relationVector.map((e) => e ?? 0.0).toList();

      // Load cached item solve-counts for this block (falls back to zeros)
      final itemPocet = await eloRepo.getItemPocet(block.blockId);

      // Run the ELO engine
      final result = EloEngine.updateTask(
        profilElo: profile.profilElo,
        profilPocet: profile.profilPocet,
        relationVector: castRelation,
        eloVector: eloVector,
        itemPocet: itemPocet,
        score: score,
      );

      if (result.updatedIndices.isEmpty) {
        return;
      }

      // Persist updated profile locally
      await eloRepo.saveProfile(user.id, result.profilElo, result.profilPocet);

      // Persist updated block stats locally (item_pocet + elo_vector)
      await eloRepo.saveBlockStats(
        block.blockId,
        result.itemPocet,
        result.eloVector,
      );

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

      // Enqueue interaction log (CREATE — append-only server log)
      final interactionId = 'elo-${DateTime.now().microsecondsSinceEpoch}';

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
          'elo_vector_snapshot': eloVector,
          'updated_indices': result.updatedIndices,
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

    } catch (e, st) { silentLog('lesson_detail_page', e, st); }
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

          // Sum XP rewards from earned achievements
          final def = config.allAchievements.where((a) => a.id == achievementId).firstOrNull;
          if (def != null && def.xpReward > 0) {
            totalXpReward += def.xpReward;
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
    final nextLesson = widget.course.lessons[nextLessonIndex];

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
        MaterialPageRoute(
          builder: (context) => LessonDetailPage(
            course: widget.course,
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
        // Set confirmed_at for completed blocks (putIfAbsent — don't overwrite)
        for (final blockId in completedBlockIds) {
          blockTimestampsJson.putIfAbsent(blockId, () => {});
          blockTimestampsJson[blockId]!.putIfAbsent(
            'confirmed_at', () => DateTime.now().toUtc().toIso8601String(),
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
    if (!block.type.isInteractiveBlock) return;
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
  bool _atomicAnswerIsWrong(ContentBlock block) {
    final q = block.atomicQuestion;
    if (q == null) return false;
    final answer = block.selectedOptionId;
    if (answer == null || answer.isEmpty) return false;
    if (q.isOpen) {
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
  Future<void> _enqueueFeedback({
    required String blockId,
    required String type,
    String? message,
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
      final syncService = ref.read(syncServiceProvider);
      syncService.sync();
    } catch (e, st) { silentLog('lesson_detail_page', e, st); }
  }

  /// Open AI chat with context about the current block.
  /// Used by go_to: "CHAT"/"LECTURE" and the hint sheet "Zeptat se AI" button.
  void _openChatWithContext(int index, {String? studentMessage}) {
    final block = _useContentBlocks ? _contentBlocks[index] : null;
    final courseName = widget.course.title;
    final lessonName = widget.lesson.title;

    // Gather rich block context
    final hint = block?.currentHint ?? '';
    final help = block?.currentHelp ?? '';

    // Collect all text from the block (all steps)
    String blockContent = '';
    if (block != null) {
      if (block.steps.isNotEmpty) {
        final stepTexts = block.steps
            .map((s) => s.displayText)
            .where((t) => t.isNotEmpty)
            .toList();
        blockContent = stepTexts.join('\n');
      } else {
        blockContent = block.displayContent;
      }
    }

    // For question blocks, include the question and options
    String questionInfo = '';
    if (block?.atomicQuestion != null) {
      final q = block!.atomicQuestion!;
      final optionTexts = q.options.map((o) => '- ${o.text}').join('\n');
      questionInfo = AppStrings.chatContextQuestionWithOptions(optionTexts);
    } else if (block != null) {
      // V2 step-based questions — find evaluation steps
      for (final step in block.steps) {
        if (step.evaluationConfig != null) {
          final opts = step.evaluationConfig!.options.map((o) => '- ${o.text}').join('\n');
          if (opts.isNotEmpty) {
            questionInfo = AppStrings.chatContextQuestionWithOptions(opts);
            break;
          }
        }
      }
    }

    // Build a natural help request message
    final contextParts = <String>[
      lessonName.isNotEmpty
          ? AppStrings.chatContextHelpIntroLesson(courseName, lessonName)
          : AppStrings.chatContextHelpIntro(courseName),
      '',
      if (blockContent.isNotEmpty) AppStrings.chatContextHelpTaskContent(blockContent.length > 400 ? '${blockContent.substring(0, 400)}...' : blockContent),
      if (questionInfo.isNotEmpty) questionInfo,
      if (hint.isNotEmpty) AppStrings.chatContextHelpHint(hint),
      if (help.isNotEmpty) AppStrings.chatContextHelpDetail(help),
      '',
      if (studentMessage != null && studentMessage.isNotEmpty)
        AppStrings.chatContextStudentQuery(studentMessage)
      else
        AppStrings.chatContextFallbackPrompt,
    ];
    final contextMessage = contextParts.where((s) => s.isNotEmpty || contextParts.indexOf(s) == 1).join('\n');

    // Navigate to chat with pre-filled context
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          sessionId: '', // empty = create new session
          sessionTitle: lessonName.isNotEmpty ? lessonName : courseName,
          persona: ChatPersona.mathMentor,
          initialContext: contextMessage,
        ),
      ),
    );
  }

  void _showHintDialog(int index) {
    final block = _useContentBlocks ? _contentBlocks[index] : null;
    if (block == null || !block.hasHint) return;

    showLessonHintSheet(
      context: context,
      block: block,
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
      onSavePractice: () {
        // Actually save the bookmark for practice
        final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
        final currentBlock = _contentBlocks[index];
        if (!currentBlock.isBookmarked) {
          bookmarkNotifier.addBookmark(widget.course.id, currentBlock, lessonId: widget.lesson.id);
          setState(() {
            _contentBlocks[index] = currentBlock.copyWith(isBookmarked: true);
          });
        }
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
      onAskAi: () {
        // Track assistant (Ask-AI) opens for the admin postup timeline (BR-BBK5FP).
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
        _openChatWithContext(index);
      },
      onSendFeedback: (studentMessage) {
        // Also save as feedback
        _enqueueFeedback(
          blockId: block.blockId,
          type: 'question',
          message: studentMessage,
        );
        _openChatWithContext(index, studentMessage: studentMessage);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        // Always wired: the engine offers the "?" for the step on screen, and
        // `_showHintDialog` reads that step's hint.
        onHintRequested: () => _showHintDialog(index),
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
      final targetLesson = widget.course.lessons[target.lessonIndex];
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LessonDetailPage(
            course: widget.course,
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
    final openInput = (question != null && question.isOpen)
        ? _buildOpenQuestionInput(index, block, question)
        : null;
    return LessonAtomicQuestionCard(
      block: block,
      question: question,
      isAnswered: _answeredBlocks.contains(index),
      evaluate: widget.course.quizEvaluate,
      openInput: openInput,
      actionRow: _buildActionButtonsRowForContentBlock(index, isCurrent,
          canConfirm: block.selectedOptionId != null),
      onOptionSelected: (optionId) =>
          _handleAtomicOptionSelected(index, optionId),
    );
  }

  Widget _buildOpenQuestionInput(
      int index, ContentBlock block, AtomicQuestion question) {
    _textControllers[index] ??= TextEditingController();
    final controller = _textControllers[index]!;
    final userAnswer = controller.text.trim();
    final correctAnswer = question.correctAnswer?.trim() ?? '';
    final isAnswered =
        _answeredBlocks.contains(index) || block.isCompleted;
    final isCorrect =
        userAnswer.toLowerCase() == correctAnswer.toLowerCase();
    return LessonAtomicOpenQuestionInput(
      controller: controller,
      question: question,
      userAnswer: userAnswer,
      correctAnswer: correctAnswer,
      isAnswered: isAnswered,
      isCorrect: isCorrect,
      showEvaluation: widget.course.quizEvaluate,
      onChanged: () => setState(() {}),
      onCheckAnswer: () => _checkOpenAnswer(index, block, question),
    );
  }

  /// Check open answer and mark block as completed
  void _checkOpenAnswer(int index, ContentBlock block, AtomicQuestion question) {

    final controller = _textControllers[index];
    if (controller == null) {
      return;
    }

    final userAnswer = controller.text.trim();
    if (userAnswer.isEmpty) {
      return;
    }


    // Store the answer and mark block as answered (shows result + solution)
    // The user must then tap the checkmark to confirm and advance.
    setState(() {
      _contentBlocks[index] = _contentBlocks[index].copyWith(
        selectedOptionId: userAnswer,
      );
      _answeredBlocks.add(index);
    });
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
      onShowHint: () => _showHintDialog(index),
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

  /// Navigate to Kvíz (all question blocks)
  void _navigateToKviz() {
    final questionBlocks = widget.course.getAllQuestionBlocks();

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
}

