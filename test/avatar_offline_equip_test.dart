// Avatar cosmetics (BR-7JRBCN): the offline half of the feature.
//
// The point of caching the SVG source in Drift rather than on disk is that the
// composed avatar survives with no network on every platform. These tests pin
// the two things that would silently break that promise: equipping while
// offline must persist locally *and* leave a queued push behind, and a refresh
// must not throw away artwork the device already downloaded.
//
// Run:
//   flutter test test/avatar_offline_equip_test.dart
import 'dart:convert';

// `Value` only — drift also exports matcher-shaped names like `isNotNull`,
// which collide with `package:matcher`.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/core/sync/sync_status.dart';
import 'package:eduai/data/datasources/remote/avatar_remote_datasource.dart';
import 'package:eduai/data/repositories/avatar_repository.dart';
import 'package:eduai/models/avatar_model.dart';

const _userId = 'user-1';

/// A repository with no reachable server — every remote call fails, which is
/// exactly the state the offline path has to survive.
AvatarRepository _offlineRepository(AppDatabase db) {
  return AvatarRepository(_UnreachableRemote(), db, SyncQueue(db));
}

Future<void> _seedCatalog(AppDatabase db) async {
  Future<void> add(
    String code,
    String slot,
    int layer, {
    bool isDefault = false,
  }) {
    return db.upsertAvatarItem(
      AvatarItemsTableCompanion(
        code: Value(code),
        name: Value(code),
        slot: Value(slot),
        layer: Value(layer),
        url: Value('https://r2.test/$code.svg'),
        rarity: const Value('common'),
        price: const Value(0),
        isDefault: Value(isDefault),
        // Renderable, and deliberately not full-bleed: the item occupies a
        // patch of the shared canvas the way real artwork does, so the
        // content box has something to measure.
        svgSource: Value(
          '<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="0 0 270.93 270.93">'
          '<rect x="67" y="67" width="136" height="136" fill="#000"/>'
          '<!--$code--></svg>',
        ),
      ),
    );
  }

  await add('torso_base', 'torso', 20, isDefault: true);
  await add('eyes_base', 'eyes', 30, isDefault: true);
  await add('head_crown', 'head', 40);
  await add('head_cap', 'head', 40);
  await add('hands_down', 'hands', 51, isDefault: true);
  await add('hands_raised', 'hands', 51);
  await add('held_lollipop', 'held', 52);
}

Future<void> _grant(AppDatabase db, List<String> codes) {
  return db.upsertUserAvatar(
    UserAvatarTableCompanion(
      userId: const Value(_userId),
      equipped: const Value('{}'),
      ownedCodes: Value(jsonEncode(codes)),
      syncStatus: Value(SyncStatus.synced.toInt()),
    ),
  );
}

