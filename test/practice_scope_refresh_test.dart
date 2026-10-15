// Regression test for BR-27AEMT.
//
// The practice picker ("Co chceš procvičovat") is built from the student's
// whole deck by practiceScopeProvider — a plain, cached FutureProvider that
// reads the card rows itself. Every place that writes cards refreshed the
// queue and the dashboard count, but nothing refreshed the scope, so it was
// computed once per app session. A student who opened Procvičování while
// their cards sat in one lesson (picker hidden: nothing to choose between)
// kept a hidden picker after bookmarking in other lessons and courses, even
// with the queue showing all of the new cards.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/practice/practice_scope.dart';
import 'package:eduai/core/providers/bookmark_provider.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/practice_providers.dart';
import 'package:eduai/data/repositories/practice_repository.dart';
import 'package:eduai/models/block_model.dart';

const _userId = 'user-1';
const _courseId = 'course-1';

ContentBlock _block(String id) =>
    ContentBlock(blockId: id, type: BlockType.question, content: '?');

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);

    await db.upsertUser(const UsersTableCompanion(
      id: Value(_userId),
      name: Value('Zvědavý orel'),
      email: Value(''),
      isActive: Value(true),
    ));
    await db.into(db.coursesTable).insert(CoursesTableCompanion(
          id: const Value(_courseId),
          courseId: const Value('S1_Statistika_c1'),
          name: const Value('Statistika pro ZŠ'),
          data: Value(jsonEncode({
            'name': 'Statistika pro ZŠ',
            'lessons': [
              {'id': 'L1', 'name': 'Data a základní pojmy'},
              {'id': 'L2', 'name': 'Zobrazení dat'},
            ],
          })),
        ));

    // The deck the student starts from: one card, one lesson.
    await PracticeRepository(db: db).createCardFromBlock(
      userId: _userId,
      courseId: _courseId,
      lessonId: 'L1',
      block: _block('b1'),
      sourceType: 'bookmark',
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  int areaCount(List<PracticeSubject> scope) =>
      scope.fold(0, (sum, s) => sum + s.areas.length);

  test('a bookmark in another lesson reaches the practice picker', () async {
    // The practice page is open (or was opened once) — the scope is cached.
    final sub = container.listen(practiceScopeProvider, (_, _) {});
    addTearDown(sub.close);
    expect(areaCount(await container.read(practiceScopeProvider.future)), 1,
        reason: 'precondition: a single area, so the picker hides');

    // Bookmarking writes the card in the background; wait for the row.
    container
        .read(bookmarkProvider.notifier)
        .addBookmark(_courseId, _block('b2'), lessonId: 'L2');
    for (var i = 0; i < 100; i++) {
      if (await db.getPracticeCardByBlock(_userId, 'b2') != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(Duration.zero);

    final scope = await container.read(practiceScopeProvider.future);
    expect(areaCount(scope), 2,
        reason: 'the new lesson must show up as a second area, which is what '
            'makes the picker appear');
    expect(scope.single.areas.map((a) => a.lessonId), ['L1', 'L2']);
  });
}
