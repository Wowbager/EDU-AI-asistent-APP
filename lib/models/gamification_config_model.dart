import 'dart:convert';

import '../core/strings/app_strings.dart';

/// Parsed gamification config from the server.
/// Contains definitions for levels, trophies, goals, and challenges.
class GamificationConfig {
  final int version;
  final List<LevelDef> levels;
  final List<AchievementDef> trophies;
  final List<AchievementDef> goals;
  final List<AchievementDef> challenges;

  const GamificationConfig({
    required this.version,
    this.levels = const [],
    this.trophies = const [],
    this.goals = const [],
    this.challenges = const [],
  });

  factory GamificationConfig.fromJson(Map<String, dynamic> json) {
    return GamificationConfig(
      version: json['version'] as int? ?? 1,
      levels: _parseList(json['levels'], LevelDef.fromJson),
      trophies: _parseList(json['trophies'], AchievementDef.fromJson),
      goals: _parseList(json['goals'], AchievementDef.fromJson),
      challenges: _parseList(json['challenges'], AchievementDef.fromJson),
    );
  }

  factory GamificationConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return GamificationConfig.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'levels': levels.map((l) => l.toJson()).toList(),
    'trophies': trophies.map((a) => a.toJson()).toList(),
    'goals': goals.map((a) => a.toJson()).toList(),
    'challenges': challenges.map((a) => a.toJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());

  /// All achievement definitions across all categories.
  List<AchievementDef> get allAchievements => [
    ...trophies,
    ...goals,
    ...challenges,
  ];

  /// Default config used before server config is downloaded.
  /// Also serves as API contract documentation.
  ///
  /// Not `const` because titles/descriptions read from `AppStrings`,
  /// which is locale-aware and resolved at access time.
  static final GamificationConfig defaultConfig = GamificationConfig(
    version: 1,
    levels: [
      LevelDef(level: 1, xpRequired: 0, title: AppStrings.levelTitle1, icon: '\u{1F331}'),
      LevelDef(level: 2, xpRequired: 500, title: AppStrings.levelTitle2, icon: '\u{1F4DA}'),
      LevelDef(level: 3, xpRequired: 1000, title: AppStrings.levelTitle3, icon: '\u{1F393}'),
      LevelDef(level: 4, xpRequired: 1500, title: AppStrings.levelTitle4, icon: '\u{2B50}'),
      LevelDef(level: 5, xpRequired: 2000, title: AppStrings.levelTitle5, icon: '\u{1F4A1}'),
      LevelDef(level: 6, xpRequired: 2500, title: AppStrings.levelTitle6, icon: '\u{1F451}'),
      LevelDef(level: 7, xpRequired: 3000, title: AppStrings.levelTitle7, icon: '\u{1F9D9}'),
      LevelDef(level: 8, xpRequired: 4000, title: AppStrings.levelTitle8, icon: '\u{1F3C6}'),
      LevelDef(level: 9, xpRequired: 5000, title: AppStrings.levelTitle9, icon: '\u{1F680}'),
      LevelDef(level: 10, xpRequired: 7500, title: AppStrings.levelTitle10, icon: '\u{1F30C}'),
    ],
    trophies: [
      AchievementDef(
        id: 'trophy_first_lesson',
        title: AppStrings.trophyFirstLessonTitle,
        description: AppStrings.trophyFirstLessonDesc,
        icon: '\u{1F3C6}',
        xpReward: 25,
        condition: AchievementCondition(type: 'lessons_completed', value: 1),
        category: 'trophy',
      ),
      AchievementDef(
        id: 'trophy_five_lessons',
        title: AppStrings.trophyDiligentStudentTitle,
        description: AppStrings.trophyDiligentStudentDesc,
        icon: '\u{1F4DA}',
        xpReward: 50,
        condition: AchievementCondition(type: 'lessons_completed', value: 5),
        category: 'trophy',
      ),
      AchievementDef(
        id: 'trophy_first_quiz',
        title: AppStrings.trophyQuizNoviceTitle,
        description: AppStrings.trophyQuizNoviceDesc,
        icon: '\u{1F9E0}',
        xpReward: 30,
        condition: AchievementCondition(type: 'quizzes_completed', value: 1),
        category: 'trophy',
      ),
      AchievementDef(
        id: 'trophy_first_course',
        title: AppStrings.trophyMasterpieceTitle,
        description: AppStrings.trophyMasterpieceDesc,
        icon: '\u{1F9EC}',
        xpReward: 100,
        condition: AchievementCondition(type: 'courses_completed', value: 1),
        category: 'trophy',
      ),
      AchievementDef(
        id: 'trophy_week_streak',
        title: AppStrings.trophyWeekStreak,
        description: AppStrings.trophyWeekStreakDesc,
        icon: '\u{1F525}',
        xpReward: 50,
        condition: AchievementCondition(type: 'streak_days', value: 7),
        category: 'trophy',
      ),
      AchievementDef(
        id: 'trophy_month_streak',
        title: AppStrings.trophyMonthStreakTitle,
        description: AppStrings.trophyMonthStreakDesc,
        icon: '\u{1F4AA}',
        xpReward: 150,
        condition: AchievementCondition(type: 'streak_days', value: 30),
        category: 'trophy',
      ),
    ],
    goals: [
      AchievementDef(
        id: 'goal_xp_100',
        title: AppStrings.goal100XpTitle,
        description: AppStrings.goalXpDesc,
        icon: '\u{26A1}',
        xpReward: 10,
        condition: AchievementCondition(type: 'total_xp', value: 100),
        category: 'goal',
      ),
      AchievementDef(
        id: 'goal_xp_500',
        title: AppStrings.goal500XpTitle,
        description: AppStrings.goalXpDesc,
        icon: '\u{26A1}',
        xpReward: 50,
        condition: AchievementCondition(type: 'total_xp', value: 500),
        category: 'goal',
      ),
      AchievementDef(
        id: 'goal_xp_1000',
        title: AppStrings.goal1000XpTitle,
        description: AppStrings.goalXpDesc,
        icon: '\u{26A1}',
        xpReward: 100,
        condition: AchievementCondition(type: 'total_xp', value: 1000),
        category: 'goal',
      ),
      AchievementDef(
        id: 'goal_streak_3',
        title: AppStrings.goal3DayStreakTitle,
        description: AppStrings.goalDailyStreakDesc,
        icon: '\u{1F525}',
        xpReward: 15,
        condition: AchievementCondition(type: 'streak_days', value: 3),
        category: 'goal',
      ),
      AchievementDef(
        id: 'goal_streak_14',
        title: AppStrings.goal14DayStreakTitle,
        description: AppStrings.goalDailyStreakDesc,
        icon: '\u{1F525}',
        xpReward: 70,
        condition: AchievementCondition(type: 'streak_days', value: 14),
        category: 'goal',
      ),
      AchievementDef(
        id: 'goal_level_3',
        title: AppStrings.goalLevel3Title,
        description: AppStrings.goalLevelDesc,
        icon: '\u{2B50}',
        xpReward: 50,
        condition: AchievementCondition(type: 'level', value: 3),
        category: 'goal',
      ),
      AchievementDef(
        id: 'goal_lessons_10',
        title: AppStrings.goalComplete10LessonsTitle,
        description: AppStrings.goalPracticeDesc,
        icon: '\u{1F4DA}',
        xpReward: 60,
        condition: AchievementCondition(type: 'lessons_completed', value: 10),
        category: 'goal',
      ),
    ],
    challenges: [
      AchievementDef(
        id: 'challenge_xp_5000',
        title: AppStrings.challenge5000XpTitle,
        description: AppStrings.challenge5000XpDesc,
        icon: '\u{1F48E}',
        xpReward: 500,
        condition: AchievementCondition(type: 'total_xp', value: 5000),
        type: 'lifetime',
        category: 'challenge',
      ),
      AchievementDef(
        id: 'challenge_courses_3',
        title: AppStrings.challenge3CoursesTitle,
        description: AppStrings.challenge3CoursesDesc,
        icon: '\u{1F680}',
        xpReward: 200,
        condition: AchievementCondition(type: 'courses_completed', value: 3),
        type: 'lifetime',
        category: 'challenge',
      ),
      AchievementDef(
        id: 'challenge_streak_60',
        title: AppStrings.challenge60DayStreakTitle,
        description: AppStrings.challenge60DayStreakDesc,
        icon: '\u{1F30B}',
        xpReward: 300,
        condition: AchievementCondition(type: 'streak_days', value: 60),
        type: 'lifetime',
        category: 'challenge',
      ),
    ],
  );

  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }
}

