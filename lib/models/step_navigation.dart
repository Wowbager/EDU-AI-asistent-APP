// Step navigation models for the Block V2 step rendering engine.
//
// Pure Dart — no Flutter dependency. Contains navigation types,
// answer state, progress data, and the go_to resolver.

import 'block_model.dart';
import 'open_answer_feedback.dart';

/// Export mode determines quiz/exercise behavior.
enum ExportMode {
  courseV2,    // Normal course: hints, solutions, feedback shown
  exerciseV2, // Exercise: linear flow, go_to ignored, questions evaluated
  quizV2,     // Quiz: no hints, no solutions, no feedback
}

/// Tracks the user's answer state for a single step.
class StepAnswerState {
  final String? selectedOptionId;
  final Set<String>? selectedOptionIds; // for allow_multiple
  final String? textAnswer;
  final bool isAnswered;
  final bool? isCorrect;
  final String? markValue;   // Czech grade "1"-"5" from option.mark (quiz mode)
  final double? scoreKoef;   // option.score_koef for the selected answer

  // AI grading of open answers (BR-FFVVYR). Absent when the answer was graded
  // locally — offline, on timeout, or when the question opted out of AI.
  final bool evaluatedByAi;
  final String? aiFeedback;
  final String? aiModel;

  // ─── Formative feedback + photo answers (BR-P745Q8) ───────────────────────

  /// The three-part feedback the student was shown. Null on a locally graded
  /// answer, and on an attempt whose evaluation failed.
  final FormativeFeedback? feedback;

  /// Handle of the photographed answer, as issued by the upload endpoint.
  /// Kept in the answer state so a reload restores the attachment, not just
  /// the typed text.
  final String? photoName;

  /// True when AI evaluation was attempted and did not produce feedback.
  ///
  /// This is what stops a failed evaluation from being dressed up as a verdict:
  /// the student is shown a retry, and the attempt is logged as failed rather
  /// than silently falling back to a string comparison that would call any
  /// paragraph-length answer wrong.
  final bool evaluationFailed;

  /// How many times this step has been submitted and graded.
  ///
  /// Drives AI-guided solving (BR-V9TQA7), which withholds the authored
  /// explanation until the attempts run out. It is persisted with the rest of
  /// the answer because a reload that reset it to zero would hand the student
  /// a fresh set of attempts — and, since the reveal is the thing being
  /// rationed, an unlimited supply of them.
  ///
  /// Counts graded submissions only: an evaluation that never produced a
  /// verdict (offline, timeout) does not spend an attempt.
  final int attemptCount;

  const StepAnswerState({
    this.selectedOptionId,
    this.selectedOptionIds,
    this.textAnswer,
    this.isAnswered = false,
    this.isCorrect,
    this.markValue,
    this.scoreKoef,
    this.evaluatedByAi = false,
    this.aiFeedback,
    this.aiModel,
    this.feedback,
    this.photoName,
    this.evaluationFailed = false,
    this.attemptCount = 0,
  });

  Map<String, dynamic> toJson() => {
    if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
    if (selectedOptionIds != null) 'selectedOptionIds': selectedOptionIds!.toList(),
    if (textAnswer != null) 'textAnswer': textAnswer,
    'isAnswered': isAnswered,
    if (isCorrect != null) 'isCorrect': isCorrect,
    if (markValue != null) 'markValue': markValue,
    if (scoreKoef != null) 'scoreKoef': scoreKoef,
    if (evaluatedByAi) 'evaluatedByAi': true,
    if (aiFeedback != null) 'aiFeedback': aiFeedback,
    if (aiModel != null) 'aiModel': aiModel,
    if (feedback != null) 'feedback': feedback!.toJson(),
    if (photoName != null) 'photoName': photoName,
    if (evaluationFailed) 'evaluationFailed': true,
    if (attemptCount > 0) 'attemptCount': attemptCount,
  };

