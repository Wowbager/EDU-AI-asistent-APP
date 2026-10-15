import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';

/// Local data source for user stats using Drift/SQLite.
class UserStatsLocalDataSource {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  UserStatsLocalDataSource(this._db);

  /// Get stats for a specific user.
  Future<UserStatsTableData?> getUserStats(String userId) {
    return _db.getUserStats(userId);
  }

  /// Watch stats for a specific user as a stream.
  Stream<UserStatsTableData?> watchUserStats(String userId) {
    return _db.watchUserStats(userId);
  }

  /// Create default stats for a user.
  /// Returns the local ID of the created stats.
  Future<String> createDefaultStats(String userId) async {
    final localId = _uuid.v4();
    final now = DateTime.now();

    await _db.upsertUserStats(
      UserStatsTableCompanion(
        id: Value(localId),
        userId: Value(userId),
        level: const Value(1),
        xpPoints: const Value(0),
        coursesCount: const Value(0),
        streakDays: const Value(1),
        achievementsCount: const Value(0),
        syncStatus: Value(SyncStatus.synced.toInt()),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return localId;
  }

  /// Get or create stats for a user.
  Future<UserStatsTableData> getOrCreateStats(String userId) async {
    final existing = await getUserStats(userId);
    if (existing != null) {
      return existing;
    }

    final localId = await createDefaultStats(userId);
    final created = await _db.getUserStats(userId);
    if (created != null) return created;
    // Fallback: query by the localId we just inserted
    final byId = await _db.getUserStatsByLocalId(localId);
    if (byId != null) return byId;
    throw StateError('Failed to create stats for user $userId');
  }

  /// Insert or update stats from server data.
  Future<void> upsertFromServer({
    required int serverId,
    required String userId,
    required int level,
    required int xpPoints,
    required int coursesCount,
    required int streakDays,
    required int achievementsCount,
    required int coinsEarned,
    required int coinsBalance,
    DateTime? lastStreakDate,
    required DateTime serverUpdatedAt,
    String? existingLocalId,
  }) async {
    final localId = existingLocalId ?? _uuid.v4();

    await _db.upsertUserStats(
      UserStatsTableCompanion(
        id: Value(localId),
        serverId: Value(serverId),
        userId: Value(userId),
        level: Value(level),
        xpPoints: Value(xpPoints),
        coursesCount: Value(coursesCount),
        streakDays: Value(streakDays),
        achievementsCount: Value(achievementsCount),
        coinsEarned: Value(coinsEarned),
        coinsBalance: Value(coinsBalance),
        lastStreakDate: Value(lastStreakDate),
        syncStatus: Value(SyncStatus.synced.toInt()),
        updatedAt: Value(serverUpdatedAt),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  /// Update streak locally.
  Future<void> updateStreak({
    required String localId,
    required int streakDays,
    required DateTime lastStreakDate,
  }) async {
    await _db.updateUserStats(
      id: localId,
      streakDays: streakDays,
      lastStreakDate: lastStreakDate,
    );
  }

  /// Update XP, level, and daily XP tracking.
  Future<void> updateXp({
    required String localId,
    required int xpPoints,
    required int level,
    required DateTime dailyXpDate,
    required int dailyXpAmount,
  }) async {
    await _db.updateUserStats(
      id: localId,
      xpPoints: xpPoints,
      level: level,
      dailyXpDate: dailyXpDate,
      dailyXpAmount: dailyXpAmount,
    );
  }

  /// Update the EDUX coin wallet (BR-HK9828).
  Future<void> updateCoins({
    required String localId,
    required int coinsEarned,
    required int coinsBalance,
  }) async {
    await _db.updateUserStats(
      id: localId,
      coinsEarned: coinsEarned,
      coinsBalance: coinsBalance,
    );
  }

  /// Increment achievements count.
  Future<void> incrementAchievements({
    required String localId,
    required int achievementsCount,
  }) async {
    await _db.updateUserStats(
      id: localId,
      achievementsCount: achievementsCount,
    );
  }

  /// Delete stats for a user.
  Future<void> deleteStats(String userId) {
    return _db.deleteUserStats(userId);
  }
}
