import 'package:drift/drift.dart';

/// Read cache of the server's task calibration (BR-697NCA): the calibrated
/// difficulty per GPF dimension (null where none yet) and the update counts,
/// as GET /api/blocks/stats publishes them. The app never writes D itself.
class BlockStatsTable extends Table {
  @override
  String get tableName => 'block_stats';

  TextColumn get blockId => text()();
  TextColumn get itemPocet => text()();
  TextColumn get eloVector => text()();

  /// The downloaded course whose pull wrote this row — the per-course cursor
  /// of the next pull. Null on rows from before schema 21 (none survive it).
  TextColumn get courseId => text().nullable()();

  /// The server's `updated_at` for the row.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {blockId};
}
