// Formative feedback on an open answer (BR-P745Q8).
//
// Pure Dart — no Flutter, no Riverpod — because this travels through three
// layers that must not depend on the network stack: the step engine's answer
// state, the local Drift sync queue, and the widgets that render it.

/// The three-part feedback a student is shown, plus an optional hint.
///
/// BR-FFVVYR returned one sentence and a pass/fail verdict. The brief that
/// replaced it is explicit that feedback teaches rather than classifies, so the
/// shape is fixed: what went well, what to improve, one next step. All three
/// are always present — the API rejects a model response missing any of them —
/// which is why they are non-nullable here.
///
/// Deliberately absent: score, percentage, verdict. Those exist on the server
/// and in the teacher view; nothing student-facing carries them.
class FormativeFeedback {
  final String strengths;
  final String improvements;
  final String nextStep;

  /// A question that nudges the student toward what they missed. Null when the
  /// answer was complete enough not to need one.
  final String? hintQuestion;

  const FormativeFeedback({
    required this.strengths,
    required this.improvements,
    required this.nextStep,
    this.hintQuestion,
  });

  /// Parse the `feedback_parts` object.
  ///
  /// Returns null rather than a half-filled instance: a card with an empty
  /// "what to improve" section reads as a bug to a student, and the caller can
  /// fall back to the flat `feedback` string that older responses carry.
  static FormativeFeedback? fromJson(dynamic raw) {
    if (raw is! Map) return null;

    String read(String key) {
      final value = raw[key];
      return value is String ? value.trim() : '';
    }

    final strengths = read('strengths');
    final improvements = read('improvements');
    final nextStep = read('next_step');
    if (strengths.isEmpty || improvements.isEmpty || nextStep.isEmpty) {
      return null;
    }

    final hint = read('hint_question');

    return FormativeFeedback(
      strengths: strengths,
      improvements: improvements,
      nextStep: nextStep,
      hintQuestion: hint.isEmpty ? null : hint,
    );
  }

  Map<String, dynamic> toJson() => {
    'strengths': strengths,
    'improvements': improvements,
    'next_step': nextStep,
    if (hintQuestion != null) 'hint_question': hintQuestion,
  };
}

/// Why an evaluation needs different wording than ordinary feedback.
///
/// The API sets these; the app uses them to decide whether to keep the photo
/// attached, whether to offer a retry, and nothing else. The feedback text
/// itself already handles the situation — these do not replace it.
enum AnswerFlag {
  /// Empty, "nevím", or a few random characters.
  emptyAnswer,

  /// The answer does not address the task.
  offTopic,

  /// Blurred, blank, or unrelated photo. The AI did not guess at its contents.
  unreadablePhoto,

  /// Personal data or inappropriate content. The feedback redirects to the
  /// topic without commenting on it, and neither does the app.
  sensitiveContent;

  static AnswerFlag? parse(String raw) => switch (raw) {
    'empty_answer' => AnswerFlag.emptyAnswer,
    'off_topic' => AnswerFlag.offTopic,
    'unreadable_photo' => AnswerFlag.unreadablePhoto,
    'sensitive_content' => AnswerFlag.sensitiveContent,
    _ => null,
  };

  static List<AnswerFlag> parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().map(AnswerFlag.parse).nonNulls.toList();
  }
}
