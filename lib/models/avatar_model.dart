import 'dart:ui' show Rect;

import '../core/database/app_database.dart';

/// Avatar slots, in paint order.
///
/// A slot holds at most one item, so "take the hat off" and "wear another hat"
/// are the same operation. The order here is the order the server assigns
/// layers in, but rendering always sorts by [AvatarItem.layer] — the server is
/// the authority, not this list.
enum AvatarSlot {
  torso,
  legs,
  eyes,
  mouth,
  face,
  head,
  neck,
  hands,
  held;

  static AvatarSlot? tryParse(String value) {
    for (final slot in AvatarSlot.values) {
      if (slot.name == value) return slot;
    }
    return null;
  }

  /// Slots that cannot be worn at the same time as this one.
  ///
  /// A held object is drawn with the arm that holds it — the lollipop artwork
  /// ships its own hand — so wearing it alongside an arm pose puts two sets of
  /// arms on the avatar. Everything else stacks freely; this is the one pair
  /// where the artwork overlaps rather than layers.
  Set<AvatarSlot> get conflicts => switch (this) {
        AvatarSlot.hands => const {AvatarSlot.held},
        AvatarSlot.held => const {AvatarSlot.hands},
        _ => const {},
      };
}

enum AvatarRarity {
  common,
  rare,
  epic;

  static AvatarRarity parse(String? value) {
    for (final rarity in AvatarRarity.values) {
      if (rarity.name == value) return rarity;
    }
    return AvatarRarity.common;
  }
}

/// One cosmetic in the catalog.
class AvatarItem {
  final String code;
  final String name;
  final AvatarSlot slot;

  /// Paint order — lower renders behind higher.
  final int layer;

  /// R2 URL the artwork lives at.
  final String url;

  final AvatarRarity rarity;

  /// Always 0 while the shop is free.
  final int price;

  /// Part of the free starting outfit.
  final bool isDefault;

  final bool owned;

  /// The downloaded SVG markup. Null until the artwork has been fetched at
  /// least once; the item is still listed, just not drawable.
  final String? svgSource;

  /// Tight box around the visible artwork, normalised to the shared canvas
  /// (0..1). Null until the artwork has been measured.
  ///
  /// Layers are *composed* on the full canvas — that is what makes them line
  /// up. This is only for showing artwork on its own, where the empty margin
  /// around a crown would otherwise be most of the tile.
  final Rect? contentBounds;

  final DateTime? serverUpdatedAt;

  const AvatarItem({
    required this.code,
    required this.name,
    required this.slot,
    required this.layer,
    required this.url,
    required this.rarity,
    required this.price,
    required this.isDefault,
    required this.owned,
    this.svgSource,
    this.contentBounds,
    this.serverUpdatedAt,
  });

  bool get isDrawable => svgSource != null;

