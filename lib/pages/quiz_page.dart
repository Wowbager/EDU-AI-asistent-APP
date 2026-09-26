import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../core/elo/elo_engine.dart';
import '../data/repositories/user_course_repository.dart';
import '../core/network/api_endpoints.dart';
import '../core/utils/image_url.dart';
import '../core/providers/bookmark_provider.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/practice_providers.dart';
import '../core/practice/grade_calculator.dart';
import '../core/sync/sync_queue.dart';
import '../core/theme/app_theme.dart';
import '../models/block_model.dart';
import '../models/step_navigation.dart';
import '../widgets/block_step_engine.dart';
import '../widgets/markdown_latex_widget.dart';
import '../widgets/step_content_renderer.dart';
import '../core/strings/app_strings.dart';
import 'package:eduai/core/util/silent_log.dart';
import '../models/chat_models.dart';
import 'chat_detail_page.dart';

/// Holds quiz answer state so progress survives page reopens.
class QuizProgress {
  int currentIndex = 0;
  int correctAnswers = 0;
  final Map<int, String?> selectedAnswers = {};
  final Map<int, Set<String>> selectedMultiAnswers = {};
  final Map<int, bool> answeredFlags = {};
  final Map<int, bool> correctFlags = {};
  final Map<int, String> textAnswers = {};
  /// V2 block step-level progress keyed by question index.
  final Map<int, StepProgressData> v2Progress = {};

  void reset() {
    currentIndex = 0;
    correctAnswers = 0;
    selectedAnswers.clear();
    selectedMultiAnswers.clear();
    answeredFlags.clear();
    correctFlags.clear();
    textAnswers.clear();
    v2Progress.clear();
  }
}

/// Quiz Page for practicing question blocks from a course
class QuizPage extends ConsumerStatefulWidget {
  final List<ContentBlock> questionBlocks;
  final String courseTitle;
  final String courseId;
  final QuizProgress? progress;
  final bool evaluate;
  final bool onlyOnce;
  /// True when launched as an exercise (Cvičení) — affects ELO handling and
  /// completion flow. False = full course quiz.
  final bool isExercise;

  /// True when launched as an FSRS practice session (from PracticePage).
  /// Each answered block is graded and fed back into the FSRS scheduler
  /// so the card is rescheduled.
  final bool isFsrsPractice;

  /// True for in-course/in-lesson "Procvičování" launches. Enables the display
  /// self-rating bar (Nevím/Připomeň/Jde to/Pamatuji) and hides the AI-mentor
  /// robot, matching the dashboard practice UX — WITHOUT switching question
  /// blocks to full FSRS grading (that stays gated on [isFsrsPractice]).
  final bool selfRateDisplayBlocks;

  const QuizPage({
    super.key,
    required this.questionBlocks,
    required this.courseTitle,
    required this.courseId,
    this.progress,
    this.evaluate = false,
    this.onlyOnce = false,
    this.isExercise = false,
    this.isFsrsPractice = false,
    this.selfRateDisplayBlocks = false,
  });

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  /// Whether display/content blocks are self-rated (four rating buttons) rather
  /// than shown with a plain "Pokračovat" bar. True for both dashboard FSRS
  /// practice and in-course/in-lesson "Procvičování".
  bool get _selfRateDisplays =>
      widget.isFsrsPractice || widget.selfRateDisplayBlocks;

  late final DateTime _startTime;
  late int _currentQuestionIndex;
  late int _correctAnswers;
  int _answeredQuestions = 0;

  // Answer state per question (by index)
  late Map<int, String?> _selectedAnswers;
  late Map<int, Set<String>> _selectedMultiAnswers;
  late Map<int, bool> _answeredFlags;
  late Map<int, bool> _correctFlags;
  final Map<int, TextEditingController> _textControllers = {};

  // Saved step progress for V2 blocks (by question index)
  final Map<int, StepProgressData> _v2Progress = {};

  // Timestamp when each question was answered (by index)
  final Map<int, DateTime> _answerTimestamps = {};

  // Timestamp when each question was first shown (by index). Combined with
  // _answerTimestamps this gives the per-block solve duration that the
  // server records on `elo_interactions.opened_at` / `confirmed_at`.
  final Map<int, DateTime> _questionOpenedAt = {};

  // Tracks hint/help usage per question index for ELO score penalty.
  // 0 = no hint, 1 = hint shown, 2 = help (detailed explanation) shown.
  final Map<int, int> _hintUsage = {};

  // Detailed hint/help tracking per block ID for progress persistence.
  final Map<String, Map<String, dynamic>> _hintHelpTracking = {};

  // Guards against duplicate quiz-attempt submission from rapid taps,
  // hot reloads, or retries. Once true, stays true for the page's lifetime.
  bool _hasSubmittedAttempt = false;

  // FSRS practice session tally — accumulated as each card is reviewed and
  // shown in the end-of-session summary (only meaningful when isFsrsPractice).
  int _fsrsXpEarned = 0;
  int _fsrsReviewedCount = 0;
  int _fsrsCorrectCount = 0;

  /// Controller for V2 blocks — lets this page's bottom bar drive the engine.
  final BlockStepEngineController _engineController = BlockStepEngineController();

  // Pooled video/audio players for FSRS-practice display cards. Display blocks
  // in practice are rendered by this page (not BlockStepEngine), so they need
  // their own controller pool to play step videos/audio instead of a static
  // placeholder — same pattern as BlockStepEngine (BR-27DCT3).
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, VideoPlayerController> _audioControllers = {};

  ContentBlock get _currentBlock => widget.questionBlocks[_currentQuestionIndex];

  /// When evaluate is off, hide answers (no feedback). When on, show feedback.
  bool get _currentBlockHidesAnswers => !widget.evaluate;

  /// True unless this is an exercise launched from lesson_detail_page
  /// (which handles its own ELO). Quiz-only courses also get ELO.
  bool get _isQuizMode => !widget.isExercise;

