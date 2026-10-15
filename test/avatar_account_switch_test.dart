// The previous user's avatar after a logout + login (BR-SPR9WH).
//
// Reported from the web build: log out, log back in as somebody else with a
// student code, and "Můj účet / Upravit avatara" still draws the outfit of the
// account that just left. Closing the browser fixed it — the giveaway that the
// stale copy lived in memory rather than on the device.
//
// `activeUserProvider` caches the active row and is not autoDispose, so it kept
// handing out the departing student and [AvatarController], which is built on
// it, was never rebuilt for the arriving one. The name and e-mail in the same
// menu came from `activeUserStreamProvider` — a live Drift query — and updated
// correctly, which is why only the avatar looked wrong.
//
// Run:
//   flutter test test/avatar_account_switch_test.dart
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/sync/sync_status.dart';
import 'package:eduai/data/datasources/remote/avatar_remote_datasource.dart';
import 'package:eduai/models/avatar_model.dart';

const _crown = 'head_zlata_korunka';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="0 0 270.93 270.93">'
    '<rect x="67" y="67" width="136" height="136" fill="#000"/></svg>';

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
/// and the test is isolated to the local half of the sequence.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.tokens);

  @override
  bool get isAuthenticated => false;
}

/// A device with no connection: every read falls back to local storage, so
/// what the test observes is the cache alone.
class _OfflineRemote implements AvatarRemoteDataSource {
  @override
  Future<ApiResult<List<AvatarItem>>> getCatalog() async =>
      ApiResult.failure('offline');

  @override
  Future<ApiResult<String>> downloadSvg(String url) async =>
      ApiResult.failure('offline');

  @override
  Future<ApiResult<RemoteUserAvatar>> getUserAvatar() async =>
      ApiResult.failure('offline');

  @override
  Future<ApiResult<RemoteUserAvatar>> purchase(String code) async =>
      ApiResult.failure('offline');

  @override
  Future<ApiResult<RemoteUserAvatar>> updateEquipped(
    Map<String, String> equipped,
  ) async =>
      ApiResult.failure('offline');
}

/// A bought crown, worn by [userId].
Future<void> _seedWornCrown(AppDatabase db, String userId) async {
  await db.upsertAvatarItem(
    const AvatarItemsTableCompanion(
      code: Value(_crown),
      name: Value('Zlatá korunka'),
      slot: Value('head'),
      layer: Value(40),
      url: Value('https://r2.test/$_crown.svg'),
      rarity: Value('rare'),
      price: Value(0),
      isDefault: Value(false),
      svgSource: Value(_svg),
    ),
  );

  await db.upsertUserAvatar(
    UserAvatarTableCompanion(
      userId: Value(userId),
      equipped: Value(jsonEncode(const {'head': _crown})),
      ownedCodes: Value(jsonEncode(const [_crown])),
      syncStatus: Value(SyncStatus.synced.toInt()),
    ),
  );
}

void main() {
  // The repository reads the bundled starting outfit through `rootBundle`.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = _FakeAuthTokenStorage(prefs: prefs);

    return ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      authTokenStorageProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(_FakeApiClient(tokens)),
      avatarRemoteDataSourceProvider.overrideWithValue(_OfflineRemote()),
    ]);
  }

  test('logging out drops the avatar of the account that left', () async {
    await db.createAndActivateUser(
      const UsersTableCompanion(
        id: Value('user-a'),
        email: Value('a@b.test'),
        name: Value('Student A'),
        isActive: Value(true),
      ),
    );
    await _seedWornCrown(db, 'user-a');

    final container = await buildContainer();
    addTearDown(container.dispose);

    // Keep the avatar built, the way the signed-in shell does — the whole bug
    // is that nothing rebuilt it once the account changed underneath.
    container.listen(avatarControllerProvider, (_, _) {});

    final before = await container.read(avatarControllerProvider.future);
    expect(
      before.equipped[AvatarSlot.head],
      _crown,
      reason: 'user A is wearing the crown they bought',
    );

    await container.read(logoutCoordinatorProvider).teardown();

    final after = await container.read(avatarControllerProvider.future);
    expect(
      after.equipped[AvatarSlot.head],
      isNot(_crown),
      reason: 'the next student on this device must not inherit the crown',
    );
  });

  test('wiping local data takes the avatar inventory with it', () async {
    await db.createAndActivateUser(
      const UsersTableCompanion(
        id: Value('user-a'),
        email: Value('a@b.test'),
        name: Value('Student A'),
        isActive: Value(true),
      ),
    );
    await _seedWornCrown(db, 'user-a');

    await db.clearAllData();

    expect(
      await db.getUserAvatar('user-a'),
      isNull,
      reason: "a shared device must not keep the last student's inventory",
    );
  });
}