  /// Parse a catalog entry. Returns null for a slot this build does not know,
  /// so the server can introduce a slot before the client that renders it has
  /// shipped without breaking the whole catalog.
  static AvatarItem? fromJson(Map<String, dynamic> json) {
    final slot = AvatarSlot.tryParse(json['slot'] as String? ?? '');
    if (slot == null) return null;

    final rawUpdatedAt = json['updated_at'] as String?;

    return AvatarItem(
      code: json['code'] as String,
      name: json['name'] as String? ?? '',
      slot: slot,
      layer: json['layer'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      rarity: AvatarRarity.parse(json['rarity'] as String?),
      price: json['price'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      owned: json['owned'] as bool? ?? false,
      serverUpdatedAt:
          rawUpdatedAt == null ? null : DateTime.tryParse(rawUpdatedAt),
    );
  }

  factory AvatarItem.fromTableData(
    AvatarItemsTableData data, {
    required bool owned,
  }) {
    return AvatarItem(
      code: data.code,
      name: data.name,
      // A row can only reach the table through a parsed slot, so this cannot
      // fail — the fallback exists to keep the constructor non-nullable.
      slot: AvatarSlot.tryParse(data.slot) ?? AvatarSlot.head,
      layer: data.layer,
      url: data.url,
      rarity: AvatarRarity.parse(data.rarity),
      price: data.price,
      isDefault: data.isDefault,
      owned: owned || data.isDefault,
      svgSource: data.svgSource,
      contentBounds: _boundsFrom(data),
      serverUpdatedAt: data.serverUpdatedAt,
    );
  }

  /// Rebuild the box from its four stored edges. All-or-nothing: a partially
  /// written row means the measurement never completed and must not be
  /// half-trusted.
  static Rect? _boundsFrom(AvatarItemsTableData data) {
    final left = data.boundsLeft;
    final top = data.boundsTop;
    final right = data.boundsRight;
    final bottom = data.boundsBottom;

    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    if (right <= left || bottom <= top) return null;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  AvatarItem copyWith({String? svgSource, bool? owned, Rect? contentBounds}) {
    return AvatarItem(
      code: code,
      name: name,
      slot: slot,
      layer: layer,
      url: url,
      rarity: rarity,
      price: price,
      isDefault: isDefault,
      owned: owned ?? this.owned,
      svgSource: svgSource ?? this.svgSource,
      contentBounds: contentBounds ?? this.contentBounds,
      serverUpdatedAt: serverUpdatedAt,
    );
  }
}

/// The catalog plus the user's outfit — everything the shop and the avatar
/// renderer need, resolved together so they can never disagree.
class AvatarState {
  final List<AvatarItem> catalog;

  /// slot => item code. A slot absent from the map is not worn.
  final Map<AvatarSlot, String> equipped;

  /// True when this was assembled from the local cache because the network
  /// was unavailable.
  final bool fromCache;

  const AvatarState({
    required this.catalog,
    required this.equipped,
    this.fromCache = false,
  });

  static const empty = AvatarState(catalog: [], equipped: {});

  Map<String, AvatarItem> get byCode => {
        for (final item in catalog) item.code: item,
      };

  List<AvatarItem> itemsForSlot(AvatarSlot slot) =>
      catalog.where((i) => i.slot == slot).toList(growable: false);

  /// The worn items, in paint order, skipping anything without artwork.
  ///
  /// A missing item is dropped rather than substituted: drawing someone else's
  /// hat would be worse than drawing no hat.
  List<AvatarItem> get equippedLayers {
    final lookup = byCode;

    final layers = equipped.values
        .map((code) => lookup[code])
        .whereType<AvatarItem>()
        .where((item) => item.isDrawable)
        .toList();

    layers.sort((a, b) => a.layer.compareTo(b.layer));
    return layers;
  }

  /// The measured boxes of the worn layers, for cropping the composed figure.
  ///
  /// Layers with no measurement are simply absent — the crop then covers a bit
  /// more canvas than needed, which is far better than clipping a hat off.
  List<Rect> get equippedBounds => equippedLayers
      .map((item) => item.contentBounds)
      .whereType<Rect>()
      .toList(growable: false);

  bool isEquipped(AvatarItem item) => equipped[item.slot] == item.code;

  AvatarState copyWith({
    List<AvatarItem>? catalog,
    Map<AvatarSlot, String>? equipped,
    bool? fromCache,
  }) {
    return AvatarState(
      catalog: catalog ?? this.catalog,
      equipped: equipped ?? this.equipped,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  /// Encode [equipped] for the API and for local storage.
  Map<String, String> get equippedJson =>
      equipped.map((slot, code) => MapEntry(slot.name, code));

  /// Decode a slot => code map, dropping slots this build does not know.
  static Map<AvatarSlot, String> parseEquipped(Map<String, dynamic>? json) {
    if (json == null) return {};

    final result = <AvatarSlot, String>{};
    json.forEach((key, value) {
      final slot = AvatarSlot.tryParse(key);
      if (slot != null && value is String && value.isNotEmpty) {
        result[slot] = value;
      }
    });
    return result;
  }
}
