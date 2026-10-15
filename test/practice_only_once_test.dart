// BR-E495XK — courses flagged `only_once` (tests) must never feed practice.
//
// The flag is course-level and already drives re-entry blocking and the course
// listings. What was missing is the practice side: blocks of a test could still
// be seeded as FSRS cards (lesson completion, sync seeding, auto-bookmark on a
// wrong answer) and then come back in the daily queue, leaking the test.
//
// Two layers are covered here:
//   * the offer — `getPracticeableCards` drops cards of an only_once course,
//     without deleting them (existing queues are not cleaned, by design);
//   * the source — no new card is created for such a course at all.
//
// The flag lives in a `courses.only_once` column derived on write, so the
// filter is a two-column lookup rather than a decode of every course JSON.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/data/datasources/local/course_local_datasource.dart';
import 'package:eduai/data/repositories/practice_repository.dart';
import 'package:eduai/data/repositories/user_course_repository.dart';
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/lesson_detail/mentor_sheet.dart';

/// The bundled fixture with [count] lesson-referenced blocks flagged
/// default_practice, plus any extra top-level [flags].
Map<String, dynamic> _courseData({int count = 3, Map<String, dynamic> flags = const {}}) {
  final data = jsonDecode(
    File('assets/courses/EDU_ONBOARDING_APP.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final definedIds = {
    for (final b in (data['blocks'] as List)) (b as Map)['block_id'] as String,
  };
  final referenced = <String>[];
  for (final l in (data['lessons'] as List)) {
    for (final ref in ((l as Map)['blocks'] as List? ?? const [])) {
      final bid = (ref as Map)['block_id'] as String?;
      if (bid != null && definedIds.contains(bid) && !referenced.contains(bid)) {
        referenced.add(bid);
      }
    }
  }
  final flagged = referenced.take(count).toSet();
  for (final b in (data['blocks'] as List)) {
    if (flagged.contains((b as Map)['block_id'])) {
      b['default_practice'] = true;
    }
  }
  return {...data, ...flags};
}

Future<void> _insertCourse(
  AppDatabase db, {
  required String id,
  required String courseId,
  required bool onlyOnce,
}) {
  return db.upsertCourse(CoursesTableCompanion(
    id: Value(id),
    courseId: Value(courseId),
    name: Value('Course $id'),
    data: Value(jsonEncode({'course_id': courseId, 'only_once': onlyOnce})),
  ));
}

Future<void> _insertCard(
  AppDatabase db, {
  required String id,
  required String userId,
  required String courseId,
}) {
  return db.upsertPracticeCard(PracticeCardsTableCompanion(
    id: Value(id),
    userId: Value(userId),
    courseId: Value(courseId),
    lessonId: const Value('L1'),
    blockId: Value('block-$id'),
    sourceType: const Value('lesson'),
  ));
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('upsertCourse derives the only_once column from the course JSON',
      () async {
    await _insertCourse(db, id: 'c-test', courseId: 'TEST_1', onlyOnce: true);
    await _insertCourse(db, id: 'c-plain', courseId: 'PLAIN_1', onlyOnce: false);

    expect((await db.getCourseById('c-test'))!.onlyOnce, isTrue);
    expect((await db.getCourseById('c-plain'))!.onlyOnce, isFalse);
    expect(await db.getOnlyOnceCourseKeys(), {'c-test', 'TEST_1'});
  });

  test(
      'getPracticeableCards drops cards of an only_once course under either '
      'course id spelling, and leaves the rows in place', () async {
    const userId = 'user-1';
    await _insertCourse(db, id: 'c-test', courseId: 'TEST_1', onlyOnce: true);
    await _insertCourse(db, id: 'c-plain', courseId: 'PLAIN_1', onlyOnce: false);

    // A card's courseId may be the local row id or the course_id field.
    await _insertCard(db, id: 'card-local', userId: userId, courseId: 'c-test');
    await _insertCard(db, id: 'card-field', userId: userId, courseId: 'TEST_1');
    await _insertCard(db, id: 'card-ok', userId: userId, courseId: 'c-plain');

    final repo = PracticeRepository(db: db);

    expect((await repo.getActiveCards(userId)).length, 3,
        reason: 'existing queues are not cleaned — only the offer is filtered');
    expect(
      (await repo.getPracticeableCards(userId)).map((c) => c.id),
      ['card-ok'],
    );
  });

  test('createCardFromBlock seeds nothing for a block of an only_once course',
      () async {
    const userId = 'user-1';
    final data = _courseData(flags: {'only_once': true});
    await db.upsertCourse(CoursesTableCompanion(
      id: const Value('c-test'),
      courseId: const Value('TEST_1'),
      name: const Value('Test'),
      data: Value(jsonEncode(data)),
    ));

    final course = Course.fromJsonData(id: 'c-test', data: data);
    final block = course.getDefaultPracticeBlocks().first;
    final repo = PracticeRepository(db: db);

    // The auto-bookmark path (wrong answer inside the test) must not seed.
    final card = await repo.createCardFromBlock(
      userId: userId,
      courseId: 'c-test',
      lessonId: 'L1',
      block: block,
      sourceType: 'bookmark',
    );

    expect(card, null);
    expect(await db.getActivePracticeCards(userId), isEmpty);
  });

  test(
      'flipping only_once in admin reaches a course the student already '
      'downloaded', () async {
    final downloaded = _courseData();
    downloaded['only_once'] = false;

    final source = CourseLocalDataSource(db);
    await source.upsertFromServer(
      serverId: 1,
      courseId: 'TEST_1',
      name: 'Test',
      version: 1,
      status: 'published',
      language: 'cs',
      data: downloaded,
      serverUpdatedAt: DateTime.utc(2026, 1, 1),
      existingLocalId: 'c-test',
    );
    expect((await db.getCourseById('c-test'))!.onlyOnce, isFalse);

    // The listing sync carries metadata only — no blocks — so the stored
    // content (with the stale flag) is preserved. The flag itself is a course
    // setting and must still come through.
    await source.upsertFromServer(
      serverId: 1,
      courseId: 'TEST_1',
      name: 'Test',
      version: 2,
      status: 'published',
      language: 'cs',
      data: {'course_id': 'TEST_1', 'only_once': true},
      serverUpdatedAt: DateTime.utc(2026, 1, 2),
      existingLocalId: 'c-test',
    );

    final stored = (await db.getCourseById('c-test'))!;
    expect(stored.onlyOnce, isTrue);
    expect(
      (jsonDecode(stored.data) as Map<String, dynamic>)['blocks'],
      isNotEmpty,
      reason: 'downloaded content must survive a metadata-only sync',
    );
  });

  test('seedCardsFromCourse creates nothing for an only_once course', () async {
    const userId = 'user-1';
    final data = _courseData(flags: {'only_once': true});
    final course = Course.fromJsonData(id: 'c-test', data: data);
    expect(course.onlyOnce, isTrue);
    expect(course.getDefaultPracticeBlocks().length, 3);

    final repo = PracticeRepository(db: db);
    expect(await repo.seedCardsFromCourse(userId: userId, course: course), 0);
    expect(await db.getActivePracticeCards(userId), isEmpty);
  });

  test('UserCourse.isOnlyOnce reads the flag the course lists filter on',
      () async {
    await _insertCourse(db, id: 'c-test', courseId: 'TEST_1', onlyOnce: true);
    await _insertCourse(db, id: 'c-plain', courseId: 'PLAIN_1', onlyOnce: false);
    await db.upsertUserCourse(const UserCoursesTableCompanion(
      id: Value('uc-test'),
      userId: Value('user-1'),
      courseId: Value('c-test'),
    ));
    await db.upsertUserCourse(const UserCoursesTableCompanion(
      id: Value('uc-plain'),
      userId: Value('user-1'),
      courseId: Value('c-plain'),
    ));

    final byCourse = <String, UserCourse>{};
    for (final row in await db.getUserCourses('user-1')) {
      byCourse[row.courseId] = UserCourse.fromTableData(
        row,
        course: await db.getCourseById(row.courseId),
      );
    }

    expect(byCourse['c-test']!.isOnlyOnce, isTrue);
    expect(byCourse['c-plain']!.isOnlyOnce, isFalse);
  });

  test('the hint sheet stops offering practice inside an only_once course', () {
    final block = ContentBlock(blockId: 'b1', type: BlockType.question);
    final bookmarked = ContentBlock(
        blockId: 'b2', type: BlockType.question, isBookmarked: true);
    final testCourse = Course.fromJsonData(id: 'c1', data: {'only_once': true});
    final plain = Course.fromJsonData(id: 'c2', data: {});

    // Already in practice — the pre-existing rule (BR-FEQ97Q).
    expect(practiceOptionUnavailable(block: bookmarked, course: plain), isTrue);
    // A test never feeds practice, so the option would be a silent no-op:
    // the sheet would close and the snackbar would claim it was added.
    expect(practiceOptionUnavailable(block: block, course: testCourse), isTrue);
    expect(practiceOptionUnavailable(block: block, course: plain), isFalse);
  });
}
