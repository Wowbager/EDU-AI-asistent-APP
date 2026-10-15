// Regression test for the FSRS review-persist bug (stage: "practice
// neukládá postup").
//
// PracticeService.reviewCard persists the rescheduled card through
// PracticeRepository.updateCard(FsrsBridge.fromFsrsCard(...)). The companion
// built by fromFsrsCard carries only the FSRS fields, and updateCard used to
// route it through insertOnConflictUpdate — drift validates that as an INSERT,
// the required identity columns (userId, courseId, …) are absent, and it
// throws InvalidDataException before touching the database. The exception was
// swallowed by silentLog in quiz_page, so every review was a silent no-op,
// locally and (because nothing was marked pending) on the server too.
//
// Run:
//   flutter test test/practice_review_persist_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/practice/fsrs_bridge.dart';
import 'package:eduai/data/repositories/practice_repository.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

void main() {
  late AppDatabase db;
  late PracticeRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PracticeRepository(db: db);
  });

  tearDown(() async => db.close());

  test('review reschedules the card and marks it pending sync', () async {
    // Seed a full card row (what bookmark/seeding creates).
    final now = DateTime.now();
    await db.upsertPracticeCard(PracticeCardsTableCompanion.insert(
      id: 'card-1',
      userId: 'u1',
      courseId: 'C1',
      lessonId: 'L1',
      blockId: 'B1',
      sourceType: 'bookmark',
    ));
    // Simulate the state after a successful server push: synced.
    await db.markPracticeCardSynced(
      'card-1',
      (await db.getPracticeCardByBlock('u1', 'B1'))!.updatedAt,
      serverId: '42',
    );

    final before = (await db.getPracticeCardByBlock('u1', 'B1'))!;
    expect(before.reps, 0);

    // Review it the way PracticeService does: scheduler → fromFsrsCard →
    // updateCard.
    final scheduler = FsrsBridge.buildScheduler(null);
    final result = scheduler.reviewCard(
      FsrsBridge.toFsrsCard(before),
      fsrs.Rating.easy,
      reviewDateTime: now.toUtc(),
    );
    await repo.updateCard(FsrsBridge.fromFsrsCard(
      result.card,
      before.id,
      previousReps: before.reps,
      previousLapses: before.lapses,
      rating: 4,
    ));

    final after = (await db.getPracticeCardByBlock('u1', 'B1'))!;
    expect(after.reps, 1, reason: 'review must increment reps');
    expect(after.dueDate.isAfter(now), isTrue,
        reason: 'reviewed card must be rescheduled into the future');
    expect(after.syncStatus, 1,
        reason: 'reviewed card must be marked pending so sync pushes it');
    // Identity columns must survive the update untouched.
    expect(after.userId, 'u1');
    expect(after.courseId, 'C1');
    expect(after.blockId, 'B1');
  });

  test('step-level bookmark card is found via the base block id', () async {
    // Step bookmarks store blockId as "base:step"; the practice player
    // resolves the card back to the BASE block, so the review lookup must
    // widen to the step variants or the review is silently dropped.
    await db.upsertPracticeCard(PracticeCardsTableCompanion.insert(
      id: 'card-step',
      userId: 'u1',
      courseId: 'C1',
      lessonId: 'L1',
      blockId: 'JYS5U63S3U:s1',
      sourceType: 'bookmark',
    ));

    expect(await repo.getCardByBlock('u1', 'JYS5U63S3U'), isNull,
        reason: 'exact lookup misses the step-suffixed card (the old bug)');

    final found = await repo.getCardForResolvedBlock('u1', 'JYS5U63S3U');
    expect(found, isNotNull);
    expect(found!.id, 'card-step');

    // Exact ids keep working through the same helper.
    final exact = await repo.getCardForResolvedBlock('u1', 'JYS5U63S3U:s1');
    expect(exact!.id, 'card-step');
  });

  test('base-id card is found when the player resolves a step block', () async {
    // Opposite direction: the bookmark stored the BASE block id while the V2
    // practice player emits step blocks ("base:sN").
    await db.upsertPracticeCard(PracticeCardsTableCompanion.insert(
      id: 'card-base',
      userId: 'u1',
      courseId: 'C1',
      lessonId: 'L1',
      blockId: 'S1.1-Statistika_01',
      sourceType: 'bookmark',
    ));

    final found =
        await repo.getCardForResolvedBlock('u1', 'S1.1-Statistika_01:s1');
    expect(found, isNotNull);
    expect(found!.id, 'card-base');
  });
}
