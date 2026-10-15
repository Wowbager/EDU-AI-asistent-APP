// Practice card weight pipeline + queue tie-breaking.
//
// The admin block editor lets authors set a per-block FSRS `weight`
// (block.fsrs.weight in the course JSON), which drives queue priority per the
// FSRS spec (§7: sort by weight, then due date). Until now the app dropped the
// value on the floor: FsrsParameters didn't parse `weight` and
// createCardFromBlock never wrote it, so every card fell back to the DB
// default (5.0) and the queue degenerated to insertion order — the "practice
// is always in the same order" complaint.
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/practice/queue_builder.dart';
import 'package:eduai/data/repositories/practice_repository.dart';
import 'package:eduai/models/block_model.dart';

void main() {
  group('FsrsParameters.fromJson', () {
    test('parses weight from block JSON', () {
      final fsrs = FsrsParameters.fromJson(const {'weight': 7.5});
      expect(fsrs.weight, 7.5);
    });

    test('weight is null when absent so callers can apply the default', () {
      final fsrs = FsrsParameters.fromJson(const {'stability': 2.5});
      expect(fsrs.weight, isNull);
    });
  });

  group('PracticeRepository.createCardFromBlock', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    ContentBlock blockWith({required String id, FsrsParameters? fsrs}) {
      return ContentBlock(
        blockId: id,
        type: BlockType.display,
        fsrs: fsrs,
        steps: const [],
      );
    }

    test('seeds card weight from block.fsrs.weight', () async {
      final repo = PracticeRepository(db: db);
      final card = await repo.createCardFromBlock(
        userId: 'u1',
        courseId: 'c1',
        lessonId: 'l1',
        block: blockWith(id: 'b1', fsrs: const FsrsParameters(weight: 8.0)),
        sourceType: 'lesson',
      );
      expect(card!.weight, 8.0);
    });

    test('defaults card weight to 5.0 when block has no fsrs data', () async {
      final repo = PracticeRepository(db: db);
      final card = await repo.createCardFromBlock(
        userId: 'u1',
        courseId: 'c1',
        lessonId: 'l1',
        block: blockWith(id: 'b2'),
        sourceType: 'lesson',
      );
      expect(card!.weight, 5.0);
    });
  });

  group('QueueBuilder.buildQueue', () {
    PracticeCardsTableData card({
      required String id,
      required String courseId,
      double weight = 5.0,
      int state = 0,
      DateTime? dueDate,
    }) {
      final now = DateTime.now();
      return PracticeCardsTableData(
        id: id,
        userId: 'u1',
        courseId: courseId,
        lessonId: 'l1',
        blockId: 'block-$id',
        sourceType: 'lesson',
        state: state,
        dueDate: dueDate ?? now.subtract(const Duration(hours: 1)),
        stability: 0,
        difficulty: 0,
        reps: state == 0 ? 0 : 1,
        lapses: 0,
        scheduledDays: 0,
        elapsedDays: 0,
        lastReview: null,
        weight: weight,
        avgTimeSec: 10,
        skipCondition: null,
        isActive: true,
        syncStatus: 0,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('higher-weight cards come first', () {
      final cards = [
        card(id: 'low', courseId: 'c1', weight: 2.0),
        card(id: 'high', courseId: 'c1', weight: 9.0),
        card(id: 'mid', courseId: 'c1', weight: 5.0),
      ];
      final queue = QueueBuilder.buildQueue(
        allCards: cards,
        dailyNewLimit: 10,
        dailyReviewLimit: 50,
        random: Random(1),
      );
      expect(queue.map((c) => c.id).toList(), ['high', 'mid', 'low']);
    });

    test('equal-weight ties are shuffled, not stuck in insertion order', () {
      final cards = [
        for (var i = 0; i < 12; i++) card(id: 'card-$i', courseId: 'c1'),
      ];
      final orders = <String>{};
      for (var seed = 0; seed < 10; seed++) {
        final queue = QueueBuilder.buildQueue(
          allCards: cards,
          dailyNewLimit: 20,
          dailyReviewLimit: 50,
          random: Random(seed),
        );
        orders.add(queue.map((c) => c.id).join(','));
      }
      expect(orders.length, greaterThan(1),
          reason: 'same input must not always produce the same order');
    });

    test('overdue cards due the same day are shuffled despite ms-precision '
        'dueDate differences', () {
      final base = DateTime.now().subtract(const Duration(days: 1));
      final cards = [
        for (var i = 0; i < 12; i++)
          card(
            id: 'card-$i',
            courseId: 'c1',
            state: 2,
            dueDate: base.add(Duration(milliseconds: i)),
          ),
      ];
      final orders = <String>{};
      for (var seed = 0; seed < 10; seed++) {
        final queue = QueueBuilder.buildQueue(
          allCards: cards,
          dailyNewLimit: 20,
          dailyReviewLimit: 50,
          random: Random(seed),
        );
        orders.add(queue.map((c) => c.id).join(','));
      }
      expect(orders.length, greaterThan(1),
          reason: 'same-day overdue ties must not be ordered by creation ms');
    });

    test('older overdue days still come before newer days', () {
      final now = DateTime.now();
      final cards = [
        card(
          id: 'yesterday',
          courseId: 'c1',
          state: 2,
          dueDate: now.subtract(const Duration(days: 1)),
        ),
        card(
          id: 'week-old',
          courseId: 'c1',
          state: 2,
          dueDate: now.subtract(const Duration(days: 7)),
        ),
      ];
      for (var seed = 0; seed < 5; seed++) {
        final queue = QueueBuilder.buildQueue(
          allCards: cards,
          dailyNewLimit: 20,
          dailyReviewLimit: 50,
          random: Random(seed),
        );
        expect(queue.map((c) => c.id).toList(), ['week-old', 'yesterday']);
      }
    });

    test('same seed reproduces the same order (determinism for resume)', () {
      final cards = [
        for (var i = 0; i < 12; i++) card(id: 'card-$i', courseId: 'c1'),
      ];
      String run() => QueueBuilder.buildQueue(
            allCards: cards,
            dailyNewLimit: 20,
            dailyReviewLimit: 50,
            random: Random(42),
          ).map((c) => c.id).join(',');
      expect(run(), run());
    });
  });
}
