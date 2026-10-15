import 'package:eduai/core/evaluation/quiz_block_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-of-quiz outcome tally (BR-JCUJVR). The split that matters is
/// "correct" vs "correct only after a hint" — the spec counts them apart.
void main() {
  group('QuizBlockSummary.outcomeFor', () {
    test('correct without any hint', () {
      expect(
        QuizBlockSummary.outcomeFor(answered: true, correct: true, hintLevel: 0),
        QuizQuestionOutcome.correctNoHint,
      );
    });

    test('a hint (level 1) moves a correct answer into the hinted bucket', () {
      expect(
        QuizBlockSummary.outcomeFor(answered: true, correct: true, hintLevel: 1),
        QuizQuestionOutcome.correctWithHint,
      );
    });

    test('the detailed explanation (level 2) counts as a hint too', () {
      expect(
        QuizBlockSummary.outcomeFor(answered: true, correct: true, hintLevel: 2),
        QuizQuestionOutcome.correctWithHint,
      );
    });

    test('a wrong answer stays wrong whatever the hint level', () {
      for (final level in [0, 1, 2]) {
        expect(
          QuizBlockSummary.outcomeFor(
              answered: true, correct: false, hintLevel: level),
          QuizQuestionOutcome.wrong,
          reason: 'hintLevel $level',
        );
      }
    });

    test('never answered is not the same as wrong', () {
      expect(
        QuizBlockSummary.outcomeFor(
            answered: false, correct: false, hintLevel: 0),
        QuizQuestionOutcome.unanswered,
      );
    });

    test('a stale correct flag on an unanswered question does not count', () {
      // _correctFlags can outlive _answeredFlags after a reset; "answered"
      // is the authority.
      expect(
        QuizBlockSummary.outcomeFor(
            answered: false, correct: true, hintLevel: 0),
        QuizQuestionOutcome.unanswered,
      );
    });
  });

  group('QuizBlockSummary.fromAnswers', () {
    test('tallies a mixed block', () {
      final summary = QuizBlockSummary.fromAnswers(
        questionIndexes: const [0, 1, 2, 3],
        answeredFlags: const {0: true, 1: true, 2: true},
        correctFlags: const {0: true, 1: true, 2: false},
        hintUsage: const {1: 2},
      );

      expect(summary.correctNoHint, 1);
      expect(summary.correctWithHint, 1);
      expect(summary.wrong, 1);
      expect(summary.unanswered, 1);
      expect(summary.total, 4);
      expect(summary.correct, 2);
    });

    test('display-only blocks between questions are not counted', () {
      // Indexes 1 and 3 are display cards — they are simply not listed.
      final summary = QuizBlockSummary.fromAnswers(
        questionIndexes: const [0, 2],
        answeredFlags: const {0: true, 1: true, 2: true, 3: true},
        correctFlags: const {0: true, 1: true, 2: true, 3: true},
        hintUsage: const {},
      );

      expect(summary.total, 2);
      expect(summary.correctNoHint, 2);
    });

    test('a block with no questions is empty rather than all-zero noise', () {
      final summary = QuizBlockSummary.fromAnswers(
        questionIndexes: const [],
        answeredFlags: const {},
        correctFlags: const {},
        hintUsage: const {},
      );

      expect(summary.isEmpty, isTrue);
      expect(summary.total, 0);
    });

    test('missing map entries default to unanswered', () {
      final summary = QuizBlockSummary.fromAnswers(
        questionIndexes: const [0, 1, 2],
        answeredFlags: const {},
        correctFlags: const {},
        hintUsage: const {},
      );

      expect(summary.unanswered, 3);
      expect(summary.wrong, 0);
    });
  });
}
