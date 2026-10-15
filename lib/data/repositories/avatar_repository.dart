import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../../core/database/app_database.dart';
import '../../core/sync/sync_queue.dart';
import '../../core/sync/sync_status.dart';
import '../../core/util/silent_log.dart';
import '../../core/util/svg_bounds.dart';
import '../../models/avatar_model.dart';
import '../datasources/remote/avatar_remote_datasource.dart';

/// The free starting outfit, shipped inside the app bundle.
///
/// The catalog and its artwork normally come from the API and R2 — but a first
/// launch with no connection would then have literally nothing to draw. These
/// five layers (~20 KB) guarantee every account has a face from the very first
/// frame, and are overwritten by the server's copy as soon as one fetch lands.
const _bundledDefaults = <String, ({AvatarSlot slot, int layer, String name})>{
  'torso_telo_fialove': (slot: AvatarSlot.torso, layer: 20, name: 'Tělo'),
  'legs_nohy_staticke': (slot: AvatarSlot.legs, layer: 21, name: 'Nohy'),
  'eyes_vesele': (slot: AvatarSlot.eyes, layer: 30, name: 'Veselé oči'),
  'mouth_vesela': (slot: AvatarSlot.mouth, layer: 31, name: 'Veselá pusa'),
  'hands_u_tela': (slot: AvatarSlot.hands, layer: 51, name: 'Ruce u těla'),
};

String _bundledAssetPath(String code) => 'assets/avatar/base/$code.svg';

/// How many artwork downloads may be in flight at once.
///
/// The catalog is ~40 items of ~5 KB — trivial bytes, but one round trip
/// apiece. Fetching them one after another made a first launch wait for the
/// *sum* of 40 latencies, and the onboarding's "vibe" step sat empty for all
/// of it (BR-VCD7JD). Eight at a time turns that into a handful of waves
/// without opening a connection per item.
const _artworkConcurrency = 8;

/// Avatar cosmetics: catalog, ownership and the worn outfit.
///
/// Offline-first in both directions. Reads always resolve from the local
/// database — the SVG source lives there too, so a composed avatar renders
/// with no network on every platform including web. Writes (equipping) apply
/// locally and go through [SyncQueue]; only *acquiring* an item needs the
/// server, because only the server can grant it.
class AvatarRepository {
  final AvatarRemoteDataSource _remoteDataSource;
  final AppDatabase _db;
  final SyncQueue _syncQueue;

  AvatarRepository(this._remoteDataSource, this._db, this._syncQueue);

  // ═══════════════════════════════════════════════════════════════════════════
  // Reads
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load the avatar state for [userId], refreshing from the server first.
  ///
  /// A failed refresh is not an error: the cache is the point. The returned
  /// state is flagged [AvatarState.fromCache] so the UI can say so.
  Future<AvatarState> load(String userId) async {
    var refreshed = false;

    try {
      refreshed = await refresh(userId);
    } catch (e, st) {
      silentLog('avatar:refresh', e, st);
    }

    try {
      final state = await readLocal(userId);
      return state.copyWith(fromCache: !refreshed);
    } catch (e, st) {
      // Cosmetics are not worth a dead-end screen. Reading local storage
      // should not fail, but if it does the shop shows an empty catalog rather
      // than an error page over what is, at worst, a missing hat.
      silentLog('avatar:read', e, st);
      return const AvatarState(catalog: [], equipped: {}, fromCache: true);
    }
  }

  /// Assemble the avatar state from local storage alone.
  Future<AvatarState> readLocal(String userId) async {
    await _ensureBundledDefaults();

    var rows = await _db.getAvatarItems();

    // Artwork cached before the crop existed has no measurement. Measuring it
    // here means those devices get the cropped rendering without waiting for
    // the artwork to go stale and be re-downloaded — which for an unchanged
    // item would be never.
    if (await _ensureBounds(rows)) {
      rows = await _db.getAvatarItems();
    }

    final avatar = await _db.getUserAvatar(userId);

    final owned = avatar == null
        ? <String>{}
        : (jsonDecode(avatar.ownedCodes) as List<dynamic>)
            .whereType<String>()
            .toSet();

    final catalog = rows
        .map((row) => AvatarItem.fromTableData(row, owned: owned.contains(row.code)))
        .toList();

    final equipped = avatar == null
        ? _defaultEquipped(catalog)
        : AvatarState.parseEquipped(
            (jsonDecode(avatar.equipped) as Map).cast<String, dynamic>(),
          );

    return AvatarState(
      catalog: catalog,
      // An empty stored outfit means "never customised", not "wearing
      // nothing" — an invisible avatar is never what the user wanted.
      equipped: equipped.isEmpty ? _defaultEquipped(catalog) : equipped,
    );
  }

