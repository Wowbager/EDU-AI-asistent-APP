// Integration coverage for decision 12 (docs/superpowers/plans/
// 2026-08-13-minor-consent-onboarding.md): everything else in this epic
// tests minorModeProvider and wipeLocalDataIfMinor in isolation
// (test/consent/minor_mode_test.dart) — nothing exercises the real sequence
// _checkExistingAuth() in root_navigator.dart runs: restore() before any
// network call, then branch on the /api/user response. That sequence is the
// path decision 12 says must not fail open.
//
// AuthWrapper itself is too heavy to pump in a widget test: its build()
// unconditionally wraps every state in InactivityWatcher, which starts a
// real Timer.periodic (and, via WorkTimeTracker, a second one) in initState.
// flutter_test refuses to end a test with a timer still pending, and
// InactivityWatcher.dispose() calling ref.read() during the framework's own
// forced tree teardown throws ("Cannot use ref after the widget was
// disposed") before it gets the chance to cancel it — an interaction between
// Riverpod's ConsumerStatefulElement and flutter_test's teardown that no
// amount of pumpWidget sequencing on the test side avoids, since dispose()
// only reaches the cancelling line if that ref.read() succeeds. That was the
// same shape of problem test/widgets/auth_page_to_consent_request_test.dart
// hit with AuthWrapper (see its header comment) — its answer was to
// reproduce the relevant sequence with the real, involved pieces rather than
// mount the real wrapper. This file follows the same precedent: _runBootSequence
// below mirrors _checkExistingAuth's post-"active user found" shape line for
// line, but calls the actual minorModeProvider, wipeLocalDataIfMinor and
// LogoutCoordinator — the parts decision 12 is actually about — instead of
// mounting AuthWrapper/InactivityWatcher.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';

/// Always reports the fixed [online] state — no real connectivity_plus
/// platform channel involved.
class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({required bool online}) : _online = online;
  final bool _online;

  @override
  Future<ConnectivityState> get currentState async =>
      _online ? ConnectivityState.wifi : ConnectivityState.offline;

  @override
  Future<bool> get isOnline async => _online;
}

/// In-memory token, so tests never touch the real FlutterSecureStorage
/// platform channel (unavailable in `flutter test`).
class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs, String? initialToken})
      : _fakeToken = initialToken;

  String? _fakeToken;

  @override
  String? get token => _fakeToken;

  @override
  bool get isAuthenticated => (_fakeToken ?? '').isNotEmpty;

  @override
  Future<void> setToken(String value) async => _fakeToken = value;

  @override
  Future<void> clearToken() async => _fakeToken = null;

  @override
  Future<void> load() async {}
}

/// Controls the /api/user response; every other path succeeds as a no-op so
/// LogoutCoordinator.teardown()'s best-effort flush/revoke calls don't throw.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.tokens);

  int userStatusCode = 200;
  Map<String, dynamic> userData = const {};

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    if (path == '/api/user') {
      if (userStatusCode == 200) {
        return ApiResult.success(userData as T, statusCode: 200);
      }
      return ApiResult.failure('unauthorized', statusCode: userStatusCode);
    }
    return ApiResult.failure('not mocked in test: $path', statusCode: 404);
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Duration? receiveTimeout,
  }) async {
    return ApiResult.success(<String, dynamic>{} as T, statusCode: 200);
  }
}

/// Mirrors AuthWrapper._checkExistingAuth's shape from "active user found"
/// onward (root_navigator.dart): restore() before any network call, then —
/// if online and authenticated — a 401/403 wipes local data via the real
/// wipeLocalDataIfMinor and LogoutCoordinator.teardown. The 200 branch isn't
/// reproduced; these tests don't exercise it.
Future<void> _runBootSequence(ProviderContainer container) async {
  final db = container.read(appDatabaseProvider);
  final apiClient = container.read(apiClientProvider);
  final connectivity = container.read(connectivityServiceProvider);

  await container.read(minorModeProvider.notifier).restore();

  final isOnline = await connectivity.isOnline;
  if (isOnline && apiClient.isAuthenticated) {
    final response = await apiClient.get('/api/user').timeout(
          const Duration(seconds: 10),
          onTimeout: () => ApiResult.failure('timeout'),
        );
    if (response.statusCode == 401 || response.statusCode == 403) {
      await wipeLocalDataIfMinor(
        isMinor: container.read(minorModeProvider),
        db: db,
      );
      await container.read(logoutCoordinatorProvider).teardown();
    }
  }
}

const _minorUserId = 'minor-1';

Future<void> _seedMinorUser(AppDatabase db, {required String name}) {
  return db.createAndActivateUser(
    UsersTableCompanion(
      id: const Value(_minorUserId),
      email: const Value(''), // minors never get a real email locally
      name: Value(name),
      isEmailValidated: const Value(true), // set at login, like a real minor
      isActive: const Value(true),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

void main() {
  // _FakeConnectivityService's superclass constructor subscribes to the
  // connectivity_plus EventChannel, which needs a Flutter test binding even
  // though these are plain (non-widget) tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProviderContainer buildContainer({
    required SharedPreferences prefs,
    required bool online,
    required int userStatusCode,
    String? authToken = 'device-token',
  }) {
    final tokens = _FakeAuthTokenStorage(prefs: prefs, initialToken: authToken);
    final connectivity = _FakeConnectivityService(online: online);
    final apiClient = _FakeApiClient(tokens)..userStatusCode = userStatusCode;

    return ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      authTokenStorageProvider.overrideWithValue(tokens),
      connectivityServiceProvider.overrideWithValue(connectivity),
      apiClientProvider.overrideWithValue(apiClient),
    ]);
  }

  test(
    'offline cold start restores is_minor before any network call and stays gated',
    () async {
      SharedPreferences.setMockInitialValues({'is_minor': true});
      final prefs = await SharedPreferences.getInstance();
      await _seedMinorUser(db, name: 'Stydlivý delfín');

      container = buildContainer(
        prefs: prefs,
        online: false,
        userStatusCode: 200, // unreachable while offline; asserts network is skipped
      );

      await _runBootSequence(container);

      expect(
        container.read(minorModeProvider),
        isTrue,
        reason: 'a known minor must stay gated on an offline cold start — '
            'the flag must never fail open',
      );
    },
  );

  test(
    '401 on a minor account wipes local data and clears the flag',
    () async {
      SharedPreferences.setMockInitialValues({'is_minor': true});
      final prefs = await SharedPreferences.getInstance();
      await _seedMinorUser(db, name: 'Stydlivý delfín');
      expect(await db.getActiveUser(), isNotNull, reason: 'sanity check');

      container = buildContainer(
        prefs: prefs,
        online: true,
        userStatusCode: 401, // simulates a revoked Sanctum token
      );

      await _runBootSequence(container);

      expect(
        await db.getActiveUser(),
        isNull,
        reason: 'the first reconnect after revocation must wipe local data, '
            'not just log out (decision 12)',
      );
      expect(
        container.read(minorModeProvider),
        isFalse,
        reason: 'the minor flag must be cleared alongside the wipe',
      );
    },
  );
}
