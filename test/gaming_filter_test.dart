// The gaming filter marks too-fast answers as guesses ("Tipováno"): logged,
// but unevaluated — no ELO, no FSRS, and their own row in the feedback popup.
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/evaluation/gaming_filter.dart';
import 'package:eduai/core/evaluation/quiz_block_summary.dart';

void main() {
  final opened = DateTime.utc(2026, 9, 1, 12);

  group('isGamingAttempt', () {
    test('under two seconds is a guess', () {
      expect(
        isGamingAttempt(
          openedAt: opened,
          answeredAt: opened.add(const Duration(milliseconds: 1999)),
        ),
        isTrue,
      );
    });

    test('two seconds and up is a real attempt', () {
      expect(
        isGamingAttempt(
          openedAt: opened,
          answeredAt: opened.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
    });

    test('no opened timestamp means no verdict', () {
      expect(
        isGamingAttempt(openedAt: null, answeredAt: opened),
        isFalse,
      );
    });

    test('a UTC/local mix still measures absolute time', () {
      // quiz_page stores opened-at in UTC and answered-at in local time.
      final answeredLocal =
          opened.add(const Duration(minutes: 1)).toLocal();
      expect(
        isGamingAttempt(openedAt: opened, answeredAt: answeredLocal),
        isFalse,
      );
    });

    test('an answer stamped before the open (clock skew) is a guess', () {
      expect(
        isGamingAttempt(
          openedAt: opened,
          answeredAt: opened.subtract(const Duration(seconds: 5)),
        ),
        isTrue,
      );
    });

    // BR-H3TCRE: the verdict goes through GamingGuard.classify, so a task's
    // reference times switch it from the fixed floor to the robust threshold.
    group('with reference times of the task', () {
      const tenRefs = [5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0];

      test('fewer than ten references keep the fixed 2 s floor', () {
        expect(
          isGamingAttempt(
            openedAt: opened,
            answeredAt: opened.add(const Duration(milliseconds: 2500)),
            referenceTimesSeconds: tenRefs.sublist(1),
          ),
          isFalse,
        );
      });

      test('ten references raise the threshold to median − 3·MAD', () {
        // Robust threshold for tenRefs is ≈ 2.563 s (see elo_engine_test).
        expect(
          isGamingAttempt(
            openedAt: opened,
            answeredAt: opened.add(const Duration(milliseconds: 2500)),
            referenceTimesSeconds: tenRefs,
          ),
          isTrue,
        );
        expect(
          isGamingAttempt(
            openedAt: opened,
            answeredAt: opened.add(const Duration(milliseconds: 2600)),
            referenceTimesSeconds: tenRefs,
          ),
          isFalse,
        );
      });

      test('unusable reference times are dropped, not thrown', () {
        // Nine good times plus junk is still under ten usable references.
        expect(
          isGamingAttempt(
            openedAt: opened,
            answeredAt: opened.add(const Duration(milliseconds: 2500)),
            referenceTimesSeconds: [
              ...tenRefs.sublist(1),
              double.nan,
              double.infinity,
              -1.0,
            ],
          ),
          isFalse,
        );
      });
    });
  });

  // BR-3N79C3 — the lesson reads its verdict off the block_timestamps pair it
  // persists, and the admin ELO backfill (EloBackfillController) reads that
  // same pair back. These fixtures are the ones EloBackfillGamingTest uses, so
  // both sides agree on the same inputs.
  group('isGamingLessonAttempt', () {
    test('1.999 s from shown to submitted is a guess', () {
      expect(
        isGamingLessonAttempt(
          openedAt: '2026-09-01T12:00:00.000Z',
          confirmedAt: '2026-09-01T12:00:01.999Z',
        ),
        isTrue,
      );
    });

    test('exactly two seconds is a real attempt', () {
      expect(
        isGamingLessonAttempt(
          openedAt: '2026-09-01T12:01:00.000Z',
          confirmedAt: '2026-09-01T12:01:02.000Z',
        ),
        isFalse,
      );
    });

    test('the microsecond strings the lesson writes parse too', () {
      final shown = DateTime.utc(2026, 9, 1, 12, 0, 0, 0, 250);
      expect(
        isGamingLessonAttempt(
          openedAt: shown.toIso8601String(),
          confirmedAt:
              shown.add(const Duration(milliseconds: 800)).toIso8601String(),
        ),
        isTrue,
      );
    });

    test('a missing or unreadable timestamp means no verdict', () {
      const confirmed = '2026-09-01T12:03:00.000Z';
      expect(isGamingLessonAttempt(openedAt: null, confirmedAt: confirmed),
          isFalse);
      expect(
          isGamingLessonAttempt(
              openedAt: '2026-09-01T12:03:00.000Z', confirmedAt: null),
          isFalse);
      expect(
          isGamingLessonAttempt(openedAt: 'garbage', confirmedAt: confirmed),
          isFalse);
    });
  });

  group('gamed outcome', () {
    test('gaming outranks right and wrong — the attempt is unevaluated', () {
      for (final correct in [true, false]) {
        expect(
          QuizBlockSummary.outcomeFor(
            answered: true,
            correct: correct,
            hintLevel: 0,
            gamed: true,
          ),
          QuizQuestionOutcome.gamed,
          reason: 'correct=$correct',
        );
      }
    });

    test('an unanswered question cannot be a guess', () {
      expect(
        QuizBlockSummary.outcomeFor(
          answered: false,
          correct: false,
          hintLevel: 0,
          gamed: true,
        ),
        QuizQuestionOutcome.unanswered,
      );
    });

    test('gamed answers land in their own tally bucket', () {
      final summary = QuizBlockSummary.fromAnswers(
        questionIndexes: [0, 1, 2],
        answeredFlags: {0: true, 1: true, 2: true},
        correctFlags: {0: true, 1: true, 2: false},
        hintUsage: {},
        gamedFlags: {1: true},
      );
      expect(summary.correctNoHint, 1);
      expect(summary.gamed, 1);
      expect(summary.wrong, 1);
      expect(summary.total, 3);
    });

    test('a guess that landed right still scores as nothing (BR-RQQVP6)', () {
      final summary = QuizBlockSummary.fromAnswers(
        questionIndexes: [0, 1],
        answeredFlags: {0: true, 1: true},
        correctFlags: {0: true, 1: true},
        hintUsage: {},
        gamedFlags: {1: true},
      );
      // Two right answers, one of them guessed — the score is 1, and the
      // guess is reported on its own row instead.
      expect(summary.correct, 1);
      expect(summary.gamed, 1);
      expect(summary.total, 2);
    });
  });
}
