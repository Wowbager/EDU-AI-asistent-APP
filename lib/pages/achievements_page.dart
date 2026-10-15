import 'package:flutter/material.dart';
import '../core/gamification/achievement_evaluator.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';
import '../models/gamification_config_model.dart';
import '../models/skill_display_model.dart';
import '../widgets/detail_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/skill_card.dart';
import '../core/layout/breakpoints.dart';

/// Achievements page displaying user progress, trophies, goals and challenges.
///
/// Data is server-driven via [GamificationConfig]. The caller loads the config
/// and earned achievement IDs, then passes them in along with user stats.
class AchievementsPage extends StatefulWidget {
  final int level;
  final int currentXp;
  final int xpForNextLevel;
  final int totalXp;
  final int streakDays;
  final int trophiesCount;

  /// Lifetime EDUX coins the student has earned (BR-HK9828).
  final int coinsEarned;
  final int lessonsCompleted;
  final int coursesCompleted;
  final int quizzesCompleted;

  /// Server-driven config (nullable — page degrades gracefully).
  final GamificationConfig? config;

  /// Set of achievement IDs the user has already earned.
  final Set<String> earnedIds;

  /// Computed skill cards from the user's ELO profile.
  /// When null or empty, shows a placeholder message.
  final List<SkillDisplay>? skills;

  /// When true, auto-scrolls to the Dovednosti section on open.
  final bool scrollToSkills;

  const AchievementsPage({
    super.key,
    this.level = 1,
    this.currentXp = 0,
    this.xpForNextLevel = 500,
    this.totalXp = 0,
    this.streakDays = 1,
    this.trophiesCount = 0,
    this.coinsEarned = 0,
    this.lessonsCompleted = 0,
    this.coursesCompleted = 0,
    this.quizzesCompleted = 0,
    this.config,
    this.earnedIds = const {},
    this.skills,
    this.scrollToSkills = false,
  });

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final _skillsSectionKey = GlobalKey();

  /// Effective config: server-driven or default fallback.
  GamificationConfig get _config =>
      widget.config ?? GamificationConfig.defaultConfig;

  // Forward widget fields for less verbose access in build methods.
  int get level => widget.level;
  int get currentXp => widget.currentXp;
  int get xpForNextLevel => widget.xpForNextLevel;
  int get totalXp => widget.totalXp;
  int get streakDays => widget.streakDays;
  int get trophiesCount => widget.trophiesCount;
  int get coinsEarned => widget.coinsEarned;
  int get lessonsCompleted => widget.lessonsCompleted;
  int get coursesCompleted => widget.coursesCompleted;
  int get quizzesCompleted => widget.quizzesCompleted;
  Set<String> get earnedIds => widget.earnedIds;
  List<SkillDisplay>? get skills => widget.skills;

