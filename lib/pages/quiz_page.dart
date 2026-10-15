import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../core/elo/domain_elo_delta.dart';
import '../core/elo/elo_engine.dart';
import '../core/elo/gpf_vector_shape.dart';
import '../core/elo/task_difficulty.dart';
import '../core/evaluation/ai_answer_evaluator.dart';
import '../core/evaluation/expected_answer.dart';
import '../core/evaluation/gaming_filter.dart';
import '../core/evaluation/quiz_block_summary.dart';
import '../core/evaluation/quiz_feedback_comment.dart';
import '../core/gamification/global_quiz.dart';
import '../data/repositories/user_course_repository.dart';
import '../core/network/api_endpoints.dart';
import '../core/utils/content_format.dart';
import '../core/utils/image_url.dart';
import '../core/utils/ai_context_sanitizer.dart';
import '../core/providers/bookmark_provider.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/practice_providers.dart';
import '../core/practice/grade_calculator.dart';
import '../core/sync/sync_queue.dart';
import '../core/theme/app_theme.dart';
import '../models/course_model.dart';
import '../models/step_navigation.dart';
import 'lesson_detail/mentor_sheet.dart';
import '../widgets/answer_photo_picker.dart';
import '../widgets/block_step_engine.dart';
import '../widgets/lesson_image.dart';
import '../widgets/markdown_latex_widget.dart';
import '../widgets/open_answer_feedback_card.dart';
import '../widgets/quiz_feedback_dialog.dart';
import '../widgets/step_content_renderer.dart';
import '../core/strings/app_strings.dart';
import 'package:eduai/core/util/silent_log.dart';
import '../core/services/gaming_reference_service.dart';
import '../core/services/work_time_tracker.dart';
import '../models/chat_models.dart';
import 'chat_detail_page.dart';
import '../core/layout/breakpoints.dart';

/// Holds quiz answer state so progress survives page reopens.
class QuizProgress {
  int currentIndex = 0;
  int correctAnswers = 0;
  final Map<int, String?> selectedAnswers = {};
  final Map<int, Set<String>> selectedMultiAnswers = {};
  final Map<int, bool> answeredFlags = {};
  final Map<int, bool> correctFlags = {};
  /// Answers the gaming filter caught. Carried with the rest so reopening the
  /// page mid-quiz does not turn a guess back into a scored answer (BR-RQQVP6).
  final Map<int, bool> gamedFlags = {};
  final Map<int, String> textAnswers = {};
  /// V2 block step-level progress keyed by question index.
  final Map<int, StepProgressData> v2Progress = {};

  /// The questions the indices above point into, when the launcher drew them
  /// rather than asking every question (a course's Kvíz, BR-WRMW7W). Survives
  /// [reset]: a retry inside QuizPage asks the same questions again, and the
  /// answers it saves back still index into this list.
  List<ContentBlock>? questionBlocks;

