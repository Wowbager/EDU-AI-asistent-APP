// Core state machine widget managing step-by-step navigation within a block.
//
// Handles linear display flow, go_to branching for question blocks,
// exercise mode (linear + evaluated), and quizV2 mode (no hints/solutions).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../core/evaluation/ai_answer_evaluator.dart';
import '../core/evaluation/expected_answer.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/app_toast.dart';
import '../data/repositories/open_answer_repository.dart';
import '../models/block_model.dart';
import '../models/step_navigation.dart';
import 'answer_photo_picker.dart';
import 'step_content_renderer.dart';

/// Controller that allows a parent widget (e.g. QuizPage) to query and drive
/// the BlockStepEngine externally — so the parent's bottom bar can replace
/// the engine's own confirm/next buttons.
class BlockStepEngineController extends ChangeNotifier {
  VoidCallback? _confirmCallback;
  VoidCallback? _continueCallback;
  VoidCallback? _retryCallback;
  bool _hasPendingAnswer = false;
  bool _isShowingSolution = false;
  bool _isAgainRetry = false;
  bool _isEvaluating = false;

  /// Whether the engine has a selected-but-unconfirmed answer.
  bool get hasPendingAnswer => _hasPendingAnswer;

  /// Whether an open answer is currently being graded by AI (BR-FFVVYR).
  /// Parents driving their own bottom bar should disable it and show progress.
  bool get isEvaluating => _isEvaluating;

  /// Whether the engine is showing solution feedback (quiz with evaluate).
  bool get isShowingSolution => _isShowingSolution;

  /// Whether the engine is on a wrong go_to=AGAIN answer awaiting a retry.
  /// When true the parent's bottom bar should offer "Zkusit znovu" (retry)
  /// instead of "Pokračovat" (continue) — the engine hides its own button.
  bool get isAgainRetry => _isAgainRetry;

  /// Trigger answer confirmation from outside the engine.
  void confirm() => _confirmCallback?.call();

  /// Continue past the solution screen from outside the engine.
  void continueAfterSolution() => _continueCallback?.call();

  /// Clear a wrong AGAIN pick and re-enable answering from outside the engine.
  void retryAgain() => _retryCallback?.call();

  // ── internal wiring (called by _BlockStepEngineState) ──

  void _attach(VoidCallback confirmFn) {
    _confirmCallback = confirmFn;
  }

  void _attachContinue(VoidCallback continueFn) {
    _continueCallback = continueFn;
  }

  void _attachRetry(VoidCallback retryFn) {
    _retryCallback = retryFn;
  }

  /// Detach only if still bound to [confirmFn]. When a keyed engine is
  /// recreated (e.g. quiz navigation), the new State's initState (_attach)
  /// runs before the old State's dispose (_detach); an unconditional detach
  /// would null the freshly attached callbacks and break the parent's
  /// confirm/continue button.
  void _detachIfCurrent(VoidCallback confirmFn) {
    if (identical(_confirmCallback, confirmFn)) {
      _confirmCallback = null;
      _continueCallback = null;
      _retryCallback = null;
    }
  }

  void _setPendingAnswer(bool value) {
    if (_hasPendingAnswer != value) {
      _hasPendingAnswer = value;
      notifyListeners();
    }
  }

  void _setEvaluating(bool value) {
    if (_isEvaluating != value) {
      _isEvaluating = value;
      notifyListeners();
    }
  }

  /// Clear the flag without notifying. Called from the engine's [State.dispose],
  /// which runs inside the parent's build phase — notifying there would fire a
  /// setState mid-build. The parent is rebuilding anyway (that is what unmounted
  /// the engine), so it will read the cleared value on this very pass.
  void _clearEvaluatingSilently() {
    _isEvaluating = false;
  }

  void _setShowingSolution(bool value) {
    if (_isShowingSolution != value) {
      _isShowingSolution = value;
      notifyListeners();
    }
  }

  void _setAgainRetry(bool value) {
    if (_isAgainRetry != value) {
      _isAgainRetry = value;
      notifyListeners();
    }
  }
}

/// One open (free-text) answer the engine has just evaluated (BR-FFVVYR).
///
/// Emitted so the host page can persist it with course/lesson context the
/// engine does not have. QuizPage ignores this — quiz answers ride along in
/// the quiz-attempt payload instead.
class OpenAnswerEvent {
  final String blockId;
  final String stepId;
  final String answerText;
  final bool isCorrect;
  final bool evaluatedByAi;
  final double? aiScore;
  final String? aiFeedback;
  final String? aiModel;

  // ─── BR-P745Q8 ─────────────────────────────────────────────────────────────

  /// Idempotency key, minted when the answer is *given*. Carried through so a
  /// queue replay updates one row and a retry stores a separate attempt.
  final String attemptId;

  /// The three-part feedback, ready to serialize.
  final Map<String, dynamic>? feedbackParts;

  final List<Map<String, dynamic>> criteriaScores;

  /// Snapshot of what this attempt was judged against, so the stored attempt
  /// stays readable after the question is edited.
  final Map<String, dynamic>? gradingBasis;

  /// True when AI evaluation ran and produced nothing. Stored as its own
  /// attempt rather than dropped — the student saw a retry, and a teacher
  /// should be able to see why.
  final bool failed;

  final String? photoName;
  final String? promptVersion;

  const OpenAnswerEvent({
    required this.blockId,
    required this.stepId,
    required this.answerText,
    required this.isCorrect,
    required this.attemptId,
    this.evaluatedByAi = false,
    this.aiScore,
    this.aiFeedback,
    this.aiModel,
    this.feedbackParts,
    this.criteriaScores = const [],
    this.gradingBasis,
    this.failed = false,
    this.photoName,
    this.promptVersion,
  });
}

/// Internal state of the step engine
enum _EngineState {
  showingStep,     // Displaying a text/image/video step or a question before answer
  awaitingAnswer,  // Question shown, waiting for user to confirm selection
  showingSolution, // Answer evaluated, showing feedback/solution
  blockComplete,   // All steps done
}

class BlockStepEngine extends ConsumerStatefulWidget {
  final ContentBlock block;
  final ExportMode exportMode;
  final bool isCurrent;
  final bool isCompleted;
  final void Function({int earnedXp, double scoreKoef, String? mark}) onBlockCompleted;
  final void Function(String blockId)? onCrossBlockNavigate;
  final void Function()? onChatRequested;
  final void Function(StepProgressData)? onStepProgress;
  final StepProgressData? savedProgress;

  /// Optional controller for external answer confirmation (used by QuizPage).
  /// When provided, the engine hides its own bottom row and lets the parent
  /// drive confirm/next via the controller.
  final BlockStepEngineController? controller;

  // Block-level action callbacks (for exercise/question blocks — single bubble)
  final void Function()? onBookmarkToggle;
  final void Function()? onLikeToggle;
  final void Function()? onDislikeToggle;

  /// The student asked for the hint on [stepId] — the step whose action row was
  /// tapped. The engine owns the live step index, so the id has to travel with
  /// the request: the block's own cursor stays at 0 and would resolve the first
  /// step's hint (or the block's shared one) for every step (BR-JHDNB3).
  /// Null for atomic blocks, which have no steps.
  final void Function(String? stepId)? onHintRequested;

  /// Called when the user answers a question incorrectly.
  /// Used by parents to auto-bookmark the block for practice.
  final void Function()? onWrongAnswer;

  /// Called after an open (free-text) answer is evaluated, so the host page can
  /// persist it with course/lesson context (BR-FFVVYR).
  final void Function(OpenAnswerEvent)? onOpenAnswerEvaluated;

  /// Which attempt at an open question counts toward progress: "last" or
  /// "best" (CourseV2.open_answer_score, BR-P745Q8). Only affects open
  /// questions — every other type keeps taking the best attempt.
  final String openAnswerScore;

  /// Whether the course shows the student how their answer came out
  /// (CourseV2.quiz_evaluate — "Show correct/incorrect feedback and score").
  ///
  /// Formative feedback never carries a verdict in its text, but the author
  /// already has this switch for every other question type, and an open
  /// question that stays silent while the rest of the course reports status is
  /// just inconsistent. The expected answer is still never revealed.
  final bool showAnswerStatus;

  // Per-step action callbacks (for display blocks — each step independently actionable)
  final void Function(String stepId)? onStepBookmarkToggle;
  final void Function(String stepId)? onStepLikeToggle;
  final void Function(String stepId)? onStepDislikeToggle;

  /// When true, suppress all correct/incorrect feedback (course-level quizEvaluate=false).
  final bool hideEvaluation;

  // Block-level UI state (for exercise/question blocks)
  final bool isBookmarked;
  final bool isLiked;
  final bool isDisliked;

  // Per-step UI state (for display blocks — sets of stepIds)
  final Set<String> bookmarkedStepIds;
  final Set<String> likedStepIds;
  final Set<String> dislikedStepIds;

  const BlockStepEngine({
    super.key,
    required this.block,
    this.exportMode = ExportMode.courseV2,
    this.isCurrent = true,
    this.isCompleted = false,
    required this.onBlockCompleted,
    this.onCrossBlockNavigate,
    this.onChatRequested,
    this.onStepProgress,
    this.savedProgress,
    this.controller,
    this.hideEvaluation = false,
    this.onBookmarkToggle,
    this.onLikeToggle,
    this.onDislikeToggle,
    this.onHintRequested,
    this.onWrongAnswer,
    this.onOpenAnswerEvaluated,
    this.openAnswerScore = 'last',
    this.showAnswerStatus = false,
    this.onStepBookmarkToggle,
    this.onStepLikeToggle,
    this.onStepDislikeToggle,
    this.isBookmarked = false,
    this.isLiked = false,
    this.isDisliked = false,
    this.bookmarkedStepIds = const {},
    this.likedStepIds = const {},
    this.dislikedStepIds = const {},
  });