  @override
  void initState() {
    super.initState();
    if (widget.scrollToSkills) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSkills();
      });
    }
  }

  void _scrollToSkills() {
    final ctx = _skillsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.widthClass == WidthClass.compact) {
      return _buildPage(context, showHeader: true);
    }

    // Pushed above the shell on a wide viewport, so it redraws the navigation
    // itself — otherwise the page loses the sidebar the rest of the app has
    // (BR-5JSXBV). Titled rather than given a "back to …" link: it is opened
    // from the profile, the dashboard and a course detail alike, so there is no
    // single place "back" could name.
    return DetailShell(
      title: AppStrings.achievementsTitle,
      child: _buildPage(context, showHeader: false),
    );
  }

  /// [showHeader] is off beside the sidebar, where `DetailShell`'s top bar
  /// already carries the title.
  Widget _buildPage(BuildContext context, {required bool showHeader}) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        // The clamp sits inside the scaffold, not around it: the purple band
        // and the white sheet are the page's background and have to run the
        // full width of the content pane, while the content on them stays at a
        // readable measure.
        child: ContentWidth(
          maxWidth: ContentWidth.reading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purple header section (scrolls with content)
              _buildHeader(context, showHeader: showHeader),
              // White content section
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    // Trophies section
                    _buildTrophiesSection(),
                    const SizedBox(height: 32),
                    // Goals section
                    _buildGoalsSection(),
                    const SizedBox(height: 32),
                    // Challenges section
                    if (_hasChallenges) ...[
                      _buildChallengesSection(),
                      const SizedBox(height: 32),
                    ],
                    // Skills section
                    _buildSkillsSection(key: _skillsSectionKey),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasChallenges => _config.challenges.isNotEmpty;

  Widget _buildHeader(BuildContext context, {required bool showHeader}) {
    final xpRemaining = xpForNextLevel - currentXp;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              PageHeader(
                title: AppStrings.achievementsTitle,
                titleStyle: AppTextStyles.heading2Bold(color: Colors.white),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
            ],
            // Level beside Streak, Trophies beside EDUX coins (BR-HK9828).
            // Four cards of one shape rather than a full-width XP banner: the
            // banner's "progress bar" only ever drew the number, so nothing is
            // lost by giving it the same box as the rest.
            _buildStatRow([
              _buildStatCard(
                label: AppStrings.achievementsLvl(level),
                caption: AppStrings.achievementsXpRemaining(xpRemaining, level + 1),
                value:
                    '${_formatNumber(currentXp)} / ${_formatNumber(xpForNextLevel)} XP',
                icon: Icons.bolt,
                backgroundColor: AppColors.orange,
                labelColor: Colors.white,
              ),
              _buildStatCard(
                label: AppStrings.profileStatStreak,
                value: AppStrings.achievementsDaysCount(streakDays),
                icon: Icons.local_fire_department,
                backgroundColor: AppColors.cardYellow,
                labelColor: AppColors.primaryDark,
              ),
            ]),
            const SizedBox(height: 12),
            _buildStatRow([
              _buildStatCard(
                label: AppStrings.achievementsTrophies,
                value: trophiesCount.toString(),
                icon: Icons.emoji_events,
                backgroundColor: AppColors.cardYellow,
                labelColor: AppColors.primaryDark,
              ),
              _buildStatCard(
                label: AppStrings.achievementsCoins,
                value: _formatNumber(coinsEarned),
                icon: Icons.monetization_on,
                backgroundColor: AppColors.cardYellow,
                labelColor: AppColors.primaryDark,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// One row of the stat grid.
  ///
  /// [IntrinsicHeight] is what keeps the pair level: the Lvl card carries a
  /// caption line the others do not, and without it the yellow card beside it
  /// would end short of the orange one's bottom edge.
  Widget _buildStatRow(List<Widget> cards) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color labelColor,
    String? caption,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppDecorations.radiusXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label text
          Text(
            label,
            style: AppTextStyles.statValue(color: labelColor),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: AppTextStyles.meta(
                color: labelColor.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // White inner card with icon and value
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppDecorations.radiusM,
            ),
            child: Row(
              children: [
                // Gradient icon
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.xpGradient.createShader(bounds),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                // Half the width the banner had, and "1,250 / 1,500 XP" is the
                // longest string any of these cards can hold — scaling down is
                // what keeps it off the overflow stripes on a narrow phone.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: AppTextStyles.cardTitleSmall(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Trophies Section — config-driven
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTrophiesSection() {
    final trophies = _config.trophies;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.achievementsEarnedTrophies,
            style: AppTextStyles.heading3(),
          ),
          const SizedBox(height: 16),
          if (trophies.isEmpty)
            Text(
              AppStrings.achievementsSkillsPlaceholder,
              style: AppTextStyles.body(color: AppColors.primaryDark64),
            )
          else ...[
            // Trophy icon grid
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 17.0;
                final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: trophies.map((t) => _buildTrophyIcon(
                    trophy: t,
                    isEarned: earnedIds.contains(t.id),
                    size: itemWidth,
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            // Earned trophies detail list
            ...trophies
                .where((t) => earnedIds.contains(t.id))
                .map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAchievementCard(t, isEarned: true),
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildTrophyIcon({
    required AchievementDef trophy,
    required bool isEarned,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: isEarned ? AppDecorations.shadowStrong : null,
      ),
      child: Center(
        child: Opacity(
          opacity: isEarned ? 1.0 : 0.24,
          child: Text(
            trophy.icon.isNotEmpty ? trophy.icon : '\u{1F3C6}',
            style: const TextStyle(fontSize: 48),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Goals Section — config-driven with progress bars
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGoalsSection() {
    final goals = _config.goals;

    // Show unearned goals first (with progress), then earned.
    final unearnedGoals = goals.where((g) => !earnedIds.contains(g.id)).toList();
    final earnedGoals = goals.where((g) => earnedIds.contains(g.id)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.achievementsGoals,
            style: AppTextStyles.heading3(),
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Text(
              AppStrings.achievementsSkillsPlaceholder,
              style: AppTextStyles.body(color: AppColors.primaryDark64),
            )
          else ...[
            ...unearnedGoals.map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildGoalCard(goal),
                )),
            ...earnedGoals.map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAchievementCard(goal, isEarned: true),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalCard(AchievementDef goal) {
    final (current, target) = AchievementEvaluator.getProgress(
      condition: goal.condition,
      totalXp: totalXp,
      streakDays: streakDays,
      lessonsCompleted: lessonsCompleted,
      coursesCompleted: coursesCompleted,
      quizzesCompleted: quizzesCompleted,
      level: level,
    );
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        border: Border.all(
          color: AppColors.primaryDark08,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (goal.icon.isNotEmpty) ...[
                Text(goal.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  goal.title,
                  style: AppTextStyles.statValue(),
                ),
              ),
              if (goal.xpReward > 0)
                _buildXpBadge(goal.xpReward),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              goal.description,
              style: AppTextStyles.meta(
                color: AppColors.primaryDark64,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: AppDecorations.radiusXS,
                ),
                child: const Icon(
                  Icons.flag,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProgressBar(current, target, progress),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int current, int target, double progress) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppDecorations.radiusXS,
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: AppDecorations.radiusXS,
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                '$current/$target',
                style: AppTextStyles.progressCount(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Challenges Section — config-driven
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChallengesSection() {
    final challenges = _config.challenges;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.achievementsChallenges,
            style: AppTextStyles.heading3(),
          ),
          const SizedBox(height: 16),
          ...challenges.map((c) {
            final isEarned = earnedIds.contains(c.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: isEarned
                  ? _buildAchievementCard(c, isEarned: true)
                  : _buildGoalCard(c),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Skills Section — placeholder
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSkillsSection({Key? key}) {
    return _SkillsSectionContent(key: key, skills: skills ?? const []);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Widgets
  // ═══════════════════════════════════════════════════════════════════════════

  /// Card for an earned achievement (trophy, goal, or challenge).
  Widget _buildAchievementCard(AchievementDef achievement, {required bool isEarned}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        border: Border.all(
          color: isEarned ? AppColors.orange.withValues(alpha: 0.3) : AppColors.primaryDark08,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isEarned ? AppColors.orange16 : AppColors.background,
              borderRadius: AppDecorations.radiusS,
            ),
            child: Center(
              child: Text(
                achievement.icon.isNotEmpty ? achievement.icon : '\u{1F3C6}',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: AppTextStyles.statValue(),
                ),
                if (achievement.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: AppTextStyles.meta(
                      color: AppColors.primaryDark64,
                    ),
                  ),
                ],
                if (achievement.xpReward > 0) ...[
                  const SizedBox(height: 6),
                  _buildXpBadge(achievement.xpReward),
                ],
              ],
            ),
          ),
          if (isEarned)
            Icon(
              Icons.check_circle,
              color: AppColors.orange,
              size: 24,
            ),
        ],
      ),
    );
  }

  Widget _buildXpBadge(int xpReward) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.orange16,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            color: AppColors.orange,
            size: 14,
          ),
          const SizedBox(width: 2),
          Text(
            '+$xpReward XP',
            style: AppTextStyles.badge(
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Skills Section — stateful for tab filtering
// ═══════════════════════════════════════════════════════════════════════════

class _SkillsSectionContent extends StatefulWidget {
  final List<SkillDisplay> skills;
  const _SkillsSectionContent({super.key, required this.skills});

  @override
  State<_SkillsSectionContent> createState() => _SkillsSectionContentState();
}

class _SkillsSectionContentState extends State<_SkillsSectionContent> {
  int _selectedTab = 0;

  List<String> get _tabs => [
        AppStrings.skillTabAll,
        AppStrings.skillTabBeginner,
        AppStrings.skillTabIntermediate,
        AppStrings.skillTabExpert,
      ];

  static const _tabToDifficulty = {
    1: 'beginner',
    2: 'intermediate',
    3: 'expert',
  };

  List<SkillDisplay> get _filteredSkills {
    // Only show skills that have real ELO data.
    final withData = widget.skills.where((s) => s.hasData).toList();
    if (_selectedTab == 0) return withData;
    final difficulty = _tabToDifficulty[_selectedTab];
    return withData.where((s) => s.difficulty == difficulty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSkills;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.achievementsSkills,
            style: AppTextStyles.heading3(),
          ),
          const SizedBox(height: 16),

          // ── Tab chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final isSelected = i == _selectedTab;
                return Padding(
                  padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: AppDecorations.radiusPill,
                      ),
                      child: Text(
                        _tabs[i],
                        style: AppTextStyles.chipLabelNunito(
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryDark64,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // ── Skill cards ──
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppStrings.achievementsSkillsPlaceholder,
                style: AppTextStyles.body(color: AppColors.primaryDark64),
              ),
            )
          else
            ...filtered.map((skill) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SkillCard(
                    title: skill.name,
                    subtitle: skill.category,
                    emoji: skill.emoji,
                    level: skill.level,
                    confidenceLow: skill.confidenceLow,
                    confidenceHigh: skill.confidenceHigh,
                  ),
                )),
        ],
      ),
    );
  }
}
