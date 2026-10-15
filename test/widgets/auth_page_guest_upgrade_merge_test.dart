// BR-35W2HV: a guest who signs in with their student code from inside their
// own session lost everything they had done as a guest — lessons, chats, XP.
//
// /api/resolve-code folds the guest's server-side data into the student
// account (absorbGuest), but skips that on a shared device, where the leftover
// guest is likely someone else (BR-ZDXP7C). "Shared device" is the login
// screen's default, so the guest-upgrade login practically never merged —
// and the app then wipes the local copy for the incoming student. The login
// screen MainScreen pushes for a guest now says so explicitly (`merge_guest`);
// the logged-out login screen still does not, so a stranger's leftover guest
// session keeps the BR-ZDXP7C protection there.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/services/guest_auth_service.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/core/widgets/code_input_field.dart';
import 'package:eduai/data/repositories/course_repository.dart';
import 'package:eduai/pages/auth_page.dart';

/// The guest's session token is already in place, as it is for any guest who
/// reaches the login screen from inside the app.
class _GuestTokenStorage extends AuthTokenStorage {
  _GuestTokenStorage({required super.prefs});

  String? _token = 'guest-token';

  @override
  String? get token => _token;
  @override
  bool get isAuthenticated => _token != null;
  @override
  Future<void> load() async {}
  @override
  Future<void> setToken(String token) async => _token = token;
  @override
  Future<void> clearToken() async => _token = null;
}

/// Records what the login screen asked /api/resolve-code for. Answers "not
/// found" so the test stops at the request itself.
class _RecordingGuestAuth extends Fake implements GuestAuthService {
  final List<({bool sharedDevice, bool mergeGuest})> calls = [];

  @override
  Future<ResolveCodeResult?> resolveCode(
    String code, {
    bool sharedDevice = false,
    bool mergeGuest = false,
  }) async {
    calls.add((sharedDevice: sharedDevice, mergeGuest: mergeGuest));
    return null;
  }
}

/// No bundled/local course matches, so the code goes to the API.
class _NoLocalCourses extends Fake implements CourseRepository {
  @override
  Future<Course?> findCourseByCode(String code) async => null;
}

/// Nothing left to flush before the login.
class _IdleSync extends Fake implements SyncService {
  @override
  Future<bool> hasPendingChanges() async => false;
}

Future<_RecordingGuestAuth> _submitStudentCode(
  WidgetTester tester, {
  required bool guestUpgrade,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  // The test-only Ahem font overflows some fixed-width buttons. Cosmetic.
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);

  // No stored choice: the screen starts on its default, "shared device".
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final guestAuth = _RecordingGuestAuth();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authTokenStorageProvider
            .overrideWithValue(_GuestTokenStorage(prefs: prefs)),
        appDatabaseProvider.overrideWithValue(db),
        guestAuthServiceProvider.overrideWithValue(guestAuth),
        courseRepositoryProvider.overrideWithValue(_NoLocalCourses()),
        syncServiceProvider.overrideWithValue(_IdleSync()),
      ],
      child: MaterialApp(
        home: AuthPage(
          onEmailSubmit: (_) {},
          guestUpgrade: guestUpgrade,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));

  await tester.enterText(
    find.descendant(
      of: find.byType(CodeInputField),
      matching: find.byType(TextField),
    ),
    'AB12CD',
  );
  await tester.pumpAndSettle();

  return guestAuth;
}

void main() {
  testWidgets(
      'a guest signing in from their own session asks for their progress to '
      'be merged, even on the default shared-device setting', (tester) async {
    final guestAuth = await _submitStudentCode(tester, guestUpgrade: true);

    expect(guestAuth.calls, hasLength(1));
    expect(guestAuth.calls.single.sharedDevice, isTrue,
        reason: 'the session-mode default must stay untouched');
    expect(guestAuth.calls.single.mergeGuest, isTrue);
  });

  testWidgets(
      'the logged-out login screen does not ask for a merge — a leftover '
      'guest there may be someone else (BR-ZDXP7C)', (tester) async {
    final guestAuth = await _submitStudentCode(tester, guestUpgrade: false);

    expect(guestAuth.calls, hasLength(1));
    expect(guestAuth.calls.single.mergeGuest, isFalse);
  });
}