  factory StepAnswerState.fromJson(Map<String, dynamic> json) {
    return StepAnswerState(
      selectedOptionId: json['selectedOptionId'] as String?,
      selectedOptionIds: json['selectedOptionIds'] != null
          ? (json['selectedOptionIds'] as List<dynamic>).map((e) => e as String).toSet()
          : null,
      textAnswer: json['textAnswer'] as String?,
      isAnswered: json['isAnswered'] as bool? ?? false,
      isCorrect: json['isCorrect'] as bool?,
      markValue: json['markValue'] as String?,
      scoreKoef: (json['scoreKoef'] as num?)?.toDouble(),
      evaluatedByAi: json['evaluatedByAi'] as bool? ?? false,
      aiFeedback: json['aiFeedback'] as String?,
      aiModel: json['aiModel'] as String?,
      feedback: FormativeFeedback.fromJson(json['feedback']),
      photoName: json['photoName'] as String?,
      evaluationFailed: json['evaluationFailed'] as bool? ?? false,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
    );
  }

  StepAnswerState copyWith({
    String? selectedOptionId,
    Set<String>? selectedOptionIds,
    String? textAnswer,
    bool? isAnswered,
    bool? isCorrect,
    String? markValue,
    double? scoreKoef,
    bool? evaluatedByAi,
    String? aiFeedback,
    String? aiModel,
    FormativeFeedback? feedback,
    String? photoName,
    bool? evaluationFailed,
    int? attemptCount,
    // `copyWith` cannot null a field out through the usual `?? this.x` idiom,
    // and detaching a photo has to be expressible — a student who retakes a
    // blurry shot must be able to remove the old one.
    bool clearPhoto = false,
    bool clearFeedback = false,
    // Same for the legacy flat feedback. Without it a re-graded answer whose
    // new response carries no text inherits the previous attempt's, dressed up
    // as the verdict on the answer the student just wrote (BR-K8TDU4).
    bool clearAiFeedback = false,
  }) {
    return StepAnswerState(
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
      textAnswer: textAnswer ?? this.textAnswer,
      isAnswered: isAnswered ?? this.isAnswered,
      isCorrect: isCorrect ?? this.isCorrect,
      markValue: markValue ?? this.markValue,
      scoreKoef: scoreKoef ?? this.scoreKoef,
      evaluatedByAi: evaluatedByAi ?? this.evaluatedByAi,
      aiFeedback: clearAiFeedback ? null : (aiFeedback ?? this.aiFeedback),
      aiModel: aiModel ?? this.aiModel,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      photoName: clearPhoto ? null : (photoName ?? this.photoName),
      evaluationFailed: evaluationFailed ?? this.evaluationFailed,
      // Never reset by a plain copyWith: reopening an attempt clears the
      // feedback but must not refund the attempt that produced it.
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }
}

/// Tracks step-level progress within a block.
class StepProgressData {
  final String blockId;
  int currentStepIndex;
  final Map<String, StepAnswerState> stepAnswers; // stepId → answer
  bool isBlockCompleted;
  double bestScoreKoef;   // highest score_koef from answered questions (default 1.0)
  int earnedXp;           // block.xp * bestScoreKoef
  String? quizMark;       // final mark value for quiz grading

  StepProgressData({
    required this.blockId,
    this.currentStepIndex = 0,
    Map<String, StepAnswerState>? stepAnswers,
    this.isBlockCompleted = false,
    this.bestScoreKoef = 1.0,
    this.earnedXp = 0,
    this.quizMark,
  }) : stepAnswers = stepAnswers ?? {};

  Map<String, dynamic> toJson() => {
    'blockId': blockId,
    'currentStepIndex': currentStepIndex,
    'stepAnswers': stepAnswers.map((k, v) => MapEntry(k, v.toJson())),
    'isBlockCompleted': isBlockCompleted,
    'bestScoreKoef': bestScoreKoef,
    'earnedXp': earnedXp,
    if (quizMark != null) 'quizMark': quizMark,
  };

