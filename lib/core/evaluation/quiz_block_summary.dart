// Outcome tally for a finished quiz block (BR-JCUJVR).
//
// The end-of-quiz feedback popup reports how the block went split by *how* each
// question was solved, not just how many landed right: solving something after
// opening a hint is a different learning signal than solving it cold, and the
// spec ("Quiz Feedback v1") asks for the two to be counted apart.
//
// Pure Dart, no Flutter — so the counting rules can be unit-tested directly.
library;

/// How one question of a finished block turned out.
enum QuizQuestionOutcome {
  /// Correct without opening a hint or the detailed explanation.
  correctNoHint,

  /// Correct, but a hint or the explanation was opened first.
  correctWithHint,

  /// Answered, and wrong.
  wrong,

  /// Never answered — the student submitted before reaching it.
  unanswered,

  /// Answered too fast to be a real attempt (gaming filter) — reported as
  /// "Tipováno" and excluded from ELO/FSRS. Not a wrong answer: unevaluated.
  gamed,
}

extension QuizQuestionOutcomeWire on QuizQuestionOutcome {
  /// Snake-case name the quiz-feedback (AI comment) endpoint expects.
  String get wireName => switch (this) {
        QuizQuestionOutcome.correctNoHint => 'correct_no_hint',
        QuizQuestionOutcome.correctWithHint => 'correct_with_hint',
        QuizQuestionOutcome.wrong => 'wrong',
        QuizQuestionOutcome.unanswered => 'unanswered',
        QuizQuestionOutcome.gamed => 'gamed',
      };
}

/// Per-outcome counts for one finished quiz block.
class QuizBlockSummary {
  final int correctNoHint;
  final int correctWithHint;
  final int wrong;
  final int unanswered;
  final int gamed;

  const QuizBlockSummary({
    this.correctNoHint = 0,
    this.correctWithHint = 0,
    this.wrong = 0,
    this.unanswered = 0,
    this.gamed = 0,
  });

  /// Every question in the block, whatever happened to it.
  int get total => correctNoHint + correctWithHint + wrong + unanswered + gamed;

  /// Correct answers regardless of hint usage.
  int get correct => correctNoHint + correctWithHint;

  /// True when the block held no questions at all (display-only cards).
  bool get isEmpty => total == 0;

  /// Classify one question.
  ///
  /// [answered] and [correct] are the page's per-index flags; [hintLevel] is
  /// 0 (nothing opened), 1 (hint) or 2 (detailed explanation) — the same scale
  /// the ELO score penalty already uses. [gamed] wins over right/wrong: a
  /// too-fast attempt carries no verdict at all.
  static QuizQuestionOutcome outcomeFor({
    required bool answered,
    required bool correct,
    required int hintLevel,
    bool gamed = false,
  }) {
    if (!answered) return QuizQuestionOutcome.unanswered;
    if (gamed) return QuizQuestionOutcome.gamed;
    if (!correct) return QuizQuestionOutcome.wrong;
    return hintLevel >= 1
        ? QuizQuestionOutcome.correctWithHint
        : QuizQuestionOutcome.correctNoHint;
  }

  /// Tally [questionIndexes] using the quiz page's per-index state maps.
  ///
  /// Only indexes listed in [questionIndexes] are counted, so display-only
  /// blocks sitting between questions never inflate the totals.
  factory QuizBlockSummary.fromAnswers({
    required Iterable<int> questionIndexes,
    required Map<int, bool> answeredFlags,
    required Map<int, bool> correctFlags,
    required Map<int, int> hintUsage,
    Map<int, bool> gamedFlags = const {},
  }) {
    var correctNoHint = 0;
    var correctWithHint = 0;
    var wrong = 0;
    var unanswered = 0;
    var gamed = 0;

    for (final index in questionIndexes) {
      final outcome = outcomeFor(
        answered: answeredFlags[index] ?? false,
        correct: correctFlags[index] ?? false,
        hintLevel: hintUsage[index] ?? 0,
        gamed: gamedFlags[index] ?? false,
      );
      switch (outcome) {
        case QuizQuestionOutcome.correctNoHint:
          correctNoHint++;
        case QuizQuestionOutcome.correctWithHint:
          correctWithHint++;
        case QuizQuestionOutcome.wrong:
          wrong++;
        case QuizQuestionOutcome.unanswered:
          unanswered++;
        case QuizQuestionOutcome.gamed:
          gamed++;
      }
    }

    return QuizBlockSummary(
      correctNoHint: correctNoHint,
      correctWithHint: correctWithHint,
      wrong: wrong,
      unanswered: unanswered,
      gamed: gamed,
    );
  }
}
