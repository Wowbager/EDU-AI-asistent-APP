import '../../core/connectivity/connectivity_service.dart';
import '../../core/gamification/gamification_service.dart';
import '../../core/sync/sync_queue.dart';
import '../../core/sync/sync_status.dart';
import '../datasources/local/user_stats_local_datasource.dart';
import '../datasources/remote/user_stats_remote_datasource.dart';
import '../../core/database/app_database.dart';

/// User stats model for use in the UI layer.
class UserStats {
  final String id;
  final int? serverId;
  final String userId;
  final int level;
  final int xpPoints;
  final int coursesCount;
  final int streakDays;
  final int achievementsCount;
  final DateTime? lastStreakDate;
  final DateTime? dailyXpDate;
  final int dailyXpAmount;

  /// EDUX coins earned over the account's lifetime (BR-HK9828).
  final int coinsEarned;

  /// EDUX coins still available to spend.
  final int coinsBalance;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserStats({
    required this.id,
    this.serverId,
    required this.userId,
    required this.level,
    required this.xpPoints,
    required this.coursesCount,
    required this.streakDays,
    required this.achievementsCount,
    this.lastStreakDate,
    this.dailyXpDate,
    this.dailyXpAmount = 0,
    this.coinsEarned = 0,
    this.coinsBalance = 0,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserStats.fromTableData(UserStatsTableData data) {
    return UserStats(
      id: data.id,
      serverId: data.serverId,
      userId: data.userId,
      level: data.level,
      xpPoints: data.xpPoints,
      coursesCount: data.coursesCount,
      streakDays: data.streakDays < 1 ? 1 : data.streakDays,
      achievementsCount: data.achievementsCount,
      lastStreakDate: data.lastStreakDate,
      dailyXpDate: data.dailyXpDate,
      dailyXpAmount: data.dailyXpAmount,
      coinsEarned: data.coinsEarned,
      coinsBalance: data.coinsBalance,
      syncStatus: SyncStatusExtension.fromInt(data.syncStatus),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  /// Whether these stats have local changes not yet synced.
  bool get isPending => syncStatus == SyncStatus.pending;

  /// Whether these stats are synced with the server.
  bool get isSynced => syncStatus == SyncStatus.synced;

  /// Calculate XP progress towards next level.
  /// Each level requires 500 XP.
  int get xpForCurrentLevel => xpPoints % 500;

  /// XP required for next level.
  int get xpForNextLevel => 500;

  /// Progress percentage towards next level (0-100).
  double get levelProgress => (xpForCurrentLevel / xpForNextLevel) * 100;
}

/// Repository for user stats operations.
/// Implements offline-first pattern: reads from local, syncs from remote when online.
class UserStatsRepository {
  final UserStatsLocalDataSource _localDataSource;
  final UserStatsRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivity;
  final SyncQueue _syncQueue;

  UserStatsRepository({
    required UserStatsLocalDataSource localDataSource,
    required UserStatsRemoteDataSource remoteDataSource,
    required ConnectivityService connectivity,
    required SyncQueue syncQueue,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _connectivity = connectivity,
        _syncQueue = syncQueue;

  // ═══════════════════════════════════════════════════════════════════════════
  // Read Operations (always from local)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get stats for a user.
  /// Returns null if stats don't exist locally.
  Future<UserStats?> getUserStats(String userId) async {
    final data = await _localDataSource.getUserStats(userId);
    if (data == null) return null;
    return UserStats.fromTableData(data);
  }

  /// Get or create stats for a user.
  /// Creates default stats if none exist.
  Future<UserStats> getOrCreateUserStats(String userId) async {
    final data = await _localDataSource.getOrCreateStats(userId);
    return UserStats.fromTableData(data);
  }

  /// Watch stats for a user as a stream.
  Stream<UserStats?> watchUserStats(String userId) {
    return _localDataSource.watchUserStats(userId).map((data) {
      if (data == null) return null;
      return UserStats.fromTableData(data);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sync Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sync stats from server.
  /// Creates or updates local stats based on server data.
  Future<void> syncFromServer(String userId) async {
    final isOnline = await _connectivity.isOnline;
    if (!isOnline) return;

    final result = await _remoteDataSource.getUserStats();
    if (result.isFailure) return;

    final remoteStats = result.data!;
    final existingLocal = await _localDataSource.getUserStats(userId);

    await _localDataSource.upsertFromServer(
      serverId: remoteStats.id,
      userId: userId,
      level: remoteStats.level,
      xpPoints: remoteStats.xpPoints,
      coursesCount: remoteStats.coursesCount,
      streakDays: remoteStats.streakDays,
      achievementsCount: remoteStats.achievementsCount,
      coinsEarned: remoteStats.coinsEarned,
      coinsBalance: remoteStats.coinsBalance,
      lastStreakDate: remoteStats.lastStreakDate,
      serverUpdatedAt: remoteStats.updatedAt,
      existingLocalId: existingLocal?.id,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Streak Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update streak locally and sync to server.
  /// Falls back to sync queue if the API call fails or device is offline.
  Future<void> updateStreak({
    required String userId,
    required int streakDays,
    required DateTime lastStreakDate,
  }) async {
    final stats = await _localDataSource.getUserStats(userId);
    if (stats == null) return;

    // Always save locally first.
    await _localDataSource.updateStreak(
      localId: stats.id,
      streakDays: streakDays,
      lastStreakDate: lastStreakDate,
    );

    // Try direct API call, fall back to queue on failure.
    final isOnline = await _connectivity.isOnline;
    if (isOnline) {
      final result = await _remoteDataSource.updateUserStats(
        streakDays: streakDays,
        lastStreakDate: lastStreakDate,
      );
      if (result.isSuccess) return;
    }

    // Offline or API failed — enqueue for later sync.
    await _syncQueue.enqueue(
      tableName: 'user_stats',
      recordId: stats.id,
      operation: SyncOperation.update,
      payload: {
        'streak_days': streakDays,
        'last_streak_date': lastStreakDate.toIso8601String().split('T').first,
      },
    );
  }

  /// Check and update streak based on last activity date.
  /// Call this when user opens the app or completes an activity.
  Future<void> checkAndUpdateStreak(String userId) async {
    final stats = await _localDataSource.getUserStats(userId);
    if (stats == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = stats.lastStreakDate;

    if (lastDate == null) {
      // First activity - start streak at 1.
      await updateStreak(
        userId: userId,
        streakDays: 1,
        lastStreakDate: today,
      );
      return;
    }

    final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final difference = today.difference(lastDateOnly).inDays;

    if (difference == 0) {
      // Already active today - no change needed.
      return;
    } else if (difference == 1) {
      // Consecutive day - increment streak.
      await updateStreak(
        userId: userId,
        streakDays: stats.streakDays + 1,
        lastStreakDate: today,
      );
    } else {
      // Gap > 1 day — FREEZE streak (don't reset, don't increment).
      // Just update lastStreakDate to today so next consecutive day increments.
      await updateStreak(
        userId: userId,
        streakDays: stats.streakDays, // keep current value
        lastStreakDate: today,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // XP Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Award XP, applying course hard cap and daily soft cap.
  /// Returns the effective XP actually awarded (after caps).
  ///
  /// The caller is responsible for updating `courseXpEarned` in progressData.
  Future<int> awardXp({
    required String userId,
    required int rawXp,
    required int courseXpEarned,
    int? courseMaxXp,
  }) async {
    if (rawXp <= 0) return 0;

    // Real user activity counts as an active day even when XP is capped.
    // Bump streak before cap math so missed days don't silently freeze.
    await checkAndUpdateStreak(userId);

    final stats = await _localDataSource.getOrCreateStats(userId);
    final userStats = UserStats.fromTableData(stats);

    // Determine daily XP so far (reset if different day)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int dailyXpSoFar = userStats.dailyXpAmount;
    if (userStats.dailyXpDate != null) {
      final lastDate = userStats.dailyXpDate!;
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      if (lastDay != today) {
        dailyXpSoFar = 0; // New day — reset daily counter
      }
    } else {
      dailyXpSoFar = 0;
    }

    // Apply caps
    final effectiveXp = GamificationService.applyAllCaps(
      rawXp: rawXp,
      courseXpEarned: courseXpEarned,
      courseMaxXp: courseMaxXp,
      dailyXpSoFar: dailyXpSoFar,
    );

    if (effectiveXp <= 0) return 0;

    // Calculate new totals
    final newXpTotal = userStats.xpPoints + effectiveXp;
    final newLevel = GamificationService.calculateLevel(newXpTotal);
    final newDailyXp = dailyXpSoFar + effectiveXp;

    // Persist locally
    await _localDataSource.updateXp(
      localId: stats.id,
      xpPoints: newXpTotal,
      level: newLevel,
      dailyXpDate: today,
      dailyXpAmount: newDailyXp,
    );

    // Enqueue sync
    await _syncQueue.enqueue(
      tableName: 'user_stats',
      recordId: stats.id,
      operation: SyncOperation.update,
      payload: {
        'xp_points': newXpTotal,
        'level': newLevel,
        'daily_xp_date': today.toIso8601String().split('T').first,
        'daily_xp_amount': newDailyXp,
      },
    );

    return effectiveXp;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Coin Operations (BR-HK9828)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Credit EDUX coins earned on the device.
  ///
  /// Local first, like XP: a coin earned on a train has to be visible before
  /// the device is back online. The queued payload carries absolute totals
  /// rather than a delta, so a retry that lands twice credits once.
  ///
  /// Coins collected in a mini game do *not* come through here — the server
  /// banks those when the run reports its score, because it is the only party
  /// that knows the run was legitimate.
  Future<void> awardCoins({
    required String userId,
    required int amount,
  }) async {
    if (amount <= 0) return;

    final stats = await _localDataSource.getOrCreateStats(userId);

    final newEarned = stats.coinsEarned + amount;
    final newBalance = stats.coinsBalance + amount;

    await _localDataSource.updateCoins(
      localId: stats.id,
      coinsEarned: newEarned,
      coinsBalance: newBalance,
    );

    await _syncQueue.enqueue(
      tableName: 'user_stats',
      recordId: stats.id,
      operation: SyncOperation.update,
      payload: {
        'coins_earned': newEarned,
        'coins_balance': newBalance,
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Trophy Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Award a trophy (increment achievementsCount by 1).
  Future<void> awardTrophy(String userId) async {
    // Trophies imply an interaction worth counting toward the streak.
    await checkAndUpdateStreak(userId);

    final stats = await _localDataSource.getOrCreateStats(userId);

    final newCount = stats.achievementsCount + 1;
    await _localDataSource.incrementAchievements(
      localId: stats.id,
      achievementsCount: newCount,
    );

    // Enqueue sync
    await _syncQueue.enqueue(
      tableName: 'user_stats',
      recordId: stats.id,
      operation: SyncOperation.update,
      payload: {
        'achievements_count': newCount,
      },
    );
  }
}