  @override
  ConsumerState<BlockStepEngine> createState() => _BlockStepEngineState();
}

class _BlockStepEngineState extends ConsumerState<BlockStepEngine> {
  /// Sentinel value: scoreKoef hasn't been set by any answer yet.
  static const _kUninitializedScore = -1.0;

  /// True while an open answer is out for AI evaluation — blocks re-submission
  /// and drives the spinner on the confirm button.
  bool _isEvaluatingWithAi = false;

  // ─── Photographed answers + retry (BR-P745Q8) ─────────────────────────────

  /// Photo the student picked, before upload. Kept across a failed evaluation
  /// so a retry does not make them take the picture again.
  PickedAnswerPhoto? _pickedPhoto;

  /// Handle issued by the upload endpoint for [_pickedPhoto].
  String? _uploadedPhotoName;

  bool _isUploadingPhoto = false;

  /// The evaluation said it could not read the photo. Distinct from a failed
  /// evaluation: feedback *was* produced, it just asks for a better picture.
  bool _photoUnreadable = false;

  /// The last failure was a missing connection, which changes the wording and
  /// removes a retry button that could not succeed.
  bool _evaluationOffline = false;

  /// False after a terminal rejection (422): the question has nothing to judge
  /// against, so retrying loops instead of recovering.
  bool _evaluationRetryable = true;

  /// Idempotency key per step, minted at answer time and dropped once the
  /// attempt is handed off. A retry therefore gets a fresh key and is stored as
  /// its own attempt rather than overwriting the one before it.
  final Map<String, String> _attemptIds = {};

  late _EngineState _state;
  late int _currentStepIndex;
  late Map<String, StepAnswerState> _stepAnswers;
  late double _bestScoreKoef;
  late int _earnedXp;
  String? _quizMark;
  /// True while a wrong answer with go_to=AGAIN is shown: the pick stays
  /// marked incorrect with its feedback, the correct option is NOT revealed,
  /// and the main button becomes "Zkusit znovu" (retry) instead of continue.
  bool _isAgainRetry = false;

  // Video controllers for inline playback
  final Map<String, VideoPlayerController> _videoControllers = {};

  // Audio controllers (reuses VideoPlayerController for MP3/WAV)
  final Map<String, VideoPlayerController> _audioControllers = {};

  // Key for the active step card — used to scroll it into view
  final GlobalKey _activeStepKey = GlobalKey();

  // Key for the feedback the current step gained by being graded — see
  // _scrollToFeedback.
  final GlobalKey _feedbackKey = GlobalKey();

  // Text controller for open question input
  TextEditingController? _textController;

  // Stable callback identities so the controller can detach safely even when
  // a newer engine State has already attached (keyed recreation).
  late final VoidCallback _boundConfirm = _confirmAnswer;
  late final VoidCallback _boundContinue = _continueAfterSolution;
  late final VoidCallback _boundRetry = _retryAgain;

  /// The block's steps in *display* order — questions with shuffling enabled
  /// get their options randomized here, once per block view.
  ///
  /// This has to live in State: StepContentRenderer is stateless and is built
  /// inside build(), so shuffling down there would reorder the options on every
  /// setState — i.e. under the user's finger while they answer.
  List<BlockStep> _viewSteps = const [];
  String? _viewStepsBlockId;

  List<BlockStep> get _steps => _viewSteps;
  BlockStep get _currentStep => _steps[_currentStepIndex];
  bool get _isLastStep => _currentStepIndex >= _steps.length - 1;

  List<BlockStep> get _questionSteps =>
      _steps.where((s) => s.isEvaluationStep).toList();

  /// Exercise/question blocks render every step inside one card, so a block
  /// holding more than one question shows them all at once. All of them must
  /// therefore accept input, and the confirm button must wait until each one
  /// is filled — before BR-E4H835 only the current question was wired up and
  /// text typed into the others was silently dropped.
  bool get _isMultiQuestionBlock =>
      (widget.block.type == BlockType.exercise ||
       widget.block.type == BlockType.question) &&
      _questionSteps.length > 1;

  /// A multi-question block whose questions are all graded locally evaluates in
  /// one shot: a single tap scores every question and the block scores as the
  /// share answered correctly.
  ///
  /// AI-graded questions are excluded — each one is an async round trip with
  /// its own spinner, failure and retry states, so those blocks keep evaluating
  /// one question at a time. They still get the shared input wiring and the
  /// all-filled gate above, so no answer is lost either way.
  /// Every open question is an AI round trip (BR-N26ACB), whatever its
  /// `ai_evaluation` switch says, so any block holding one is excluded.
  bool get _isBatchBlock =>
      _isMultiQuestionBlock &&
      !_questionSteps.any((s) => s.evaluationConfig?.type == 'open');

  /// Whether [step] has any user input recorded (not necessarily evaluated).
  bool _hasInputFor(BlockStep step) {
    // A photo on its own is a complete answer for open questions (BR-P745Q8),
    // so it is checked before the null guard: an answer given entirely as a
    // photo may have no StepAnswerState behind it at all (BR-HF7F2H).
    // _pickedPhoto/_uploadedPhotoName are per-engine rather than per-step, so
    // they only count for the step the student is actually on.
    if (step.stepId == _currentStep.stepId &&
        (_pickedPhoto != null || _uploadedPhotoName != null)) {
      return true;
    }

    final answer = _stepAnswers[step.stepId];
    if (answer == null) return false;
    if (answer.selectedOptionId != null) return true;
    if (answer.selectedOptionIds?.isNotEmpty ?? false) return true;
    if (answer.textAnswer?.trim().isNotEmpty ?? false) return true;
    return answer.photoName != null;
  }

  bool get _allQuestionsFilled => _questionSteps.every(_hasInputFor);

  /// Whether the confirm button may fire: every question of a multi-question
  /// block, just the current one otherwise.
  bool get _canConfirm =>
      _isMultiQuestionBlock ? _allQuestionsFilled : _hasInputFor(_currentStep);

  /// Cross-block/chat navigation captured while evaluating a batch block,
  /// applied once the user continues past the solutions.
  String? _batchGoTo;