/// A level definition from the config.
class LevelDef {
  final int level;
  final int xpRequired;
  final String title;
  final String icon;

  const LevelDef({
    required this.level,
    required this.xpRequired,
    this.title = '',
    this.icon = '',
  });

  factory LevelDef.fromJson(Map<String, dynamic> json) {
    return LevelDef(
      level: json['level'] as int? ?? 1,
      xpRequired: json['xp_required'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp_required': xpRequired,
    'title': title,
    'icon': icon,
  };
}

/// A trophy, goal, or challenge definition.
class AchievementDef {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int xpReward;
  /// EDUX coins granted alongside the XP (BR-HK9828).
  final int coinReward;
  final AchievementCondition condition;
  /// For challenges: "daily" or "weekly".
  final String? type;
  /// Which category this belongs to: "trophy", "goal", "challenge".
  final String category;

  const AchievementDef({
    required this.id,
    required this.title,
    this.description = '',
    this.icon = '',
    this.xpReward = 0,
    this.coinReward = 0,
    required this.condition,
    this.type,
    this.category = 'trophy',
  });

  factory AchievementDef.fromJson(Map<String, dynamic> json) {
    return AchievementDef(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      xpReward: json['xp_reward'] as int? ?? 0,
      coinReward: json['coin_reward'] as int? ?? 0,
      condition: json['condition'] != null
          ? AchievementCondition.fromJson(json['condition'] as Map<String, dynamic>)
          : const AchievementCondition(type: 'none', value: 0),
      type: json['type'] as String?,
      category: json['category'] as String? ?? 'trophy',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'xp_reward': xpReward,
    'coin_reward': coinReward,
    'condition': condition.toJson(),
    if (type != null) 'type': type,
    'category': category,
  };
}

/// Condition that must be met to earn an achievement.
class AchievementCondition {
  /// Condition type: "total_xp", "streak_days", "lessons_completed",
  /// "courses_completed", "quizzes_completed", "level", "none".
  final String type;

  /// Threshold value to meet or exceed.
  final int value;

  const AchievementCondition({
    required this.type,
    required this.value,
  });

  factory AchievementCondition.fromJson(Map<String, dynamic> json) {
    return AchievementCondition(
      type: json['type'] as String? ?? 'none',
      value: json['value'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
  };
}