void main() {
  // The repository reads the bundled starting outfit through `rootBundle`,
  // which needs a binding even in a pure-Dart test.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AvatarRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _offlineRepository(db);
  });

  tearDown(() async => db.close());

  test('a user who never customised wears the default outfit', () async {
    await _seedCatalog(db);

    final state = await repo.readLocal(_userId);

    expect(state.equipped[AvatarSlot.torso], 'torso_base');
    expect(state.equipped[AvatarSlot.eyes], 'eyes_base');
    expect(state.equipped.containsKey(AvatarSlot.head), isFalse);
  });

  test('equipping offline persists locally and queues the push', () async {
    await _seedCatalog(db);
    await _grant(db, ['head_crown']);

    final state = await repo.readLocal(_userId);
    final crown = state.byCode['head_crown']!;

    await repo.equip(_userId, crown);

    final stored = await db.getUserAvatar(_userId);
    expect(stored, isNotNull);
    expect(
      (jsonDecode(stored!.equipped) as Map)['head'],
      'head_crown',
      reason: 'the choice must survive a restart with no network',
    );
    expect(
      SyncStatusExtension.fromInt(stored.syncStatus),
      SyncStatus.pending,
      reason: 'a pending row is what stops a later pull from clobbering it',
    );

    final queued = await db.getPendingSyncOperations();
    final avatarOps = queued.where((op) => op.tableName_ == 'user_avatar');
    expect(avatarOps, hasLength(1));

    final payload =
        (jsonDecode(avatarOps.first.payload) as Map)['equipped'] as Map;
    expect(
      payload,
      containsPair('head', 'head_crown'),
      reason: 'the queue carries the whole outfit, not a delta',
    );
    expect(
      payload.keys,
      containsAll(['torso', 'eyes', 'head']),
      reason: 'the untouched slots travel along so a replay restores them too',
    );
  });

  test('equipping a second hat replaces the first — one item per slot', () async {
    await _seedCatalog(db);
    await _grant(db, ['head_crown', 'head_cap']);

    var state = await repo.readLocal(_userId);
    await repo.equip(_userId, state.byCode['head_crown']!);

    state = await repo.readLocal(_userId);
    await repo.equip(_userId, state.byCode['head_cap']!);

    state = await repo.readLocal(_userId);
    expect(state.equipped[AvatarSlot.head], 'head_cap');
    expect(
      state.equippedLayers.where((i) => i.slot == AvatarSlot.head),
      hasLength(1),
    );
  });

  test('an unowned item cannot be equipped', () async {
    await _seedCatalog(db);
    await _grant(db, []);

    final state = await repo.readLocal(_userId);

    expect(
      () => repo.equip(_userId, state.byCode['head_crown']!),
      throwsStateError,
    );
  });

  test('layers render back-to-front by the server-owned layer', () async {
    await _seedCatalog(db);
    await _grant(db, ['head_crown']);

    var state = await repo.readLocal(_userId);
    await repo.equip(_userId, state.byCode['head_crown']!);
    state = await repo.readLocal(_userId);

    final order = state.equippedLayers.map((i) => i.code).toList();
    final layers = state.equippedLayers.map((i) => i.layer).toList();

    expect(
      layers,
      orderedEquals([...layers]..sort()),
      reason: 'layers must come out sorted back-to-front',
    );

    // The hat is layer 40, the body 20 and the eyes 30 — so it paints over
    // both of them.
    expect(order.indexOf('head_crown'), greaterThan(order.indexOf('torso_base')));
    expect(order.indexOf('head_crown'), greaterThan(order.indexOf('eyes_base')));
  });

  test('an item with no cached artwork is listed but not drawn', () async {
    await _seedCatalog(db);
    await _grant(db, ['head_crown']);

    // Catalog row known, artwork never downloaded — a first run offline.
    await db.upsertAvatarItem(
      const AvatarItemsTableCompanion(
        code: Value('head_crown'),
        name: Value('head_crown'),
        slot: Value('head'),
        layer: Value(40),
        url: Value('https://r2.test/head_crown.svg'),
        svgSource: Value(null),
      ),
    );

    var state = await repo.readLocal(_userId);
    await repo.equip(_userId, state.byCode['head_crown']!);
    state = await repo.readLocal(_userId);

    expect(state.byCode['head_crown']!.isDrawable, isFalse);
    expect(state.equipped[AvatarSlot.head], 'head_crown');
    expect(
      state.equippedLayers.map((i) => i.code),
      isNot(contains('head_crown')),
      reason: 'a gap in the stack beats drawing the wrong thing',
    );
  });

  test('an item just bought can be equipped with the stale pre-purchase object',
      () async {
    // Stage regression: purchase succeeded server-side, then equipping threw
    // "not owned" and the UI reported a connection failure. The shop hands
    // over the AvatarItem it rendered, which still says owned:false on the
    // very tap that bought it — ownership has to be re-read from storage.
    await _seedCatalog(db);
    await _grant(db, []);

    final beforePurchase = (await repo.readLocal(_userId)).byCode['head_crown']!;
    expect(beforePurchase.owned, isFalse);

    // What the purchase response writes.
    await _grant(db, ['head_crown']);

    final state = await repo.equip(_userId, beforePurchase);
    expect(state.equipped[AvatarSlot.head], 'head_crown');
  });

  test('a purchase lands while an offline outfit change is still queued',
      () async {
    // The pending guard protects the *outfit* from being overwritten by the
    // server — it must not also block the *inventory*, or an item bought right
    // after an offline equip can never be worn.
    await _seedCatalog(db);
    await _grant(db, ['head_cap']);

    var state = await repo.readLocal(_userId);
    await repo.equip(_userId, state.byCode['head_cap']!);

    final queued = await db.getUserAvatar(_userId);
    expect(
      SyncStatusExtension.fromInt(queued!.syncStatus),
      SyncStatus.pending,
    );

    await repo.applyRemoteAvatarForTest(
      _userId,
      equipped: const {},
      ownedCodes: {'head_cap', 'head_crown'},
    );

    final after = await db.getUserAvatar(_userId);
    expect(
      jsonDecode(after!.ownedCodes),
      containsAll(['head_cap', 'head_crown']),
      reason: 'the server is the only authority on ownership',
    );
    expect(
      (jsonDecode(after.equipped) as Map)['head'],
      'head_cap',
      reason: 'the queued outfit is the newer intent and must survive',
    );
    expect(
      SyncStatusExtension.fromInt(after.syncStatus),
      SyncStatus.pending,
      reason: 'marking it synced would drop the push that never happened',
    );

    state = await repo.readLocal(_userId);
    await repo.equip(_userId, state.byCode['head_crown']!);
    expect((await repo.readLocal(_userId)).equipped[AvatarSlot.head],
        'head_crown');
  });

  test('artwork cached before the crop existed gets measured on read',
      () async {
    // A device that installed an earlier build has artwork but no content box.
    // Without a backfill it would only be measured once the item went stale
    // and was re-downloaded — which for an unchanged item is never.
    await _seedCatalog(db);

    expect((await db.getAvatarItem('head_crown'))!.boundsLeft, isNull);

    final state = await repo.readLocal(_userId);

    expect(
      state.byCode['head_crown']!.contentBounds,
      isNotNull,
      reason: 'an unmeasured item renders uncropped, i.e. as a tiny speck',
    );
    expect((await db.getAvatarItem('head_crown'))!.boundsLeft, isNotNull);
  });

  group('hands and held cannot be worn together', () {
    // The held artwork ships the arm that holds it — the lollipop comes with
    // its own hand — so an arm pose underneath it draws two sets of arms.

    test('holding something takes the empty hands off', () async {
      await _seedCatalog(db);
      await _grant(db, ['held_lollipop']);

      var state = await repo.readLocal(_userId);
      expect(state.equipped[AvatarSlot.hands], 'hands_down');

      await repo.equip(_userId, state.byCode['held_lollipop']!);

      state = await repo.readLocal(_userId);
      expect(state.equipped[AvatarSlot.held], 'held_lollipop');
      expect(state.equipped.containsKey(AvatarSlot.hands), isFalse);
    });

    test('putting it down brings the hands back', () async {
      // Otherwise the avatar is left with no arms at all.
      await _seedCatalog(db);
      await _grant(db, ['held_lollipop']);

      var state = await repo.readLocal(_userId);
      await repo.equip(_userId, state.byCode['held_lollipop']!);

      await repo.unequip(_userId, AvatarSlot.held);

      state = await repo.readLocal(_userId);
      expect(state.equipped[AvatarSlot.hands], 'hands_down');
      expect(state.equipped.containsKey(AvatarSlot.held), isFalse);
    });

    test('choosing an arm pose drops what was held', () async {
      await _seedCatalog(db);
      await _grant(db, ['held_lollipop', 'hands_raised']);

      var state = await repo.readLocal(_userId);
      await repo.equip(_userId, state.byCode['held_lollipop']!);

      state = await repo.readLocal(_userId);
      await repo.equip(_userId, state.byCode['hands_raised']!);

      state = await repo.readLocal(_userId);
      expect(state.equipped[AvatarSlot.hands], 'hands_raised');
      expect(state.equipped.containsKey(AvatarSlot.held), isFalse);
    });

    test('only one set of arms is ever drawn', () async {
      await _seedCatalog(db);
      await _grant(db, ['held_lollipop']);

      var state = await repo.readLocal(_userId);
      await repo.equip(_userId, state.byCode['held_lollipop']!);
      state = await repo.readLocal(_userId);

      final armLayers = state.equippedLayers.where(
        (i) => i.slot == AvatarSlot.hands || i.slot == AvatarSlot.held,
      );
      expect(armLayers, hasLength(1));
    });

    test('an unrelated slot leaves the hands alone', () async {
      await _seedCatalog(db);
      await _grant(db, ['head_crown']);

      var state = await repo.readLocal(_userId);
      await repo.equip(_userId, state.byCode['head_crown']!);

      state = await repo.readLocal(_userId);
      expect(state.equipped[AvatarSlot.hands], 'hands_down');
      expect(state.equipped[AvatarSlot.head], 'head_crown');
    });
  });

  test('a failed refresh falls back to the cache and says so', () async {
    await _seedCatalog(db);

    final state = await repo.load(_userId);

    expect(state.fromCache, isTrue);
    expect(state.catalog, isNotEmpty);
  });
}

/// Stands in for a device with no connectivity: every call fails the way Dio
/// reports an unreachable host, rather than throwing.
class _UnreachableRemote implements AvatarRemoteDataSource {
  static const _offline = 'offline';

  @override
  Future<ApiResult<List<AvatarItem>>> getCatalog() async =>
      ApiResult.failure(_offline);

  @override
  Future<ApiResult<RemoteUserAvatar>> getUserAvatar() async =>
      ApiResult.failure(_offline);

  @override
  Future<ApiResult<RemoteUserAvatar>> purchase(String code) async =>
      ApiResult.failure(_offline);

  @override
  Future<ApiResult<RemoteUserAvatar>> updateEquipped(
    Map<String, String> equipped,
  ) async =>
      ApiResult.failure(_offline);

  @override
  Future<ApiResult<String>> downloadSvg(String url) async =>
      ApiResult.failure(_offline);
}