  void _rebuildViewSteps() {
    // Keyed on blockId: _restoreOrInitState also re-runs for the SAME block when
    // saved progress lands asynchronously, and that must not reshuffle.
    if (_viewStepsBlockId == widget.block.blockId && _viewSteps.isNotEmpty) {
      return;
    }
    _viewStepsBlockId = widget.block.blockId;
    _viewSteps = widget.block.steps.map((step) {
      final config = step.evaluationConfig;
      if (config == null || !config.shuffleOptions) return step;
      return step.copyWith(
        evaluationConfig: config.copyWith(options: config.shuffledOptions()),
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _restoreOrInitState();
    widget.controller?._attach(_boundConfirm);
    widget.controller?._attachContinue(_boundContinue);
    widget.controller?._attachRetry(_boundRetry);
    _syncControllerPendingState();
  }

  void _restoreOrInitState() {
    _rebuildViewSteps();
    final saved = widget.savedProgress;
    if (saved != null && saved.blockId == widget.block.blockId) {
      _currentStepIndex = saved.currentStepIndex.clamp(0, _steps.length - 1);
      _stepAnswers = Map.from(saved.stepAnswers);
      _bestScoreKoef = saved.bestScoreKoef;
      _earnedXp = saved.earnedXp;
      _quizMark = saved.quizMark;
      _isAgainRetry = false;
      _state = (saved.isBlockCompleted || widget.isCompleted)
          ? _EngineState.blockComplete
          : _deriveState();
    } else {
      _currentStepIndex = 0;
      _stepAnswers = {};
      _bestScoreKoef = _kUninitializedScore;
      _earnedXp = 0;
      _quizMark = null;
      _isAgainRetry = false;
      _state = widget.isCompleted
          ? _EngineState.blockComplete
          : _deriveState();
    }

    // Exercise/question blocks show all steps at once — jump to the first
    // question step so display steps are passive context, not blocking progress.
    if ((widget.block.type == BlockType.exercise ||
         widget.block.type == BlockType.question) &&
        _state != _EngineState.blockComplete) {
      _skipToNextQuestion();
    }
  }

  /// Advance _currentStepIndex past any non-evaluation steps (exercise mode).
  /// A batch block also skips questions that are already evaluated, so it lands
  /// on the first one still awaiting an answer — restoring progress saved by
  /// the old one-question-at-a-time flow must not drop the rest.
  void _skipToNextQuestion() {
    final batch = _isBatchBlock;
    while (_currentStepIndex < _steps.length &&
        (!_steps[_currentStepIndex].isEvaluationStep ||
         (batch &&
          _stepAnswers[_steps[_currentStepIndex].stepId]?.isAnswered == true))) {
      _currentStepIndex++;
    }
    if (_currentStepIndex < _steps.length) {
      _state = _deriveState();
    } else if (batch && _questionSteps.isNotEmpty) {
      // Every question is answered — sit on the last one showing its solution.
      _currentStepIndex = _steps.indexOf(_questionSteps.last);
      _state = _deriveState();
    } else {
      _completeBlock();
    }
  }

  /// Derive the correct engine state from the current step
  _EngineState _deriveState() {
    if (_currentStepIndex >= _steps.length) return _EngineState.blockComplete;
    final step = _steps[_currentStepIndex];
    final answer = _stepAnswers[step.stepId];

    if (step.isEvaluationStep) {
      if (answer != null && answer.isAnswered) {
        // Already answered — show solution or advance
        if (widget.exportMode == ExportMode.quizV2 && widget.hideEvaluation) {
          return _EngineState.showingStep; // quiz with eval off: no solution
        }
        final config = step.evaluationConfig;
        // show_solution hides the authored solution, not the feedback written
        // about the student's own answer — the same rule _shouldSkipSolutionFor
        // applies on submission, so a restored block lands where it was left
        // rather than skipping the feedback a reload was supposed to bring back
        // (BR-TFX6BJ).
        if (config != null &&
            !config.showSolution &&
            !_hasFormativeFeedbackFor(config, answer)) {
          return _EngineState.showingStep; // show_solution=false: skip solution
        }
        return _EngineState.showingSolution;
      }
      return _EngineState.awaitingAnswer;
    }
    return _EngineState.showingStep;
  }

  @override
  void didUpdateWidget(covariant BlockStepEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.blockId != widget.block.blockId) {
      _disposeVideoControllers();
      _restoreOrInitState();
      // Re-attach controller for the new block
      widget.controller?._attach(_boundConfirm);
      widget.controller?._attachContinue(_boundContinue);
      widget.controller?._attachRetry(_boundRetry);
      _syncControllerPendingState();
    } else if (_state != _EngineState.blockComplete &&
        _state != _EngineState.showingSolution &&
        (widget.savedProgress != null && oldWidget.savedProgress == null ||
         widget.isCompleted && !oldWidget.isCompleted)) {
      // Saved progress or completion state arrived after initial build
      // (e.g. async _loadSavedProgress). Re-initialize to show saved answers.
      _restoreOrInitState();
      _syncControllerPendingState();
    } else {
    }
  }

  /// Sync controller's hasPendingAnswer based on restored engine state.
  /// Deferred to post-frame to avoid setState-during-build when the parent
  /// (e.g. QuizPage) listens to the controller and calls setState.
  void _syncControllerPendingState() {
    if (widget.controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Keep the shared controller's retry flag in step with this engine —
      // a freshly (re)built card is never an AGAIN retry, so this also clears
      // any stale flag leaking from the previous card's retry state.
      widget.controller!._setAgainRetry(_isAgainRetry);
      if (_state != _EngineState.awaitingAnswer) {
        widget.controller!._setPendingAnswer(false);
        return;
      }
      widget.controller!._setPendingAnswer(_canConfirm);
    });
  }

  @override
  void dispose() {
    // The controller outlives this State. An engine torn down mid-evaluation
    // would otherwise leave the flag set until the response lands, and the
    // engine recreated for the next question inherits it — a bottom bar stuck
    // spinning on a question nobody is evaluating (BR-4AT4CC).
    if (_isEvaluatingWithAi) widget.controller?._clearEvaluatingSilently();
    widget.controller?._detachIfCurrent(_boundConfirm);
    _disposeVideoControllers();
    _textController?.dispose();
    super.dispose();
  }

  void _disposeVideoControllers() {
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
        debugPrint('[BlockStepEngine] video init failed for $url: $e');
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
        debugPrint('[BlockStepEngine] audio init failed for $url: $e');
        if (mounted) setState(() {});
      });
      return controller;
    });
  }

  /// Scroll the active step card into view after the frame renders.
  void _scrollToActiveStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeStepKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });
  }

  /// Scroll the feedback an evaluation just produced into view.
  ///
  /// Feedback, verdict and explanation all render *below* the question, so on
  /// a step carrying a tall image the whole answer landed off-screen and the
  /// student had to go looking for it (BR-E6MWSB). Nothing happens when the
  /// step produced no feedback: there the grading changes nothing below the
  /// fold, and scrolling anyway would move the page for no reason.
  void _scrollToFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _feedbackKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  // ─── State Transitions ───────────────────────────────────

  /// Handle "Next" tap on a display step
  void _advanceDisplayStep() {
    if (_state == _EngineState.blockComplete) return;

    final step = _currentStep;
    // Resolve go_to on the step itself (for display steps with navigation)
    final goTo = step.goTo;

    if (goTo != null && goTo.isNotEmpty) {
      _resolveAndNavigate(goTo);
      return;
    }

    // Linear advance
    if (_isLastStep) {
      _completeBlock();
    } else {
      setState(() {
        _currentStepIndex++;
        _state = _deriveState();
      });
      _emitProgress();
      _scrollToActiveStep();
    }
  }

  /// Handle option selection for question steps
  void _onOptionSelected(String optionId) =>
      _onOptionSelectedFor(_currentStep, optionId);

  /// Handle multi-option selection
  void _onMultipleOptionsSelected(Set<String> optionIds) =>
      _onMultipleOptionsSelectedFor(_currentStep, optionIds);

  /// Record a single-select pick for [step]. A multi-question block answers
  /// several questions side by side, so the step is passed in rather than
  /// assumed to be the current one.
  void _onOptionSelectedFor(BlockStep step, String optionId) {
    if (_state == _EngineState.blockComplete) return;

    setState(() {
      _isAgainRetry = false;
      _stepAnswers[step.stepId] = StepAnswerState(
        selectedOptionId: optionId,
        isAnswered: false,
      );
      _state = _EngineState.awaitingAnswer;
    });
    widget.controller?._setPendingAnswer(_canConfirm);
  }

  /// Record a multi-select pick for [step].
  void _onMultipleOptionsSelectedFor(BlockStep step, Set<String> optionIds) {
    if (_state == _EngineState.blockComplete) return;

    setState(() {
      _isAgainRetry = false;
      _stepAnswers[step.stepId] = StepAnswerState(
        selectedOptionIds: optionIds,
        isAnswered: false,
      );
      _state = _EngineState.awaitingAnswer;
    });
    widget.controller?._setPendingAnswer(_canConfirm);
  }

  /// Handle text answer change
  /// Whether the student may edit an already-answered question and submit
  /// again (BR-P745Q8).
  ///
  /// The brief splits this by mode: practice invites repeated attempts, a quiz
  /// allows one. Only formative (AI-evaluated) questions are affected — an
  /// exact-match question keeps the behaviour it always had.
  bool _canReanswer(EvaluationConfig? config) =>
      (config?.aiEvaluation ?? false) && widget.exportMode != ExportMode.quizV2;

  /// [_canReanswer] narrowed by what the student has already achieved.
  ///
  /// A guided question they got right is finished (BR-EDB2MB): the short
  /// feedback and the solution appear and the block moves on, with no way back
  /// into the field. Leaving it open let a student who had already got there
  /// answer again — and under `open_answer_score: last` score *worse* for it.
  ///
  /// A guided question whose attempts are spent is finished for the mirror
  /// reason (BR-K8TDU4): that is the moment the explanation is handed over, and
  /// an attempt made after reading the worked solution measures nothing. Under
  /// `open_answer_score: last` it would also let a copied answer overwrite the
  /// score the student actually earned. Both endings are the same state — the
  /// guided loop is no longer holding anything back — so both close the field.
  ///
  /// Unguided formative questions keep the open-ended rework BR-P745Q8 added:
  /// they ration nothing, so there is no loop to have finished.
  bool _canReanswerNow(EvaluationConfig? config, StepAnswerState? answer) {
    if (!_canReanswer(config)) return false;
    if (!_isGuided(config)) return true;
    return _guidedHolds(config, answer);
  }

  /// Whether [config] runs the AI-guided loop here (BR-V9TQA7).
  ///
  /// Gated on [_canReanswer] rather than on `aiGuided` alone: guided solving
  /// *is* a retry loop, so in a mode that grants one attempt there is no loop
  /// to run and the question keeps the behaviour it has always had.
  ///
  /// Multi-question blocks are excluded for a different reason: they lock every
  /// answered question into read-only history while the siblings are still
  /// being filled in, so a per-question retry loop would hold the whole card
  /// hostage with no field to answer in. The renderer draws the same line by
  /// only treating a question as guided while its input is live.
  bool _isGuided(EvaluationConfig? config) =>
      (config?.aiGuided ?? false) &&
      _canReanswer(config) &&
      !_isMultiQuestionBlock;

  /// True while a guided question is still holding its explanation back — the
  /// answer was graded, it did not land, and attempts remain.
  bool _guidedHolds(EvaluationConfig? config, StepAnswerState? answer) {
    if (answer == null || !_isGuided(config)) return false;
    if (answer.isCorrect ?? false) return false;
    return answer.attemptCount <
        (config?.aiGuidedAttempts ?? kDefaultGuidedAttempts);
  }

  /// The current step is mid-loop: feedback is on screen, the field is open
  /// again, and the block does not move on until the student answers or spends
  /// their last attempt.
  bool get _isGuidedRetryOpen => _guidedHolds(
        _currentStep.evaluationConfig,
        _stepAnswers[_currentStep.stepId],
      );

  void _onTextAnswerChanged(String text) =>
      _onTextAnswerChangedFor(_currentStep, text);

  /// Record typed text for [step].
  void _onTextAnswerChangedFor(BlockStep step, String text) {
    if (_state == _EngineState.blockComplete) return;
    final existing = _stepAnswers[step.stepId] ?? const StepAnswerState();
    final config = step.evaluationConfig;

    // Editing an answered question starts a fresh attempt in practice mode:
    // the previous feedback described text that no longer exists, so it goes,
    // and the confirm button comes back.
    final reopening = (existing.isAnswered || existing.evaluationFailed) &&
        _canReanswerNow(config, existing);

    // A guided retry keeps the previous feedback on screen: it is the
    // instruction for this attempt, and wiping it the moment the student starts
    // typing takes away the only thing they have to work from (BR-V9TQA7).
    final keepFeedback = _isGuided(config);

    setState(() {
      // copyWith, not a new instance: a fresh StepAnswerState dropped the
      // attached photo and the feedback, so typing one character after
      // attaching a photo silently detached it.
      _stepAnswers[step.stepId] = existing.copyWith(
        textAnswer: text,
        isAnswered: reopening ? false : existing.isAnswered,
        evaluationFailed: reopening ? false : existing.evaluationFailed,
        clearFeedback: reopening && !keepFeedback,
      );

      if (reopening) {
        _isAgainRetry = false;
        _evaluationRetryable = true;
        // A new attempt needs its own idempotency key, or the retry would
        // overwrite the attempt it followed instead of appending.
        _attemptIds.remove(step.stepId);
      }

      if (text.isNotEmpty &&
          (reopening || _state != _EngineState.showingSolution)) {
        _state = _EngineState.awaitingAnswer;
      }
    });

    widget.controller?._setPendingAnswer(_canConfirm);
  }

  /// Confirm the answer for the current question step.
  ///
  /// Open questions take an async detour: the answer is sent to the API, the
  /// engine shows a spinner, and evaluation resumes in [_applyAnswer] once a
  /// verdict (or a fallback) is available. Every other question type stays
  /// fully synchronous.
  void _confirmAnswer() {
    if (_state != _EngineState.awaitingAnswer) return;
    if (_isEvaluatingWithAi) return;
    if (_isBatchBlock) {
      _confirmAllAnswers();
      return;
    }

    final step = _currentStep;
    final config = step.evaluationConfig;
    if (config == null) return;

    if (!_hasInputFor(step)) return;

    // A photo-only answer never passes through _onTextAnswerChangedFor, so no
    // StepAnswerState exists yet. Bailing on null here made the confirm button
    // a silent no-op for exactly the case allow_photo was built for
    // (BR-HF7F2H) — an empty state is the right starting point instead.
    final current = _stepAnswers[step.stepId] ?? const StepAnswerState();

    // Every open answer is graded by AI (BR-N26ACB). `ai_evaluation` only
    // decides whether the student is shown the AI's feedback or a plain
    // right/wrong with the solution — see StepContentRenderer.
    if (config.type == 'open') {
      unawaited(_confirmOpenAnswerWithAi(step, config, current));
      return;
    }

    _applyAnswer(step, config, current);
  }

  /// Evaluate an open answer with AI, then hand off to the shared tail.
  ///
  /// A failure falls back to comparing the answer with the expected one
  /// (BR-N26ACB). BR-P745Q8 had replaced that fallback with a retry, because
  /// against a paragraph-long expected answer the comparison always fails; the
  /// brief now asks for it back, so an offline student still gets a verdict
  /// and can move on. Only an answer with no text to compare — a photo on its
  /// own — still gets the retry and a logged failed attempt.
  Future<void> _confirmOpenAnswerWithAi(
    BlockStep step,
    EvaluationConfig config,
    StepAnswerState current,
  ) async {
    // The previous attempt's feedback goes the moment a new one is submitted
    // (BR-K8TDU4). Guided solving keeps it on screen while the student types —
    // it is the instruction they are working from (BR-V9TQA7) — but once the
    // answer it described has been replaced and sent, it is advice about text
    // that no longer exists. Leaving it up through a 25-second grading call
    // reads as "already answered", and a failed second attempt would keep the
    // first one's card standing as if it were the new verdict.
    if (current.feedback != null || (current.aiFeedback?.isNotEmpty ?? false)) {
      current = current.copyWith(clearFeedback: true, clearAiFeedback: true);
      final cleared = current;
      setState(() => _stepAnswers[step.stepId] = cleared);
    }

    setState(() => _isEvaluatingWithAi = true);
    widget.controller?._setEvaluating(true);

    final evaluator = ref.read(aiAnswerEvaluatorProvider);

    // Upload the photo first, if the student attached one and it has not been
    // sent yet. A failed upload is not fatal — the answer may also have text,
    // and the picked file is kept so a retry does not need a new photo.
    String? photoName = current.photoName;
    if (config.allowPhoto && _pickedPhoto != null && photoName == null) {
      setState(() => _isUploadingPhoto = true);
      final uploaded = await evaluator.uploadPhoto(
        bytes: _pickedPhoto!.bytes,
        filename: _pickedPhoto!.filename,
      );
      if (!mounted) {
        widget.controller?._setEvaluating(false);
        return;
      }
      setState(() {
        _isUploadingPhoto = false;
        _uploadedPhotoName = uploaded?.name;
      });
      photoName = uploaded?.name;
    }

    final outcome = await evaluator.evaluate(
      question: _questionStatementFor(step, config),
      studentAnswer: current.textAnswer ?? '',
      photoName: photoName,
      help: step.help ?? widget.block.atomicHelp,
      solution: config.solution,
      correctAnswer: config.correctAnswer,
      criteria: config.aiCriteria,
      criteriaList: config.aiCriteriaList,
    );

    if (!mounted) {
      // The controller outlives this State, so its flag must be cleared even
      // when the engine is gone — otherwise the parent's bar stays disabled.
      widget.controller?._setEvaluating(false);
      return;
    }

    setState(() => _isEvaluatingWithAi = false);
    widget.controller?._setEvaluating(false);

    // The student may have navigated away or retried while the call was in
    // flight; only apply the outcome if we are still on the same question.
    if (_state != _EngineState.awaitingAnswer ||
        _currentStep.stepId != step.stepId) {
      return;
    }

    if (outcome.isSuccess) {
      setState(() => _photoUnreadable = outcome.result!.photoUnreadable);
      _applyAnswer(step, config, current, aiResult: outcome.result, photoName: photoName);
      return;
    }

    // Offline, or the AI gave nothing back: the answer is graded by comparison
    // with the expected answer instead (BR-N26ACB) — for every open question,
    // `ai_evaluation` on or off. There is no feedback to show, so the student
    // gets right/wrong and the solution; the expected answer itself never
    // appears. A photo-only answer has nothing to compare, so it keeps the
    // retry below.
    if (current.textAnswer?.trim().isNotEmpty ?? false) {
      _applyAnswer(step, config, current, photoName: photoName);
      return;
    }

    _handleEvaluationFailure(step, config, current, outcome.failure!, photoName);
  }

  /// Evaluation ran and produced nothing usable.
  ///
  /// The step deliberately stays in [_EngineState.awaitingAnswer]: no verdict is
  /// recorded, nothing feeds ELO or FSRS, and the confirm button remains live so
  /// the student can try again. The attempt is still handed to the host page so
  /// the failure is logged rather than lost — and because a later retry mints a
  /// new attempt id, it appends instead of overwriting this one.
  void _handleEvaluationFailure(
    BlockStep step,
    EvaluationConfig config,
    StepAnswerState current,
    AiEvaluationFailure failure,
    String? photoName,
  ) {
    setState(() {
      _evaluationOffline = failure == AiEvaluationFailure.offline;
      _evaluationRetryable = failure != AiEvaluationFailure.notEvaluable;
      _stepAnswers[step.stepId] = current.copyWith(
        evaluationFailed: true,
        clearFeedback: true,
        photoName: photoName,
      );
    });

    // Nothing to record for an answer that was never written.
    final text = current.textAnswer?.trim() ?? '';
    if (text.isEmpty && photoName == null) return;

    widget.onOpenAnswerEvaluated?.call(OpenAnswerEvent(
      blockId: widget.block.blockId,
      stepId: step.stepId,
      attemptId: _attemptIdFor(step.stepId),
      answerText: text,
      isCorrect: false,
      failed: true,
      photoName: photoName,
      gradingBasis: _gradingBasisFor(step, config),
    ));

    // The next submission is a new attempt, so it needs a new id.
    _attemptIds.remove(step.stepId);
  }

  /// Student attached a photo of their solution.
  ///
  /// Only stored locally here — the upload happens on confirm, together with
  /// the evaluation, so picking a photo and then changing your mind costs
  /// nothing and leaves no orphan in the bucket.
  void _onPhotoPicked(PickedAnswerPhoto photo) {
    final step = _currentStep;
    setState(() {
      _pickedPhoto = photo;
      _uploadedPhotoName = null;
      _photoUnreadable = false;
      // Seed the answer state the photo belongs to. Without it a student who
      // only photographs their work leaves _stepAnswers empty, and
      // _confirmAnswer reads that as "nothing to submit" (BR-HF7F2H).
      _stepAnswers[step.stepId] =
          _stepAnswers[step.stepId] ?? const StepAnswerState();
    });
    // Not an unconditional true: in a multi-question block the other questions
    // still have to be filled before the block can be checked (BR-E4H835).
    widget.controller?._setPendingAnswer(_canConfirm);
  }

  void _onPhotoRemoved() {
    final step = _currentStep;
    setState(() {
      _pickedPhoto = null;
      _uploadedPhotoName = null;
      _photoUnreadable = false;
      final current = _stepAnswers[step.stepId];
      if (current != null) {
        _stepAnswers[step.stepId] = current.copyWith(clearPhoto: true);
      }
    });
    // Removing the photo can empty the answer entirely, so the parent's
    // confirm button has to re-evaluate whether there is anything to submit.
    widget.controller?._setPendingAnswer(_canConfirm);
  }

  /// Re-run a failed evaluation with the answer the student already wrote.
  void _retryEvaluation() {
    final step = _currentStep;
    final config = step.evaluationConfig;
    final current = _stepAnswers[step.stepId];
    if (config == null || current == null) return;
    if (_isEvaluatingWithAi) return;

    setState(() {
      _evaluationOffline = false;
      _evaluationRetryable = true;
      _stepAnswers[step.stepId] = current.copyWith(evaluationFailed: false);
    });

    unawaited(_confirmOpenAnswerWithAi(step, config, _stepAnswers[step.stepId]!));
  }

  /// Reopen an answered formative question so the student can rework it.
  ///
  /// Unlocking the text field was not enough: once the block finishes, every
  /// step re-renders as read-only history (see _buildHistoryStepCard), so the
  /// field the student could edit is no longer on screen. Practice is supposed
  /// to invite another attempt, so the block has to be able to come back.
  ///
  /// The previous attempt is already recorded and stays recorded — this starts
  /// a new one rather than editing it.
  void _reopenForNewAttempt(int stepIndex) {
    final step = _steps[stepIndex];
    final current = _stepAnswers[step.stepId];

    setState(() {
      _currentStepIndex = stepIndex;
      _state = _EngineState.awaitingAnswer;
      _isAgainRetry = false;
      _evaluationOffline = false;
      _evaluationRetryable = true;
      _photoUnreadable = false;
      if (current != null) {
        _stepAnswers[step.stepId] = current.copyWith(
          isAnswered: false,
          evaluationFailed: false,
          clearFeedback: true,
        );
      }
      // A fresh key, so the new attempt appends instead of overwriting.
      _attemptIds.remove(step.stepId);
    });

    widget.controller?._setPendingAnswer(_canConfirm);
  }

  /// Index of the formative question the student may rework, or null.
  int? get _reworkableStepIndex {
    if (widget.exportMode == ExportMode.quizV2) return null;
    for (var i = _steps.length - 1; i >= 0; i--) {
      final config = _steps[i].evaluationConfig;
      final answer = _stepAnswers[_steps[i].stepId];
      if (_canReanswerNow(config, answer) && (answer?.isAnswered ?? false)) {
        return i;
      }
    }
    return null;
  }

  /// Stable idempotency key per in-flight attempt at a step.
  String _attemptIdFor(String stepId) =>
      _attemptIds.putIfAbsent(stepId, OpenAnswerRepository.newAttemptId);

  /// The task statement to send for evaluation.
  ///
  /// `config.question` is filled from the question step's own text. Authors
  /// routinely put the statement in a preceding text step instead and leave the
  /// question step blank, which used to send an empty question — rejected by
  /// the API, read by the client as "retry", and retried forever. Walking back
  /// to the nearest text-bearing step finds the statement where it actually is.
  String _questionStatementFor(BlockStep step, EvaluationConfig config) {
    final own = config.question?.trim();
    if (own != null && own.isNotEmpty) return own;

    final blockContent = widget.block.content?.trim();
    if (blockContent != null && blockContent.isNotEmpty) return blockContent;

    final index = _steps.indexWhere((s) => s.stepId == step.stepId);
    for (var i = index - 1; i >= 0; i--) {
      final text = _steps[i].content?.text?.trim();
      if (text != null && text.isNotEmpty) return text;
    }

    // Genuinely nothing. The API decides whether the expected answer alone is
    // enough to judge against, and says so with a terminal 422 if it is not.
    return '';
  }

  /// What this attempt is being judged against, captured now.
  Map<String, dynamic> _gradingBasisFor(BlockStep step, EvaluationConfig config) {
    return OpenAnswerRepository.gradingBasisFor(
      question: _questionStatementFor(step, config),
      expectedAnswer: config.correctAnswer,
      solution: config.solution,
      criteria: config.aiCriteriaList,
    );
  }

  /// Hand an evaluated open answer to the host page for persistence
  /// (BR-FFVVYR). No-op for every other question type.
  void _reportOpenAnswer(
    BlockStep step,
    EvaluationConfig config,
    StepAnswerState current,
    bool isCorrect, {
    AiEvaluationResult? aiResult,
    String? photoName,
  }) {
    final openText = current.textAnswer?.trim() ?? '';
    if (config.type != 'open' || (openText.isEmpty && photoName == null)) return;

    widget.onOpenAnswerEvaluated?.call(OpenAnswerEvent(
      blockId: widget.block.blockId,
      stepId: step.stepId,
      attemptId: _attemptIdFor(step.stepId),
      answerText: openText,
      isCorrect: isCorrect,
      evaluatedByAi: aiResult != null,
      aiScore: aiResult?.score,
      aiFeedback: aiResult?.feedbackText,
      aiModel: aiResult?.model,
      feedbackParts: aiResult?.feedback?.toJson(),
      criteriaScores: aiResult?.criteriaScores ?? const [],
      gradingBasis: _gradingBasisFor(step, config),
      photoName: photoName,
      promptVersion: aiResult?.promptVersion,
    ));
    // This attempt is recorded; anything after it is a new one.
    _attemptIds.remove(step.stepId);
  }

  /// Whether the solution/feedback screen for a question carries nothing worth
  /// pausing on, so the engine can advance straight past it.
  bool _shouldSkipSolutionFor(
    EvaluationConfig config,
    StepAnswerState answer, {
    AiEvaluationResult? aiResult,
  }) {
    // A quiz with evaluation switched off shows nothing at all, feedback
    // included — that decision outranks everything below.
    if (widget.exportMode == ExportMode.quizV2 && widget.hideEvaluation) {
      return true;
    }

    // Formative feedback is written about what this student wrote, so
    // show_answers and show_solution have no say over it: neither reveals
    // anything, and the renderer already keeps the authored solution out of
    // the card when show_solution is off. Letting those flags veto the pause
    // meant an author who hid the solution silently switched the feedback off
    // too — the answer was graded, the feedback arrived, and the block
    // advanced past it before the student could read a word (BR-TFX6BJ).
    if (_hasFormativeFeedbackFor(config, answer, aiResult: aiResult)) {
      return false;
    }

    // In quiz mode with evaluation on, always pause on the answered state so
    // the user sees feedback (solution banner, card highlighting, etc.). The
    // renderer already respects show_answers — when it's false the correct
    // option just isn't revealed, but the solution banner still shows. So we
    // do NOT gate the pause on show_answers in quiz/eval mode.
    if (widget.exportMode == ExportMode.quizV2) return false;

    // Determine if there's any feedback/solution content worth showing
    final hasSolutionText = config.solution != null && config.solution!.isNotEmpty;
    final hasSolutionImage = config.solutionImage != null;
    final selectedOption = config.options.where((o) => o.id == answer.selectedOptionId).firstOrNull;
    final hasOptionFeedback = selectedOption?.feedback != null && selectedOption!.feedback!.isNotEmpty;
    final hasFeedbackContent =
        hasSolutionText || hasSolutionImage || hasOptionFeedback;

    return !(config.showAnswers) ||
        !(config.showSolution) ||
        !hasFeedbackContent;
  }

  /// Whether this answer carries AI feedback the student is owed.
  ///
  /// Read from [aiResult] on the submission that produced it, and from the
  /// persisted answer afterwards — restoring a block must reach the same
  /// verdict as the tap that filled it in.
  ///
  /// Only `ai_evaluation` questions show the feedback (BR-N26ACB). The rest are
  /// graded by AI too, but their student sees right/wrong and the solution, so
  /// feedback they are never shown must not hold the block on screen.
  bool _hasFormativeFeedbackFor(
    EvaluationConfig config,
    StepAnswerState answer, {
    AiEvaluationResult? aiResult,
  }) {
    if (config.type != 'open' || !config.aiEvaluation) return false;
    if (aiResult != null) {
      return aiResult.feedback != null || aiResult.feedbackText.isNotEmpty;
    }
    return answer.feedback != null || (answer.aiFeedback?.isNotEmpty ?? false);
  }

  /// Score one question against its config, without touching engine state.
  ///
  /// Split out of [_applyAnswer] so a batch block can evaluate every question
  /// in one pass (BR-E4H835) without a second copy of the correctness rules.
  ({StepAnswerState answer, String? goTo}) _evaluateStep(
    BlockStep step,
    EvaluationConfig config,
    StepAnswerState current, {
    AiEvaluationResult? aiResult,
    String? photoName,
  }) {
    // Evaluate correctness
    bool isCorrect = false;
    double scoreKoef = 1.0;
    String? markValue;
    String? goToValue;

    if (config.allowMultiple) {
      // Multi-select: all correct options must be selected
      final selected = current.selectedOptionIds ?? {};
      final correctIds = config.options.where((o) => o.isCorrect).map((o) => o.id).toSet();
      isCorrect = selected.length == correctIds.length && selected.containsAll(correctIds);
    } else if (config.type == 'numeric') {
      // Numeric question: tolerance-based comparison
      final userAnswer = double.tryParse(
        (current.textAnswer ?? '').trim().replaceAll(',', '.'));
      if (userAnswer != null && config.correctNumber != null) {
        isCorrect = (userAnswer - config.correctNumber!).abs() <= config.tolerance;
      }
    } else if (config.type == 'open') {
      if (aiResult != null) {
        // AI verdict wins: partial credit flows into scoreKoef, so ELO and
        // FSRS see a graded answer rather than a binary one.
        isCorrect = aiResult.isCorrect;
        scoreKoef = aiResult.score;
      } else {
        // Open question: compare text answer against every variant the
        // author listed, one per line (BR-RBUR29)
        final userAnswer = (current.textAnswer ?? '').trim().toLowerCase();
        isCorrect = matchesExpectedAnswer(userAnswer, config.correctAnswer);
        // Also check against options if present
        if (!isCorrect && config.options.isNotEmpty) {
          isCorrect = config.options.any((o) =>
              o.isCorrect && o.text.trim().toLowerCase() == userAnswer);
        }
        scoreKoef = isCorrect ? 1.0 : 0.0;
      }
    } else {
      // Single select / true_false
      final selectedId = current.selectedOptionId;
      if (selectedId != null) {
        final option = config.options.where((o) => o.id == selectedId).firstOrNull;
        if (option != null) {
          isCorrect = option.isCorrect;
          scoreKoef = option.scoreKoef;
          markValue = option.mark;
          goToValue = option.goTo;
        }
      }
    }

    // Also check next_actions for go_to
    if (goToValue == null && step.nextActions != null) {
      goToValue = GoToResolver.resolveNextActionGoTo(
        nextActions: step.nextActions,
        isCorrect: isCorrect,
      );
    }

    // Derive effective scoreKoef from isCorrect when options don't carry
    // a meaningful score_koef (default 1.0 for all options).
    // AI grading is the exception: its score already *is* partial credit, so
    // zeroing a below-threshold answer would throw that information away.
    final effectiveScoreKoef =
        aiResult != null ? scoreKoef : (isCorrect ? scoreKoef : 0.0);

    // Update answer state
    final updatedAnswer = current.copyWith(
      isAnswered: true,
      isCorrect: isCorrect,
      scoreKoef: effectiveScoreKoef,
      markValue: markValue,
      evaluatedByAi: aiResult != null,
      aiFeedback: aiResult?.feedbackText,
      aiModel: aiResult?.model,
      feedback: aiResult?.feedback,
      // What this grading produced, not what the last one left behind
      // (BR-K8TDU4). `copyWith` keeps the old value when the new one is null,
      // so a re-graded answer whose response carries no parts would otherwise
      // show the previous attempt's card as the verdict on this one. Only for
      // AI-graded questions: elsewhere there is no per-attempt feedback to
      // stale out.
      clearFeedback: config.aiEvaluation && aiResult?.feedback == null,
      clearAiFeedback:
          config.aiEvaluation && (aiResult?.feedbackText ?? '').isEmpty,
      photoName: photoName,
      evaluationFailed: false,
      // One graded submission = one attempt spent. Read by AI-guided solving
      // to decide whether the explanation is still being held back
      // (BR-V9TQA7); a failed evaluation never reaches here, so a timeout does
      // not cost the student an attempt.
      attemptCount: current.attemptCount + 1,
    );

    return (answer: updatedAnswer, goTo: goToValue);
  }

  /// Shared evaluation + navigation tail for every question type.
  void _applyAnswer(
    BlockStep step,
    EvaluationConfig config,
    StepAnswerState current, {
    AiEvaluationResult? aiResult,
    String? photoName,
  }) {
    final evaluation = _evaluateStep(
      step,
      config,
      current,
      aiResult: aiResult,
      photoName: photoName,
    );
    final updatedAnswer = evaluation.answer;
    final goToValue = evaluation.goTo;
    final isCorrect = updatedAnswer.isCorrect ?? false;
    final effectiveScoreKoef = updatedAnswer.scoreKoef ?? 0.0;
    final markValue = updatedAnswer.markValue;

    // Track the score that counts (start from 0 on first answer).
    //
    // Repeated attempts have always taken the best. BR-P745Q8 makes that a
    // course setting for open questions, because a course built around
    // answering, reading feedback and answering again wants the latest attempt
    // to be the one that stands — otherwise a lucky first try masks the fact
    // that the student never got there on their own.
    final takeLast = config.type == 'open' && widget.openAnswerScore == 'last';
    if (takeLast ||
        _bestScoreKoef == _kUninitializedScore ||
        effectiveScoreKoef > _bestScoreKoef) {
      _bestScoreKoef = effectiveScoreKoef;
    }
    _quizMark = markValue ?? _quizMark;

    widget.controller?._setPendingAnswer(false);

    // Auto-bookmark on wrong answer (for Practice/Cvičení collection)
    if (!isCorrect) {
      widget.onWrongAnswer?.call();
    }

    _reportOpenAnswer(step, config, current, isCorrect,
        aiResult: aiResult, photoName: photoName);

    // Pre-resolve to detect "again" loops
    final preResolved = GoToResolver.resolve(
      goToValue: goToValue,
      blockType: widget.block.type,
      steps: _steps,
      currentStepIndex: _currentStepIndex,
    );


    final shouldSkipSolution =
        _shouldSkipSolutionFor(config, updatedAnswer, aiResult: aiResult);

    if (preResolved.type == NavActionType.again) {
      // Wrong answer with go_to=AGAIN: keep the selection on screen marked
      // incorrect (with its feedback), but do NOT reveal the correct option or
      // the solution. The user taps "Zkusit znovu" to clear and re-answer.
      setState(() {
        _isAgainRetry = true;
        _stepAnswers[step.stepId] = updatedAnswer;
        _state = _EngineState.showingSolution;
        widget.controller?._setShowingSolution(true);
        widget.controller?._setAgainRetry(true);
      });
      _scrollToFeedback();
    } else if (shouldSkipSolution) {
      // Skip solution screen — record answer without rendering green state.
      // _resolveAndNavigate has its own setState that will advance immediately.
      _isAgainRetry = false;
      _stepAnswers[step.stepId] = updatedAnswer;
      _resolveAndNavigate(goToValue);
    } else {
      // Show solution with feedback
      setState(() {
        _isAgainRetry = false;
        _stepAnswers[step.stepId] = updatedAnswer;
        _state = _EngineState.showingSolution;
        widget.controller?._setShowingSolution(true);
        widget.controller?._setAgainRetry(false);
      });
      _scrollToFeedback();
    }

    _emitProgress();
  }

  /// Evaluate every question of a batch block in one go (BR-E4H835).
  ///
  /// The block scores as the share of questions answered correctly, rather than
  /// the best single answer — with several questions on screen, "one right out
  /// of three" is not a full mark. Per-question go_to branching is ignored (a
  /// card that already shows every step has nowhere to branch to), but a
  /// cross-block jump or chat handoff carries over to the continue tap.
  void _confirmAllAnswers() {
    final questions = _questionSteps;
    if (questions.isEmpty) return;

    final evaluated = <String, StepAnswerState>{};
    var correctCount = 0;
    var anyWrong = false;
    var anySolutionToShow = false;
    String? crossBlockGoTo;

    for (final step in questions) {
      final config = step.evaluationConfig;
      final current = _stepAnswers[step.stepId];
      if (config == null || current == null) {
        // Nothing recorded — count it as wrong so the score stays honest.
        anyWrong = true;
        continue;
      }

      final evaluation = _evaluateStep(step, config, current);
      final answer = evaluation.answer;
      evaluated[step.stepId] = answer;

      final isCorrect = answer.isCorrect ?? false;
      if (isCorrect) {
        correctCount++;
      } else {
        anyWrong = true;
      }
      _quizMark = answer.markValue ?? _quizMark;

      _reportOpenAnswer(step, config, current, isCorrect);

      if (!_shouldSkipSolutionFor(config, answer)) {
        anySolutionToShow = true;
      }

      if (crossBlockGoTo == null && evaluation.goTo != null) {
        final action = GoToResolver.resolve(
          goToValue: evaluation.goTo,
          blockType: widget.block.type,
          steps: _steps,
          currentStepIndex: _currentStepIndex,
        );
        if (action.type == NavActionType.crossBlockJump ||
            action.type == NavActionType.chat) {
          crossBlockGoTo = evaluation.goTo;
        }
      }
    }

    _bestScoreKoef = correctCount / questions.length;
    _batchGoTo = crossBlockGoTo;

    widget.controller?._setPendingAnswer(false);

    // Auto-bookmark when anything went wrong (for Practice/Cvičení collection)
    if (anyWrong) {
      widget.onWrongAnswer?.call();
    }

    setState(() {
      _isAgainRetry = false;
      _stepAnswers.addAll(evaluated);
      _currentStepIndex = _steps.indexOf(questions.last);
      widget.controller?._setAgainRetry(false);
      if (anySolutionToShow) {
        _state = _EngineState.showingSolution;
        widget.controller?._setShowingSolution(true);
      }
    });

    if (anySolutionToShow) {
      _emitProgress();
      _scrollToFeedback();
    } else {
      // Nothing to pause on — finish the block right away.
      _finishBatchBlock();
    }
  }

  /// Complete a batch block, honouring a cross-block/chat handoff if one of the
  /// answers carried it.
  void _finishBatchBlock() {
    final goTo = _batchGoTo;
    _batchGoTo = null;

    final action = GoToResolver.resolve(
      goToValue: goTo,
      blockType: widget.block.type,
      steps: _steps,
      currentStepIndex: _currentStepIndex,
    );

    _completeBlock();

    if (action.type == NavActionType.crossBlockJump &&
        action.targetBlockId != null) {
      widget.onCrossBlockNavigate?.call(action.targetBlockId!);
    } else if (action.type == NavActionType.chat) {
      widget.onChatRequested?.call();
    }
  }

  /// Handle "Pokračovat" after showing solution
  void _continueAfterSolution() {
    widget.controller?._setShowingSolution(false);
    widget.controller?._setAgainRetry(false);

    if (_isBatchBlock) {
      final pending = _questionSteps
          .where((s) => _stepAnswers[s.stepId]?.isAnswered != true)
          .toList();
      if (pending.isNotEmpty) {
        // Progress saved by the old one-question-at-a-time flow can leave some
        // questions unevaluated. Go answer them instead of completing the block.
        setState(() {
          _currentStepIndex = _steps.indexOf(pending.first);
          _state = _EngineState.awaitingAnswer;
        });
        widget.controller?._setPendingAnswer(_canConfirm);
        return;
      }
      _finishBatchBlock();
      return;
    }

    final step = _currentStep;
    final answer = _stepAnswers[step.stepId];

    // Determine go_to value
    String? goToValue;
    final config = step.evaluationConfig;
    if (config != null && answer != null) {
      final selectedId = answer.selectedOptionId;
      if (selectedId != null) {
        final option = config.options.where((o) => o.id == selectedId).firstOrNull;
        goToValue = option?.goTo;
      }
    }
    if (goToValue == null && step.nextActions != null && answer != null) {
      goToValue = GoToResolver.resolveNextActionGoTo(
        nextActions: step.nextActions,
        isCorrect: answer.isCorrect ?? false,
      );
    }

    _resolveAndNavigate(goToValue);
  }

  /// Clear an AGAIN wrong answer so the user can pick again. Bound to the
  /// "Zkusit znovu" button shown while [_isAgainRetry] is true.
  void _retryAgain() {
    setState(() {
      _isAgainRetry = false;
      _stepAnswers.remove(_currentStep.stepId);
      _state = _EngineState.awaitingAnswer;
      widget.controller?._setShowingSolution(false);
      widget.controller?._setAgainRetry(false);
      widget.controller?._setPendingAnswer(false);
    });
    _emitProgress();
    _scrollToActiveStep();
  }

  void _resolveAndNavigate(String? goToValue) {
    final action = GoToResolver.resolve(
      goToValue: goToValue,
      blockType: widget.block.type,
      steps: _steps,
      currentStepIndex: _currentStepIndex,
    );

    setState(() {
      _isAgainRetry = false;
      switch (action.type) {
        case NavActionType.nextStep:
          if (_isLastStep) {
            _completeBlock();
          } else {
            _currentStepIndex++;
            _state = _deriveState();
          }
        case NavActionType.again:
          // Reset current step answer and re-show
          _stepAnswers.remove(_currentStep.stepId);
          _state = _deriveState();
        case NavActionType.end:
          _completeBlock();
        case NavActionType.jumpToStep:
          final idx = _steps.indexWhere((s) => s.stepId == action.targetStepId);
          if (idx >= 0) {
            _currentStepIndex = idx;
            _state = _deriveState();
          } else {
            // Step not found — advance linearly
            if (_isLastStep) {
              _completeBlock();
            } else {
              _currentStepIndex++;
              _state = _deriveState();
            }
          }
        case NavActionType.crossBlockJump:
          _completeBlock();
          // Signal parent to navigate to another block
          widget.onCrossBlockNavigate?.call(action.targetBlockId!);
        case NavActionType.chat:
          _completeBlock();
          // Signal parent to open AI chat with block context
          widget.onChatRequested?.call();
      }

      // Exercise/question blocks: skip past display steps to the next question
      if ((widget.block.type == BlockType.exercise ||
           widget.block.type == BlockType.question) &&
          _state != _EngineState.blockComplete) {
        _skipToNextQuestion();
      }
    });

    _emitProgress();
    _scrollToActiveStep();
  }

  void _completeBlock() {
    final finalScore = _bestScoreKoef == _kUninitializedScore ? 0.0 : _bestScoreKoef;

    // Calculate granular XP from step types:
    // +1 per display step (bubble), +8 per correct-no-hints exercise, +5 otherwise
    int rawXp = 0;
    for (final step in _steps) {
      if (step.isEvaluationStep) {
        final answer = _stepAnswers[step.stepId];
        final isCorrectNoHints = answer != null && (answer.scoreKoef ?? 0) >= 1.0;
        rawXp += isCorrectNoHints ? 8 : 5;
      } else {
        rawXp += 1; // display/text/image/video bubble
      }
    }
    _earnedXp = rawXp;

    // Use setState to schedule a frame — without it, addPostFrameCallback
    // below has no frame to attach to and the deferred onBlockCompleted
    // never fires until an unrelated interaction (scroll, other tap) triggers one.
    // Nested setState (when called from _resolveAndNavigate's setState) is safe.
    setState(() {
      _state = _EngineState.blockComplete;
    });

    // Emit progress immediately so the parent has isBlockCompleted=true
    // in its in-memory step_progress. This is critical because the
    // deferred onBlockCompleted below may be missed if the user navigates
    // away before the post-frame callback fires.
    _emitProgress();

    // Defer callback to avoid setState-during-build when called from
    // didUpdateWidget → _restoreOrInitState → _skipToNextQuestion chain.
    // Guard with blockId so a stale callback doesn't fire after the engine
    // has already switched to a different block (e.g. user clicked back).
    final blockId = widget.block.blockId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.block.blockId != blockId) return;
      widget.onBlockCompleted(
        earnedXp: _earnedXp,
        scoreKoef: finalScore,
        mark: _quizMark,
      );
    });
  }

  void _emitProgress() {
    widget.onStepProgress?.call(StepProgressData(
      blockId: widget.block.blockId,
      currentStepIndex: _currentStepIndex,
      stepAnswers: Map.from(_stepAnswers),
      isBlockCompleted: _state == _EngineState.blockComplete,
      bestScoreKoef: _bestScoreKoef == _kUninitializedScore ? 0.0 : _bestScoreKoef,
      earnedXp: _earnedXp,
      quizMark: _quizMark,
    ));
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return _buildEmptyBlock();
    }

    // Exercise and question blocks: keep all steps inside one card.
    // Question blocks with steps (e.g. text prompt + MC question) belong
    // together visually — same as exercises.
    if (widget.block.type == BlockType.exercise ||
        widget.block.type == BlockType.question) {
      return _buildExerciseCard();
    }

    // All other blocks: render each visited step as its own card.
    // Completed steps show as dimmed history; the current step is active.
    final isBlockDone = _state == _EngineState.blockComplete || widget.isCompleted;
    final visibleCount = isBlockDone ? _steps.length : _currentStepIndex + 1;

    final reworkable = isBlockDone ? _reworkableStepIndex : null;

    return Column(
      children: [
        for (int i = 0; i < visibleCount; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          i < _currentStepIndex || isBlockDone
              ? _buildHistoryStepCard(i)
              : _buildActiveStepCard(),
        ],
        // Practice invites another attempt, but a finished block is read-only
        // history — without this the student reads the feedback and has no way
        // to act on it (BR-P745Q8).
        if (reworkable != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _reopenForNewAttempt(reworkable),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(AppStrings.openFeedbackRework),
            ),
          ),
        ],
      ],
    );
  }

  /// Whether step[i] is a display/text prompt that immediately precedes a question.
  /// In the exercise bubble these are merged: the prompt text renders inline
  /// as the question header, so we skip the prompt as its own row.
  bool _isPromptForNextQuestion(int i) {
    if (i < 0 || i + 1 >= _steps.length) return false;
    final step = _steps[i];
    final next = _steps[i + 1];
    // Only pure text/display steps count as prompts, not image/video/audio.
    final isTextPrompt = step.type == StepType.text ||
        step.type == StepType.display ||
        step.type == StepType.displayTask;
    return isTextPrompt && next.isEvaluationStep;
  }

  /// Exercise card: ALL steps rendered inside a single bubble.
  /// Display steps are passive context; only question steps are interactive.
  Widget _buildExerciseCard() {
    final isBlockDone = _state == _EngineState.blockComplete || widget.isCompleted;

    final children = <Widget>[];

    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final isQuestion = step.isEvaluationStep;

      // Divider between sections — but NOT between a text prompt and
      // the question that follows it (they merge visually).
      if (children.isNotEmpty && !_isPromptForNextQuestion(i > 0 ? i - 1 : -1)) {
        children.add(const SizedBox(height: 24));
        children.add(Divider(color: AppColors.primaryDark.withValues(alpha: 0.08), height: 1));
        children.add(const SizedBox(height: 24));
      } else if (children.isNotEmpty) {
        // Prompt → question: just a small gap, no divider
        children.add(const SizedBox(height: 16));
      }

      // A multi-question block shows every question at once, so every
      // unanswered one stays interactive — otherwise the extra fields look
      // live but discard what the student types (BR-E4H835).
      final isActiveQuestion = isQuestion && !isBlockDone &&
          (_isMultiQuestionBlock
              ? _stepAnswers[step.stepId]?.isAnswered != true
              : i == _currentStepIndex);
      // Photo/evaluation state is a single slot on the engine, so it belongs to
      // the current step only — passing it to a sibling question would show one
      // question's photo under another.
      final isCurrentQuestion = isQuestion && i == _currentStepIndex;

      if (isActiveQuestion) {
        // Active question — full interaction
        children.add(StepContentRenderer(
          step: step,
          answerState: _stepAnswers[step.stepId],
          exportMode: widget.exportMode,
          showSolution: _state == _EngineState.showingSolution && !_isAgainRetry,
          revealCorrectAnswer: !_isAgainRetry,
          // Only the step being answered may carry the anchor — the key is
          // global, and a multi-question card renders its siblings alongside.
          feedbackAnchorKey: isCurrentQuestion ? _feedbackKey : null,
          // Photo + retry wiring for AI-evaluated open answers (BR-P745Q8).
          pickedPhoto: isCurrentQuestion ? _pickedPhoto : null,
          uploadedPhotoName: isCurrentQuestion ? _uploadedPhotoName : null,
          isUploadingPhoto: isCurrentQuestion && _isUploadingPhoto,
          photoUnreadable: isCurrentQuestion && _photoUnreadable,
          evaluationOffline: isCurrentQuestion && _evaluationOffline,
          evaluationRetryable: isCurrentQuestion && _evaluationRetryable,
          canReanswer:
              _canReanswerNow(step.evaluationConfig, _stepAnswers[step.stepId]),
          onPhotoPicked: _onPhotoPicked,
          showAnswerStatus: widget.showAnswerStatus,
          onPhotoRemoved: _onPhotoRemoved,
          onEvaluationRetry: _retryEvaluation,
          onReworkAnswer: () => _reopenForNewAttempt(i),
          hideResults: widget.hideEvaluation,
          hideFeedback: widget.hideEvaluation,
          onOptionSelected: (optionId) => _onOptionSelectedFor(step, optionId),
          onMultipleOptionsSelected: (ids) =>
              _onMultipleOptionsSelectedFor(step, ids),
          onTextAnswerChanged: (text) => _onTextAnswerChangedFor(step, text),
          onTextAnswerSubmitted: _confirmAnswer,
          getVideoController: _getVideoController,
          getAudioController: _getAudioController,
        ));
      } else {
        // Display step (always passive) or completed question (read-only)
        children.add(StepContentRenderer(
          step: step,
          answerState: _stepAnswers[step.stepId],
          exportMode: widget.exportMode,
          // A batch block grades every question at once, so the one just
          // answered is read-only by the time its solution appears — the
          // anchor has to live here too, or there is nothing to scroll to.
          feedbackAnchorKey: isCurrentQuestion ? _feedbackKey : null,
          showSolution: _stepAnswers[step.stepId]?.isAnswered == true && !widget.hideEvaluation,
          hideResults: widget.hideEvaluation,
          hideFeedback: widget.hideEvaluation,
          getVideoController: _getVideoController,
          getAudioController: _getAudioController,
        ));
      }
    }

    // When a controller is provided (quiz mode), the parent handles the
    // confirm button — but we still show action buttons (e.g. hint).
    if (widget.controller == null) {
      children.add(const SizedBox(height: 24));
      children.add(_buildBottomRow());
    } else if (_hasHintForCurrentStep) {
      children.add(const SizedBox(height: 16));
      children.add(_buildActionButtons());
    }

    return Container(
      key: _activeStepKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// A completed step card — same look as active card but with green check.
  Widget _buildHistoryStepCard(int stepIndex) {
    final step = _steps[stepIndex];
    final answer = _stepAnswers[step.stepId];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepContentRenderer(
            step: step,
            answerState: answer,
            exportMode: widget.exportMode,
            showSolution: answer?.isAnswered == true,
            getVideoController: _getVideoController,
            getAudioController: _getAudioController,
          ),
          const SizedBox(height: 24),
          _buildHistoryBottomRow(step),
        ],
      ),
    );
  }

  /// Bottom row for completed history steps — per-step action buttons + green checkmark.
  Widget _buildHistoryBottomRow(BlockStep step) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepActionButtons(step),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            boxShadow: AppDecorations.shadowStrong,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  /// The current active step card with full interaction and per-step action buttons.
  Widget _buildActiveStepCard() {
    return Container(
      key: _activeStepKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepContentRenderer(
            step: _currentStep,
            answerState: _stepAnswers[_currentStep.stepId],
            exportMode: widget.exportMode,
            showSolution: _state == _EngineState.showingSolution && !_isAgainRetry,
            revealCorrectAnswer: !_isAgainRetry,
            feedbackAnchorKey: _feedbackKey,
            // Photo + retry wiring for AI-evaluated open answers (BR-P745Q8).
            pickedPhoto: _pickedPhoto,
            uploadedPhotoName: _uploadedPhotoName,
            isUploadingPhoto: _isUploadingPhoto,
            photoUnreadable: _photoUnreadable,
            evaluationOffline: _evaluationOffline,
            evaluationRetryable: _evaluationRetryable,
            canReanswer: _canReanswerNow(
              _currentStep.evaluationConfig,
              _stepAnswers[_currentStep.stepId],
            ),
            onPhotoPicked: _onPhotoPicked,
            showAnswerStatus: widget.showAnswerStatus,
            onPhotoRemoved: _onPhotoRemoved,
            onEvaluationRetry: _retryEvaluation,
            onReworkAnswer: () => _reopenForNewAttempt(_currentStepIndex),
            hideResults: widget.hideEvaluation,
            hideFeedback: widget.hideEvaluation,
            onOptionSelected: _onOptionSelected,
            onMultipleOptionsSelected: _onMultipleOptionsSelected,
            onTextAnswerChanged: _onTextAnswerChanged,
            onTextAnswerSubmitted: _confirmAnswer,
            getVideoController: _getVideoController,
            getAudioController: _getAudioController,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepActionButtons(_currentStep),
              _buildMainButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBlock() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Text(
        widget.block.displayTitle,
        style: AppTextStyles.cardTitle(),
      ),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side action buttons
        _buildActionButtons(),
        // Right side: confirm/next button
        _buildMainButton(),
      ],
    );
  }

  /// The live step, or null once the engine has run past the last one — the
  /// finished block then falls back to the block's own shared hint.
  BlockStep? get _currentStepOrNull =>
      _currentStepIndex >= 0 && _currentStepIndex < _steps.length
          ? _steps[_currentStepIndex]
          : null;

  /// Whether the step the student is on has a hint to offer — its own, or the
  /// block's shared one as fallback (BR-JHDNB3).
  bool get _hasHintForCurrentStep =>
      widget.block.hasHintForStep(_currentStepOrNull?.stepId);

  /// Per-step action buttons for display blocks — each step has independent state.
  Widget _buildStepActionButtons(BlockStep step) {
    final stepId = step.stepId;
    final isBookmarked = widget.bookmarkedStepIds.contains(stepId);
    final isLiked = widget.likedStepIds.contains(stepId);
    final isDisliked = widget.dislikedStepIds.contains(stepId);

    final isQuiz = widget.exportMode == ExportMode.quizV2;

    // In quiz mode, only show hint button (no bookmark/like/dislike)
    final buttons = <Widget>[
      if (!isQuiz) ...[
        _buildActionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          isActive: isBookmarked,
          onTap: () => widget.onStepBookmarkToggle?.call(stepId),
        ),
        _buildActionButton(
          icon: Icons.thumb_up_outlined,
          isActive: isLiked,
          activeColor: AppColors.success,
          onTap: () => widget.onStepLikeToggle?.call(stepId),
        ),
        _buildActionButton(
          icon: Icons.thumb_down_outlined,
          isActive: isDisliked,
          activeColor: AppColors.orange,
          onTap: () => widget.onStepDislikeToggle?.call(stepId),
        ),
      ],
      // Each step card carries its own hint button: a step without a hint of
      // its own still offers the block's shared one (BR-JHDNB3).
      if (widget.block.hasHintForStep(stepId))
        _buildActionButton(
          icon: Icons.help_outline,
          isActive: false,
          onTap: () => widget.onHintRequested?.call(stepId),
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(36),
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons,
      ),
    );
  }

  /// Block-level action buttons (for exercise/question blocks — single bubble).
  Widget _buildActionButtons() {
    final isQuiz = widget.exportMode == ExportMode.quizV2;

    // In quiz mode, only show hint button (no bookmark/like/dislike)
    final buttons = <Widget>[
      if (!isQuiz) ...[
        _buildActionButton(
          icon: widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          isActive: widget.isBookmarked,
          onTap: widget.onBookmarkToggle,
        ),
        _buildActionButton(
          icon: Icons.thumb_up_outlined,
          isActive: widget.isLiked,
          activeColor: AppColors.success,
          onTap: widget.onLikeToggle,
        ),
        _buildActionButton(
          icon: Icons.thumb_down_outlined,
          isActive: widget.isDisliked,
          activeColor: AppColors.orange,
          onTap: widget.onDislikeToggle,
        ),
      ],
      // The single-bubble card shows one row for the whole block, so the hint
      // follows whichever step is live inside it (BR-JHDNB3).
      if (_hasHintForCurrentStep)
        _buildActionButton(
          icon: Icons.help_outline,
          isActive: false,
          onTap: () =>
              widget.onHintRequested?.call(_currentStepOrNull?.stepId),
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(36),
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons,
      ),
    );
  }

  Widget _buildActionButton({
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

  Widget _buildMainButton() {
    final bool isComplete = _state == _EngineState.blockComplete || widget.isCompleted;

    if (isComplete) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          boxShadow: AppDecorations.shadowStrong,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 24),
      );
    }

    // Determine button behavior based on state
    VoidCallback? onTap;
    String? label;
    bool enabled = widget.isCurrent;

    switch (_state) {
      case _EngineState.showingStep:
        // Display step — tap to advance
        onTap = enabled ? _advanceDisplayStep : null;
        break;
      case _EngineState.awaitingAnswer:
        // Check if the user has answered — every question of a multi-question
        // block, just the current one otherwise.
        if (_canConfirm) {
          onTap = enabled ? _confirmAnswer : null;
          // When show_answers is false, there's no feedback to show —
          // just validate and advance, so label is "Další" not "Zkontrolovat".
          final showAnswers = _currentStep.evaluationConfig?.showAnswers ?? true;
          label = showAnswers ? AppStrings.engineCheck : AppStrings.engineNext;
        } else {
          enabled = false;
        }
        break;
      case _EngineState.showingSolution:
        if (_isAgainRetry) {
          // Wrong AGAIN answer: button clears the pick for another attempt.
          onTap = enabled ? _retryAgain : null;
          label = AppStrings.engineTryAgain;
        } else if (_isGuidedRetryOpen) {
          // AI-guided solving: the answer did not land and attempts remain, so
          // the block waits rather than offering a way past it (BR-V9TQA7).
          // The field above is already unlocked — the button names what happens
          // next and comes alive as soon as the answer changes.
          label = AppStrings.engineCheck;
          enabled = false;
        } else {
          onTap = enabled ? _continueAfterSolution : null;
        }
        break;
      case _EngineState.blockComplete:
        break;
    }

    // While an answer is out for AI grading the button is inert and spins —
    // the student gets a visible "working" signal instead of a dead tap.
    if (_isEvaluatingWithAi) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: AppDecorations.radiusM,
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // If we have a text label, show a pill button
    if (label != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryDark : AppColors.surfaceLight,
            borderRadius: AppDecorations.radiusM,
          ),
          child: Text(
            label,
            style: AppTextStyles.statValue(
              color: enabled ? Colors.white : AppColors.disabled,
            ),
          ),
        ),
      );
    }

    // Default: checkmark circle button
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (widget.isCurrent && _state == _EngineState.awaitingAnswer) {
          showAppToast(
            context,
            _isMultiQuestionBlock
                ? AppStrings.engineAnswerAllQuestions
                : AppStrings.engineSelectAnswer,
          );
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppDecorations.shadowStrong,
        ),
        child: Icon(
          Icons.check,
          color: enabled ? AppColors.primaryDark : AppColors.disabled,
          size: 24,
        ),
      ),
    );
  }
}
