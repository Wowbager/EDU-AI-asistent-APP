// BR-VUESR3: after the 15-minute shared-device idle limit the app wiped the
// session (the countdown banner and the courses both vanished) but stayed on
// the Courses screen instead of returning to login — the previous student's
// signed-in shell, left on a shared classroom machine.
//
// LogoutCoordinator.teardown() flushes over the network and wipes the whole
// local database, and the "now show login" step used to be a plain
// continuation after it (`await teardown(); <navigate>`). A step that stalls
// therefore loses the navigation for good: by then teardown has cleared
// `shared_device`, so InactivityWatcher._check() returns at its first guard
// and never retries.
//
// These tests pin the guarantee that the navigation request survives a
// teardown that never finishes and one that throws. root_navigator's
// _forceLogoutToAuth applies the same try/timeout/finally shape against the
// same deadline; AuthWrapper itself is too heavy to pump in a widget test
// (see test/widgets/root_navigator_minor_test.dart's header).
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';

/// In-memory token, so tests never touch the real FlutterSecureStorage
/// platform channel (unavailable in `flutter test`).
class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs});

  @override
  String? get token => null;

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> clearToken() async {}

  @override
  Future<void> load() async {}
}

/// Never authenticated, so teardown's best-effort flush and revoke are skipped
/// and the test is isolated to the local-wipe half of the sequence.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.tokens);

  @override
  bool get isAuthenticated => false;
}

/// Stands in for the local wipe. [stall] never completes; [fail] throws.
class _WipeControlDatabase extends AppDatabase {
  _WipeControlDatabase() : super.forTesting(NativeDatabase.memory());

  bool stall = false;
  bool fail = false;
  bool wipeStarted = false;

  @override
  Future<void> clearAllData() async {
    wipeStarted = true;
    if (stall) return Completer<void>().future;
    if (fail) throw StateError('wipe failed');
    return super.clearAllData();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _WipeControlDatabase db;
  late ProviderContainer container;

  const deadline = Duration(milliseconds: 50);

  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = _FakeAuthTokenStorage(prefs: prefs);

    return ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      authTokenStorageProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(_FakeApiClient(tokens)),
      logoutCoordinatorProvider.overrideWith(
        (ref) => LogoutCoordinator(ref, navigationDeadline: deadline),
      ),
    ]);
  }

  setUp(() {
    db = _WipeControlDatabase();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a wipe that never finishes still sends the user to login', () async {
    container = await buildContainer();
    db.stall = true;

    await container
        .read(logoutCoordinatorProvider)
        .forceLogoutToLogin()
        .timeout(const Duration(seconds: 5));

    expect(db.wipeStarted, isTrue,
        reason: 'the local data is already being wiped — this is exactly the '
            'state the user must not be left inside the app in');
    expect(
      container.read(forceAuthScreenProvider),
      1,
      reason: 'the login screen must be requested even though teardown never '
          'returned (BR-VUESR3)',
    );
  });

  test('a wipe that throws still sends the user to login', () async {
    container = await buildContainer();
    db.fail = true;

    await container.read(logoutCoordinatorProvider).forceLogoutToLogin();

    expect(container.read(forceAuthScreenProvider), 1);
  });

  test('a healthy teardown requests login exactly once', () async {
    container = await buildContainer();

    await container.read(logoutCoordinatorProvider).forceLogoutToLogin();

    expect(db.wipeStarted, isTrue);
    expect(container.read(forceAuthScreenProvider), 1);
  });
}