  void reset() {
    currentIndex = 0;
    correctAnswers = 0;
    selectedAnswers.clear();
    selectedMultiAnswers.clear();
    answeredFlags.clear();
    correctFlags.clear();
    gamedFlags.clear();
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

  /// Overrides the AppBar heading. The default heading follows the behaviour
  /// flags above, which is wrong for the global quiz (BR-KEMJ4V): it runs with
  /// [isExercise] on to keep ELO and the completion dialog off the sentinel
  /// course, yet it is a quiz and must say "Kvíz".
  final String? appBarTitle;

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
    this.appBarTitle,
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
  late final WorkTimeTracker _workTimeTracker;
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

  // Shuffled answer order for atomic questions (by question index). See
  // [_displayOptions] — V2 step blocks shuffle inside BlockStepEngine instead.
  final Map<int, List<EvaluationOption>> _shuffledOptions = {};

  // Timestamp when each question was answered (by index)
  final Map<int, DateTime> _answerTimestamps = {};

  // AI grading results for open answers, by question index (BR-FFVVYR).
  // Only populated when the evaluator actually returned a verdict — a missing
  // entry means the answer was graded locally.
  final Map<int, AiEvaluationResult> _aiResults = {};

  /// True while an open answer is out for AI evaluation; blocks re-submission.
  bool _isEvaluatingWithAi = false;

  // ─── Photographed answers + retry (BR-P745Q8), by question index ──────────

  /// Why the last evaluation produced nothing. Present means the student is
  /// looking at a retry, not a verdict — the question stays unanswered.
  final Map<int, AiEvaluationFailure> _evaluationFailures = {};

  /// Photos picked but not yet uploaded.
  final Map<int, PickedAnswerPhoto> _pickedPhotos = {};

  /// Handles issued by the upload endpoint, once a photo is on the server.
  final Map<int, String> _photoNames = {};

  final Set<int> _uploadingPhotoIndexes = {};

  /// The evaluation asked for a better picture. Distinct from a failure: it
  /// produced feedback, the photo just could not be read.
  final Set<int> _unreadablePhotoIndexes = {};

  // Timestamp when each question was first shown (by index). Combined with
  // _answerTimestamps this gives the per-block solve duration that the
  // server records on `elo_interactions.opened_at` / `confirmed_at`.
  final Map<int, DateTime> _questionOpenedAt = {};

  // Tracks hint/help usage per question index for ELO score penalty.
  // 0 = no hint, 1 = hint shown, 2 = help (detailed explanation) shown.
  final Map<int, int> _hintUsage = {};

  // Answers caught by the gaming filter (answered faster than the threshold).
  // A gamed answer keeps its answered/correct flags for navigation, but moves
  // neither ELO nor FSRS and reports as "Tipováno" in the feedback popup.
  final Map<int, bool> _gamedFlags = {};

  // Every student's previous valid reaction times per block (seconds), the
  // reference that lifts the gaming threshold above the fixed 2 s once a task
  // has ten of them (BR-H3TCRE). Empty until fetched, and for good when
  // offline — both mean the fixed floor.
  Map<String, List<double>> _gamingReference = const {};

  // Detailed hint/help tracking per block ID for progress persistence.
  final Map<String, Map<String, dynamic>> _hintHelpTracking = {};

  // Guards against duplicate quiz-attempt submission from rapid taps,
  // hot reloads, or retries. Once true, stays true for the page's lifetime.
  bool _hasSubmittedAttempt = false;

  // Re-entrancy guard for the finish flow. Separate from _hasSubmittedAttempt:
  // that one gates the *submission*, this one only stops two overlapping runs
  // of the finish sequence, so a retry can still reach the feedback popup.
  bool _isCompleting = false;

  /// Student ELO profile as it stood immediately before this block's first ELO
  /// update. Captured lazily inside [_updateElo] rather than in initState so it
  /// cannot race the first answer, and stays null when the block never moved
  /// ELO at all (no GPF vectors, exercise mode) — which correctly yields no
  /// domain deltas in the summary. See BR-JCUJVR.
  List<double?>? _eloBefore;

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

  /// The dashboard's cross-course "Dej si kvíz" session. It runs with
  /// isExercise=true (exercise-style flow, no course-keyed writes) but must
  /// still behave like a quiz where it counts: ELO moves and the run ends in
  /// the feedback popup, not a silent pop.
  bool get _isGlobalQuiz => widget.courseId == globalQuizCourseId;

  /// True unless this is an exercise launched from lesson_detail_page
  /// (which handles its own ELO). Quiz-only courses also get ELO, and so does
  /// the global quiz — nobody else updates ELO for it.
  bool get _isQuizMode => !widget.isExercise || _isGlobalQuiz;

  int get _totalCards => widget.questionBlocks.length;
  int get _totalQuestions => widget.questionBlocks.where((b) =>
      b.atomicQuestion != null || b.hasV2Steps).length;

  /// Correct answers that actually count toward the score (BR-RQQVP6).
  ///
  /// A guess caught by the gaming filter carries no verdict at all, so it
  /// scores as neither right nor wrong — even when it happens to land on the
  /// right option. The raw [_correctAnswers] tally keeps counting it (it drives
  /// the per-answer log and the resume state); everything that reports a score
  /// reads this instead, so the headline can no longer say "5 z 5" over a
  /// breakdown that reports two of them as "Tipováno".
  int get _scoredCorrect => _buildBlockSummary().correct;
  bool get _isCurrentAnswered => _answeredFlags[_currentQuestionIndex] ?? false;
  bool get _isCurrentCorrect => _correctFlags[_currentQuestionIndex] ?? false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Track active work time while this quiz is open (BR-9SAH2R). Keep the
    // tracker instance — dispose() must not touch `ref` (Riverpod throws
    // "Cannot use ref after the widget was disposed", which used to abort the
    // rest of dispose incl. _saveProgress).
    _workTimeTracker = ref.read(workTimeTrackerProvider);
    _workTimeTracker.setLocation(
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
      _gamedFlags.addAll(p.gamedFlags);
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
    _loadGamingReference();
  }

  /// Fetch the gaming reference for this quiz's blocks. Non-blocking and
  /// best-effort: an answer submitted before it lands, or when it cannot be
  /// had at all, is judged against the fixed floor.
  Future<void> _loadGamingReference() async {
    try {
      final reference = await ref
          .read(gamingReferenceServiceProvider)
          .fetch(widget.questionBlocks.map((b) => b.blockId));
      if (mounted) _gamingReference = reference;
    } catch (e, st) { silentLog('quiz_page', e, st); }
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
      final restoredGamed = <int, bool>{};
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
        if (m['is_gamed'] == true) restoredGamed[idx] = true;
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
        _gamedFlags
          ..clear()
          ..addAll(restoredGamed);
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
    // Via the cached instance — `ref` must not be used in dispose() (Riverpod
    // throws, aborting the rest of this method incl. _saveProgress).
    _workTimeTracker.clearLocation();
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
                  // Matches the `block.hasHint` gate above: this row belongs
                  // to cards the step engine does not drive, so the block's own
                  // cursor is the only step on offer.
                  onTap: () => _showHintBottomSheet(block,
                      stepId: block.currentStep?.stepId),
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
    p.gamedFlags
      ..clear()
      ..addAll(_gamedFlags);
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

  /// Evaluate the current atomic question.
  ///
  /// Open questions detour through the API first; every other type is decided
  /// locally and applied straight away.
  void _checkAnswer() {
    if (_isEvaluatingWithAi) return;

    final block = _currentBlock;
    final question = block.atomicQuestion;
    if (question == null) return;

    // Every open answer is graded by AI (BR-N26ACB). `ai_evaluation` only
    // decides whether the student is shown the AI's feedback or a plain
    // right/wrong with the solution — see _buildOpenAnswer.
    if (question.isOpen) {
      unawaited(_checkOpenAnswerWithAi(block, question));
      return;
    }

    _applyCheckedAnswer(block, question);
  }

  /// Evaluate an open atomic answer with AI, then apply the outcome.
  ///
  /// A failure falls back to comparing the answer with the expected one
  /// (BR-N26ACB). BR-P745Q8 had replaced that fallback with a retry, because
  /// against a paragraph-long expected answer the comparison always fails; the
  /// brief now asks for it back, so an offline student still gets a verdict.
  /// Only an answer with no text to compare — a photo on its own — still gets
  /// the retry.
  Future<void> _checkOpenAnswerWithAi(
    ContentBlock block,
    AtomicQuestion question,
  ) async {
    final index = _currentQuestionIndex;
    setState(() {
      _isEvaluatingWithAi = true;
      _evaluationFailures.remove(index);
    });

    final evaluator = ref.read(aiAnswerEvaluatorProvider);

    // Upload an attached photo before evaluating. A failed upload is not fatal:
    // the answer may also have text, and the picked file stays put so a retry
    // does not require re-taking the picture.
    String? photoName = _photoNames[index];
    if (question.allowPhoto && _pickedPhotos[index] != null && photoName == null) {
      setState(() => _uploadingPhotoIndexes.add(index));
      final uploaded = await evaluator.uploadPhoto(
        bytes: _pickedPhotos[index]!.bytes,
        filename: _pickedPhotos[index]!.filename,
        courseId: widget.courseId,
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
      studentAnswer: _getTextController(index).text,
      photoName: photoName,
      help: block.atomicHelp,
      solution: question.solution,
      correctAnswer: question.correctAnswer,
      criteria: question.aiCriteria,
      criteriaList: question.aiCriteriaList,
    );

    if (!mounted) return;
    setState(() => _isEvaluatingWithAi = false);

    // The student may have navigated on while the call was in flight.
    if (_currentQuestionIndex != index || (_answeredFlags[index] ?? false)) {
      return;
    }

    if (!outcome.isSuccess) {
      // Offline, or the AI gave nothing back: grade by comparison with the
      // expected answer instead (BR-N26ACB), `ai_evaluation` on or off. The
      // student gets right/wrong and the solution; the expected answer itself
      // never appears.
      if (_getTextController(index).text.trim().isNotEmpty) {
        // A re-answered question may still hold the previous attempt's grade.
        _aiResults.remove(index);
        _applyCheckedAnswer(block, question);
        return;
      }
      // Not marked answered: the one-attempt rule is about the student's
      // answer, not about our infrastructure failing them.
      setState(() => _evaluationFailures[index] = outcome.failure!);
      return;
    }

    setState(() {
      if (outcome.result!.photoUnreadable) _unreadablePhotoIndexes.add(index);
    });

    _applyCheckedAnswer(block, question, aiResult: outcome.result);
  }

  /// Re-run an evaluation that failed, keeping the answer already written.
  void _retryEvaluation() {
    if (_isEvaluatingWithAi) return;
    final block = _currentBlock;
    final question = block.atomicQuestion;
    if (question == null || !question.isOpen) return;

    unawaited(_checkOpenAnswerWithAi(block, question));
  }

  void _onPhotoPicked(PickedAnswerPhoto photo) {
    setState(() {
      _pickedPhotos[_currentQuestionIndex] = photo;
      _photoNames.remove(_currentQuestionIndex);
      _unreadablePhotoIndexes.remove(_currentQuestionIndex);
    });
  }

  void _onPhotoRemoved() {
    setState(() {
      _pickedPhotos.remove(_currentQuestionIndex);
      _photoNames.remove(_currentQuestionIndex);
      _unreadablePhotoIndexes.remove(_currentQuestionIndex);
    });
  }

  void _applyCheckedAnswer(
    ContentBlock block,
    AtomicQuestion question, {
    AiEvaluationResult? aiResult,
  }) {
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
      _selectedAnswers[_currentQuestionIndex] = _getTextController(_currentQuestionIndex).text;
      if (aiResult != null) {
        isCorrect = aiResult.isCorrect;
        _aiResults[_currentQuestionIndex] = aiResult;
      } else {
        // Check open answer against every variant the author listed, one per
        // line (BR-RBUR29)
        isCorrect = matchesExpectedAnswer(
          _getTextController(_currentQuestionIndex).text,
          question.correctAnswer,
        );
      }
    }

    // Gaming filter: an answer faster than the threshold is a guess, not an
    // attempt. It stays in the answer log, but it is unevaluated — no ELO, no
    // FSRS, no practice seeding — and the popup reports it as "Tipováno".
    final answeredAt = DateTime.now();
    final gamed = isGamingAttempt(
      openedAt: _questionOpenedAt[_currentQuestionIndex],
      answeredAt: answeredAt,
      referenceTimesSeconds: _gamingReference[block.blockId] ?? const [],
    );

    setState(() {
      _answeredFlags[_currentQuestionIndex] = true;
      _correctFlags[_currentQuestionIndex] = isCorrect;
      _gamedFlags[_currentQuestionIndex] = gamed;
      _answerTimestamps[_currentQuestionIndex] = answeredAt;
      _answeredQuestions++;
      if (isCorrect) _correctAnswers++;
    });

    // Wrong atomic answer → seed a Practice (Cvičení) card, same as V2 blocks.
    if (!isCorrect && !gamed) _autoBookmarkOnWrong(block);

    // Update ELO for quiz mode — apply hint/help penalty.
    // AI grading contributes its partial score instead of a binary 1/0.
    double eloScore = aiResult?.score ?? (isCorrect ? 1.0 : 0.0);
    final hintLevel = _hintUsage[_currentQuestionIndex] ?? 0;
    if (hintLevel >= 2) {
      eloScore = eloScore.clamp(0.0, 0.5);
    } else if (hintLevel >= 1) {
      eloScore = eloScore.clamp(0.0, 0.75);
    }
    if (!gamed) _updateElo(block, eloScore);

    // FSRS practice: grade this block and reschedule its card.
    if (widget.isFsrsPractice && !gamed) {
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
    if (!block.type.seedsPracticeOnWrong) return;
    try {
      final db = ref.read(appDatabaseProvider);
      final localCourse = await db.getCourseByFieldCourseId(widget.courseId);
      if (localCourse == null) return;
      final bookmarkNotifier = ref.read(bookmarkProvider.notifier);
      if (bookmarkNotifier.isBookmarked(localCourse.id, block.blockId)) return;
      // Resolve the owning lesson: the quiz has no lesson context of its own,
      // and a bookmark (and the practice card seeded from it) without a
      // lesson_id is second-class data on the server (BR-ZBJ99Z).
      var lessonId = '';
      try {
        final course = Course.fromJsonData(
          id: localCourse.id,
          data: jsonDecode(localCourse.data) as Map<String, dynamic>,
        );
        final baseBlockId = block.blockId.contains(':')
            ? block.blockId.split(':').first
            : block.blockId;
        lessonId = course.findLessonForBlock(baseBlockId)?.lessonId ?? '';
      } catch (e, st) { silentLog('quiz_page:auto_bookmark_lesson', e, st); }
      bookmarkNotifier.addBookmark(localCourse.id, block, lessonId: lessonId);
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
      // Widened lookup: step-level bookmark cards store "base:step" blockIds
      // while the player resolves them to the base block.
      final card = await repo.getCardForResolvedBlock(user.id, block.blockId);
      if (card == null) {
        silentLog('quiz_page:fsrs_review',
            'no practice card found for block ${block.blockId} (user ${user.id})');
        return;
      }

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
      // The bonus queue reads the card rows directly, so it doesn't cascade
      // from the invalidation above — refresh it too or an extra set would
      // replay the card that was just reviewed.
      ref.invalidate(practiceBonusQueueProvider);
      // Same for the practice picker, whose per-area counts would otherwise
      // still list the card as due (BR-27AEMT).
      ref.invalidate(practiceScopeProvider);

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
      await _showHintBottomSheet(block, stepId: block.currentStep?.stepId);
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
          if (_gamedFlags[i] ?? false) 'is_gamed': true,
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
          'quiz_correct': _scoredCorrect,
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

    bool hasInput(StepAnswerState? answer) =>
        answer != null &&
        (answer.selectedOptionId != null ||
         (answer.selectedOptionIds?.isNotEmpty ?? false) ||
         (answer.textAnswer?.trim().isNotEmpty ?? false) ||
         answer.photoName != null);

    // A block with several questions is answered as a whole (BR-E4H835), so
    // every one of them must carry input before the block counts as checkable
    // — matching the engine's own gate.
    if (questionIndex >= 0 && questionIndex < widget.questionBlocks.length) {
      final questions = widget.questionBlocks[questionIndex].steps
          .where((s) => s.isEvaluationStep)
          .toList();
      if (questions.length > 1) {
        return questions.every((s) => hasInput(progress.stepAnswers[s.stepId]));
      }
    }

    return progress.stepAnswers.values.any(hasInput);
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

  /// Pull the AI verdict off a V2 block's step answers, if any step was graded
  /// by AI. A block holds at most one open question in practice, so the first
  /// AI-graded step answer is the one that matters (BR-FFVVYR).
  AiEvaluationResult? _extractV2AiResult(int questionIndex) {
    final progress = _v2Progress[questionIndex];
    if (progress == null) return null;
    for (final answer in progress.stepAnswers.values) {
      if (answer.evaluatedByAi) {
        return AiEvaluationResult(
          score: answer.scoreKoef ?? 0.0,
          isCorrect: answer.isCorrect ?? false,
          feedbackText: answer.aiFeedback ?? '',
          feedback: answer.feedback,
          model: answer.aiModel,
        );
      }
    }
    return null;
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
      // A guess rides along flagged, so the stored attempt stays honest about
      // why its score is lower than its tally of right answers (BR-RQQVP6).
      final gamed = _gamedFlags[i] ?? false;
      // AI grading of an open answer (BR-FFVVYR). Atomic blocks record it in
      // _aiResults; V2 blocks carry it on the step answer inside _v2Progress.
      final ai = _aiResults[i] ?? _extractV2AiResult(i);
      answers.add({
        'question_index': i,
        'question_id': block.blockId,
        'selected_answer': selectedAnswer,
        'is_correct': _correctFlags[i] ?? false,
        if (gamed) 'gamed': true,
        if (timestamp != null) 'answered_at': timestamp.toUtc().toIso8601String(),
        if (ai != null) ...{
          'evaluated_by_ai': true,
          'ai_score': ai.score,
          if (ai.feedbackText.isNotEmpty) 'ai_feedback': ai.feedbackText,
          if (ai.model != null) 'ai_model': ai.model,
          // Formative feedback + audit trail (BR-P745Q8). Rides inside the
          // existing answers JSON — same reason as BR-FFVVYR: the shape of one
          // answer changed, not the storage model.
          if (ai.feedback != null) 'feedback_parts': ai.feedback!.toJson(),
          if (ai.criteriaScores.isNotEmpty) 'criteria_scores': ai.criteriaScores,
          if (ai.promptVersion != null) 'prompt_version': ai.promptVersion,
          if (_photoNames[i] != null) 'photo_name': _photoNames[i],
          'attempt_status': 'evaluated',
        } else if (_evaluationFailures[i] != null) ...{
          // The student was shown a retry rather than a verdict; record that
          // rather than letting the attempt look merely wrong.
          'attempt_status': 'failed',
          if (_photoNames[i] != null) 'photo_name': _photoNames[i],
        },
      });
    }

    final payload = {
      'course_id': widget.courseId,
      'total_questions': _totalQuestions,
      'correct_answers': _scoredCorrect,
      'score_percent': _totalQuestions > 0
          ? ((_scoredCorrect / _totalQuestions) * 100).round()
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

    // The global quiz is exercise-shaped but ends like a quiz: submit the
    // attempt and show the feedback popup with the outcome breakdown and the
    // domain ELO movement ("Quiz Feedback v1").
    if (_isGlobalQuiz) {
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
  ///
  /// [stepId] is the step whose "?" was tapped, reported by BlockStepEngine —
  /// its own hint/help overrides the block's shared one (BR-JHDNB3). Null for
  /// atomic blocks, which have no steps.
  Future<void> _showHintBottomSheet(ContentBlock block, {String? stepId}) async {
    final hint = block.hintForStep(stepId);
    if (hint == null || hint.isEmpty) return;

    final idx = _currentQuestionIndex;
    final blockId = block.blockId;

    await showMentorSheet(
      context: context,
      block: block,
      stepId: stepId,
      buildAiContext: () =>
          _buildQuizChatContext(idx, includeClosingPrompt: false),
      // A graded test keeps the AI mentor out of reach — the sheet then stops
      // at the block's own help text, as the old "Zeptat se AI" gate did.
      allowAi: widget.evaluate,
      // The quiz has no bookmark store, so it cannot offer the practice reply.
      onSavePractice: null,
      onShown: () {
        // Track hint usage for ELO score penalty
        final prev = _hintUsage[idx] ?? 0;
        if (prev < 1) _hintUsage[idx] = 1;

        // Detailed hint tracking with timestamps and counters
        final now = DateTime.now().toUtc().toIso8601String();
        _hintHelpTracking.putIfAbsent(blockId, () => {});
        final tracking = _hintHelpTracking[blockId]!;
        tracking['hint_count'] = (tracking['hint_count'] as int? ?? 0) + 1;
        tracking['hint_first_ts'] ??= now;
        tracking['hint_last_ts'] = now;
      },
      onEscalateToHelp: () {
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
      onAskMentor: (question, {required isFirst}) {
        // The opening question doubles as block feedback — parity with the
        // "Upřesni svůj dotaz" form this sheet replaces.
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

  /// [flushNow] runs a sync straight away instead of waiting for the periodic
  /// timer — false for the mentor sheet, whose question is enqueued alongside
  /// the chat POST the student is waiting on (BR-M7EQY8).
  Future<void> _enqueueFeedback({
    required String blockId,
    required String type,
    String? message,
    bool flushNow = true,
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
      if (flushNow) {
        final syncService = ref.read(syncServiceProvider);
        syncService.sync();
      }
    } catch (e, st) { silentLog('quiz_page', e, st); }
  }

  /// Build the AI-chat context describing the quiz block at [index].
  ///
  /// [includeClosingPrompt] is false for the mentor sheet, which sends the
  /// student's question as its own visible message and therefore needs the
  /// context without a request tacked on the end.
  String _buildQuizChatContext(
    int index, {
    String? studentMessage,
    bool includeClosingPrompt = true,
  }) {
    final block = widget.questionBlocks[index];
    final courseName = widget.courseTitle;

    final hint = sanitizeAiContext(block.currentHint ?? '');
    final help = sanitizeAiContext(block.currentHelp ?? '');

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
    // Drop media links before the 400-char budget is measured (BR-KFHPAR).
    blockContent = sanitizeAiContext(blockContent);

    // For question blocks, include question and options
    String questionInfo = '';
    if (block.atomicQuestion != null) {
      final q = block.atomicQuestion!;
      final optionTexts =
          q.options.map((o) => '- ${sanitizeAiContext(o.label)}').join('\n');
      questionInfo = AppStrings.chatContextQuestionWithOptions(optionTexts);
    } else {
      for (final step in block.steps) {
        if (step.evaluationConfig != null) {
          final opts = step.evaluationConfig!.options
              .map((o) => '- ${sanitizeAiContext(o.label)}')
              .join('\n');
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
      if (includeClosingPrompt && studentMessage != null && studentMessage.isNotEmpty)
        studentMessage,
      if (includeClosingPrompt) AppStrings.chatContextFallbackPrompt,
    ];
    return contextParts
        .where((s) => s.isNotEmpty || contextParts.indexOf(s) == 1)
        .join('\n');
  }

  /// Open the full AI chat page with context about the current quiz block.
  ///
  /// The context travels as the hidden `context` message the server keeps for
  /// the model; the transcript opens with the student's question rather than
  /// the assembled blob (BR-NAH3TR).
  void _openChatWithContext(int index, {String? studentMessage}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          sessionId: '',
          sessionTitle: widget.courseTitle,
          persona: ChatPersona.mathMentor,
          initialContext:
              _buildQuizChatContext(index, includeClosingPrompt: false),
          initialQuestion: (studentMessage != null &&
                  studentMessage.trim().isNotEmpty)
              ? studentMessage.trim()
              : null,
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
          if (_gamedFlags[i] ?? false) 'is_gamed': true,
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
              ? ((_scoredCorrect / _totalQuestions) * 100).round()
              : 0,
          'quiz_correct': _scoredCorrect,
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
    if (_isCompleting) return;
    _isCompleting = true;
    try {
      // Quiz-attempt submission / progress / trophy are course-quiz concerns —
      // skip them for a cross-course FSRS practice session. Guarded separately
      // so a retry still reaches the feedback popup below.
      if (!_hasSubmittedAttempt) {
        _hasSubmittedAttempt = true;
        if (!widget.isFsrsPractice) {
          await _submitQuizAttempt();
          await _saveQuizProgressLocally();
          await _awardQuizTrophy();
        }

        // FSRS practice: bank the XP accumulated across the session so it
        // counts toward the user's level/daily XP.
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
      }

      if (!mounted) return;
      await _showQuizFeedback();
    } finally {
      _isCompleting = false;
    }
  }

  /// End-of-quiz feedback popup — "Quiz Feedback v1" (BR-JCUJVR).
  ///
  /// Always shown, including for courses with `quiz_evaluate` off, which used
  /// to pop straight back to the course list leaving the student with no
  /// acknowledgement at all. What differs by that flag is the *content*: with
  /// evaluation off the outcome counts are withheld (they are the score, which
  /// the course deliberately hides) while the domain-level ELO movement still
  /// shows — that is the student's own long-term profile, surfaced on the
  /// skills page regardless of any course setting.
  Future<void> _showQuizFeedback() async {
    final domainDeltas = await _computeDomainEloDeltas();
    final domainNames = domainDeltas.isEmpty
        ? const <String, String>{}
        : await _loadDomainNames();
    if (!mounted) return;

    final summary = _buildBlockSummary();
    // Guesses are reported on their own row and score as nothing (BR-RQQVP6),
    // so every line below counts off the summary rather than the raw tally.
    final scoredCorrect = summary.correct;
    final hasQuestions = _totalQuestions > 0;
    final allCorrect = hasQuestions && scoredCorrect == _totalQuestions;
    final mostCorrect = hasQuestions && scoredCorrect >= _totalQuestions * 0.7;
    final pageNavigator = Navigator.of(context);

    // AI comment on the block — online-only and best-effort (the dialog shows
    // a spinner until it resolves, and nothing at all when it fails). Started
    // here so it runs while the student reads the counts. Withheld together
    // with the outcome counts when the course hides evaluation.
    final aiCommentFuture = widget.evaluate && hasQuestions
        ? _fetchAiComment(domainDeltas)
        : null;

    // Retry is offered only where returning to the quiz is actually allowed:
    // a only_once course promises the opposite in its submit confirmation.
    final canRetry = widget.evaluate &&
        hasQuestions &&
        !widget.onlyOnce &&
        !widget.isFsrsPractice &&
        scoredCorrect < _totalQuestions;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (doneCtx) => QuizFeedbackDialog(
        title: widget.isFsrsPractice
            ? AppStrings.practiceCompleted
            : !widget.evaluate
                ? AppStrings.quizSubmittedTitle
                : hasQuestions
                    ? AppStrings.quizCompleted
                    : AppStrings.quizReviewCompleted,
        headline: !widget.evaluate
            ? AppStrings.quizSubmittedThanks
            : hasQuestions
                ? AppStrings.quizCorrectResult(scoredCorrect, _totalQuestions)
                : AppStrings.quizCardsReviewed(_totalCards),
        subline: !widget.evaluate
            ? null
            : !hasQuestions
                ? AppStrings.quizGreatReview
                : allCorrect
                    ? AppStrings.quizAllCorrect
                    : mostCorrect
                        ? AppStrings.quizGreatJob
                        : AppStrings.quizTryAgain,
        icon: !widget.evaluate
            ? Icons.check_circle_outline
            : !hasQuestions
                ? Icons.auto_stories
                : allCorrect
                    ? Icons.emoji_events
                    : mostCorrect
                        ? Icons.thumb_up
                        : Icons.refresh,
        iconColor: !widget.evaluate
            ? AppColors.primaryDark
            : !hasQuestions
                ? AppColors.quizPurple
                : allCorrect
                    ? Colors.amber
                    : mostCorrect
                        ? AppColors.success
                        : AppColors.errorLight,
        summary: widget.evaluate ? summary : null,
        domainDeltas: domainDeltas,
        domainNames: domainNames,
        // The green success panel started out as a practice-only flourish; the
        // client asked for the same close on a quiz (BR-9SCMRQ). Practice
        // scores itself off the FSRS ratings it just wrote, a quiz off its own
        // correct/total — and neither shows a score a course wanted hidden.
        successPercent: widget.isFsrsPractice
            ? (_fsrsReviewedCount == 0
                ? 0
                : ((_fsrsCorrectCount / _fsrsReviewedCount) * 100).round())
            : (widget.evaluate && hasQuestions
                ? ((scoredCorrect / _totalQuestions) * 100).round()
                : null),
        // Only a practice session banks XP today.
        xpEarned: widget.isFsrsPractice ? _fsrsXpEarned : null,
        aiCommentFuture: aiCommentFuture,
        onDone: () {
          Navigator.pop(doneCtx);
          if (mounted) pageNavigator.pop(true);
        },
        onRetry: canRetry
            ? () {
                Navigator.pop(doneCtx);
                _resetQuiz();
              }
            : null,
      ),
    );
  }

  /// Tally this block's outcomes over the question blocks only — display-only
  /// cards carry no verdict and must not land in the counts.
  QuizBlockSummary _buildBlockSummary() {
    final questionIndexes = <int>[];
    for (var i = 0; i < widget.questionBlocks.length; i++) {
      final b = widget.questionBlocks[i];
      if (b.atomicQuestion == null && !b.hasV2Steps) continue;
      questionIndexes.add(i);
    }
    return QuizBlockSummary.fromAnswers(
      questionIndexes: questionIndexes,
      answeredFlags: _answeredFlags,
      correctFlags: _correctFlags,
      hintUsage: _hintUsage,
      gamedFlags: _gamedFlags,
    );
  }

  /// Task statement of [block] as plain text for the AI comment — same
  /// extraction the mentor-chat context uses, with the same media scrub.
  String _blockAssignmentText(ContentBlock block) {
    String text;
    if (block.steps.isNotEmpty) {
      text = block.steps
          .map((s) => s.displayText)
          .where((t) => t.isNotEmpty)
          .join('\n');
    } else {
      text = block.displayContent;
    }
    text = sanitizeAiContext(text).trim();
    return text.length > 500 ? '${text.substring(0, 500)}…' : text;
  }

  /// The AI comment on how this block went. Resolves to null on any failure —
  /// the feedback popup then hides the section.
  Future<String?> _fetchAiComment(List<DomainEloDelta> domainDeltas) async {
    try {
      final tasks = <QuizFeedbackTask>[];
      for (var i = 0; i < widget.questionBlocks.length; i++) {
        final block = widget.questionBlocks[i];
        if (block.atomicQuestion == null && !block.hasV2Steps) continue;
        final hintLevel = _hintUsage[i] ?? 0;
        final openedAt = _questionOpenedAt[i];
        final answeredAt = _answerTimestamps[i];
        tasks.add(QuizFeedbackTask(
          assignment: _blockAssignmentText(block),
          outcome: QuizBlockSummary.outcomeFor(
            answered: _answeredFlags[i] ?? false,
            correct: _correctFlags[i] ?? false,
            hintLevel: hintLevel,
            gamed: _gamedFlags[i] ?? false,
          ).wireName,
          hintUsed: hintLevel >= 1,
          helpUsed: hintLevel >= 2,
          durationMs: openedAt != null && answeredAt != null
              ? answeredAt.difference(openedAt).inMilliseconds.clamp(0, 1 << 31)
              : null,
        ));
      }
      if (tasks.isEmpty) return null;
      return await ref.read(quizFeedbackCommentProvider).fetchComment(
            tasks: tasks,
            domainDeltas: {
              for (final d in domainDeltas) d.domain.code: d.delta,
            },
          );
    } catch (e, st) {
      silentLog('quiz_page', e, st);
      return null;
    }
  }

  /// Average ELO movement per GPF domain over this block, or an empty list
  /// when nothing moved (no ELO updates, no profile, or offline read failure).
  Future<List<DomainEloDelta>> _computeDomainEloDeltas() async {
    final before = _eloBefore;
    if (before == null) return const [];
    try {
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user == null) return const [];
      final profile = await ref.read(eloRepositoryProvider).getProfile(user.id);
      if (profile == null) return const [];
      return computeDomainEloDeltas(before: before, after: profile.profilElo);
    } catch (e, st) {
      silentLog('quiz_page', e, st);
      return const [];
    }
  }

  /// Czech domain names from the backend's canonical labels (Drift-cached,
  /// bundled-asset fallback), so the popup works offline. Falls back to the
  /// bare domain code if even that fails.
  Future<Map<String, String>> _loadDomainNames() async {
    try {
      return await ref.read(gpfLabelRepositoryProvider).domainNames();
    } catch (e, st) {
      silentLog('quiz_page', e, st);
      return const {};
    }
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
      // Hint usage and the ELO baseline belong to the attempt, not the page:
      // without clearing them the retry's feedback popup would report the
      // previous run's hints and ELO movement (BR-JCUJVR).
      _hintUsage.clear();
      _eloBefore = null;
      // Gaming verdicts and the solve-time clocks too — without resetting
      // the opened-at times, every retry answer would measure from the first
      // run and the gaming filter could never fire again.
      _gamedFlags.clear();
      _questionOpenedAt
        ..clear()
        ..[0] = DateTime.now().toUtc();
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

    // Read up front: the catch below can run after the page is gone.
    final eloFailureReporter = ref.read(eloFailureReporterProvider);
    final courseId = widget.courseId;

    try {
      final eloRepo = ref.read(eloRepositoryProvider);
      final syncQueue = ref.read(syncQueueProvider);

      final profile = await eloRepo.getOrCreateProfile(user.id);
      // First ELO-moving answer of this block — snapshot the "before" side of
      // the end-of-quiz domain deltas (BR-JCUJVR).
      _eloBefore ??= List<double?>.from(profile.profilElo);
      // The engine rejects anything that is not exactly 35 slots wide, so fit
      // every vector to the GPF shape first (see gpf_vector_shape.dart).
      final castRelation = fitGpfVector(
        relationVector.map((e) => e ?? 0.0).toList(),
        0.0,
      );
      // The server's calibrated difficulty where it has one, the content's
      // elsewhere — the global quiz too, whatever course the block came
      // from. Only the student half of the result is kept: the server is the
      // only writer of D and its counts (BR-697NCA).
      final taskElo = await eloRepo.effectiveTaskElo(block.blockId, eloVector);
      final profilEloBefore = fitGpfVector(profile.profilElo, null);

      final result = EloEngine.updateTask(
        profilElo: profilEloBefore,
        profilPocet: fitGpfVector(profile.profilPocet, 0),
        relationVector: castRelation,
        eloVector: taskElo,
        itemPocet: List<int>.filled(kGpfDimensions, 0),
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

      // The queue id doubles as the server's idempotency key, so a re-sent
      // answer never moves D twice.
      final interactionId = const Uuid().v4();
      await syncQueue.enqueue(
        tableName: 'elo_interactions',
        recordId: interactionId,
        operation: SyncOperation.create,
        payload: {
          'block_id': block.blockId,
          'course_id': widget.courseId,
          'source': 'quiz',
          'score': score,
          'hint_used': (_hintUsage[_currentQuestionIndex] ?? 0) >= 1,
          'help_used': (_hintUsage[_currentQuestionIndex] ?? 0) >= 2,
          'profil_elo_snapshot': result.profilElo,
          ...taskCalibrationFields(
            clientUuid: interactionId,
            profilEloBefore: profilEloBefore,
            eloVectorUsed: taskElo,
          ),
          'updated_indices': result.updatedIndices,
          'elo_config_version': result.configVersion,
          if (openedAt != null) 'opened_at': openedAt.toIso8601String(),
          'confirmed_at': confirmedAt.toIso8601String(),
          if (durationMs != null) 'duration_ms': durationMs,
        },
      );
    } catch (e, st) {
      silentLog('quiz_page', e, st);
      // silentLog is silent in release builds, and a block whose vectors the
      // engine rejects would stop moving ELO unnoticed (BR-S9SVNM).
      unawaited(eloFailureReporter.report(
        source: 'quiz',
        courseId: courseId,
        blockId: block.blockId,
        error: e,
        stackTrace: st,
        relationVector: relationVector,
        eloVector: eloVector,
      ));
    }
  }

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
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
          widget.appBarTitle ??
              (widget.isFsrsPractice
                  ? AppStrings.practiceTitle
                  : widget.isExercise
                      ? AppStrings.quizExerciseTitle
                      : AppStrings.quizTitle),
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
                  // The running count is a score readout like the recap's, so
                  // guesses stay out of it too (BR-RQQVP6).
                  AppStrings.quizCorrectCount(_scoredCorrect, _totalQuestions),
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
        showAnswerStatus: widget.evaluate,
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
          // Same gaming filter as _applyCheckedAnswer — completing a whole
          // step block under the threshold is guessing all the same.
          final answeredAt = DateTime.now();
          final gamed = isGamingAttempt(
            openedAt: _questionOpenedAt[_currentQuestionIndex],
            answeredAt: answeredAt,
            referenceTimesSeconds: _gamingReference[
                    widget.questionBlocks[_currentQuestionIndex].blockId] ??
                const [],
          );
          setState(() {
            _answeredFlags[_currentQuestionIndex] = true;
            _correctFlags[_currentQuestionIndex] = isNowCorrect;
            _gamedFlags[_currentQuestionIndex] = gamed;
            _answerTimestamps[_currentQuestionIndex] = answeredAt;
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
          if (!gamed) {
            _updateElo(widget.questionBlocks[_currentQuestionIndex], eloScore);
          }
          // FSRS practice: V2 (step-engine) blocks complete through this
          // callback, not _checkAnswer, so grade + reschedule the card here
          // too — without this, V2 exercise cards were never reviewed and
          // stayed due forever.
          if (widget.isFsrsPractice && !gamed) {
            _recordFsrsReview(
              block: widget.questionBlocks[_currentQuestionIndex],
              index: _currentQuestionIndex,
              isCorrect: isNowCorrect,
              hintLevel: hintLevel,
            );
          }
          _persistPartialProgress();
          // Auto-advance: when show_answers=false there's no feedback,
          // and when evaluate=true the user already saw solution via "Pokračovat".
          if (_currentBlockHidesAnswers || widget.evaluate) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _goToNextQuestion();
            });
          }
        },
        // The engine gates the button per step and reports which one asked.
        onHintRequested: (stepId) =>
            _showHintBottomSheet(block, stepId: stepId),
        onChatRequested: widget.evaluate ? () => _openChatWithContext(_currentQuestionIndex) : null,
        onWrongAnswer: () => _autoBookmarkOnWrong(block),
      );
    }

    final question = block.atomicQuestion;

    // Get content
    final content = block.displayContent;
    final hasHtml = looksLikeHtml(content);
    final hasMarkdown = !hasHtml && looksLikeMarkdown(content);

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
        extensions: lessonHtmlImageExtensions(),
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
      final hasHtml = looksLikeHtml(c);
      final hasMarkdown = !hasHtml && looksLikeMarkdown(c);
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

  /// Display order for an atomic question's options, shuffled once per quiz
  /// session when the question (or its course) asks for it.
  ///
  /// Cached by question index rather than shuffled inline: this runs from
  /// build(), so a fresh shuffle per call would reorder the answers on every
  /// setState. A new QuizPage mount = a new session = a new order.
  List<EvaluationOption> _displayOptions(AtomicQuestion question) {
    if (!question.shuffleOptions) return question.options;
    return _shuffledOptions.putIfAbsent(
      _currentQuestionIndex,
      question.shuffledOptions,
    );
  }

  Widget _buildMultipleChoiceOptions(AtomicQuestion question) {
    final isMulti = question.allowMultiple;
    final showResult = _isCurrentAnswered && widget.evaluate;

    return Column(
      children: _displayOptions(question).map((option) {
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
                      option.label,
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
    final index = _currentQuestionIndex;
    final controller = _getTextController(index);

    // AI-evaluated open questions are formative (BR-P745Q8): no verdict, no
    // colour-coding, and never the expected answer. Everything that would read
    // as a mark is switched off for them rather than restyled.
    final formative = question.aiEvaluation;
    final failure = _evaluationFailures[index];

    // Offline, or the AI gave nothing back, so the answer was compared with the
    // expected one instead (BR-N26ACB). There is no feedback to hold back for
    // the end of the quiz, so even a formative question shows its verdict.
    final gradedByComparison = _isCurrentAnswered && _aiResults[index] == null;
    final showResult = _isCurrentAnswered && (!formative || gradedByComparison);

    Color fieldFill() => showResult
        ? (_isCurrentCorrect ? AppColors.successBg : AppColors.errorBg)
        : AppColors.background;

    Color fieldBorder() => showResult
        ? (_isCurrentCorrect ? AppColors.success : AppColors.errorLight)
        : AppColors.inputBg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          // A quiz is one attempt (BR-P745Q8). Formative questions lock once
          // answered; exact-match questions keep the behaviour they had.
          enabled: !(formative && _isCurrentAnswered),
          maxLines: formative ? 5 : 1,
          minLines: formative ? 3 : 1,
          keyboardType: formative ? TextInputType.multiline : TextInputType.text,
          onChanged: (_) {
            // Reset answered state to allow re-answering
            if (_isCurrentAnswered && !formative) {
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
            fillColor: fieldFill(),
            border: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(color: fieldBorder(), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(color: fieldBorder(), width: 2),
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

        // Photo attach. Rendered only when the author enabled it — the brief
        // requires the option to be absent, not disabled, when the switch is off.
        if (question.allowPhoto) ...[
          const SizedBox(height: 8),
          AnswerPhotoPicker(
            picked: _pickedPhotos[index],
            uploadedName: _photoNames[index],
            isUploading: _uploadingPhotoIndexes.contains(index),
            unreadable: _unreadablePhotoIndexes.contains(index),
            onPicked: _isCurrentAnswered ? null : _onPhotoPicked,
            onRemoved: _isCurrentAnswered ? null : _onPhotoRemoved,
          ),
        ],

        // The expected answer is never printed, practice included (BR-N26ACB)
        // — authors write it as a grading key and the editor promises the
        // student never sees it (BR-RBUR29). The red border + cancel icon
        // carry the verdict, and the solution below does the teaching.
        //
        // Nor is the AI's feedback, unless the author switched `ai_evaluation`
        // on: the answer was graded by AI all the same, but the student of an
        // exact-match question gets right/wrong and the solution.

        if (failure != null) ...[
          const SizedBox(height: 12),
          OpenAnswerRetryNotice(
            offline: failure == AiEvaluationFailure.offline,
            canRetry: failure != AiEvaluationFailure.notEvaluable,
            onRetry: _retryEvaluation,
          ),
        ],

        // Quiz: one attempt, and feedback lands once the block is finished —
        // which for an atomic question is the moment it is answered. When the
        // course switched evaluation off entirely there is nothing to show, so
        // the student gets an acknowledgement instead of silence.
        if (formative &&
            _isCurrentAnswered &&
            failure == null &&
            !gradedByComparison) ...[
          const SizedBox(height: 12),
          if (widget.evaluate && _aiResults[index]?.feedback != null)
            // No `retryPending`: a quiz grants one attempt, so the sections
            // that tell the student what to do on the next one have no next
            // one to point at (BR-Y3A5M8).
            OpenAnswerFeedbackCard(
              feedback: _aiResults[index]!.feedback!,
            )
          else
            Text(
              AppStrings.openFeedbackQuizPending,
              style: AppTextStyles.meta(color: AppColors.primaryDark80),
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

    // An AI-graded open answer is a network round trip (25s, 55s with a photo),
    // and this bar is the only button on screen — the engine hides its own
    // spinner whenever a controller drives it. Without this the tap looked
    // like a no-op for seconds on end (BR-4AT4CC). Both answer paths report
    // here: V2 steps through the engine controller, atomic open questions
    // through _isEvaluatingWithAi.
    if (_isEvaluatingWithAi || _engineController.isEvaluating) {
      return _buildEvaluatingBottomBar();
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
                // A photo is a complete answer by itself (BR-HF7F2H) — the
                // whole point of allow_photo is handing in work done on paper.
                _pickedPhotos[_currentQuestionIndex] != null ||
                _photoNames[_currentQuestionIndex] != null ||
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

    return _bottomBarShell(
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

  /// Bottom bar while an answer is out for AI grading (BR-4AT4CC).
  ///
  /// No [GestureDetector] and no back arrow: the bar is inert for as long as
  /// the call is in flight. Dropping the arrow is deliberate — leaving the
  /// question mid-call would strand the engine controller's evaluating flag on
  /// the next question, and there is nothing useful to go back to anyway.
  Widget _buildEvaluatingBottomBar() {
    return _bottomBarShell(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: AppDecorations.radiusM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                AppStrings.openFeedbackEvaluating,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.statValue(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shared chrome for every bottom-bar variant, so the busy state cannot
  /// drift from the normal one.
  Widget _bottomBarShell({required Widget child}) {
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
      child: child,
    );
  }
}
