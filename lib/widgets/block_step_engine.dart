// Core state machine widget managing step-by-step navigation within a block.
//
// Handles linear display flow, go_to branching for question blocks,
// exercise mode (linear + evaluated), and quizV2 mode (no hints/solutions).

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/block_model.dart';
import '../models/step_navigation.dart';
import 'block_action_buttons.dart';
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

  /// Whether the engine has a selected-but-unconfirmed answer.
  bool get hasPendingAnswer => _hasPendingAnswer;

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

/// Internal state of the step engine
enum _EngineState {
  showingStep,     // Displaying a text/image/video step or a question before answer
  awaitingAnswer,  // Question shown, waiting for user to confirm selection
  showingSolution, // Answer evaluated, showing feedback/solution
  blockComplete,   // All steps done
}

class BlockStepEngine extends StatefulWidget {
  final ContentBlock block;
  final ExportMode exportMode;
  final bool isCurrent;
  final bool isCompleted;
  final void Function({int earnedXp, double scoreKoef, String? mark}) onBlockCompleted;
  final void Function(String blockId)? onCrossBlockNavigate;
  final void Function()? onChatRequested;
  final void Function(StepProgressData)? onStepProgress;
  final StepProgressData? savedProgress;

  /// Called with the index of the step now on screen whenever it changes,
  /// including the first one after mounting or restoring — which is what
  /// [onStepProgress] does not cover. Reported after the frame, once per change.
  /// Null in the student's app; the editor's preview follows the run with it.
  final void Function(int stepIndex)? onStepShown;

  /// Optional controller for external answer confirmation (used by QuizPage).
  /// When provided, the engine hides its own bottom row and lets the parent
  /// drive confirm/next via the controller.
  final BlockStepEngineController? controller;

  // Block-level action callbacks (for exercise/question blocks — single bubble)
  final void Function()? onBookmarkToggle;
  final void Function()? onLikeToggle;
  final void Function()? onDislikeToggle;
  final void Function()? onHintRequested;

  /// Called when the user answers a question incorrectly.
  /// Used by parents to auto-bookmark the block for practice.
  final void Function()? onWrongAnswer;

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
  final bool hasHint;

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
    this.onStepShown,
    this.controller,
    this.hideEvaluation = false,
    this.onBookmarkToggle,
    this.onLikeToggle,
    this.onDislikeToggle,
    this.onHintRequested,
    this.onWrongAnswer,
    this.onStepBookmarkToggle,
    this.onStepLikeToggle,
    this.onStepDislikeToggle,
    this.isBookmarked = false,
    this.isLiked = false,
    this.isDisliked = false,
    this.hasHint = false,
    this.bookmarkedStepIds = const {},
    this.likedStepIds = const {},
    this.dislikedStepIds = const {},
  });

  @override
  State<BlockStepEngine> createState() => _BlockStepEngineState();
}

class _BlockStepEngineState extends State<BlockStepEngine> {
  /// Sentinel value: scoreKoef hasn't been set by any answer yet.
  static const _kUninitializedScore = -1.0;

  late _EngineState _state;

  /// Every write goes through the setter, so [BlockStepEngine.onStepShown] is
  /// reported from one place however the index moved — mount, restore, skip to
  /// the question, advance, branch.
  late int _stepIndex;
  int get _currentStepIndex => _stepIndex;
  set _currentStepIndex(int value) {
    _stepIndex = value;
    _scheduleStepShown();
  }

  int? _shownStepIndex;
  bool _stepShownScheduled = false;