  factory StepProgressData.fromJson(Map<String, dynamic> json) {
    // stepAnswers can be [] (empty list) when serialized from empty map
    final raw = json['stepAnswers'];
    final answersRaw = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
    final answers = answersRaw.map(
      (k, v) => MapEntry(k, StepAnswerState.fromJson(v as Map<String, dynamic>)),
    );

    return StepProgressData(
      blockId: json['blockId'] as String? ?? '',
      currentStepIndex: json['currentStepIndex'] as int? ?? 0,
      stepAnswers: answers,
      isBlockCompleted: json['isBlockCompleted'] as bool? ?? false,
      bestScoreKoef: (json['bestScoreKoef'] as num?)?.toDouble() ?? 1.0,
      earnedXp: json['earnedXp'] as int? ?? 0,
      quizMark: json['quizMark'] as String?,
    );
  }
}

/// Types of navigation actions that can result from go_to resolution.
enum NavActionType {
  nextStep,       // Advance to the next step in order
  again,          // Repeat the current step
  end,            // End the block (mark complete)
  jumpToStep,     // Jump to a specific step within this block
  crossBlockJump, // Jump to a different block entirely
  chat,           // Open AI chat with block context
}

/// A resolved navigation action.
class NavigationAction {
  final NavActionType type;
  final String? targetStepId;   // for jumpToStep
  final String? targetBlockId;  // for crossBlockJump

  const NavigationAction({
    required this.type,
    this.targetStepId,
    this.targetBlockId,
  });

  const NavigationAction.nextStep()
      : type = NavActionType.nextStep,
        targetStepId = null,
        targetBlockId = null;

  const NavigationAction.again()
      : type = NavActionType.again,
        targetStepId = null,
        targetBlockId = null;

  const NavigationAction.end()
      : type = NavActionType.end,
        targetStepId = null,
        targetBlockId = null;

  const NavigationAction.jumpToStep(String stepId)
      : type = NavActionType.jumpToStep,
        targetStepId = stepId,
        targetBlockId = null;

  const NavigationAction.crossBlockJump(String blockId)
      : type = NavActionType.crossBlockJump,
        targetStepId = null,
        targetBlockId = blockId;

  const NavigationAction.chat()
      : type = NavActionType.chat,
        targetStepId = null,
        targetBlockId = null;
}

/// Resolves go_to strings into NavigationAction objects.
class GoToResolver {
  /// Resolves a go_to value into a NavigationAction.
  ///
  /// For exercise blocks: always returns nextStep (ignores go_to).
  ///
  /// Algorithm:
  /// - null / "NEXT_STEP" → nextStep
  /// - "AGAIN" → again
  /// - "END" → end
  /// - matches a step ID in block → jumpToStep
  /// - else → crossBlockJump (target is another block)
  static NavigationAction resolve({
    required String? goToValue,
    required BlockType blockType,
    required List<BlockStep> steps,
    required int currentStepIndex,
  }) {
    // Exercise blocks always advance linearly — go_to is ignored
    if (blockType == BlockType.exercise) {
      return const NavigationAction.nextStep();
    }

    // Null or explicit NEXT_STEP
    if (goToValue == null || goToValue.isEmpty || goToValue == 'NEXT_STEP') {
      return const NavigationAction.nextStep();
    }

    // Special keywords
    if (goToValue == 'AGAIN') {
      return const NavigationAction.again();
    }
    if (goToValue == 'END') {
      return const NavigationAction.end();
    }
    if (goToValue == 'CHAT' || goToValue == 'LECTURE') {
      return const NavigationAction.chat();
    }

    // Check if it matches a step ID within this block
    final matchingIndex = steps.indexWhere((s) => s.stepId == goToValue);
    if (matchingIndex >= 0) {
      return NavigationAction.jumpToStep(goToValue);
    }

    // Otherwise treat as a cross-block jump
    return NavigationAction.crossBlockJump(goToValue);
  }

  /// Resolve go_to from a question evaluation step's next_actions
  /// based on whether the answer was correct or incorrect.
  static String? resolveNextActionGoTo({
    required NextActions? nextActions,
    required bool isCorrect,
  }) {
    if (nextActions == null) return null;
    return isCorrect ? nextActions.correct : nextActions.incorrect;
  }

  /// Resolve go_to from an option's go_to field (question.options[].go_to).
  static String? resolveOptionGoTo({
    required EvaluationOption? selectedOption,
  }) {
    return selectedOption?.goTo;
  }
}
