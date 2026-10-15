import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Remote user stats data from the API.
class RemoteUserStats {
  final int id;
  final int userId;
  final int level;
  final int xpPoints;
  final int coursesCount;
  final int streakDays;
  final int achievementsCount;
  final int coinsEarned;
  final int coinsBalance;
  final DateTime? lastStreakDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  RemoteUserStats({
    required this.id,
    required this.userId,
    required this.level,
    required this.xpPoints,
    required this.coursesCount,
    required this.streakDays,
    required this.achievementsCount,
    this.coinsEarned = 0,
    this.coinsBalance = 0,
    this.lastStreakDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteUserStats.fromJson(Map<String, dynamic> json) {
    return RemoteUserStats(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      level: json['level'] as int? ?? 1,
      xpPoints: json['xp_points'] as int? ?? 0,
      coursesCount: json['courses_count'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      achievementsCount: json['achievements_count'] as int? ?? 0,
      // Absent when the app talks to an API older than the wallet — a zero
      // there is "not reported", and the local total stays whatever it was.
      coinsEarned: json['coins_earned'] as int? ?? 0,
      coinsBalance: json['coins_balance'] as int? ?? 0,
      lastStreakDate: json['last_streak_date'] != null
          ? DateTime.parse(json['last_streak_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'level': level,
      'xp_points': xpPoints,
      'courses_count': coursesCount,
      'streak_days': streakDays,
      'achievements_count': achievementsCount,
      'coins_earned': coinsEarned,
      'coins_balance': coinsBalance,
      'last_streak_date': lastStreakDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Remote data source for user stats using the API.
class UserStatsRemoteDataSource {
  final ApiClient _apiClient;

  UserStatsRemoteDataSource(this._apiClient);

  /// Fetch the current user's stats from the API.
  Future<ApiResult<RemoteUserStats>> getUserStats() async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.userStats,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final statsJson = result.data!['stats'] as Map<String, dynamic>;
      return ApiResult.success(RemoteUserStats.fromJson(statsJson));
    } catch (e) {
      return ApiResult.failure('Failed to parse user stats: $e');
    }
  }

  /// Update the current user's stats on the server.
  /// Currently only streak-related fields can be updated.
  Future<ApiResult<RemoteUserStats>> updateUserStats({
    int? streakDays,
    DateTime? lastStreakDate,
  }) async {
    final updateData = <String, dynamic>{};

    if (streakDays != null) updateData['streak_days'] = streakDays;
    if (lastStreakDate != null) {
      updateData['last_streak_date'] = lastStreakDate.toIso8601String().split('T').first;
    }

    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.userStats,
      data: updateData,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final statsJson = result.data!['stats'] as Map<String, dynamic>;
      return ApiResult.success(RemoteUserStats.fromJson(statsJson));
    } catch (e) {
      return ApiResult.failure('Failed to parse updated stats: $e');
    }
  }
}