  void _scheduleStepShown() {
    if (widget.onStepShown == null || _stepShownScheduled) return;
    _stepShownScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stepShownScheduled = false;
      if (!mounted) return;
      final index = _stepIndex;
      if (index < 0 || index >= _steps.length || index == _shownStepIndex) return;
      _shownStepIndex = index;
      widget.onStepShown?.call(index);
    });
  }
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

  // Text controller for open question input
  TextEditingController? _textController;

  // Stable callback identities so the controller can detach safely even when
  // a newer engine State has already attached (keyed recreation).
  late final VoidCallback _boundConfirm = _confirmAnswer;
  late final VoidCallback _boundContinue = _continueAfterSolution;
  late final VoidCallback _boundRetry = _retryAgain;

  List<BlockStep> get _steps => widget.block.steps;
  BlockStep get _currentStep => _steps[_currentStepIndex];
  bool get _isLastStep => _currentStepIndex >= _steps.length - 1;

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
  void _skipToNextQuestion() {
    while (_currentStepIndex < _steps.length &&
        !_steps[_currentStepIndex].isEvaluationStep) {
      _currentStepIndex++;
    }
    if (_currentStepIndex >= _steps.length) {
      _completeBlock();
    } else {
      _state = _deriveState();
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
        if (config != null && !config.showSolution) {
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
      final answer = _stepAnswers[_currentStep.stepId];
      widget.controller!._setPendingAnswer(
        answer != null &&
        (answer.selectedOptionId != null ||
         (answer.selectedOptionIds?.isNotEmpty ?? false) ||
         (answer.textAnswer?.isNotEmpty ?? false)),
      );
    });
  }

  @override
  void dispose() {
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
  void _onOptionSelected(String optionId) {
    if (_state == _EngineState.blockComplete) return;
    final step = _currentStep;

    setState(() {
      _isAgainRetry = false;
      _stepAnswers[step.stepId] = StepAnswerState(
        selectedOptionId: optionId,
        isAnswered: false,
      );
      _state = _EngineState.awaitingAnswer;
    });
    widget.controller?._setPendingAnswer(true);
  }

  /// Handle multi-option selection
  void _onMultipleOptionsSelected(Set<String> optionIds) {
    if (_state == _EngineState.blockComplete) return;
    final step = _currentStep;

    setState(() {
      _isAgainRetry = false;
      _stepAnswers[step.stepId] = StepAnswerState(
        selectedOptionIds: optionIds,
        isAnswered: false,
      );
      _state = _EngineState.awaitingAnswer;
    });
    widget.controller?._setPendingAnswer(optionIds.isNotEmpty);
  }

  /// Handle text answer change
  void _onTextAnswerChanged(String text) {
    final step = _currentStep;
    final existing = _stepAnswers[step.stepId];
    setState(() {
      _stepAnswers[step.stepId] = StepAnswerState(
        textAnswer: text,
        isAnswered: existing?.isAnswered ?? false,
        isCorrect: existing?.isCorrect,
      );
      if (text.isNotEmpty && _state != _EngineState.showingSolution) {
        _state = _EngineState.awaitingAnswer;
      }
    });
    widget.controller?._setPendingAnswer(text.isNotEmpty);
  }

  /// Confirm the answer for the current question step
  void _confirmAnswer() {
    if (_state != _EngineState.awaitingAnswer) return;

    final step = _currentStep;
    final config = step.evaluationConfig;
    if (config == null) return;

    final current = _stepAnswers[step.stepId];
    if (current == null) return;

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
      // Open question: compare text answer
      final userAnswer = (current.textAnswer ?? '').trim().toLowerCase();
      final correctAnswer = (config.correctAnswer ?? '').trim().toLowerCase();
      if (correctAnswer.isNotEmpty) {
        isCorrect = userAnswer == correctAnswer;
      }
      // Also check against options if present
      if (!isCorrect && config.options.isNotEmpty) {
        isCorrect = config.options.any((o) =>
            o.isCorrect && o.text.trim().toLowerCase() == userAnswer);
      }
      scoreKoef = isCorrect ? 1.0 : 0.0;
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
    final effectiveScoreKoef = isCorrect ? scoreKoef : 0.0;

    // Update answer state
    final updatedAnswer = current.copyWith(
      isAnswered: true,
      isCorrect: isCorrect,
      scoreKoef: effectiveScoreKoef,
      markValue: markValue,
    );

    // Track best score (start from 0 on first answer)
    if (_bestScoreKoef == _kUninitializedScore || effectiveScoreKoef > _bestScoreKoef) {
      _bestScoreKoef = effectiveScoreKoef;
    }
    _quizMark = markValue ?? _quizMark;

    widget.controller?._setPendingAnswer(false);

    // Auto-bookmark on wrong answer (for Practice/Cvičení collection)
    if (!isCorrect) {
      widget.onWrongAnswer?.call();
    }

    // Pre-resolve to detect "again" loops
    final preResolved = GoToResolver.resolve(
      goToValue: goToValue,
      blockType: widget.block.type,
      steps: _steps,
      currentStepIndex: _currentStepIndex,
    );


    // Determine if there's any feedback/solution content worth showing
    final hasSolutionText = config.solution != null && config.solution!.isNotEmpty;
    final hasSolutionImage = config.solutionImage != null;
    final selectedOption = config.options.where((o) => o.id == current.selectedOptionId).firstOrNull;
    final hasOptionFeedback = selectedOption?.feedback != null && selectedOption!.feedback!.isNotEmpty;
    final hasFeedbackContent = hasSolutionText || hasSolutionImage || hasOptionFeedback;

    // In quiz mode with evaluation on, always pause on the answered state so
    // the user sees feedback (solution banner, card highlighting, etc.). The
    // renderer already respects show_answers — when it's false the correct
    // option just isn't revealed, but the solution banner still shows. So we
    // do NOT gate the pause on show_answers in quiz/eval mode.
    final isQuizEvaluating =
        widget.exportMode == ExportMode.quizV2 && !widget.hideEvaluation;

    final shouldSkipSolution =
        (widget.exportMode == ExportMode.quizV2 && widget.hideEvaluation) ||
        (!isQuizEvaluating &&
            (!(config.showAnswers) ||
                !(config.showSolution) ||
                !hasFeedbackContent));

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
    }

    _emitProgress();
  }

  /// Handle "Pokračovat" after showing solution
  void _continueAfterSolution() {
    widget.controller?._setShowingSolution(false);
    widget.controller?._setAgainRetry(false);

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

    return Column(
      children: [
        for (int i = 0; i < visibleCount; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          i < _currentStepIndex || isBlockDone
              ? _buildHistoryStepCard(i)
              : _buildActiveStepCard(),
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

      if (isQuestion && i == _currentStepIndex && !isBlockDone) {
        // Active question — full interaction
        children.add(StepContentRenderer(
          step: step,
          answerState: _stepAnswers[step.stepId],
          exportMode: widget.exportMode,
          showSolution: _state == _EngineState.showingSolution && !_isAgainRetry,
          revealCorrectAnswer: !_isAgainRetry,
          hideResults: widget.hideEvaluation,
          hideFeedback: widget.hideEvaluation,
          onOptionSelected: _onOptionSelected,
          onMultipleOptionsSelected: _onMultipleOptionsSelected,
          onTextAnswerChanged: _onTextAnswerChanged,
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
    } else if (widget.hasHint) {
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
        const BlockMainButton(isComplete: true),
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

  /// Per-step action buttons for display blocks — each step has independent state.
  ///
  /// The closures are built here rather than passed as bare nullable callbacks: a
  /// per-step toggle needs the step id, and a `GestureDetector` with a non-null
  /// `onTap` also absorbs the tap, which is the behaviour these rows have always had.
  Widget _buildStepActionButtons(BlockStep step) {
    final stepId = step.stepId;
    return BlockActionBar(
      exportMode: widget.exportMode,
      isBookmarked: widget.bookmarkedStepIds.contains(stepId),
      isLiked: widget.likedStepIds.contains(stepId),
      isDisliked: widget.dislikedStepIds.contains(stepId),
      showHint: widget.hasHint,
      onBookmark: () => widget.onStepBookmarkToggle?.call(stepId),
      onLike: () => widget.onStepLikeToggle?.call(stepId),
      onDislike: () => widget.onStepDislikeToggle?.call(stepId),
      onHint: widget.onHintRequested,
    );
  }

  /// Block-level action buttons (for exercise/question blocks — single bubble).
  ///
  /// The callbacks go through as they are, nulls included: when the owner wires
  /// nothing to them the buttons must not swallow the tap.
  Widget _buildActionButtons() {
    return BlockActionBar(
      exportMode: widget.exportMode,
      isBookmarked: widget.isBookmarked,
      isLiked: widget.isLiked,
      isDisliked: widget.isDisliked,
      showHint: widget.hasHint,
      onBookmark: widget.onBookmarkToggle,
      onLike: widget.onLikeToggle,
      onDislike: widget.onDislikeToggle,
      onHint: widget.onHintRequested,
    );
  }

  Widget _buildMainButton() {
    final bool isComplete = _state == _EngineState.blockComplete || widget.isCompleted;

    // Short-circuit, as it always has: a finished block has no state left to read.
    if (isComplete) return const BlockMainButton(isComplete: true);

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
        // Check if user has made a selection
        final answer = _stepAnswers[_currentStep.stepId];
        final hasSelection = answer != null &&
            (answer.selectedOptionId != null ||
             answer.selectedOptionIds != null && answer.selectedOptionIds!.isNotEmpty ||
             answer.textAnswer != null && answer.textAnswer!.isNotEmpty);
        if (hasSelection) {
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
        } else {
          onTap = enabled ? _continueAfterSolution : null;
        }
        break;
      case _EngineState.blockComplete:
        break;
    }

    return BlockMainButton(
      label: label,
      enabled: enabled,
      onTap: onTap,
      disabledMessage: widget.isCurrent && _state == _EngineState.awaitingAnswer
          ? AppStrings.engineSelectAnswer
          : null,
    );
  }
}
