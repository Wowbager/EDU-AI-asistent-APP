import 'package:drift/drift.dart';

/// Local mirror of the avatar cosmetics catalog.
///
/// The SVG *source* is cached here rather than on disk on purpose: the web
/// build has no writable filesystem, and Drift already works everywhere the
/// app runs. The whole catalog is ~280 KB of text, so this costs nothing and
/// buys one offline code path on every platform.
class AvatarItemsTable extends Table {
  @override
  String get tableName => 'avatar_items';

  /// Server-side stable identifier ("head_zlata_korunka"). Primary key, so a
  /// re-fetch reconciles in place instead of duplicating the catalog.
  TextColumn get code => text()();

  TextColumn get name => text()();

  /// torso|legs|eyes|mouth|face|head|neck|hands|held
  TextColumn get slot => text()();

  /// Paint order — items are drawn ascending.
  IntColumn get layer => integer()();

  /// R2 URL the artwork was downloaded from.
  TextColumn get url => text()();

  TextColumn get rarity => text().withDefault(const Constant('common'))();

  /// Always 0 while the shop is free; kept so enabling credits is a data change.
  IntColumn get price => integer().withDefault(const Constant(0))();

  /// Part of the free starting outfit — owned implicitly by everyone.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// The downloaded SVG. Null means "catalog row known, artwork not fetched
  /// yet" — the item is listed but renders as a placeholder until a connection
  /// fills this in.
  TextColumn get svgSource => text().nullable()();

  /// Tight bounding box of the artwork's visible content, normalised to the
  /// shared canvas (0..1). Computed once when [svgSource] is cached.
  ///
  /// Assets are drawn where they belong on the body, so a crown is a small
  /// patch near the top of an otherwise empty canvas. The stored geometry has
  /// to stay that way for layering to work; these let the shop tile and the
  /// preview crop to the artwork instead of rendering mostly nothing.
  RealColumn get boundsLeft => real().nullable()();

  RealColumn get boundsTop => real().nullable()();

  RealColumn get boundsRight => real().nullable()();

  RealColumn get boundsBottom => real().nullable()();

  /// The catalog row's server timestamp. An admin replacing the artwork keeps
  /// the same URL, so this is what tells us the cached [svgSource] is stale.
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {code};
}