  int get _totalCards => widget.questionBlocks.length;
  int get _totalQuestions => widget.questionBlocks.where((b) =>
      b.atomicQuestion != null || b.hasV2Steps).length;
  bool get _isCurrentAnswered => _answeredFlags[_currentQuestionIndex] ?? false;
  bool get _isCurrentCorrect => _correctFlags[_currentQuestionIndex] ?? false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Track active work time while this quiz is open (BR-9SAH2R).
    ref.read(workTimeTrackerProvider).setLocation(
          courseId: widget.courseId,
          context: 'quiz',
        );
    // Listen for V2 engine selection changes to update the bottom bar.
    _engineController.addListener(_onEngineControllerChanged);
    final p = widget.progress;
    if (p != null && p.answeredFlags.isNotEmpty) {
      // Restore saved in-memory progress
      _currentQuestionIndex = p.currentIndex;
      _correctAnswers = p.correctAnswers;
      _selectedAnswers = Map.of(p.selectedAnswers);
      _selectedMultiAnswers = {for (final e in p.selectedMultiAnswers.entries) e.key: Set.of(e.value)};
      _answeredFlags = Map.of(p.answeredFlags);
      _correctFlags = Map.of(p.correctFlags);
      _answeredQuestions = _answeredFlags.values.where((v) => v).length;
      for (final entry in p.textAnswers.entries) {
        _textControllers[entry.key] = TextEditingController(text: entry.value);
      }
      _v2Progress.addAll(p.v2Progress);
    } else {
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _selectedAnswers = {};
      _selectedMultiAnswers = {};
      _answeredFlags = {};
      _correctFlags = {};
      // In-memory cache empty — try DB so progress survives app restarts /
      // navigating away to other courses. Non-blocking: UI starts at q1
      // and jumps when hydration completes.
      _hydrateFromDb();
    }
    // Record opened_at for the question we land on (resumed or fresh).
    _questionOpenedAt[_currentQuestionIndex] = DateTime.now().toUtc();
  }

  /// Mark `index` as opened (first reveal) for solve-time tracking. Safe to
  /// call multiple times — only the first call wins so navigating back
  /// doesn't reset the clock for a question already seen.
  void _markQuestionOpened(int index) {
    _questionOpenedAt.putIfAbsent(index, () => DateTime.now().toUtc());
  }

  /// Restore quiz state from user_courses.progressData (persisted by
  /// _persistPartialProgress). Lands on the first unanswered question so the
  /// student keeps practising where they left off.
  Future<void> _hydrateFromDb() async {
    // FSRS practice spans multiple courses and reschedules cards via the FSRS
    // card table, not the per-course quiz-resume store. Restoring from a
    // course's progressData would pre-mark already-reviewed-but-still-due cards
    // and skip them, launching fewer cards than the queue holds (BR-CNSK2C).
    if (widget.isFsrsPractice) return;
    try {
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user == null) return;
      final db = ref.read(appDatabaseProvider);
      final courseRepo = ref.read(userCourseRepositoryProvider);

      final localCourse = await db.getCourseByFieldCourseId(widget.courseId);
      if (localCourse == null) return;
      final userCourse =
          await db.getUserCourseByUserAndCourse(user.id, localCourse.id);
      if (userCourse == null) return;
      final fresh = await courseRepo.getUserCourseById(userCourse.id);
      final pd = fresh?.progressData ?? const {};

      // Skip if quiz isn't in progress (fresh or already completed).
      if (pd['quiz_in_progress'] != true) return;
      final answersRaw = pd['quiz_answers'];
      if (answersRaw is! Map) return;

      final indexById = <String, int>{
        for (var i = 0; i < widget.questionBlocks.length; i++)
          widget.questionBlocks[i].blockId: i,
      };

      final restoredAnswered = <int, bool>{};
      final restoredCorrect = <int, bool>{};
      final restoredSelected = <int, String?>{};
      final restoredMulti = <int, Set<String>>{};
      int correctCount = 0;
      for (final entry in answersRaw.entries) {
        final idx = indexById[entry.key as String];
        if (idx == null) continue;
        final m = entry.value;
        if (m is! Map) continue;
        if (m['is_answered'] != true) continue;
        restoredAnswered[idx] = true;
        final isCorrect = m['is_correct'] == true;
        restoredCorrect[idx] = isCorrect;
        if (isCorrect) correctCount++;
        final sa = m['selected_answer'];
        if (sa is String) restoredSelected[idx] = sa;
        final sm = m['selected_multi'];
        if (sm is List) {
          restoredMulti[idx] = sm.map((e) => e.toString()).toSet();
        }
      }

      if (restoredAnswered.isEmpty) return;

      // Land on first unanswered question (fall back to saved index, then 0).
      final savedIndex = (pd['quiz_current_index'] as int?) ?? 0;
      int target = savedIndex.clamp(0, widget.questionBlocks.length - 1);
      while (target < widget.questionBlocks.length &&
          (restoredAnswered[target] ?? false)) {
        target++;
      }
      if (target >= widget.questionBlocks.length) {
        target = savedIndex.clamp(0, widget.questionBlocks.length - 1);
      }

      if (!mounted) return;
      setState(() {
        _answeredFlags = restoredAnswered;
        _correctFlags = restoredCorrect;
        _selectedAnswers = restoredSelected;
        _selectedMultiAnswers = restoredMulti;
        _correctAnswers = correctCount;
        _answeredQuestions = restoredAnswered.length;
        _currentQuestionIndex = target;
        _markQuestionOpened(target);
        // Restore open-text controllers from selected_answer (open answers
        // get stored under selected_answer in _persistPartialProgress).
        for (final entry in restoredSelected.entries) {
          final value = entry.value;
          if (value != null && value.isNotEmpty) {
            _textControllers[entry.key] = TextEditingController(text: value);
          }
        }
      });
    } catch (e, st) {
      silentLog('quiz_page:hydrate', e, st);
    }
  }

  @override
  void dispose() {
    ref.read(workTimeTrackerProvider).clearLocation();
    _engineController.removeListener(_onEngineControllerChanged);
    _engineController.dispose();
    // Save progress back before disposing
    _saveProgress();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _disposeMediaControllers();
    super.dispose();
  }

  void _disposeMediaControllers() {
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    _videoControllers.clear();
    for (final c in _audioControllers.values) {
      c.dispose();
    }
    _audioControllers.clear();
  }

  VideoPlayerController? _getVideoController(String url) {
    return _videoControllers.putIfAbsent(url, () {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      controller.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((e) {
        debugPrint('[QuizPage] video init failed for $url: $e');
        if (mounted) setState(() {});
      });
      return controller;
    });
  }

  VideoPlayerController? _getAudioController(String url) {
    return _audioControllers.putIfAbsent(url, () {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      controller.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((e) {
        debugPrint('[QuizPage] audio init failed for $url: $e');
        if (mounted) setState(() {});
      });
      return controller;
    });
  }

  void _onEngineControllerChanged() {
    // Rebuild the bottom bar when the engine's pending answer state changes.
    if (mounted) setState(() {});
  }

  Widget _buildCardActionButtons(int index) {
    final block = widget.questionBlocks[index];
    final showHint = block.hasHint;
    // Hide the AI-mentor robot in practice contexts (BR-ZDYA83); keep it for
    // real course quizzes/exercises.
    final showMentor = widget.evaluate && !_selfRateDisplays;

    if (!showHint && !showMentor) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHint)
                _actionButton(
                  icon: Icons.help_outline,
                  isActive: false,
                  onTap: () => _showHintBottomSheet(block),
                ),
              if (showMentor)
                _actionButton(
                  icon: Icons.smart_toy_outlined,
                  isActive: false,
                  activeColor: AppColors.primary,
                  onTap: () => _openChatWithContext(index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required bool isActive,
    Color? activeColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 22,
          color: isActive
              ? (activeColor ?? AppColors.quizPurple)
              : AppColors.primaryDark64,
        ),
      ),
    );
  }

  void _saveProgress() {
    final p = widget.progress;
    if (p == null) return;
    p.currentIndex = _currentQuestionIndex;
    p.correctAnswers = _correctAnswers;
    p.selectedAnswers
      ..clear()
      ..addAll(_selectedAnswers);
    p.selectedMultiAnswers
      ..clear()
      ..addAll(_selectedMultiAnswers);
    p.answeredFlags
      ..clear()
      ..addAll(_answeredFlags);
    p.correctFlags
      ..clear()
      ..addAll(_correctFlags);
    p.textAnswers.clear();
    for (final entry in _textControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        p.textAnswers[entry.key] = entry.value.text;
      }
    }
    // Persist V2 block step progress
    p.v2Progress
      ..clear()
      ..addAll(_v2Progress);
  }

  TextEditingController _getTextController(int index) {
    if (!_textControllers.containsKey(index)) {
      _textControllers[index] = TextEditingController();
    }
    return _textControllers[index]!;
  }

  void _selectOption(String optionId) {
    // If already answered, reset to allow re-answering
    if (_isCurrentAnswered) {
      final wasCorrect = _correctFlags[_currentQuestionIndex] ?? false;
      _answeredFlags[_currentQuestionIndex] = false;
      _correctFlags[_currentQuestionIndex] = false;
      _answeredQuestions--;
      if (wasCorrect) _correctAnswers--;
    }
    final question = _currentBlock.atomicQuestion;
    if (question != null && question.allowMultiple) {
      setState(() {
        final current = _selectedMultiAnswers[_currentQuestionIndex] ??= {};
        if (current.contains(optionId)) {
          current.remove(optionId);
        } else {
          current.add(optionId);
        }
      });
    } else {
      setState(() {
        _selectedAnswers[_currentQuestionIndex] = optionId;
      });
    }
  }

  void _checkAnswer() {
    final block = _currentBlock;
    final question = block.atomicQuestion;
    if (question == null) return;

    bool isCorrect = false;

    if ((question.isMultipleChoice || question.isTrueFalse) && question.allowMultiple) {
      // Multi-select: compare selected set with correct set
      final correctIds = question.options.where((o) => o.isCorrect).map((o) => o.id).toSet();
      final selected = _selectedMultiAnswers[_currentQuestionIndex] ?? {};
      isCorrect = selected.length == correctIds.length && selected.containsAll(correctIds);
    } else if (question.isMultipleChoice || question.isTrueFalse) {
      // Single-select
      final selectedAnswer = _selectedAnswers[_currentQuestionIndex];
      final correctOption = question.options.firstWhere(
        (o) => o.isCorrect,
        orElse: () => question.options.first,
      );
      isCorrect = selectedAnswer == correctOption.id;
    } else if (question.isOpen) {
      // Check open answer
      final userAnswer = _getTextController(_currentQuestionIndex).text.trim().toLowerCase();
      final correctAnswer = question.correctAnswer?.toLowerCase() ?? '';
      isCorrect = userAnswer == correctAnswer;
      _selectedAnswers[_currentQuestionIndex] = _getTextController(_currentQuestionIndex).text;
    }

    setState(() {
      _answeredFlags[_currentQuestionIndex] = true;
      _correctFlags[_currentQuestionIndex] = isCorrect;
      _answerTimestamps[_currentQuestionIndex] = DateTime.now();
      _answeredQuestions++;
      if (isCorrect) _correctAnswers++;
    });

    // Wrong atomic answer → seed a Practice (Cvičení) card, same as V2 blocks.
    if (!isCorrect) _autoBookmarkOnWrong(block);

    // Update ELO for quiz mode — apply hint/help penalty
    double eloScore = isCorrect ? 1.0 : 0.0;
    final hintLevel = _hintUsage[_currentQuestionIndex] ?? 0;
    if (hintLevel >= 2) {
      eloScore = eloScore.clamp(0.0, 0.5);
    } else if (hintLevel >= 1) {
      eloScore = eloScore.clamp(0.0, 0.75);
    }
    _updateElo(block, eloScore);

    // FSRS practice: grade this block and reschedule its card.
    if (widget.isFsrsPractice) {
      _recordFsrsReview(
        block: block,
        index: _currentQuestionIndex,
        isCorrect: isCorrect,
        hintLevel: hintLevel,
      );
    }

    // Persist partial quiz progress to DB + sync after each answer
    // so progress is recoverable on refresh or device switch.
    _persistPartialProgress();

    // When not evaluating, auto-advance to next question
    if (!widget.evaluate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToNextQuestion();
      });
    }
  }

  /// Auto-bookmark an exercise block on wrong answer so it lands in Cvičení
  /// (matches the manual bookmark click). No-op for non-exercise blocks
  /// or already-bookmarked blocks.
  Future<void> _autoBookmarkOnWrong(ContentBlock block) async {
    if (!block.type.isInteractiveBlock) return;
    try {
      final db = ref.read(appDatabaseProvider);
      final localCourse = await db.getCourseByFieldCourseId(widget.courseId);
      if (localCourse == null) return;
      final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
      if (bookmarkNotifier.isBookmarked(localCourse.id, block.blockId)) return;
      bookmarkNotifier.addBookmark(localCourse.id, block);
    } catch (e, st) { silentLog('quiz_page:auto_bookmark', e, st); }
  }

  /// Grade an answered block and feed it into the FSRS scheduler so the
  /// matching practice card is rescheduled + a review log is written.
  /// No-op when the block has no practice card. Fire-and-forget.
  Future<void> _recordFsrsReview({
    required ContentBlock block,
    required int index,
    required bool isCorrect,
    required int hintLevel,
    int? explicitRating,
  }) async {
    try {
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user == null) return;

      final repo = ref.read(practiceRepositoryProvider);
      final card = await repo.getCardByBlock(user.id, block.blockId);
      if (card == null) return;

      final shownAt = _questionOpenedAt[index] ?? DateTime.now().toUtc();
      final responseTimeSec =
          DateTime.now().toUtc().difference(shownAt).inSeconds;

      // Display/content cards are self-rated (explicitRating); answerable cards
      // are graded automatically from correctness + hint usage + speed.
      final rating = explicitRating ??
          GradeCalculator.gradeExercise(
            isCorrect: isCorrect,
            usedHint: hintLevel == 1,
            usedHelp: hintLevel >= 2,
            responseTimeSec: responseTimeSec,
            avgTimeSec: card.avgTimeSec,
          );

      final result = await ref.read(practiceServiceProvider).reviewCard(
            card: card,
            rating: rating,
            shownAt: shownAt,
            userId: user.id,
          );

      // The card was just rescheduled (new future dueDate). Invalidate the
      // cached practice queue so the dashboard count drops and the NEXT launch
      // recomputes a fresh queue that excludes just-reviewed cards, instead of
      // replaying the same cached list from index 0 (BR-8SHZCR). Cascades to
      // playablePracticeProvider and dueCardsCountProvider, which watch it.
      ref.invalidate(practiceQueueProvider);

      // Tally for the end-of-session summary. grade 3-4 = answered well.
      if (mounted) {
        setState(() {
          _fsrsXpEarned += result.xpEarned;
          _fsrsReviewedCount++;
          if (rating >= 3) _fsrsCorrectCount++;
        });
      }
    } catch (e, st) {
      silentLog('quiz_page:fsrs_review', e, st);
    }
  }

  /// Self-rating for display/content practice cards (no question to grade).
  /// Maps the four buttons to FSRS ratings (Nevím=1 … Pamatuji=4), records the
  /// review, then advances to the next card.
  Future<void> _selfRateDisplay(int rating) async {
    if (_isCurrentAnswered) return;
    final block = _currentBlock;
    final index = _currentQuestionIndex;
    // "Připomeň" (rating 2) = "remind me": open the hint before continuing,
    // if the block has one (BR-ZDYA83). The rating is still recorded after.
    if (rating == 2 && block.hasHint) {
      await _showHintBottomSheet(block);
      if (!mounted) return;
    }
    setState(() {
      _answeredFlags[index] = true;
      _correctFlags[index] = rating >= 3;
      _answerTimestamps[index] = DateTime.now();
    });
    await _recordFsrsReview(
      block: block,
      index: index,
      isCorrect: rating >= 3,
      hintLevel: 0,
      explicitRating: rating,
    );
    if (mounted) _goToNextQuestion();
  }

  /// Bottom bar shown for a display/content card during FSRS practice: four
  /// self-rating buttons (Nevím / Připomeň / Jde to / Pamatuji) in a 2×2 grid,
  /// replacing the "Zkontrolovat" flow that only makes sense for questions.
  Widget _buildSelfRateBottomBar() {
    final options = <({String label, int rating, Color color})>[
      (label: AppStrings.practiceRateAgain, rating: 1, color: AppColors.error),
      (label: AppStrings.practiceRateHard, rating: 2, color: AppColors.orange),
      (label: AppStrings.practiceRateGood, rating: 3, color: AppColors.primary),
      (label: AppStrings.practiceRateEasy, rating: 4, color: AppColors.success),
    ];

    Widget btn(({String label, int rating, Color color}) o) => Expanded(
          child: GestureDetector(
            onTap: () => _selfRateDisplay(o.rating),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: o.color.withValues(alpha: 0.12),
                borderRadius: AppDecorations.radiusS,
                border: Border.all(color: o.color.withValues(alpha: 0.45)),
              ),
              child: Text(
                o.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyBold(color: o.color),
              ),
            ),
          ),
        );

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark08,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.practiceRatePrompt,
            style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
          ),
          const SizedBox(height: 10),
          Row(children: [btn(options[0]), const SizedBox(width: 8), btn(options[1])]),
          const SizedBox(height: 8),
          Row(children: [btn(options[2]), const SizedBox(width: 8), btn(options[3])]),
        ],
      ),
    );
  }

  /// Save current quiz answer state to the user_course progressData
  /// so it can be restored on refresh or device switch.
  Future<void> _persistPartialProgress() async {
    // FSRS practice must not write into a course's quiz-resume store: the queue
    // spans multiple courses yet this keys everything to widget.courseId, which
    // both corrupts that course's real resume state and causes practice to skip
    // already-answered cards on the next launch (BR-CNSK2C).
    if (widget.isFsrsPractice) return;
    try {
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user == null) return;

      final db = ref.read(appDatabaseProvider);
      final courseRepo = ref.read(userCourseRepositoryProvider);

      final localCourse = await db.getCourseByFieldCourseId(widget.courseId);
      if (localCourse == null) return;
      final userCourse = await db.getUserCourseByUserAndCourse(user.id, localCourse.id);
      if (userCourse == null) return;

      final existing = (await courseRepo.getUserCourseById(userCourse.id))?.progressData ?? {};

      // Build per-block answer map from current state
      final blockAnswers = <String, dynamic>{};
      for (var i = 0; i < widget.questionBlocks.length; i++) {
        final block = widget.questionBlocks[i];
        if (_answeredFlags[i] != true) continue;
        blockAnswers[block.blockId] = {
          'is_correct': _correctFlags[i] ?? false,
          'is_answered': true,
          'selected_answer': _selectedAnswers[i],
          'selected_multi': _selectedMultiAnswers[i]?.toList(),
          if (_answerTimestamps[i] != null)
            'answered_at': _answerTimestamps[i]!.toUtc().toIso8601String(),
        };
      }

      await courseRepo.updateProgress(
        id: userCourse.id,
        progressData: {
          ...existing,
          'quiz_in_progress': true,
          'quiz_current_index': _currentQuestionIndex,
          'quiz_correct': _correctAnswers,
          'quiz_answered': _answeredQuestions,
          'quiz_total': _totalQuestions,
          'quiz_answers': blockAnswers,
        },
      );

      // Trigger sync so progress reaches server
      ref.read(syncServiceProvider).sync();
    } catch (e, st) { silentLog('quiz_page', e, st); }
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _totalCards - 1) {
      setState(() {
        _currentQuestionIndex++;
        _markQuestionOpened(_currentQuestionIndex);
      });
    } else {
      // Quiz completed - show results
      _showResults();
    }
  }

  void _goToPreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _markQuestionOpened(_currentQuestionIndex);
        // For V2 blocks, reset answered state so the engine restores in
        // interactive mode and the user can re-confirm or change their answer.
        final block = widget.questionBlocks[_currentQuestionIndex];
        if (block.hasV2Steps && (_answeredFlags[_currentQuestionIndex] ?? false)) {
          final wasCorrect = _correctFlags[_currentQuestionIndex] ?? false;
          _answeredFlags[_currentQuestionIndex] = false;
          _correctFlags[_currentQuestionIndex] = false;
          _answeredQuestions--;
          if (wasCorrect) _correctAnswers--;
        }
      });
    }
  }

  /// Whether the saved V2 progress for [questionIndex] holds an actual pending
  /// selection (option/multi/text). Used as a fallback for the engine
  /// controller's pending state on first build; unlike a plain null-check it
  /// returns false once an AGAIN retry has cleared the pick.
  bool _v2HasSelection(int questionIndex) {
    final progress = _v2Progress[questionIndex];
    if (progress == null) return false;
    for (final answer in progress.stepAnswers.values) {
      if (answer.selectedOptionId != null ||
          (answer.selectedOptionIds?.isNotEmpty ?? false) ||
          (answer.textAnswer?.isNotEmpty ?? false)) {
        return true;
      }
    }
    return false;
  }

  /// Extract a human-readable answer string from V2 step progress.
  String _extractV2Answer(int questionIndex) {
    final progress = _v2Progress[questionIndex];
    if (progress == null) return '';
    final parts = <String>[];
    for (final answer in progress.stepAnswers.values) {
      if (answer.selectedOptionId != null) {
        parts.add(answer.selectedOptionId!);
      } else if (answer.selectedOptionIds != null && answer.selectedOptionIds!.isNotEmpty) {
        parts.add(answer.selectedOptionIds!.join(','));
      } else if (answer.textAnswer != null && answer.textAnswer!.isNotEmpty) {
        parts.add(answer.textAnswer!);
      }
    }
    return parts.join('; ');
  }

  /// Award a trophy on first quiz completion for this course.
  /// Tracks via progressData['quiz_completed'] flag on the user_course.
  Future<void> _awardQuizTrophy() async {
    try {
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user == null) return;

      final courseRepo = ref.read(userCourseRepositoryProvider);
      final db = ref.read(appDatabaseProvider);

      // Find the user_course for this course
      final localCourse = await db.getCourseByFieldCourseId(widget.courseId);
      if (localCourse == null) return;
      final userCourse = await db.getUserCourseByUserAndCourse(user.id, localCourse.id);
      if (userCourse == null) return;

      final progressData = userCourse.progressDataJson != '{}'
          ? Map<String, dynamic>.from(
              (await courseRepo.getUserCourseById(userCourse.id))?.progressData ?? {},
            )
          : <String, dynamic>{};

      final alreadyCompleted = progressData['quiz_completed'] == true;
      if (!alreadyCompleted) {
        // First quiz completion — award trophy
        final statsRepo = ref.read(userStatsRepositoryProvider);
        await statsRepo.awardTrophy(user.id);

        // Mark quiz as completed in progressData
        progressData['quiz_completed'] = true;
        await courseRepo.updateProgress(
          id: userCourse.id,
          progressData: progressData,
        );
      }
    } catch (e, st) { silentLog('quiz_page', e, st); }
  }

  Future<void> _submitQuizAttempt() async {
    final apiClient = ref.read(apiClientProvider);
    final timeSpent = DateTime.now().difference(_startTime).inSeconds;

    // Build answers array from in-memory state
    final answers = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.questionBlocks.length; i++) {
      final block = widget.questionBlocks[i];
      // Skip display-only blocks that have no question
      if (block.atomicQuestion == null && !block.hasV2Steps) continue;

      String selectedAnswer;
      if (block.hasV2Steps) {
        // V2 blocks: extract answer from step progress
        selectedAnswer = _extractV2Answer(i);
      } else {
        final multiSelected = _selectedMultiAnswers[i];
        selectedAnswer = multiSelected != null && multiSelected.isNotEmpty
            ? multiSelected.join(',')
            : _selectedAnswers[i] ?? _textControllers[i]?.text ?? '';
      }

      final timestamp = _answerTimestamps[i];
      answers.add({
        'question_index': i,
        'question_id': block.blockId,
        'selected_answer': selectedAnswer,
        'is_correct': _correctFlags[i] ?? false,
        if (timestamp != null) 'answered_at': timestamp.toUtc().toIso8601String(),
      });
    }

    final payload = {
      'course_id': widget.courseId,
      'total_questions': _totalQuestions,
      'correct_answers': _correctAnswers,
      'score_percent': _totalQuestions > 0
          ? ((_correctAnswers / _totalQuestions) * 100).round()
          : 0,
      'time_spent_seconds': timeSpent,
      'started_at': _startTime.toUtc().toIso8601String(),
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'answers': answers,
    };

    try {
      await apiClient.post(ApiEndpoints.quizAttempts, data: payload);
    } catch (_) {
      // Silently fail — quiz results are best-effort
    }
  }

  void _showResults() {
    // FSRS practice runs with isExercise=true but should end with a session
    // summary (success rate + XP), not a silent pop.
    if (widget.isFsrsPractice) {
      _submitAndShowCompletion();
      return;
    }

    // Exercise — just pop back to course detail, no completion dialog
    if (widget.isExercise) {
      Navigator.of(context).pop();
      return;
    }

    // If not only_once, skip confirmation and submit directly
    if (!widget.onlyOnce) {
      _submitAndShowCompletion();
      return;
    }

    // Step 1: Show confirmation dialog before submitting (only_once courses)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusL),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 56,
              color: AppColors.primaryDark,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.quizConfirmSubmit,
              style: AppTextStyles.statSuffix(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Odeslat button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(confirmCtx);
                  _submitAndShowCompletion();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: AppDecorations.radiusS,
                  ),
                  child: Text(
                    AppStrings.quizConfirmSend,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.statValue(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Zpět button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(confirmCtx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppDecorations.radiusS,
                    border: Border.all(color: AppColors.inputBg),
                  ),
                  child: Text(
                    AppStrings.quizConfirmBack,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.statValue(color: AppColors.primaryDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// Show hint/help in a bottom sheet for the given block. Awaitable so callers
  /// (e.g. the "Připomeň" self-rating) can continue once the sheet is dismissed.
  Future<void> _showHintBottomSheet(ContentBlock block) async {
    final hint = block.currentHint;
    if (hint == null || hint.isEmpty) return;

    // Track hint usage for ELO score penalty
    final idx = _currentQuestionIndex;
    final prev = _hintUsage[idx] ?? 0;
    if (prev < 1) _hintUsage[idx] = 1;

    // Detailed hint tracking with timestamps and counters
    final blockId = block.blockId;
    final now = DateTime.now().toUtc().toIso8601String();
    _hintHelpTracking.putIfAbsent(blockId, () => {});
    final tracking = _hintHelpTracking[blockId]!;
    tracking['hint_count'] = (tracking['hint_count'] as int? ?? 0) + 1;
    tracking['hint_first_ts'] ??= now;
    tracking['hint_last_ts'] = now;

    final title = block.displayTitle;
    bool showHelp = false;
    final feedbackController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final displayedText = showHelp
                ? (block.currentHelp ?? hint)
                : hint;
            final displayedTitle = showHelp
                ? AppStrings.lessonDetailedExplanation(title)
                : AppStrings.lessonExplanationTitle(title);
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 16),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, size: 20, color: AppColors.primaryDark),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: AppDecorations.radiusS,
                            ),
                            child: Icon(Icons.help_outline, color: AppColors.quizPurple, size: 28),
                          ),
                          const SizedBox(height: 16),
                          // Title
                          Text(
                            displayedTitle,
                            style: AppTextStyles.heading4(),
                          ),
                          const SizedBox(height: 16),
                          // Hint/help content
                          MarkdownLatexWidget(
                            content: displayedText,
                            textColor: AppColors.primaryDark88,
                          ),
                          const SizedBox(height: 24),
                          // Feedback options (Phase 1)
                          if (!showHelp) ...[
                            _buildFeedbackOption(
                              icon: Icons.check,
                              iconColor: AppColors.success,
                              label: AppStrings.lessonFeedbackClear,
                              isSelected: false,
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildFeedbackOption(
                              icon: Icons.sentiment_dissatisfied_outlined,
                              iconColor: AppColors.orange,
                              label: AppStrings.lessonFeedbackConfused,
                              isSelected: false,
                              onTap: () {
                                setModalState(() {
                                  showHelp = true;
                                });
                                // Escalate hint usage to "help" level for ELO penalty
                                _hintUsage[idx] = 2;
                                // Detailed help tracking
                                final helpNow = DateTime.now().toUtc().toIso8601String();
                                final t = _hintHelpTracking[blockId] ?? {};
                                t['help_count'] = (t['help_count'] as int? ?? 0) + 1;
                                t['help_first_ts'] ??= helpNow;
                                t['help_last_ts'] = helpNow;
                                _hintHelpTracking[blockId] = t;
                              },
                            ),
                            if (widget.evaluate) ...[
                              const SizedBox(height: 8),
                              _buildFeedbackOption(
                                icon: Icons.smart_toy_outlined,
                                iconColor: AppColors.primary,
                                label: AppStrings.quizAskAi,
                                isSelected: false,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _openChatWithContext(idx);
                                },
                              ),
                            ],
                          ],
                          // Help form (Phase 2)
                          if (showHelp) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Text(
                                  AppStrings.lessonFeedbackClarify,
                                  style: AppTextStyles.statSuffix(),
                                ),
                                Text(
                                  ' *',
                                  style: AppTextStyles.statSuffix(color: AppColors.orange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: AppDecorations.radiusS,
                                border: Border.all(
                                  color: AppColors.surfaceLight,
                                ),
                              ),
                              child: TextField(
                                controller: feedbackController,
                                maxLines: 4,
                                maxLength: 500,
                                decoration: InputDecoration(
                                  hintText: AppStrings.lessonFeedbackHint,
                                  hintStyle: AppTextStyles.bodySmall(color: AppColors.disabled),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  counterText: '',
                                ),
                                style: AppTextStyles.bodySmall(),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppStrings.lessonFeedbackCharCount(feedbackController.text.length),
                                style: AppTextStyles.caption(color: AppColors.disabled),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Builder(builder: (ctx) {
                              final isEmpty = feedbackController.text.trim().isEmpty;
                              return GestureDetector(
                                onTap: isEmpty
                                    ? null
                                    : () {
                                        final studentMessage = feedbackController.text.trim();
                                        _enqueueFeedback(
                                          blockId: block.blockId,
                                          type: 'question',
                                          message: studentMessage,
                                        );
                                        Navigator.of(ctx).pop();
                                        // Open the AI mentor with the block context and the
                                        // student's clarifying question (parity with the
                                        // in-lesson "Odeslat" flow in lesson_detail_page.dart).
                                        _openChatWithContext(idx, studentMessage: studentMessage);
                                      },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isEmpty
                                        ? AppColors.surfaceLight.withValues(alpha: 0.5)
                                        : AppColors.surfaceLight,
                                    borderRadius: AppDecorations.radiusXL,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppStrings.lessonFeedbackSend,
                                        style: AppTextStyles.buttonLarge(
                                          color: isEmpty
                                              ? AppColors.primaryDark32
                                              : AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.send,
                                        size: 18,
                                        color: isEmpty
                                            ? AppColors.primaryDark32
                                            : AppColors.primaryDark,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _enqueueFeedback({
    required String blockId,
    required String type,
    String? message,
  }) async {
    final syncQueue = ref.read(syncQueueProvider);
    final recordId = '${widget.courseId}_${blockId}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await syncQueue.enqueue(
        tableName: 'content_feedback',
        recordId: recordId,
        operation: SyncOperation.create,
        payload: {
          'course_id': widget.courseId,
          'block_id': blockId,
          'type': type,
          if (message != null) 'message': message,
        },
      );
      final syncService = ref.read(syncServiceProvider);
      syncService.sync();
    } catch (e, st) { silentLog('quiz_page', e, st); }
  }

  /// Open AI chat with context about the current quiz block.
  void _openChatWithContext(int index, {String? studentMessage}) {
    final block = widget.questionBlocks[index];
    final courseName = widget.courseTitle;

    final hint = block.currentHint ?? '';
    final help = block.currentHelp ?? '';

    // Collect all text from the block (all steps)
    String blockContent = '';
    if (block.steps.isNotEmpty) {
      final stepTexts = block.steps
          .map((s) => s.displayText)
          .where((t) => t.isNotEmpty)
          .toList();
      blockContent = stepTexts.join('\n');
    } else {
      blockContent = block.displayContent;
    }

    // For question blocks, include question and options
    String questionInfo = '';
    if (block.atomicQuestion != null) {
      final q = block.atomicQuestion!;
      final optionTexts = q.options.map((o) => '- ${o.text}').join('\n');
      questionInfo = AppStrings.chatContextQuestionWithOptions(optionTexts);
    } else {
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

    final contextParts = <String>[
      AppStrings.chatContextHelpIntro(courseName),
      '',
      if (blockContent.isNotEmpty) AppStrings.chatContextHelpTaskContent(blockContent.length > 400 ? '${blockContent.substring(0, 400)}...' : blockContent),
      if (questionInfo.isNotEmpty) questionInfo,
      if (hint.isNotEmpty) AppStrings.chatContextHelpHint(hint),
      if (help.isNotEmpty) AppStrings.chatContextHelpDetail(help),
      '',
      if (studentMessage != null && studentMessage.isNotEmpty) studentMessage,
      AppStrings.chatContextFallbackPrompt,
    ];
    final contextMessage = contextParts.where((s) => s.isNotEmpty || contextParts.indexOf(s) == 1).join('\n');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          sessionId: '',
          sessionTitle: courseName,
          persona: ChatPersona.mathMentor,
          initialContext: contextMessage,
        ),
      ),
    );
  }

  Widget _buildFeedbackOption({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : AppColors.surface,
          borderRadius: AppDecorations.radiusXL,
          border: Border.all(
            color: isSelected ? AppColors.quizPurple : AppColors.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall(),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 2: Submit the quiz and show the completion dialog.
  /// Save quiz results (score, answers, completion) into progressData on user_courses.
  Future<void> _saveQuizProgressLocally() async {
    try {
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user == null) return;

      final db = ref.read(appDatabaseProvider);
      final courseRepo = ref.read(userCourseRepositoryProvider);

      final localCourse = await db.getCourseByFieldCourseId(widget.courseId);
      if (localCourse == null) return;
      final userCourse = await db.getUserCourseByUserAndCourse(user.id, localCourse.id);
      if (userCourse == null) return;

      final existing = (await courseRepo.getUserCourseById(userCourse.id))?.progressData ?? {};
      final timeSpent = DateTime.now().difference(_startTime).inSeconds;

      // Build per-block answer map
      final blockAnswers = <String, dynamic>{};
      for (var i = 0; i < widget.questionBlocks.length; i++) {
        final block = widget.questionBlocks[i];
        final timestamp = _answerTimestamps[i];
        blockAnswers[block.blockId] = {
          'is_correct': _correctFlags[i] ?? false,
          'is_answered': _answeredFlags[i] ?? false,
          if (timestamp != null) 'answered_at': timestamp.toUtc().toIso8601String(),
        };
      }

      // Check if this is a quiz-only course — mark as completed
      final courseDataJson = localCourse.data;
      Map<String, dynamic>? courseDataMap;
      try {
        courseDataMap = Map<String, dynamic>.from(
          jsonDecode(courseDataJson) as Map,
        );
      } catch (e, st) { silentLog('quiz_page', e, st); }
      final isQuizOnly = courseDataMap?['only_quiz'] == true;

      await courseRepo.updateProgress(
        id: userCourse.id,
        addTimeSpentSeconds: timeSpent,
        status: isQuizOnly ? UserCourseStatus.completed : null,
        progressPercent: isQuizOnly ? 100 : null,
        progressData: {
          ...existing,
          'quiz_score': _totalQuestions > 0
              ? ((_correctAnswers / _totalQuestions) * 100).round()
              : 0,
          'quiz_correct': _correctAnswers,
          'quiz_total': _totalQuestions,
          'quiz_completed': true,
          'quiz_completed_at': DateTime.now().toUtc().toIso8601String(),
          'quiz_in_progress': false,
          'quiz_answers': blockAnswers,
          if (_hintHelpTracking.isNotEmpty) 'hint_help_usage': _hintHelpTracking,
        },
      );
    } catch (e, st) { silentLog('quiz_page', e, st); }
  }

  Future<void> _submitAndShowCompletion() async {
    if (_hasSubmittedAttempt) return;
    _hasSubmittedAttempt = true;
    // Quiz-attempt submission / progress / trophy are course-quiz concerns —
    // skip them for a cross-course FSRS practice session.
    if (!widget.isFsrsPractice) {
      await _submitQuizAttempt();
      await _saveQuizProgressLocally();
      await _awardQuizTrophy();
    }

    // FSRS practice: bank the XP accumulated across the session so it counts
    // toward the user's level/daily XP (it was previously computed and dropped).
    if (widget.isFsrsPractice && _fsrsXpEarned > 0) {
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user != null) {
        await ref.read(userStatsRepositoryProvider).awardXp(
              userId: user.id,
              rawXp: _fsrsXpEarned,
              courseXpEarned: _fsrsXpEarned,
            );
      }
    }

    ref.read(syncServiceProvider).sync();
    if (!mounted) return;

    // Non-evaluated: just submit and pop, no dialog
    if (!widget.evaluate) {
      Navigator.of(context).pop(true);
      return;
    }

    // Evaluated: show result dialog
    final hasQuestions = _totalQuestions > 0;
    final allCorrect = hasQuestions && _correctAnswers == _totalQuestions;
    final mostCorrect = hasQuestions && _correctAnswers >= _totalQuestions * 0.7;
    final pageNavigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (doneCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusL),
        title: Text(
          widget.isFsrsPractice
              ? AppStrings.practiceCompleted
              : hasQuestions
                  ? AppStrings.quizCompleted
                  : AppStrings.quizReviewCompleted,
          style: AppTextStyles.subtitle(),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              !hasQuestions
                  ? Icons.auto_stories
                  : allCorrect
                      ? Icons.emoji_events
                      : mostCorrect
                          ? Icons.thumb_up
                          : Icons.refresh,
              size: 64,
              color: !hasQuestions
                  ? AppColors.quizPurple
                  : allCorrect
                      ? Colors.amber
                      : mostCorrect
                          ? AppColors.success
                          : AppColors.errorLight,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuestions
                  ? AppStrings.quizCorrectResult(_correctAnswers, _totalQuestions)
                  : AppStrings.quizCardsReviewed(_totalCards),
              style: AppTextStyles.heading3(),
            ),
            const SizedBox(height: 8),
            Text(
              !hasQuestions
                  ? AppStrings.quizGreatReview
                  : allCorrect
                      ? AppStrings.quizAllCorrect
                      : mostCorrect
                          ? AppStrings.quizGreatJob
                          : AppStrings.quizTryAgain,
              style: AppTextStyles.statSuffix(color: Colors.grey[600]),
            ),
            // FSRS practice session summary — success rate + XP banked.
            if (widget.isFsrsPractice) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: AppDecorations.radiusM,
                ),
                child: Column(
                  children: [
                    Text(
                      AppStrings.practiceSummarySuccess(
                        _fsrsReviewedCount == 0
                            ? 0
                            : ((_fsrsCorrectCount / _fsrsReviewedCount) * 100)
                                .round(),
                      ),
                      style:
                          AppTextStyles.bodyBold(color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.practiceSummaryXp(_fsrsXpEarned),
                      style: AppTextStyles.bodyBold(color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Hotovo button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(doneCtx);
                  if (mounted) pageNavigator.pop(true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: AppDecorations.radiusS,
                  ),
                  child: Text(
                    AppStrings.quizDone,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.statValue(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (hasQuestions && _correctAnswers < _totalQuestions)
            TextButton(
              onPressed: () {
                Navigator.pop(doneCtx);
                _resetQuiz();
              },
              child: Text(
                AppStrings.quizRetry,
                style: AppTextStyles.subtitle(),
              ),
            ),
        ],
      ),
    );
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _answeredQuestions = 0;
      _selectedAnswers.clear();
      _selectedMultiAnswers.clear();
      _answeredFlags.clear();
      _correctFlags.clear();
      _v2Progress.clear();
      _answerTimestamps.clear();
      for (final controller in _textControllers.values) {
        controller.clear();
      }
    });
    widget.progress?.reset();
  }

  /// Update ELO profile after a block is answered (Kvíz only).
  Future<void> _updateElo(ContentBlock block, double score) async {
    if (!_isQuizMode) return;

    final relationVector = block.gpf?.relationVector;
    final eloVector = block.gpf?.eloVector;
    if (relationVector == null || relationVector.isEmpty) return;
    if (eloVector == null || eloVector.isEmpty) return;

    final user = ref.read(activeUserProvider).valueOrNull;
    if (user == null) return;

    try {
      final eloRepo = ref.read(eloRepositoryProvider);
      final syncQueue = ref.read(syncQueueProvider);

      final profile = await eloRepo.getOrCreateProfile(user.id);
      final castRelation = relationVector.map((e) => e ?? 0.0).toList();
      final itemPocet = List<int>.filled(castRelation.length, 0);

      final result = EloEngine.updateTask(
        profilElo: profile.profilElo,
        profilPocet: profile.profilPocet,
        relationVector: castRelation,
        eloVector: eloVector,
        itemPocet: itemPocet,
        score: score,
      );

      if (result.updatedIndices.isEmpty) return;

      await eloRepo.saveProfile(user.id, result.profilElo, result.profilPocet);

      await syncQueue.enqueue(
        tableName: 'user_elo_profiles',
        recordId: profile.id,
        operation: SyncOperation.update,
        payload: {
          'profil_elo': result.profilElo,
          'profil_pocet': result.profilPocet,
        },
      );

      final openedAt = _questionOpenedAt[_currentQuestionIndex];
      final confirmedAt = (_answerTimestamps[_currentQuestionIndex] ?? DateTime.now()).toUtc();
      final durationMs = openedAt != null
          ? confirmedAt.difference(openedAt).inMilliseconds.clamp(0, 1 << 31)
          : null;

      await syncQueue.enqueue(
        tableName: 'elo_interactions',
        recordId: 'elo-${DateTime.now().microsecondsSinceEpoch}',
        operation: SyncOperation.create,
        payload: {
          'block_id': block.blockId,
          'course_id': widget.courseId,
          'source': 'quiz',
          'score': score,
          'hint_used': (_hintUsage[_currentQuestionIndex] ?? 0) >= 1,
          'help_used': (_hintUsage[_currentQuestionIndex] ?? 0) >= 2,
          'profil_elo_snapshot': result.profilElo,
          'elo_vector_snapshot': eloVector,
          'updated_indices': result.updatedIndices,
          if (openedAt != null) 'opened_at': openedAt.toIso8601String(),
          'confirmed_at': confirmedAt.toIso8601String(),
          if (durationMs != null) 'duration_ms': durationMs,
        },
      );
    } catch (e, st) { silentLog('quiz_page', e, st); }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Once-only quizzes must lock on ANY exit (back button, gesture, dashboard),
      // not only on the final Submit (BR-NRSAY3). Block the automatic pop and route
      // it through the confirm+finalize handler. A finalized quiz pops freely.
      canPop: !_isLockableQuiz || _hasSubmittedAttempt,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmed = await _confirmFinalExit();
        if (confirmed != true) return;
        await _finalizeQuizAndExit();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        title: Text(
          widget.isFsrsPractice
              ? AppStrings.practiceTitle
              : widget.isExercise
                  ? AppStrings.quizExerciseTitle
                  : AppStrings.quizTitle,
          style: AppTextStyles.subtitle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress bar
          _buildProgressBar(),
          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildQuestionCard(),
            ),
          ),
          // Bottom navigation
          _buildBottomBar(),
        ],
      ),
      ),
    );
  }

  /// A once-only course quiz that must be locked after a single attempt.
  /// Excludes exercises (re-playable practice) and FSRS practice sessions.
  bool get _isLockableQuiz =>
      widget.onlyOnce && !widget.isExercise && !widget.isFsrsPractice;

  /// Confirmation shown when the user tries to leave a lockable quiz without
  /// submitting. Returns true if the user chose to leave (and thus lock).
  Future<bool?> _confirmFinalExit() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusL),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 56, color: AppColors.orange),
            const SizedBox(height: 16),
            Text(
              AppStrings.quizConfirmExitMessage,
              style: AppTextStyles.statSuffix(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.quizConfirmExitStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.quizConfirmExitLeave,
              style: AppTextStyles.buttonLarge(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Finalize a lockable quiz on early exit: submit the attempt and mark it
  /// completed (so it can never be re-launched), then pop(true) so the caller
  /// runs its completion/PIN-block handling — identical outcome to Submit.
  Future<void> _finalizeQuizAndExit() async {
    if (!_hasSubmittedAttempt) {
      _hasSubmittedAttempt = true;
      if (!widget.isFsrsPractice) {
        await _submitQuizAttempt();
        await _saveQuizProgressLocally();
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _buildProgressBar() {
    final progress = (_currentQuestionIndex + 1) / _totalCards;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.quizCardProgress(_currentQuestionIndex + 1, _totalCards),
                style: AppTextStyles.actionSmall(),
              ),
              if (_totalQuestions > 0 && widget.evaluate)
                Text(
                  AppStrings.quizCorrectCount(_correctAnswers, _totalQuestions),
                  style: AppTextStyles.actionSmall(color: AppColors.success),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.inputBg,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final block = _currentBlock;

    // FSRS practice: a display/content-TYPE block is read, not answered — render
    // its content read-only (no step-check engine) so only the self-rating
    // bottom bar drives it.
    if (_selfRateDisplays && block.type.isDisplayBlock) {
      return _buildDisplayPracticeCard(block);
    }

    // Step-based blocks → delegate to BlockStepEngine in quizV2 mode
    if (block.hasV2Steps) {
      // For re-visiting: restore previous selection but mark as un-answered
      // so the engine is interactive and the user can re-confirm or change.
      // Reset currentStepIndex to 0 so _skipToNextQuestion finds the first
      // evaluation step — using the saved index could land on a trailing
      // non-evaluation step, causing the engine to auto-complete immediately.
      final savedProg = _v2Progress[_currentQuestionIndex];
      StepProgressData? effectiveSaved;
      if (savedProg != null) {
        effectiveSaved = StepProgressData(
          blockId: savedProg.blockId,
          currentStepIndex: 0,
          stepAnswers: savedProg.stepAnswers.map((key, value) =>
              MapEntry(key, value.copyWith(isAnswered: false))),
          isBlockCompleted: false,
        );
      }
      return BlockStepEngine(
        // Per-question key forces State recreation when navigating between
        // questions, so each question reloads its own saved progress.
        // Quiz blocks often share an empty block_id, so the engine's
        // blockId-based re-init in didUpdateWidget can't be relied on.
        key: ValueKey('quiz_v2_$_currentQuestionIndex'),
        block: block,
        exportMode: ExportMode.quizV2,
        hideEvaluation: !widget.evaluate,
        controller: _engineController,
        isCurrent: true,
        isCompleted: false,
        savedProgress: effectiveSaved,
        onStepProgress: (data) {
          _v2Progress[_currentQuestionIndex] = data;
        },
        onBlockCompleted: ({int earnedXp = 0, double scoreKoef = 1.0, String? mark, DateTime? tsBubbleOpen, DateTime? tsAnswerClick, DateTime? tsAnswerSubmit, int attemptCount = 0}) {
          final wasAnswered = _answeredFlags[_currentQuestionIndex] ?? false;
          final wasCorrect = _correctFlags[_currentQuestionIndex] ?? false;
          final isNowCorrect = scoreKoef >= 1.0;
          setState(() {
            _answeredFlags[_currentQuestionIndex] = true;
            _correctFlags[_currentQuestionIndex] = isNowCorrect;
            _answerTimestamps[_currentQuestionIndex] = DateTime.now();
            if (!wasAnswered) {
              _answeredQuestions++;
              if (isNowCorrect) _correctAnswers++;
            } else {
              // Re-answer: adjust correct count
              if (wasCorrect && !isNowCorrect) _correctAnswers--;
              if (!wasCorrect && isNowCorrect) _correctAnswers++;
            }
          });
          // Update ELO for quiz mode — apply hint/help penalty
          double eloScore = scoreKoef;
          final hintLevel = _hintUsage[_currentQuestionIndex] ?? 0;
          if (hintLevel >= 2) {
            eloScore = eloScore.clamp(0.0, 0.5);
          } else if (hintLevel >= 1) {
            eloScore = eloScore.clamp(0.0, 0.75);
          }
          _updateElo(widget.questionBlocks[_currentQuestionIndex], eloScore);
          _persistPartialProgress();
          // Auto-advance: when show_answers=false there's no feedback,
          // and when evaluate=true the user already saw solution via "Pokračovat".
          if (_currentBlockHidesAnswers || widget.evaluate) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _goToNextQuestion();
            });
          }
        },
        // Always wired: the engine offers the "?" for the step on screen, and the
        // sheet reads that step's hint. The bottom bar's own "?" reads it too, so
        // it is rebuilt whenever the engine moves to another step.
        onHintRequested: () => _showHintBottomSheet(block),
        onStepShown: (_, _) {
          if (mounted) setState(() {});
        },
        onChatRequested: widget.evaluate ? () => _openChatWithContext(_currentQuestionIndex) : null,
        onWrongAnswer: () => _autoBookmarkOnWrong(block),
      );
    }

    final question = block.atomicQuestion;

    // Get content
    final content = block.displayContent;
    final hasHtml = content.contains('<') && content.contains('>');
    final hasMarkdown = !hasHtml && (content.contains('**') ||
        content.contains('__') ||
        content.contains('##') ||
        content.contains('```') ||
        content.contains('\$') ||
        content.contains('!['));

    // Display blocks (no question) - show as review content
    if (question == null) {
      return _buildDisplayCard(block, content, hasHtml, hasMarkdown);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusL,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          _buildContentWidget(content, hasHtml, hasMarkdown),
          const SizedBox(height: 24),

          // Answer options
          if (question.isOpen)
            _buildOpenAnswer(question)
          else
            _buildMultipleChoiceOptions(question),

          // Result feedback when evaluating
          if (widget.evaluate && _isCurrentAnswered && question.solution != null && question.showSolution) ...[
            const SizedBox(height: 16),
            _buildResultFeedback(question),
          ],

          // Action buttons
          _buildCardActionButtons(_currentQuestionIndex),
        ],
      ),
    );
  }

  /// Build content widget based on format (HTML, Markdown, or plain text)
  Widget _buildContentWidget(String content, bool hasHtml, bool hasMarkdown, {double fontSize = 16}) {
    if (hasHtml) {
      return Html(
        data: resolveHtmlImageUrls(content),
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(fontSize),
            color: AppColors.primaryDark,
            fontFamily: 'Nunito',
            lineHeight: const LineHeight(1.6),
          ),
          'p': Style(
            margin: Margins.only(bottom: 12),
          ),
          'h3': Style(
            fontSize: FontSize(fontSize + 2),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 8, top: 12),
          ),
          'strong': Style(
            fontWeight: FontWeight.bold,
          ),
          'em': Style(
            fontStyle: FontStyle.italic,
          ),
        },
      );
    } else if (hasMarkdown) {
      return MarkdownLatexWidget(content: content);
    } else {
      return Text(
        content,
        style: AppTextStyles.statSuffix().copyWith(height: 1.6),
      );
    }
  }

  /// Build a display card for review content (non-question blocks)
  /// Read-only render of a display/content block for FSRS self-rating. Shows
  /// every text step's content (no per-step check/confirm engine); the four
  /// self-rating buttons live in the bottom bar.
  Widget _buildDisplayPracticeCard(ContentBlock block) {
    final parts = <Widget>[];

    void addContent(String raw) {
      final c = raw.replaceAll(r'\n', '\n');
      if (c.trim().isEmpty) return;
      final hasHtml = c.contains('<') && c.contains('>');
      final hasMarkdown = !hasHtml &&
          (c.contains('**') ||
              c.contains('##') ||
              c.contains('```') ||
              c.contains(r'$') ||
              c.contains('!['));
      if (parts.isNotEmpty) parts.add(const SizedBox(height: 16));
      parts.add(_buildContentWidget(c, hasHtml, hasMarkdown));
    }

    if (block.steps.isNotEmpty) {
      // Render each step exactly like the lesson view (StepContentRenderer):
      // markdown, LaTeX, images, SVG, and playable video/audio — instead of the
      // old text-only path that silently dropped step images/media (BR-27DCT3).
      for (final step in block.steps) {
        if (parts.isNotEmpty) parts.add(const SizedBox(height: 16));
        parts.add(StepContentRenderer(
          step: step,
          getVideoController: _getVideoController,
          getAudioController: _getAudioController,
        ));
      }
    } else {
      addContent(block.displayContent);
    }
    if (parts.isEmpty) addContent(block.displayContent);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusL,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts,
      ),
    );
  }

  Widget _buildDisplayCard(ContentBlock block, String content, bool hasHtml, bool hasMarkdown) {
    // Mark as "answered" (reviewed) for display blocks
    // This happens automatically when user sees the card

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusL,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content
          _buildContentWidget(content, hasHtml, hasMarkdown),

          // Hint if available
          if (block.atomicHint != null && block.atomicHint!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.hintBg,
                borderRadius: AppDecorations.radiusS,
                border: Border.all(color: AppColors.hintBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.hintIconColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      block.atomicHint!,
                      style: AppTextStyles.bodySmall(),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons (self-rating for display cards lives in the bottom
          // bar so it also covers engine-rendered multi-step display blocks).
          _buildCardActionButtons(_currentQuestionIndex),
        ],
      ),
    );
  }

  Widget _buildResultFeedback(AtomicQuestion question) {
    final isCorrect = _isCurrentCorrect;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? AppColors.successBg : AppColors.errorBg,
        borderRadius: AppDecorations.radiusS,
        border: Border.all(
          color: isCorrect ? AppColors.success : AppColors.errorLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? AppColors.success : AppColors.errorLight,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MarkdownLatexWidget(content: question.solution!),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceOptions(AtomicQuestion question) {
    final isMulti = question.allowMultiple;
    final showResult = _isCurrentAnswered && widget.evaluate;

    return Column(
      children: question.options.map((option) {
        final isSelected = isMulti
            ? (_selectedMultiAnswers[_currentQuestionIndex]?.contains(option.id) ?? false)
            : _selectedAnswers[_currentQuestionIndex] == option.id;

        Color backgroundColor = isSelected ? AppColors.infoBg : AppColors.surface;
        Color borderColor = isSelected ? AppColors.primaryDark : AppColors.inputBg;

        // Show correct/incorrect coloring when evaluating
        if (showResult) {
          if (option.isCorrect) {
            backgroundColor = AppColors.successBg;
            borderColor = AppColors.success;
          } else if (isSelected && !option.isCorrect) {
            backgroundColor = AppColors.errorBg;
            borderColor = AppColors.errorLight;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _selectOption(option.id),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: AppDecorations.radiusS,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.text,
                      style: AppTextStyles.statSuffix(color: AppColors.primaryDark).copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showResult && option.isCorrect)
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 24,
                    )
                  else if (showResult && isSelected && !option.isCorrect)
                    Icon(
                      Icons.cancel,
                      color: AppColors.errorLight,
                      size: 24,
                    )
                  else if (isSelected)
                    Icon(
                      isMulti ? Icons.check_box : Icons.radio_button_checked,
                      color: AppColors.primaryDark,
                      size: 24,
                    )
                  else
                    Icon(
                      isMulti ? Icons.check_box_outline_blank : Icons.radio_button_off,
                      color: AppColors.inputBg,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOpenAnswer(AtomicQuestion question) {
    final controller = _getTextController(_currentQuestionIndex);
    final showResult = _isCurrentAnswered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: true,
          onChanged: (_) {
            // Reset answered state to allow re-answering
            if (_isCurrentAnswered) {
              final wasCorrect = _correctFlags[_currentQuestionIndex] ?? false;
              _answeredFlags[_currentQuestionIndex] = false;
              _correctFlags[_currentQuestionIndex] = false;
              _answeredQuestions--;
              if (wasCorrect) _correctAnswers--;
            }
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: AppStrings.quizAnswerHint,
            hintStyle: AppTextStyles.statSuffix(color: Colors.grey),
            filled: true,
            fillColor: showResult
                ? (_isCurrentCorrect ? AppColors.successBg : AppColors.errorBg)
                : AppColors.background,
            border: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(
                color: showResult
                    ? (_isCurrentCorrect ? AppColors.success : AppColors.errorLight)
                    : AppColors.inputBg,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(
                color: showResult
                    ? (_isCurrentCorrect ? AppColors.success : AppColors.errorLight)
                    : AppColors.inputBg,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(color: AppColors.primaryDark, width: 2),
            ),
            suffixIcon: showResult
                ? Icon(
                    _isCurrentCorrect ? Icons.check_circle : Icons.cancel,
                    color: _isCurrentCorrect ? AppColors.success : AppColors.errorLight,
                  )
                : null,
          ),
          style: AppTextStyles.statSuffix().copyWith(fontWeight: FontWeight.w500),
        ),
        if (showResult && !_isCurrentCorrect && question.correctAnswer != null) ...[
          const SizedBox(height: 12),
          Text(
            AppStrings.quizCorrectAnswer(question.correctAnswer!),
            style: AppTextStyles.actionSmall(color: AppColors.success),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    final block = _currentBlock;
    final isV2Block = block.hasV2Steps;
    final isDisplayBlock = block.atomicQuestion == null && !isV2Block;
    final isShowingSolution = isV2Block && _engineController.isShowingSolution;

    // FSRS practice: a display/content-TYPE block (display, content, motivation,
    // learning, org) — even one built from V2 text steps — is self-rated, not
    // checked. Show the four rating buttons instead of the "Zkontrolovat" flow.
    if (_selfRateDisplays &&
        block.type.isDisplayBlock &&
        !_isCurrentAnswered) {
      return _buildSelfRateBottomBar();
    }

    // Display blocks can always proceed (no answer needed).
    final canGoNext = isDisplayBlock || _isCurrentAnswered;
    final hasMultiSelection = (_selectedMultiAnswers[_currentQuestionIndex]?.isNotEmpty ?? false);
    // For V2 blocks, use the engine controller OR saved progress as fallback
    // (the controller may not have synced yet when the engine is first created).
    // The fallback checks for an actual selection, not just non-null progress —
    // after an AGAIN retry the pick is cleared but the progress entry remains,
    // and treating that as checkable would leave the button wrongly enabled.
    final canCheck = !isDisplayBlock && !_isCurrentAnswered && !isShowingSolution &&
        (isV2Block
            ? (_engineController.hasPendingAnswer || _v2HasSelection(_currentQuestionIndex))
            : (_selectedAnswers[_currentQuestionIndex] != null ||
                hasMultiSelection ||
                _getTextController(_currentQuestionIndex).text.isNotEmpty));
    final isLastCard = _currentQuestionIndex == _totalCards - 1;

    // Determine button action and label
    VoidCallback? onTap;
    String label;
    bool isEnabled;

    if (isShowingSolution) {
      if (_engineController.isAgainRetry) {
        // Wrong go_to=AGAIN answer: the engine keeps the pick marked incorrect
        // with its feedback but reveals no solution — the button clears the
        // pick for another attempt instead of continuing (matches the in-lesson
        // engine, which renders its own "Zkusit znovu" button in this state).
        onTap = _engineController.retryAgain;
        label = AppStrings.engineTryAgain;
      } else {
        // Engine showing solution feedback — button continues past it
        onTap = _engineController.continueAfterSolution;
        label = AppStrings.actionContinue;
      }
      isEnabled = true;
    } else if (canCheck) {
      onTap = isV2Block ? _engineController.confirm : _checkAnswer;
      label = widget.evaluate ? AppStrings.quizCheck : (isLastCard ? AppStrings.quizFinish : AppStrings.actionContinue);
      isEnabled = true;
    } else if (canGoNext) {
      onTap = _goToNextQuestion;
      label = isLastCard ? AppStrings.quizFinish : AppStrings.actionContinue;
      isEnabled = true;
    } else {
      onTap = null;
      label = widget.evaluate ? AppStrings.quizCheck : (isLastCard ? AppStrings.quizFinish : AppStrings.actionContinue);
      isEnabled = false;
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark08,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (_currentQuestionIndex > 0 && !isShowingSolution)
            IconButton(
              onPressed: _goToPreviousQuestion,
              icon: const Icon(Icons.arrow_back),
              color: AppColors.primaryDark,
            ),
          // Main button — full width
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppColors.primaryDark
                      : AppColors.inputBg,
                  borderRadius: AppDecorations.radiusM,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.statValue(
                    color: isEnabled ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
