// Regression test for BR-ZBJ99Z.
//
// A bookmark row is keyed by whatever course id created it: the local Drift
// row id (`local-<uuid>`) when it was made in-app, or the server course code
// (`A34-Funkce_c1_v3`) when it arrived from the server. Those row ids are
// generated per device, so a bookmark synced from another device can never
// match this device's local id — the course looked bookmark-free and its
// "Cvičení" button disappeared.
//
// The notifier must therefore match a course under either scheme, and
// hydration must resolve bookmarks stored under the alternate one.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/bookmark_provider.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/models/block_model.dart';

const _localCourseId = 'local-1111';
const _courseCode = 'A34-Funkce_c1_v3';
const _userId = 'user-1';

Future<void> _addUser(AppDatabase db) => db.upsertUser(const UsersTableCompanion(
      id: Value(_userId),
      name: Value('Tester'),
      email: Value(''),
      isActive: Value(true),
    ));

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    await _addUser(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a bookmark stored under the server course code is found via the local '
      'course id', () async {
    // Exactly what _pullBookmarkUpdates writes for a bookmark another device
    // created: keyed by the server course code.
    await db.addBookmark(BookmarksTableCompanion(
      id: const Value('bm-1'),
      userId: const Value(_userId),
      courseId: const Value(_courseCode),
      blockId: const Value('block-a'),
      lessonId: const Value('lesson-1'),
    ));

    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.initForUser(_userId);

    // The local row id alone misses it — that was the bug.
    expect(notifier.hasBookmarksForCourse(_localCourseId), isFalse);
    // With the course code as an alias it resolves.
    expect(
      notifier.hasBookmarksForCourse(_localCourseId, alsoMatch: [_courseCode]),
      isTrue,
    );
  });

  test('hydrateForCourse resolves blocks for the aliased course id', () async {
    await db.addBookmark(BookmarksTableCompanion(
      id: const Value('bm-1'),
      userId: const Value(_userId),
      courseId: const Value(_courseCode),
      blockId: const Value('block-a'),
      lessonId: const Value('lesson-1'),
    ));

    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.initForUser(_userId);

    final block = ContentBlock(
      blockId: 'block-a',
      type: BlockType.question,
      content: 'Kolik je 2+2?',
    );

    notifier.hydrateForCourse(_localCourseId, [block],
        alsoMatch: [_courseCode]);

    final blocks = notifier
        .getBookmarksForCourse(_localCourseId, alsoMatch: [_courseCode]);
    expect(blocks.map((b) => b.blockId), ['block-a']);
  });
}
