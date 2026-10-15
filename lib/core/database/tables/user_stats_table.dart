import 'package:drift/drift.dart';

/// Drift table definition for user stats.
/// Tracks user profile statistics like level, XP, streak, etc.
class UserStatsTable extends Table {
  @override
  String get tableName => 'user_stats';

  /// Local unique identifier (UUID).
  TextColumn get id => text()();

  /// Server-side ID (null if created offline and not yet synced).
  IntColumn get serverId => integer().nullable()();

  /// The user who owns these stats.
  TextColumn get userId => text()();

  /// User's current level.
  IntColumn get level => integer().withDefault(const Constant(1))();

  /// User's experience points.
  IntColumn get xpPoints => integer().withDefault(const Constant(0))();

  /// Number of courses the user has (downloaded/completed).
  IntColumn get coursesCount => integer().withDefault(const Constant(0))();

  /// Current streak in days.
  IntColumn get streakDays => integer().withDefault(const Constant(0))();

  /// Number of achievements earned.
  IntColumn get achievementsCount => integer().withDefault(const Constant(0))();

  /// Date of last streak activity (for streak calculation).
  DateTimeColumn get lastStreakDate => dateTime().nullable()();

  /// Date of last daily XP tracking (for daily soft cap).
  DateTimeColumn get dailyXpDate => dateTime().nullable()();

  /// XP earned on the [dailyXpDate] (resets each new day).
  IntColumn get dailyXpAmount => integer().withDefault(const Constant(0))();

  /// EDUX coins earned over the account's lifetime — the number the
  /// Achievements screen shows. Only ever grows (BR-HK9828).
  IntColumn get coinsEarned => integer().withDefault(const Constant(0))();

  /// EDUX coins still available to spend. Tracked apart from [coinsEarned] so
  /// buying something in the shop cannot shrink what the student has earned.
  IntColumn get coinsBalance => integer().withDefault(const Constant(0))();

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// When the record was created locally.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When the record was last updated (local or remote).
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Server's last update timestamp (for conflict detection).
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
