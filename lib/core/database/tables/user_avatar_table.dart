import 'package:drift/drift.dart';

/// A user's worn outfit and the items they own.
///
/// One row per user, keyed on the local user id, so switching accounts on a
/// shared device swaps avatars without either user's inventory leaking.
class UserAvatarTable extends Table {
  @override
  String get tableName => 'user_avatar';

  /// Local user id (`users.id`).
  TextColumn get userId => text()();

  /// JSON object, slot => item code (`{"head":"head_zlata_korunka"}`). A slot
  /// that is absent or null is simply not worn.
  TextColumn get equipped => text().withDefault(const Constant('{}'))();

  /// JSON array of owned item codes. Default items are included by the server
  /// so the app never has to special-case them.
  TextColumn get ownedCodes => text().withDefault(const Constant('[]'))();

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Server's last write, for conflict detection on pull.
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}
