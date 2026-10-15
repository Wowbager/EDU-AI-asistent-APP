// Regression test for BR-8FDF37 (reviewer follow-up on Task 16).
//
// Locking the name field on ProfileSetupPage stopped a minor typing a real
// name, but did nothing about the Continue button: _handleContinue still ran
// its full flow — create a brand-new local user (deactivating the minor's
// row as a side effect), migrate every local table onto that new id, THEN
// ask the server (which correctly 403s), and call onComplete() regardless —
// landing the app on a user the server never acknowledged while the minor's
// own local row and data sat orphaned under an id nothing points to anymore.
//
// This drives the real ProfileSetupPage with minorModeProvider forced true,
// taps Continue, and asserts the minor's original row is still the active
// user and their data is still keyed to it — the wipe-equivalent regression
// this task needed for the client side.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/pages/profile_setup_page.dart';

const _minorUserId = 'minor-1';
const _minorName = 'Stydlivý delfín';

Future<void> _seedMinorUserWithData(AppDatabase db) async {
  await db.createAndActivateUser(
    UsersTableCompanion(
      id: const Value(_minorUserId),
      email: const Value(''),
      name: const Value(_minorName),
      isEmailValidated: const Value(true),
      isActive: const Value(true),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );
  // Something concrete keyed to the minor's id, so a silent migration onto a
  // new orphan row would be caught here, not just an empty-table coincidence.
  await db.addBookmark(const BookmarksTableCompanion(
    id: Value('bm-1'),
    userId: Value(_minorUserId),
    courseId: Value('course-1'),
    blockId: Value('block-1'),
    lessonId: Value('lesson-1'),
  ));
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  testWidgets(
    'Continue on ProfileSetupPage does not touch a minor\'s local account',
    (tester) async {
      await _seedMinorUserWithData(db);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      var onCompleteCalled = false;

      // minorModeProvider must already read true by the time initState()
      // runs (not set afterwards) — ProfileSetupPage only pre-fills the
      // locked name field from the minor flag at construction time, and an
      // empty field would trip the unrelated "name required" check before
      // ever reaching the code this test is protecting against.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
            minorModeProvider.overrideWith((ref) => MinorModeNotifier()..state = true),
          ],
          child: MaterialApp(
            home: ProfileSetupPage(
              email: 'someone-else@example.com',
              onComplete: () => onCompleteCalled = true,
            ),
          ),
        ),
      );
      // Let the async name pre-fill (initState's getActiveUser().then(...))
      // land before interacting with the field.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The onboarding now has two steps (nickname + color profile, then the
      // avatar vibe); the commit that this test guards runs on the second
      // Continue.
      await tester.tap(find.text(AppStrings.actionContinue));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(AppStrings.actionContinue));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(onCompleteCalled, isFalse,
          reason: 'a minor must never be handed off to the main app from '
              'this screen — there is nothing legitimate for it to do here');

      final activeUser = await db.getActiveUser();
      expect(activeUser, isNotNull);
      expect(activeUser!.id, _minorUserId,
          reason: 'the minor\'s own row must still be the active user, not '
              'deactivated in favour of a freshly created orphan');
      expect(activeUser.name, _minorName,
          reason: 'the server-assigned pseudonym must be untouched');

      final bookmarks = await (db.select(db.bookmarksTable)
            ..where((b) => b.userId.equals(_minorUserId)))
          .get();
      expect(bookmarks, hasLength(1),
          reason: 'local data must still be keyed to the minor\'s real id, '
              'not migrated onto a new user Continue was never allowed to '
              'create');

      // Sanity check: no second user row was created and left active.
      final allUsers = await db.select(db.usersTable).get();
      expect(allUsers, hasLength(1),
          reason: 'no orphan local user should have been created at all');
    },
  );
}
