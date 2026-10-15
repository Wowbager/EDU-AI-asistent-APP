// Spec test for the FSRS practice-queue builder.
//
// Mirrors the product spec:
//   1. Cards with due_date <= today are eligible (overdue).
//   2. Unseen cards (state == 0) sorted by weight, capped at dailyNewLimit.
//   3. Seen cards (state > 0) sorted by weight, then oldest due first.
//   4. Whole queue capped at dailyReviewLimit (minus reviews already done
//      today); same-priority ties diversify across source courses.
//   5. Cards with a satisfied skip_condition are skipped.
//
// Pure function — no database, runs in milliseconds:
//   flutter test test/queue_builder_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/practice/practice_filter.dart';
import 'package:eduai/core/practice/queue_builder.dart';

PracticeCardsTableData card({
  required String id,
  String courseId = 'course-A',
  String lessonId = 'L1',
  int state = 0,
  DateTime? dueDate,
  int reps = 0,
  double weight = 5.0,
  String? skipCondition,
  bool isActive = true,
  DateTime? lastReview,
}) {
  final now = DateTime.now();
  return PracticeCardsTableData(
    id: id,
    serverId: null,
    userId: 'u1',
    courseId: courseId,
    lessonId: lessonId,
    blockId: 'block-$id',
    sourceType: 'bookmark',
    state: state,
    dueDate: dueDate ?? now.subtract(const Duration(minutes: 1)),
    stability: 0,
    difficulty: 0,
    reps: reps,
    lapses: 0,
    scheduledDays: 0,
    elapsedDays: 0,
    lastReview: lastReview,
    weight: weight,
    avgTimeSec: 20,
    skipCondition: skipCondition,
    isActive: isActive,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final now = DateTime.now();

  group('rule 1 — due filter', () {
    test('seen card due in the future is excluded', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(id: 'future', state: 2, reps: 1, dueDate: now.add(const Duration(days: 3))),
          card(id: 'due', state: 2, reps: 1, dueDate: now.subtract(const Duration(days: 1))),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue.map((c) => c.id), ['due']);
    });

    test('inactive card is excluded', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [card(id: 'off', isActive: false)],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue, isEmpty);
    });
  });

  group('rule 2 — new cards', () {
    test('sorted by weight desc, capped at dailyNewLimit', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(id: 'w3', weight: 3),
          card(id: 'w9', weight: 9),
          card(id: 'w6', weight: 6),
        ],
        dailyNewLimit: 2,
        dailyReviewLimit: 100,
      );
      expect(queue.map((c) => c.id), ['w9', 'w6']);
    });
  });

  group('rule 3 — seen cards ordering', () {
    test('weight desc first, then oldest due first', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(id: 'light-old', state: 2, reps: 1, weight: 2, dueDate: now.subtract(const Duration(days: 9))),
          card(id: 'heavy-new', state: 2, reps: 1, weight: 8, dueDate: now.subtract(const Duration(days: 1))),
          card(id: 'heavy-old', state: 2, reps: 1, weight: 8, dueDate: now.subtract(const Duration(days: 5))),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue.map((c) => c.id), ['heavy-old', 'heavy-new', 'light-old']);
    });

    test('overdue seen cards come before new cards', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(id: 'new', weight: 9),
          card(id: 'seen', state: 2, reps: 1, weight: 1, dueDate: now.subtract(const Duration(days: 1))),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue.map((c) => c.id), ['seen', 'new']);
    });
  });

  group('rule 4 — daily review limit + course diversity', () {
    test('caps total queue at dailyReviewLimit minus reviews done today', () {
      final cards = List.generate(10, (i) => card(id: 'c$i'));
      final queue = QueueBuilder.buildQueue(
        allCards: cards,
        dailyNewLimit: 20,
        dailyReviewLimit: 8,
        todayReviewCount: 5,
      );
      expect(queue.length, 3);
    });

    test('same-weight ties interleave across courses', () {
      // The builder shuffles ties, so assert the interleaving PROPERTY
      // (courses alternate) rather than one fixed order; seeded Random keeps
      // the run deterministic.
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(id: 'a1', courseId: 'A'),
          card(id: 'a2', courseId: 'A'),
          card(id: 'b1', courseId: 'B'),
          card(id: 'b2', courseId: 'B'),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
        random: Random(42),
      );
      expect(queue.length, 4);
      final courses = queue.map((c) => c.courseId).toList();
      expect(courses.where((c) => c == 'A').length, 2);
      for (var i = 1; i < courses.length; i++) {
        expect(courses[i], isNot(courses[i - 1]),
            reason: 'courses must alternate within a same-priority tie');
      }
    });
  });

  group('rule 6 — one review per card per day (BR-ZBJ99Z)', () {
    test('card already reviewed today is excluded even once it comes due', () {
      // FSRS learning steps reschedule an "Again" card ~1 minute out. Without
      // day-scoping it pops straight back onto the dashboard, which reads as
      // "I finished practice and it is still there" — and made two devices
      // disagree purely on when each last recomputed its queue.
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(
            id: 'learning-again',
            state: 1,
            reps: 1,
            dueDate: now.subtract(const Duration(seconds: 10)),
            lastReview: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue, isEmpty);
    });

    test('card reviewed on a previous day is still eligible', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(
            id: 'yesterday',
            state: 2,
            reps: 1,
            dueDate: now.subtract(const Duration(hours: 2)),
            lastReview: now.subtract(const Duration(days: 1)),
          ),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue.map((c) => c.id), ['yesterday']);
    });

    test('unseen card is unaffected (no lastReview)', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [card(id: 'new')],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue.map((c) => c.id), ['new']);
    });

    test('a new card seeded and reviewed today does not return the same day', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(
            id: 'seeded-then-reviewed',
            state: 0,
            reps: 1,
            lastReview: now.subtract(const Duration(minutes: 5)),
          ),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue, isEmpty);
    });
  });

  group('rule 0 — practice scope (BR-K4KHJZ)', () {
    test('empty filter keeps every card', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [card(id: 'a', courseId: 'A'), card(id: 'b', courseId: 'B')],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
      );
      expect(queue.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('a selected subject keeps only its cards', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [card(id: 'a', courseId: 'A'), card(id: 'b', courseId: 'B')],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
        filter: const PracticeFilter(courseIds: {'A'}),
      );
      expect(queue.map((c) => c.id), ['a']);
    });

    test('a selected area keeps only that lesson', () {
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(id: 'l1', courseId: 'A', lessonId: 'L1'),
          card(id: 'l2', courseId: 'A', lessonId: 'L2'),
        ],
        dailyNewLimit: 20,
        dailyReviewLimit: 100,
        filter: const PracticeFilter(lessonKeys: {'A|L2'}),
      );
      expect(queue.map((c) => c.id), ['l2']);
    });

    test('cards without a lesson are selectable through the empty lesson id',
        () {
      final cards = [
        card(id: 'bookmark', courseId: 'A', lessonId: ''),
        card(id: 'lesson', courseId: 'A', lessonId: 'L1'),
      ];
      expect(
        QueueBuilder.buildQueue(
          allCards: cards,
          dailyNewLimit: 20,
          dailyReviewLimit: 100,
          filter: const PracticeFilter(lessonKeys: {'A|'}),
        ).map((c) => c.id),
        ['bookmark'],
      );
    });

    test('the scope applies before the daily new-card limit', () {
      // The whole point of filtering inside the builder: a student who picked
      // course B must get B's full daily allowance, not the leftovers after
      // A's cards ate the cap.
      final queue = QueueBuilder.buildQueue(
        allCards: [
          card(id: 'a1', courseId: 'A', weight: 9),
          card(id: 'a2', courseId: 'A', weight: 9),
          card(id: 'b1', courseId: 'B', weight: 1),
          card(id: 'b2', courseId: 'B', weight: 1),
        ],
        dailyNewLimit: 2,
        dailyReviewLimit: 100,
        filter: const PracticeFilter(courseIds: {'B'}),
      );
      expect(queue.map((c) => c.id).toSet(), {'b1', 'b2'});
    });
  });

  // Rule 5 (skip_condition) is evaluated when cards are resolved to playable
  // blocks — the expression needs the block's GPF vector and the student's
  // ELO profile, which the pure QueueBuilder doesn't see. Covered by
  // skip_condition_evaluator_test.dart.

  // ── Bonus set (BR-A6HU52) ────────────────────────────────────────────────
  // A student who has cleared everything due today gets an empty daily queue
  // by design. buildBonusQueue is the second-choice pool offered instead of
  // "nothing to practise": future cards first (soonest, wrong ones first),
  // already-practised cards after that.
  group('bonus queue', () {
    test('today\'s cleared deck still yields a bonus set', () {
      final cards = [
        card(
          id: 'done',
          state: 2,
          reps: 3,
          dueDate: now.add(const Duration(days: 4)),
          lastReview: now,
        ),
      ];

      // The regression itself: the daily queue is empty, the bonus one is not.
      expect(
        QueueBuilder.buildQueue(
          allCards: cards,
          dailyNewLimit: 20,
          dailyReviewLimit: 100,
        ),
        isEmpty,
      );
      expect(
        QueueBuilder.buildBonusQueue(allCards: cards).map((c) => c.id),
        ['done'],
      );
    });

    test('future cards come first, soonest due first', () {
      final queue = QueueBuilder.buildBonusQueue(
        allCards: [
          card(
            id: 'far',
            state: 2,
            reps: 2,
            dueDate: now.add(const Duration(days: 9)),
          ),
          card(
            id: 'near',
            state: 2,
            reps: 2,
            dueDate: now.add(const Duration(days: 2)),
          ),
        ],
      );
      expect(queue.map((c) => c.id), ['near', 'far']);
    });

    test('within the same due day, previously-wrong cards come first', () {
      final due = now.add(const Duration(days: 3));
      final queue = QueueBuilder.buildBonusQueue(
        allCards: [
          card(id: 'clean', state: 2, reps: 4, dueDate: due),
          // state 3 = relearning: the last answer was "Again".
          card(id: 'relearning', state: 3, reps: 4, dueDate: due),
        ],
      );
      expect(queue.first.id, 'relearning');
    });

    test('already-practised cards rank below anything scheduled ahead', () {
      final queue = QueueBuilder.buildBonusQueue(
        allCards: [
          card(
            id: 'practised',
            state: 2,
            reps: 5,
            dueDate: now.subtract(const Duration(days: 1)),
            lastReview: now,
          ),
          card(
            id: 'ahead',
            state: 2,
            reps: 2,
            dueDate: now.add(const Duration(days: 6)),
          ),
        ],
      );
      expect(queue.map((c) => c.id), ['ahead', 'practised']);
    });

    test('with nothing scheduled ahead, practised cards are offered again', () {
      final queue = QueueBuilder.buildBonusQueue(
        allCards: [
          card(
            id: 'recent',
            state: 2,
            reps: 5,
            dueDate: now.subtract(const Duration(days: 1)),
            lastReview: now,
          ),
          card(
            id: 'stale',
            state: 2,
            reps: 5,
            dueDate: now.subtract(const Duration(days: 1)),
            lastReview: now.subtract(const Duration(hours: 6)),
          ),
        ],
      );
      // Least recently practised first.
      expect(queue.map((c) => c.id), ['stale', 'recent']);
    });

    test('cards still due today outrank both — the daily caps hid them', () {
      final queue = QueueBuilder.buildBonusQueue(
        allCards: [
          card(
            id: 'ahead',
            state: 2,
            reps: 2,
            dueDate: now.add(const Duration(days: 1)),
          ),
          card(
            id: 'still-due',
            state: 2,
            reps: 2,
            dueDate: now.subtract(const Duration(days: 1)),
          ),
        ],
      );
      expect(queue.first.id, 'still-due');
    });

    test('inactive cards and the chosen scope still apply', () {
      final queue = QueueBuilder.buildBonusQueue(
        allCards: [
          card(id: 'off', courseId: 'A', isActive: false, lastReview: now),
          card(id: 'other', courseId: 'B', lastReview: now),
          card(id: 'wanted', courseId: 'A', lastReview: now),
        ],
        filter: const PracticeFilter(courseIds: {'A'}),
      );
      expect(queue.map((c) => c.id), ['wanted']);
    });

    test('the bonus set is capped', () {
      final queue = QueueBuilder.buildBonusQueue(
        allCards: [
          for (var i = 0; i < 30; i++) card(id: 'c$i', lastReview: now),
        ],
        limit: 3,
      );
      expect(queue, hasLength(3));
    });
  });
}