  /// The outfit a user gets before they touch the shop.
  Map<AvatarSlot, String> _defaultEquipped(List<AvatarItem> catalog) {
    final result = <AvatarSlot, String>{};

    for (final item in catalog.where((i) => i.isDefault)) {
      // Two defaults in one slot would be a catalog mistake; take the lower
      // layer so the choice is at least deterministic.
      final existing = result[item.slot];
      if (existing == null) {
        result[item.slot] = item.code;
      }
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Refresh
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pull the catalog, the user's state, and any missing artwork.
  ///
  /// Returns whether the server was actually reached.
  Future<bool> refresh(String userId) async {
    final catalogResult = await _remoteDataSource.getCatalog();
    if (catalogResult.isFailure) return false;

    final items = catalogResult.data!;
    final needArtwork = <AvatarItem>[];

    for (final item in items) {
      final cached = await _db.getAvatarItem(item.code);

      // Re-download when the artwork was never fetched, or when the server row
      // moved after we cached it — an admin replacing the SVG keeps the URL,
      // so the timestamp is the only signal.
      final stale = cached?.svgSource == null ||
          (item.serverUpdatedAt != null &&
              cached?.serverUpdatedAt != null &&
              item.serverUpdatedAt!.isAfter(cached!.serverUpdatedAt!));

      await _db.upsertAvatarItem(
        AvatarItemsTableCompanion(
          code: Value(item.code),
          name: Value(item.name),
          slot: Value(item.slot.name),
          layer: Value(item.layer),
          url: Value(item.url),
          rarity: Value(item.rarity.name),
          price: Value(item.price),
          isDefault: Value(item.isDefault),
          // Keep whatever artwork we already hold unless it went stale;
          // dropping it would leave the avatar half-drawn until the download
          // below finishes.
          svgSource: stale ? const Value(null) : const Value.absent(),
          serverUpdatedAt: Value(item.serverUpdatedAt),
          updatedAt: Value(DateTime.now()),
        ),
      );

      if (stale) needArtwork.add(item);
    }

    await _db.deleteAvatarItemsExcept(items.map((i) => i.code).toList());

    await _downloadAllArtwork(needArtwork);

    final avatarResult = await _remoteDataSource.getUserAvatar();
    if (avatarResult.isSuccess) {
      await _applyRemoteAvatar(userId, avatarResult.data!);
    }

    return true;
  }

  /// Fetch the artwork for [items], [_artworkConcurrency] at a time.
  ///
  /// A fixed pool of workers pulling from a shared cursor, rather than one
  /// `Future.wait` over the whole list: forty simultaneous connections to the
  /// bucket is its own kind of slow, and on web the browser queues them anyway.
  Future<void> _downloadAllArtwork(List<AvatarItem> items) async {
    var next = 0;

    Future<void> worker() async {
      while (next < items.length) {
        await _downloadArtwork(items[next++]);
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(_artworkConcurrency, items.length); i++)
        worker(),
    ]);
  }

  /// Fetch one item's SVG and cache it. Failures are swallowed — a missing
  /// layer degrades that one item, it must not fail the whole refresh.
  Future<void> _downloadArtwork(AvatarItem item) async {
    if (item.url.isEmpty) return;

    final svgResult = await _remoteDataSource.downloadSvg(item.url);
    if (svgResult.isFailure) {
      silentLog(
        'avatar:artwork',
        svgResult.error ?? 'download failed',
        StackTrace.current,
      );
      return;
    }

    await _cacheArtwork(item.code, svgResult.data!);
  }

  /// Measure any cached artwork that has no content box yet.
  ///
  /// Returns whether anything was written, so the caller knows to re-read. A
  /// row is only ever measured once — after the first pass this is a handful
  /// of null checks over an already-loaded list.
  Future<bool> _ensureBounds(List<AvatarItemsTableData> rows) async {
    var measured = false;

    for (final row in rows) {
      final svg = row.svgSource;
      if (svg == null || row.boundsLeft != null) continue;

      final bounds = await computeSvgContentBounds(svg);
      if (bounds == null) continue;

      await _db.setAvatarItemBounds(row.code, bounds);
      measured = true;
    }

    return measured;
  }

  /// Store artwork together with its measured content box.
  ///
  /// Measuring here rather than at render time means it happens once per item
  /// ever, off the frame that would otherwise have to rasterise 40 SVGs the
  /// moment the shop opens.
  Future<void> _cacheArtwork(String code, String svg) async {
    final bounds = await computeSvgContentBounds(svg);

    await _db.setAvatarItemSvg(
      code,
      svg,
      boundsLeft: bounds?.left,
      boundsTop: bounds?.top,
      boundsRight: bounds?.right,
      boundsBottom: bounds?.bottom,
    );
  }

  /// Write the server's copy of the user's avatar into the local database.
  ///
  /// Ownership and the outfit are treated differently on purpose. The server is
  /// the only authority on what a user *owns*, so that always lands. The worn
  /// outfit is the device's own decision, so a locally queued change wins —
  /// overwriting it here would silently undo what the user just did offline.
  Future<void> _applyRemoteAvatar(String userId, RemoteUserAvatar remote) async {
    final local = await _db.getUserAvatar(userId);

    final pending = local != null &&
        SyncStatusExtension.fromInt(local.syncStatus) == SyncStatus.pending;

    await _db.upsertUserAvatar(
      UserAvatarTableCompanion(
        userId: Value(userId),
        equipped: pending
            ? Value(local.equipped)
            : Value(jsonEncode(
                remote.equipped.map((slot, code) => MapEntry(slot.name, code)),
              )),
        ownedCodes: Value(jsonEncode(remote.ownedCodes.toList())),
        syncStatus: Value(
          (pending ? SyncStatus.pending : SyncStatus.synced).toInt(),
        ),
        updatedAt: Value(DateTime.now()),
        serverUpdatedAt: Value(pending ? local.serverUpdatedAt : remote.updatedAt),
      ),
    );
  }

  /// Apply a server-shaped avatar payload directly. Test seam for the
  /// ownership/outfit split above, which is otherwise only reachable through
  /// a live purchase.
  @visibleForTesting
  Future<void> applyRemoteAvatarForTest(
    String userId, {
    required Map<AvatarSlot, String> equipped,
    required Set<String> ownedCodes,
  }) {
    return _applyRemoteAvatar(
      userId,
      RemoteUserAvatar(equipped: equipped, ownedCodes: ownedCodes),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Writes
  // ═══════════════════════════════════════════════════════════════════════════

  /// Wear [item], replacing whatever occupied its slot.
  ///
  /// Applies locally and queues the push, so this works with no connection —
  /// that is the whole point of customising offline.
  Future<AvatarState> equip(String userId, AvatarItem item) async {
    final state = await readLocal(userId);

    // Ownership is read back from storage rather than trusted from [item]:
    // callers hand over the instance they rendered, which still says "not
    // owned" on the very tap that just bought it.
    final current = state.byCode[item.code];

    if (current == null) {
      throw StateError('Unknown avatar item: ${item.code}');
    }
    if (!current.owned && !current.isDefault) {
      throw StateError('Cannot equip an unowned item: ${item.code}');
    }

    final equipped = Map<AvatarSlot, String>.from(state.equipped)
      ..[current.slot] = current.code;

    return _persistEquipped(
      userId,
      state,
      _resolveSlotRules(equipped, state.catalog, justEquipped: current.slot),
    );
  }

  /// Take off whatever is worn in [slot].
  Future<AvatarState> unequip(String userId, AvatarSlot slot) async {
    final state = await readLocal(userId);

    final equipped = Map<AvatarSlot, String>.from(state.equipped)..remove(slot);

    // No `justEquipped`: nothing was chosen, so only the default-restore pass
    // runs — taking the lollipop off puts the empty hands back.
    return _persistEquipped(
      userId,
      state,
      _resolveSlotRules(equipped, state.catalog),
    );
  }

  /// Settle the slots that cannot coexist, then fill any gap left behind.
  ///
  /// Two passes, in this order:
  ///
  /// 1. A slot that conflicts with a worn one is cleared — putting a lollipop
  ///    in the avatar's hand has to take the empty-handed arms off, because
  ///    the lollipop artwork brings its own arm and the two would overlap.
  /// 2. Any slot that is now empty, has a free default and no conflicting slot
  ///    worn, gets its default back. Without this, taking the lollipop off
  ///    would leave the avatar with no arms at all.
  ///
  /// [justEquipped] is what the user chose on this tap, so it is the side that
  /// wins the conflict — clearing by iterating the whole map instead would let
  /// the pair cancel each other out.
  Map<AvatarSlot, String> _resolveSlotRules(
    Map<AvatarSlot, String> equipped,
    List<AvatarItem> catalog, {
    AvatarSlot? justEquipped,
  }) {
    final result = Map<AvatarSlot, String>.from(equipped);

    if (justEquipped != null) {
      for (final conflicting in justEquipped.conflicts) {
        result.remove(conflicting);
      }
    }

    for (final item in catalog.where((i) => i.isDefault)) {
      if (result.containsKey(item.slot)) continue;
      if (item.slot.conflicts.any(result.containsKey)) continue;

      result[item.slot] = item.code;
    }

    return result;
  }

  Future<AvatarState> _persistEquipped(
    String userId,
    AvatarState state,
    Map<AvatarSlot, String> equipped,
  ) async {
    final existing = await _db.getUserAvatar(userId);
    final ownedJson = existing?.ownedCodes ?? '[]';

    await _db.upsertUserAvatar(
      UserAvatarTableCompanion(
        userId: Value(userId),
        equipped: Value(jsonEncode(
          equipped.map((slot, code) => MapEntry(slot.name, code)),
        )),
        ownedCodes: Value(ownedJson),
        syncStatus: Value(SyncStatus.pending.toInt()),
        updatedAt: Value(DateTime.now()),
        serverUpdatedAt: Value(existing?.serverUpdatedAt),
      ),
    );

    await _syncQueue.enqueue(
      tableName: 'user_avatar',
      recordId: userId,
      operation: SyncOperation.update,
      payload: {
        'equipped': equipped.map((slot, code) => MapEntry(slot.name, code)),
      },
    );

    return state.copyWith(equipped: equipped);
  }

  /// Acquire an item.
  ///
  /// Requires a connection by design: only the server can grant ownership, and
  /// pretending otherwise would let a device hand itself items that vanish on
  /// the next refresh.
  Future<AvatarState> purchase(String userId, AvatarItem item) async {
    final result = await _remoteDataSource.purchase(item.code);

    if (result.isFailure) {
      throw Exception(result.error);
    }

    await _applyRemoteAvatar(userId, result.data!);
    return readLocal(userId);
  }

  /// Push a queued outfit change. Called by the sync service.
  Future<bool> pushEquipped(String userId, Map<String, dynamic> payload) async {
    final equipped = (payload['equipped'] as Map?)?.cast<String, dynamic>() ?? {};

    final result = await _remoteDataSource.updateEquipped(
      equipped.map((key, value) => MapEntry(key, value as String)),
    );

    if (result.isFailure) return false;

    await _db.updateUserAvatarSyncStatus(userId, SyncStatus.synced.toInt());
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Bundled fallback
  // ═══════════════════════════════════════════════════════════════════════════

  /// Seed the catalog from the app bundle for codes that have no artwork yet.
  ///
  /// Runs on every local read but only touches rows that are actually missing
  /// artwork, so once the server's copy has landed this is a handful of
  /// no-op lookups.
  Future<void> _ensureBundledDefaults() async {
    for (final entry in _bundledDefaults.entries) {
      final cached = await _db.getAvatarItem(entry.key);
      if (cached?.svgSource != null) continue;

      try {
        final svg = await rootBundle.loadString(_bundledAssetPath(entry.key));
        final bounds = await computeSvgContentBounds(svg);

        await _db.upsertAvatarItem(
          AvatarItemsTableCompanion(
            code: Value(entry.key),
            name: Value(cached?.name ?? entry.value.name),
            slot: Value(cached?.slot ?? entry.value.slot.name),
            layer: Value(cached?.layer ?? entry.value.layer),
            url: Value(cached?.url ?? ''),
            rarity: Value(cached?.rarity ?? AvatarRarity.common.name),
            price: const Value(0),
            isDefault: const Value(true),
            svgSource: Value(svg),
            boundsLeft: Value(bounds?.left),
            boundsTop: Value(bounds?.top),
            boundsRight: Value(bounds?.right),
            boundsBottom: Value(bounds?.bottom),
            serverUpdatedAt: Value(cached?.serverUpdatedAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } catch (e, st) {
        silentLog('avatar:bundled', e, st);
      }
    }
  }
}
