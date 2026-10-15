import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/elo/elo_engine.dart';
import '../core/elo/gpf_structure.dart';
import '../core/gamification/dashboard_tiers.dart';
import '../core/gamification/global_quiz.dart';
import '../core/gamification/global_quiz_selection.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/practice_providers.dart';
import '../core/util/silent_log.dart';
import '../data/repositories/user_course_repository.dart';
import '../data/repositories/user_stats_repository.dart';
import '../models/chat_models.dart';
import '../models/course_card_view.dart';
import '../models/course_model.dart';
import '../routing/tab_routes.dart';
import '../utils/achievement_stats.dart';
import '../widgets/widgets.dart';
import 'achievements_page.dart';
import 'chat_detail_page.dart';
import 'course_detail_page.dart';
import 'knihovna_page.dart';
import 'lesson_detail_page.dart';
import 'practice_page.dart';
import 'quiz_page.dart';
import 'course_quiz_launch.dart';
import 'shop_page.dart';
import '../core/layout/breakpoints.dart';
import '../core/util/shell_route.dart';

/// Selected chip of the dashboard's "Moje kurzy" grid.
///
/// A provider rather than page state because [PrehledPage] is a
/// `ConsumerWidget` and this is the only thing on it that needs to persist
/// across a rebuild.
final _dashboardCourseFilterProvider = StateProvider<int>((ref) => 0);

/// How many course tiles the dashboard shows before "Zobrazit všechny".
const int _dashboardCourseLimit = 4;

/// `courses.course_id` of the onboarding course behind the "Začněte s návodem"
/// challenge.
const String _onboardingCourseId = 'EDU_ONBOARDING_APP';

/// `courses.course_id` of the entrance-exam (JPZ) intro course behind the
/// "Uvažuješ o přijímačkách?" banner.
const String _jpzIntroCourseId = 'EDU_JPZ_INTRO';

/// Whether the JPZ intro course has reached this device.
///
/// The banner below the Cermatík threshold has nowhere to go without it, so it
/// hides rather than dead-ends. Watching the course stream (not just reading
/// the table once) means a course that arrives with a later sync brings the
/// banner with it, without an app restart.
final _jpzCourseAvailableProvider = FutureProvider<bool>((ref) async {
  ref.watch(coursesStreamProvider);
  final db = ref.watch(appDatabaseProvider);
  return await db.getCourseByFieldCourseId(_jpzIntroCourseId) != null;
});

/// Index of the Kurzy tab, for the "show all" link.
const int _kurzyTabIndex = 3;

/// The wide "Začněte s návodem" card. Named so the layout tests can measure it
/// against the button it has to keep inside itself (BR-USWXWV).
const Key guideCardKey = Key('dashboard-guide-card');

List<String> get _dashboardFilters => [
      AppStrings.filterAll,
      AppStrings.filterInProgress,
      AppStrings.filterNotStarted,
      AppStrings.filterCompleted,
    ];

/// The lesson the learner is currently inside, plus the numbers the
/// "Pokračuj v lekci" rail card needs.
class _CurrentLesson {
  final UserCourse userCourse;
  final Course course;
  final Lesson lesson;
  final int lessonIndex;
  final int stepsDone;
  final int stepsTotal;

  const _CurrentLesson({
    required this.userCourse,
    required this.course,
    required this.lesson,
    required this.lessonIndex,
    required this.stepsDone,
    required this.stepsTotal,
  });

  String get label =>
      '${AppStrings.lessonFallbackName(lessonIndex + 1)}: ${lesson.title}';
}

/// Dashboard.
///
/// One set of sections, two arrangements:
/// * phone/tablet — a single scrolling column, unchanged from the original
///   layout (each section pads itself by 16, carousels bleed to the edges).
/// * desktop — a two-thirds main column plus a 340px rail carrying progress,
///   the current lesson and recent activity, with the carousels turned into
///   grids.
///
/// The inline header (logo, XP, Doplňky, profile) is phone-only: from tablet
/// width up the shell's sidebar carries all four, so drawing it again would
/// duplicate the chrome (BR-H98WYB).
class PrehledPage extends ConsumerWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenDoplnky;
  final String? userName;
  final Map<String, QuizProgress> quizProgressCache;

  const PrehledPage({
    super.key,
    this.onOpenDrawer,
    this.onOpenDoplnky,
    this.userName,
    required this.quizProgressCache,
  });

  /// Width of the dashboard rail. Wide enough for the progress ring plus its
  /// caption without the two colliding.
  static const double _railWidth = 340;

  void _openAchievements(
      BuildContext context, WidgetRef ref, UserStats? stats) async {
    final config = ref.read(gamificationConfigProvider).valueOrNull;
    final earnedIds =
        ref.read(earnedAchievementsProvider).valueOrNull ?? <String>[];

    // Refresh skills to get latest data (may fetch from API if not synced yet).
    ref.invalidate(skillDisplayProvider);
    final skills = await ref.read(skillDisplayProvider.future);

    // Count lessons/courses/quizzes from user courses
    final userCourses = ref.read(userCoursesStreamProvider).valueOrNull ?? [];
    final counts = countAchievementStats(userCourses);

    if (!context.mounted) return;
    Navigator.of(context).push(
      shellPageRoute(
        context,
        builder: (_) => AchievementsPage(
          level: stats?.level ?? 1,
          currentXp: stats?.xpForCurrentLevel ?? 0,
          xpForNextLevel: stats?.xpForNextLevel ?? 500,
          totalXp: stats?.xpPoints ?? 0,
          streakDays: stats?.streakDays ?? 1,
          trophiesCount: stats?.achievementsCount ?? 0,
          coinsEarned: stats?.coinsEarned ?? 0,
          lessonsCompleted: counts.lessons,
          coursesCompleted: counts.courses,
          quizzesCompleted: counts.quizzes,
          config: config,
          earnedIds: earnedIds.toSet(),
          skills: skills,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCoursesAsync = ref.watch(userCoursesStreamProvider);
    final stats = ref.watch(userStatsStreamProvider).valueOrNull;
    final dueCount = ref.watch(dueCardsCountProvider).valueOrNull ?? 0;
    // The count above already respects the student's practice scope, so the
    // tile has to be able to say when *the selection* is what emptied it.
    final practiceScoped = !ref.watch(practiceFilterProvider).isAll;
    // Watched here rather than inside the LayoutBuilder below: that callback
    // runs during layout, and a dependency registered there would ask for a
    // rebuild mid-layout.
    final jpzCourseAvailable =
        ref.watch(_jpzCourseAvailableProvider).valueOrNull ?? false;
    final screen = context.widthClass;
    final isMobile = screen == WidthClass.compact;
    final isDesktop = screen == WidthClass.expanded;

    // Tests are hidden from the dashboard by design — including the "Rychlé
    // kvízy" challenge, which is built from this same list (BR-E495XK).
    final visibleCourses = (userCoursesAsync.valueOrNull ?? const <UserCourse>[])
        .where((uc) => !uc.isOnlyOnce)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final outerPad = isMobile ? 16.0 : 32.0;
        final contentWidth = constraints.maxWidth - outerPad * 2;
        final withRail = hasSideRail(contentWidth);
        final mainWidth =
            withRail ? contentWidth - _railWidth - 24 : contentWidth;

        final sections = _buildSections(
          context: context,
          ref: ref,
          stats: stats,
          xp: stats?.xpPoints ?? 0,
          jpzCourseAvailable: jpzCourseAvailable,
          dueCount: dueCount,
          practiceScoped: practiceScoped,
          userCoursesAsync: userCoursesAsync,
          visibleCourses: visibleCourses,
          isMobile: isMobile,
          isDesktop: isDesktop,
          gridColumns: gridColumns(mainWidth),
        );

        if (isMobile) {
          // Untouched phone layout: sections pad themselves, carousels bleed.
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                ...sections,
                // Bottom padding to account for bottom nav
                const SizedBox(height: 120),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(outerPad, 8, outerPad, 40),
            child: withRail
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sections,
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: _railWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildRail(
                            context: context,
                            ref: ref,
                            stats: stats,
                            visibleCourses: visibleCourses,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections,
                  ),
          ),
        );
      },
    );
  }

  // ── Main column ───────────────────────────────────────────────────────

  List<Widget> _buildSections({
    required BuildContext context,
    required WidgetRef ref,
    required UserStats? stats,
    required int xp,
    required bool jpzCourseAvailable,
    required int dueCount,
    required bool practiceScoped,
    required AsyncValue<List<UserCourse>> userCoursesAsync,
    required List<UserCourse> visibleCourses,
    required bool isMobile,
    required bool isDesktop,
    required int gridColumns,
  }) {
    // On phones every section pads itself; wider layouts pad the whole column
    // once, so the per-section padding would double up.
    Widget pad(Widget child) => isMobile
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          )
        : child;

    // The challenge slot holds the onboarding course while the learner is new
    // and practice from `practiceInsteadOfGuide` XP on (BR-ERUJBY) — past that
    // point the tile stands even with nothing due, because it is the learner's
    // standing invitation and its own copy covers the empty case.
    //
    // Below the threshold practice still joins the guide whenever something is
    // genuinely due, or when the student narrowed the scope themselves: hiding
    // it then would hide the only way back to the picker that emptied it.
    final practiceSection = [
      pad(Text(AppStrings.practiceTitle, style: AppTextStyles.heading1())),
      const SizedBox(height: 16),
      pad(_buildPracticeCard(context, dueCount, scoped: practiceScoped)),
    ];

    return [
      // Every layout with a sidebar already carries the logo, the XP, Doplňky
      // and the profile in it — so the inline header only belongs on the
      // phone. It used to be dropped on `isDesktop` alone, which left the
      // tablet rail showing a second logo beside the first (BR-H98WYB).
      if (isMobile) ...[
        pad(_buildHeaderRow(context, ref, stats)),
        const SizedBox(height: 16),
      ],
      // The greeting is content, not chrome: it stays wherever there is no top
      // bar to carry it.
      if (!isDesktop) ...[
        pad(_buildWelcomeCard(xp)),
        const SizedBox(height: 16),
      ],
      pad(_buildStatsRow(context, ref, stats, xp, isMobile: isMobile)),
      const SizedBox(height: 24),
      if (DashboardTiers.showsPractice(xp))
        ...practiceSection
      else ...[
        pad(Text(AppStrings.guideHeading, style: AppTextStyles.heading1())),
        const SizedBox(height: 16),
        pad(_buildGuideCard(context, ref, userCoursesAsync,
            isMobile: isMobile)),
        if (dueCount > 0 || practiceScoped) ...[
          const SizedBox(height: 24),
          ...practiceSection,
        ],
      ],
      const SizedBox(height: 16),
      pad(_buildPromoCard(context, xp)),
      ..._buildGlobalQuizSection(
        context: context,
        ref: ref,
        visibleCourses: visibleCourses,
        pad: pad,
      ),
      ..._buildJpzSection(
        context: context,
        ref: ref,
        xp: xp,
        courseAvailable: jpzCourseAvailable,
        userCoursesAsync: userCoursesAsync,
        pad: pad,
      ),
      ..._buildCourseSections(
        context: context,
        ref: ref,
        userCoursesAsync: userCoursesAsync,
        visibleCourses: visibleCourses,
        isMobile: isMobile,
        gridColumns: gridColumns,
      ),
    ];
  }

  Widget _buildHeaderRow(
      BuildContext context, WidgetRef ref, UserStats? stats) {
    return Row(
      children: [
        // Single-fill mark: a filter is all it takes to follow the palette.
        SvgPicture.asset(
          'assets/logo.svg',
          height: 40,
          colorFilter:
              ColorFilter.mode(AppColors.progressFill, BlendMode.srcIn),
        ),
        const Spacer(),
        // Level + XP indicator
        GestureDetector(
          onTap: () => _openAchievements(context, ref, stats),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark06,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: AppColors.headerGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${stats?.level ?? 1}',
                      style: AppTextStyles.badge(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${stats?.xpPoints ?? 0} XP',
                  style: AppTextStyles.actionSmall(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Doplňky button - mini games, avatar editor and themes in one place
        GestureDetector(
          onTap: onOpenDoplnky,
          child: Container(
            width: 48,
            height: 48,
            decoration: AppDecorations.circleButton,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/doplnky.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  AppColors.primaryDark,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Search button hidden (TODO: re-enable when ready)
        // Personalisation button - opens drawer
        GestureDetector(
          onTap: onOpenDrawer,
          child: Container(
            width: 48,
            height: 48,
            decoration: AppDecorations.circleButton,
            child: const Center(
              // Three-colour face — srcIn would flatten the eyes away.
              child: ThemedSvg(
                'assets/icons/personalisation.svg',
                width: 24,
                height: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(int xp) {
    return WelcomeCard(
      title: userName != null && userName!.isNotEmpty
          ? userName!
          : AppStrings.welcomeGreeting,
      // Same tier text the desktop shell puts under the greeting, so the two
      // layouts never say different things to the same learner.
      description: DashboardTiers.greetingSubtitle(xp),
      illustrationPath: 'assets/images/skins_bg.png',
      onTap: () {
        // TODO: Navigate to profile or achievements
      },
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    WidgetRef ref,
    UserStats? stats,
    int xp, {
    required bool isMobile,
  }) {
    void openAchievements() => _openAchievements(context, ref, stats);
    void openShop() => Navigator.of(context).push(
          shellPageRoute(context, builder: (_) => const ShopPage()),
        );
    final days = stats?.streakDays ?? 1;
    final trophies = stats?.achievementsCount ?? 0;
    // Past `shopInsteadOfTrophies` the second half-tile turns into the avatar
    // shop (BR-ERUJBY). Trophies do not become unreachable: the streak tile and
    // the XP badge both still open the achievements screen.
    final showsShop = DashboardTiers.showsShop(xp);

    // Wide layouts get the design's tall panels; the compact pills would leave
    // most of a 600px column empty.
    return Row(
      children: [
        Expanded(
          child: isMobile
              ? StatCard.streak(days: days, onTap: openAchievements)
              : BigStatCard.streak(
                  days: days, xp: xp, onTap: openAchievements),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: showsShop
              ? (isMobile
                  ? StatCard.shop(onTap: openShop)
                  : BigStatCard.shop(xp: xp, onTap: openShop))
              : (isMobile
                  ? StatCard.trophies(count: trophies, onTap: openAchievements)
                  : BigStatCard.trophies(
                      count: trophies, xp: xp, onTap: openAchievements)),
        ),
      ],
    );
  }

  /// Open a course the dashboard links by its `courses.course_id`, repairing a
  /// metadata-only row on the way in.
  ///
  /// These courses are opened straight from local data — they are never added
  /// via Knihovna, the only other path that pulls full content from R2. A fresh
  /// account often holds only a metadata-only catalog row (`data = '{}'`,
  /// seeded by sync) or a bundled row the server has since superseded; both
  /// render CourseDetailPage's "corrupted" panel (0 lekcí). So ensure the
  /// lessons/blocks payload is present before navigating (BR-V72RWM).
  ///
  /// Online, the server is asked for a newer version first, so a fresh install
  /// opens the current intro course instead of the one bundled with the build
  /// and then offering an update a moment later (BR-6CEUUB).
  Future<void> _openLocalCourse(
    BuildContext context,
    WidgetRef ref, {
    required String fieldCourseId,
    required AsyncValue<List<UserCourse>> userCoursesAsync,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final courseRepo = ref.read(courseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    final initial = await db.getCourseByFieldCourseId(fieldCourseId);
    if (initial == null || !context.mounted) return;
    var row = initial;

    final refreshed = await courseRepo.refreshOutdatedContent(row.id);
    if (refreshed) {
      row = await db.getCourseById(row.id) ?? row;
    }
    if (!context.mounted) return;

    var data = jsonDecode(row.data) as Map<String, dynamic>;
    if ((data['lessons'] as List<dynamic>?)?.isNotEmpty != true) {
      await courseRepo.downloadFullCourseJson(row.id);
      final refreshed = await db.getCourseByFieldCourseId(fieldCourseId);
      if (refreshed != null) row = refreshed;
      data = jsonDecode(row.data) as Map<String, dynamic>;
    }

    if ((data['lessons'] as List<dynamic>?)?.isNotEmpty != true) {
      // Still empty (e.g. offline with no bundled fallback). Surface a hint
      // instead of dropping into the corrupted-course screen.
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.onboardingLoadError)),
      );
      return;
    }
    if (!context.mounted) return;

    // Find matching UserCourse for progress tracking
    final rowId = row.id;
    final userCourses = userCoursesAsync.valueOrNull ?? [];
    final uc = userCourses.where((u) => u.courseId == rowId).firstOrNull;

    // The enrollment now holds the version just downloaded — without this,
    // CourseDetailPage would still lock the lessons behind its update banner.
    if (refreshed && uc != null && uc.downloadedVersion < row.version) {
      await db.updateUserCourseDownloadedVersion(
        id: uc.id,
        downloadedVersion: row.version,
      );
      if (!context.mounted) return;
    }

    final course = Course.fromJsonData(
      id: rowId,
      data: data,
      completedLessons: uc?.completedLessons ?? 0,
      isCompleted: uc?.isCompleted ?? false,
    );

    Navigator.of(context).push(
      shellPageRoute(
        context,
        builder: (_) => CourseDetailPage(
          course: course,
          userCourseId: uc?.id,
        ),
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<UserCourse>> userCoursesAsync, {
    required bool isMobile,
  }) {
    Future<void> openGuide() => _openLocalCourse(
          context,
          ref,
          fieldCourseId: _onboardingCourseId,
          userCoursesAsync: userCoursesAsync,
        );

    if (isMobile) {
      return InProgressCard(
        icon: Icons.menu_book_rounded,
        iconOnRight: true,
        title: AppStrings.guideTitle,
        subtitle: AppStrings.guideSubtitle,
        showProgressBar: false,
        buttonText: AppStrings.guideButton,
        onButtonTap: openGuide,
      );
    }

    // Wide: text on the left, mascot panel on the right, per the design.
    //
    // Both the panel width and the card height have to give with the card. On
    // a portrait tablet the card is only ~650 wide, and a hard 300px panel left
    // the copy a ribbon that wrapped past the old fixed 226 height — which the
    // card clips, so the start button disappeared under its own edge and the
    // guide could not be opened at all (BR-USWXWV).
    //
    // 226 stays, as a *minimum*: the illustration panel still has to fill the
    // card vertically, and a stretch Row inside an unbounded column cannot
    // resolve that on its own — IntrinsicHeight is what bounds it now.
    return LayoutBuilder(
      builder: (context, constraints) {
        // The panel keeps its designed width wherever there is room for it and
        // shrinks with the card below that; the mascot follows it down, so it
        // never grows wider than the panel it sits in (the asset is 325×260).
        final panelWidth = (constraints.maxWidth * 0.32).clamp(180.0, 300.0);
        final imageHeight = ((panelWidth - 32) * 260 / 325).clamp(96.0, 190.0);

        return Container(
          key: guideCardKey,
          constraints: const BoxConstraints(minHeight: 226),
          decoration: AppDecorations.cardDecorationLight,
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: AppDecorations.radiusM,
                          ),
                          child: Icon(Icons.menu_book_rounded,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppStrings.guideTitle,
                                  style: AppTextStyles.cardTitle()),
                              const SizedBox(height: 6),
                              Text(
                                AppStrings.guideSubtitle,
                                style: AppTextStyles.bodySmall(
                                    color: AppColors.primaryDark64),
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: openGuide,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: AppDecorations.radiusM,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        AppStrings.guideButton,
                                        style: AppTextStyles.actionSmall(
                                            color: AppColors.surface),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward,
                                          size: 18, color: AppColors.surface),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Illustration panel. Wide enough that it never squeezes
                // the copy, narrow enough that the copy never squeezes it.
                Container(
                  width: panelWidth,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Center(
                    child: Image.asset(
                      'assets/images/skins_bg.png',
                      height: imageHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPracticeCard(BuildContext context, int dueCount,
      {bool scoped = false}) {
    // Nothing due *because of the student's own selection* is a different
    // state from nothing due at all — the card points at the picker instead of
    // offering a session that would open empty.
    final emptyByChoice = dueCount == 0 && scoped;
    // Nothing due and nothing narrowed: the tile is now shown by XP tier rather
    // than by having work in it, so it has to say why it is empty instead of
    // promising cards that are not there (BR-ERUJBY).
    final emptyQueue = dueCount == 0 && !scoped;
    return InProgressCard(
      icon: Icons.access_time_filled,
      iconOnRight: true,
      title: AppStrings.practiceDueCount(dueCount),
      subtitle: emptyByChoice
          ? AppStrings.practiceScopeEmpty
          : emptyQueue
              ? AppStrings.practiceNothingDue
              : AppStrings.practiceDashSubtitle,
      showProgressBar: false,
      buttonText: emptyByChoice
          ? AppStrings.practiceScopeTitle
          : AppStrings.practiceStart,
      onButtonTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PracticePage()),
        );
      },
    );
  }

  Widget _buildPromoCard(BuildContext context, int xp) {
    return PromoCard(
      badge: AppStrings.promoBadge,
      title: AppStrings.promoTitle,
      // Past `promoReward` the same banner names the reward waiting in
      // Doplňky; the destination stays Knihovna either way — studying is what
      // unlocks it (BR-ERUJBY).
      description: DashboardTiers.showsPromoReward(xp)
          ? AppStrings.promoDescriptionReward
          : AppStrings.promoDescription,
      illustrationPath: 'assets/images/card_news_bg.png',
      onTap: () {
        Navigator.of(context).push(
          shellPageRoute(context, builder: (_) => const KnihovnaPage()),
        );
      },
    );
  }

  /// "Dej si kvíz" — the standing challenge that mixes questions from every
  /// course the learner has (BR-ERUJBY).
  ///
  /// No XP threshold: it is meant to be there from the start. It does hide
  /// when there is nothing to ask, though — a card that opens an empty quiz is
  /// worse than no card.
  List<Widget> _buildGlobalQuizSection({
    required BuildContext context,
    required WidgetRef ref,
    required List<UserCourse> visibleCourses,
    required Widget Function(Widget) pad,
  }) {
    final quizzable = visibleCourses
        .where((uc) => courseDataHasQuestions(uc.courseData))
        .toList();
    if (quizzable.isEmpty) return const [];

    return [
      const SizedBox(height: 24),
      pad(Text(AppStrings.globalQuizHeading, style: AppTextStyles.heading1())),
      const SizedBox(height: 16),
      pad(InProgressCard(
        icon: Icons.bolt_rounded,
        iconOnRight: true,
        title: AppStrings.globalQuizTitle,
        subtitle: AppStrings.globalQuizSubtitle,
        showProgressBar: false,
        buttonText: AppStrings.globalQuizStart,
        onButtonTap: () => _startGlobalQuiz(context, ref, quizzable),
      )),
    ];
  }

  /// Ask what to practise, pick ten ELO-matched questions, open [QuizPage].
  ///
  /// "Global Quiz v1" + BR-RB8WRW: whenever there is an actual choice to make
  /// (several domains, several courses/lessons, or more questions than one
  /// quiz holds), an entry dialog first narrows the pool by GPF domain and by
  /// course/lesson, then `selectGlobalQuizBlocks` matches the rest to the
  /// student's ELO profile. With no real choice the quiz starts right away.
  /// The spec's subject step is skipped: the app carries a single subject.
  ///
  /// The session is attributed to [globalQuizCourseId] rather than to one of
  /// the courses it drew from: that sentinel matches no local course row, so
  /// QuizPage's course-keyed resume/progress writes all early-return instead of
  /// corrupting a real course's state the way BR-CNSK2C did, while the attempt
  /// still reaches the server under a stable id.
  Future<void> _startGlobalQuiz(
    BuildContext context,
    WidgetRef ref,
    List<UserCourse> courses,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final parsed = <Course>[];
    for (final uc in courses) {
      final data = uc.courseData;
      if (data == null || data.isEmpty) continue;
      parsed.add(Course.fromJsonData(
        id: uc.courseId,
        data: data,
        completedLessons: uc.completedLessons,
        isCompleted: uc.isCompleted,
      ));
    }

    final groups = buildGlobalQuizLessonGroups(parsed);
    var pool = [for (final g in groups) ...g.blocks];
    if (pool.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.practiceEmpty)),
      );
      return;
    }

    // Offer only what the pool actually holds.
    final domains = GpfStructure.domains
        .where((d) => pool.any((b) => blockTouchesDomain(b, d)))
        .toList();

    // Which domains each lesson can serve; next to a domain list the dialog
    // offers only lessons with a task in one of them (BR-RQMMS5), so groups
    // without vectors do not count as a choice there.
    final groupDomains = {
      for (final g in groups) g.key: representedDomains(g.blocks),
    };
    final offeredGroups = domains.isEmpty
        ? groups.length
        : groups.where((g) => groupDomains[g.key]!.isNotEmpty).length;

    // The dialog earns its interruption only when it offers a real decision
    // (BR-RB8WRW follow-up: the choice belongs to the homepage entry point).
    final offersChoice = domains.length >= 2 ||
        offeredGroups >= 2 ||
        pool.length > globalQuizLength;

    var domainCodes = const <String>{};
    if (offersChoice) {
      var domainNames = const <String, String>{};
      if (domains.isNotEmpty) {
        try {
          domainNames = await ref.read(gpfLabelRepositoryProvider).domainNames();
        } catch (e, st) {
          silentLog('prehled_page', e, st); // codes still show without names
        }
      }

      // Fold the flat lesson groups back into their courses, keeping order.
      final courseNodes = <GlobalQuizCourseNode>[];
      for (final group in groups) {
        final option = GlobalQuizLessonOption(
          key: group.key,
          title: group.title,
          domainCodes: groupDomains[group.key]!,
        );
        if (courseNodes.isNotEmpty &&
            courseNodes.last.courseId == group.courseId) {
          courseNodes.last.lessons.add(option);
        } else {
          courseNodes.add(GlobalQuizCourseNode(
            courseId: group.courseId,
            title: group.courseTitle,
            lessons: [option],
          ));
        }
      }

      if (!context.mounted) return;
      final choice = await showDialog<GlobalQuizEntryChoice>(
        context: context,
        builder: (_) => GlobalQuizEntryDialog(
          domains: domains,
          domainNames: domainNames,
          courses: courseNodes,
        ),
      );
      if (choice == null) return; // dismissed — no quiz today

      final chosen = [
        for (final g in groups)
          if (choice.lessonKeys.contains(g.key)) ...g.blocks,
      ];
      if (chosen.isNotEmpty) pool = chosen;
      domainCodes = choice.domainCodes;
    }

    // The student's profile drives the ELO matching; unavailable (guest
    // before first sync, read failure) degrades to the engine's default
    // rating per dimension rather than skipping the selection.
    var studentElo = List<double?>.filled(kGpfDimensions, null);
    // Tasks are matched on the difficulty the answer path uses: the server's
    // calibration where it has one (BR-697NCA), the content elsewhere.
    var calibratedTaskElo = const <String, List<double?>>{};
    try {
      final eloRepo = ref.read(eloRepositoryProvider);
      final user = ref.read(activeUserProvider).valueOrNull;
      if (user != null) {
        final profile = await eloRepo.getProfile(user.id);
        if (profile != null) studentElo = profile.profilElo;
      }
      calibratedTaskElo =
          await eloRepo.calibratedTaskElo(pool.map((b) => b.blockId));
    } catch (e, st) {
      silentLog('prehled_page', e, st);
    }

    List<ContentBlock> blocks = selectGlobalQuizBlocks(
      pool: pool,
      studentElo: studentElo,
      domainCodes: domainCodes,
      calibratedTaskElo: calibratedTaskElo,
    );

    if (blocks.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.practiceEmpty)),
      );
      return;
    }

    // "před novým blokem se všech deset úloh náhodně zamíchá."
    blocks = List.of(blocks)..shuffle();

    navigator.push(
      MaterialPageRoute(
        builder: (_) => QuizPage(
          questionBlocks: blocks,
          courseTitle: AppStrings.globalQuizTitle,
          courseId: globalQuizCourseId,
          progress: QuizProgress(),
          evaluate: true,
          isExercise: true,
          // isExercise is on for the ELO/completion behaviour above, not
          // because this is an exercise — the heading stays "Kvíz" (BR-KEMJ4V).
          appBarTitle: AppStrings.quizTitle,
        ),
      ),
    );
  }

  /// "Uvažuješ o přijímačkách?" — the JPZ intro course, or the Cermatík chat
  /// once the learner is past `cermatikInsteadOfJpz` XP (BR-ERUJBY).
  ///
  /// Below that threshold the banner needs the intro course to exist on the
  /// device; without it there is nowhere to send the learner, so it stays
  /// hidden until sync brings the course in.
  List<Widget> _buildJpzSection({
    required BuildContext context,
    required WidgetRef ref,
    required int xp,
    required bool courseAvailable,
    required AsyncValue<List<UserCourse>> userCoursesAsync,
    required Widget Function(Widget) pad,
  }) {
    final toCermatik = DashboardTiers.showsCermatik(xp);
    if (!toCermatik && !courseAvailable) return const [];

    return [
      const SizedBox(height: 16),
      pad(PromoCard(
        badge: AppStrings.jpzBadge,
        title: AppStrings.jpzTitle,
        description: toCermatik
            ? AppStrings.jpzCermatikDescription
            : AppStrings.jpzDescription,
        borderColor: AppColors.primary,
        illustrationPath: 'assets/images/card_news_bg.png',
        onTap: () {
          if (toCermatik) {
            _openCermatikChat(context, ref);
          } else {
            _openLocalCourse(
              context,
              ref,
              fieldCourseId: _jpzIntroCourseId,
              userCoursesAsync: userCoursesAsync,
            );
          }
        },
      )),
    ];
  }

  /// Start a fresh conversation with the entrance-exam mentor.
  ///
  /// The session is created up front rather than passing an empty id:
  /// ChatDetailPage only self-creates when it is also given an opening message,
  /// and there is none to send here.
  Future<void> _openCermatikChat(BuildContext context, WidgetRef ref) async {
    try {
      final user = await ref.read(activeUserProvider.future);
      if (user == null) return;

      final session = await ref
          .read(chatRepositoryProvider)
          .createSession(user.id, ChatPersona.cermatik.id);

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            sessionId: session.id,
            sessionTitle: session.title.isNotEmpty
                ? session.title
                : ChatPersona.cermatik.displayName,
            persona: ChatPersona.cermatik,
          ),
        ),
      );
    } catch (e, st) {
      silentLog('prehled_page', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.chatRequiresInternet)),
      );
    }
  }

  /// "Rychlé kvízy" and "Pokračovat" — carousels on phones, grids when there
  /// is room to show every card at once.
  List<Widget> _buildCourseSections({
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue<List<UserCourse>> userCoursesAsync,
    required List<UserCourse> visibleCourses,
    required bool isMobile,
    required int gridColumns,
  }) {
    if (userCoursesAsync.isLoading || userCoursesAsync.hasError) {
      return const [SizedBox.shrink()];
    }
    if (visibleCourses.isEmpty) return const [SizedBox.shrink()];

    final cardColors = [
      AppColors.cardBlue,
      AppColors.cardLavender,
      AppColors.cardPeach,
      AppColors.cardPeachDark,
      AppColors.successBg,
    ];

    // Rychlé kvízy: courses with exercise blocks where all lessons are
    // completed (or only_quiz allows running the quiz first).
    final quizCourses = visibleCourses.where((uc) {
      if (uc.isCompleted) return false;
      final data = uc.courseData;
      if (data == null) return false;
      final blocks = data['blocks'] as List<dynamic>?;
      if (blocks == null || blocks.isEmpty) return false;

      final hasExercise = blocks.any((b) {
        final type = (b as Map<String, dynamic>)['type'] as String?;
        return type == 'exercise' || type == 'question' || type == 'quiz';
      });
      if (!hasExercise) return false;

      final onlyQuiz = data['only_quiz'] as bool? ?? false;
      if (onlyQuiz) return true;
      final total = _lessonCountOf(uc);
      return total > 0 && uc.completedLessons >= total;
    }).toList();

    final quizCards = quizCourses.map((uc) {
      final data = uc.courseData ?? {};
      final emoji = data['emoji'] as String? ?? '📖';
      final colorIdx = quizCourses.indexOf(uc) % cardColors.length;

      return CourseCard(
        iconWidget: Text(emoji, style: const TextStyle(fontSize: 32)),
        iconBackgroundColor: cardColors[colorIdx].withValues(alpha: 0.48),
        title: uc.courseName ?? AppStrings.defaultCourseName,
        badge: AppStrings.sectionQuickQuizzes,
        metaItems: [
          CardMetaItem(
            icon: Icons.quiz_outlined,
            iconColor: AppColors.progressFill,
            label: '${(data['blocks'] as List<dynamic>? ?? []).where((b) {
              final t = (b as Map<String, dynamic>)['type'] as String?;
              return t == 'exercise' || t == 'question' || t == 'quiz';
            }).length}',
          ),
        ],
        onTap: () async {
          if (data.isEmpty) return;
          final navigator = Navigator.of(context);
          final course = Course.fromJsonData(
            id: uc.courseId,
            data: data,
            completedLessons: uc.completedLessons,
            isCompleted: uc.isCompleted,
          );
          final progress =
              quizProgressCache.putIfAbsent(course.id, () => QuizProgress());
          // Ten ELO-matched questions, like the global quiz (BR-WRMW7W).
          final questionBlocks = await courseQuizBlocks(ref, course, progress);
          if (questionBlocks.isEmpty || !context.mounted) return;
          navigator.push(
            MaterialPageRoute(
              builder: (_) => QuizPage(
                questionBlocks: questionBlocks,
                courseTitle: course.title,
                courseId: course.id,
                evaluate: course.quizEvaluate,
                onlyOnce: course.onlyOnce,
                progress: progress,
              ),
            ),
          );
        },
      );
    }).toList();

    // Pokračovat — courses with any recorded progress that aren't yet
    // completed. Uses UserCourse.hasStarted (not just completedLessons) so
    // block/quiz-based courses, which never increment completedLessons, still
    // appear here instead of falling through both sections (BR-ZBW7TB).
    final inProgressCourses = visibleCourses
        .where((uc) =>
            uc.hasStarted &&
            uc.courseData != null &&
            // only_quiz courses live in "Rychlé kvízy"; don't duplicate them.
            uc.courseData?['only_quiz'] != true)
        .toList();

    final sectionPadding = isMobile ? 16.0 : 0.0;

    // On a phone the two course sections stack straight on top of each other,
    // so every started course is drawn twice — once in the "Pokračovat"
    // carousel, once in the "Moje kurzy" list right below it (BR-WYA3RQ).
    // "Moje kurzy" is the one that goes: the carousel is the shortcut the
    // phone layout is built around, and the Kurzy tab holds the full list.
    //
    // Only when the carousel actually renders, though. It filters on
    // hasStarted, so hiding "Moje kurzy" unconditionally would put a
    // just-enrolled student back in front of an empty dashboard (BR-H42B3V).
    final showMyCourses = !isMobile || inProgressCourses.isEmpty;

    return [
      if (quizCards.isNotEmpty) ...[
        const SizedBox(height: 32),
        CardSection(
          title: AppStrings.sectionQuickQuizzes,
          carouselHeight: 200,
          cards: quizCards,
          asGrid: !isMobile,
          gridColumns: gridColumns,
          horizontalPadding: sectionPadding,
        ),
      ],
      // Phones keep the "Pokračovat" carousel as a shortcut back into a
      // half-finished course; when it has nothing to show, "Moje kurzy" below
      // takes over so the dashboard is never empty (BR-H42B3V).
      if (isMobile && inProgressCourses.isNotEmpty) ...[
        const SizedBox(height: 32),
        CardSection(
          title: AppStrings.sectionContinue,
          carouselHeight: 220,
          cards: inProgressCourses.map((uc) {
            final data = uc.courseData!;
            final emoji = data['emoji'] as String? ?? '📖';
            final description = data['description'] as String?;
            final colorIdx =
                inProgressCourses.indexOf(uc) % cardColors.length;

            return CourseCard(
              iconWidget: Text(emoji, style: const TextStyle(fontSize: 32)),
              iconBackgroundColor:
                  cardColors[colorIdx].withValues(alpha: 0.48),
              title: uc.courseName ?? AppStrings.defaultCourseName,
              description: description,
              onTap: () {
                final course = Course.fromJsonData(
                  id: uc.courseId,
                  data: data,
                  completedLessons: uc.completedLessons,
                  isCompleted: uc.isCompleted,
                );
                Navigator.of(context).push(
                  shellPageRoute(
      context,
                    builder: (_) => CourseDetailPage(
                      course: course,
                      userCourseId: uc.id,
                    ),
                  ),
                );
              },
            );
          }).toList(),
          asGrid: !isMobile,
          gridColumns: gridColumns,
          horizontalPadding: sectionPadding,
        ),
      ],
      if (showMyCourses)
        _buildMyCoursesSection(
          context: context,
          ref: ref,
          visibleCourses: visibleCourses,
          gridColumns: gridColumns,
          isMobile: isMobile,
        ),
    ];
  }

  /// "Moje kurzy" — the design's dashboard grid: a heading, filter chips, a
  /// "show all" link, and up to [_dashboardCourseLimit] tiles.
  ///
  /// Deliberately the same [CourseGridCard] the Kurzy page uses; two cards
  /// showing the same thing differently is how they drift apart.
  Widget _buildMyCoursesSection({
    required BuildContext context,
    required WidgetRef ref,
    required List<UserCourse> visibleCourses,
    required int gridColumns,
    required bool isMobile,
  }) {
    if (visibleCourses.isEmpty) return const SizedBox.shrink();

    final filterIndex = ref.watch(_dashboardCourseFilterProvider);
    final filtered = _filterForDashboard(visibleCourses, filterIndex)
        .take(_dashboardCourseLimit)
        .toList();

    final headerColors = [
      AppColors.cardLavender,
      AppColors.successBg,
      AppColors.cardPeach,
      AppColors.cardYellow,
      AppColors.cardBlue,
      AppColors.cardPeachDark,
    ];

    // Phones pad every section themselves; wider layouts pad the whole column
    // once, so padding here would double up.
    Widget pad(Widget child) => isMobile
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          )
        : child;

    // Scrolls horizontally and carries its own 16px padding, so on phones it
    // stays outside pad() and bleeds to the edge like the carousels do.
    final chips = FilterChipRow(
      labels: _dashboardFilters,
      selectedIndex: filterIndex,
      onSelected: (i) =>
          ref.read(_dashboardCourseFilterProvider.notifier).state = i,
    );

    final showAllLink = GestureDetector(
      onTap: () => goToMainTab(context, ref, _kurzyTabIndex),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.sectionShowAllCourses,
            style: AppTextStyles.actionSmall(color: AppColors.primary),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
        ],
      ),
    );

    final heading =
        Text(AppStrings.sectionMyCourses, style: AppTextStyles.heading1());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        // A phone has no room for heading + chips + link on one line, so the
        // chips drop to a row of their own instead of being squeezed out.
        if (isMobile) ...[
          pad(Row(children: [heading, const Spacer(), showAllLink])),
          const SizedBox(height: 12),
          chips,
        ] else
          Row(
            children: [
              heading,
              const SizedBox(width: 16),
              Expanded(child: chips),
              const SizedBox(width: 16),
              showAllLink,
            ],
          ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          pad(Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              AppStrings.kurzyEmptySubtitle,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
            ),
          ))
        // Phones get the list card the Kurzy tab uses. The grid tile is drawn
        // for a ~300px column; at one column it stretches to the full width
        // but keeps its fixed 320px height, so the Spacer above the progress
        // bar opens a hole and the 6px bar reads as a hairline (BR-NS3UBD).
        else if (isMobile)
          pad(Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < filtered.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildDashboardCourseListCard(context, filtered[i]),
              ],
            ],
          ))
        else
          pad(GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridColumns,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              mainAxisExtent: 320,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _buildDashboardCourseCard(
              context,
              filtered[index],
              headerColors[index % headerColors.length],
            ),
          )),
      ],
    );
  }

  List<UserCourse> _filterForDashboard(List<UserCourse> courses, int index) {
    switch (index) {
      case 1:
        return courses
            .where((c) => c.status == UserCourseStatus.inProgress)
            .toList();
      case 2:
        return courses
            .where((c) => c.status == UserCourseStatus.downloaded)
            .toList();
      case 3:
        return courses
            .where((c) => c.status == UserCourseStatus.completed)
            .toList();
      default:
        return courses;
    }
  }

  /// The bits both dashboard card shapes need: the derived view and the tap
  /// target. Derivation lives in [CourseCardView] so the dashboard and the
  /// Kurzy tab cannot disagree about a course's progress.
  ({CourseCardView view, VoidCallback open}) _dashboardCourse(
    BuildContext context,
    UserCourse userCourse,
  ) {
    final view = CourseCardView.of(userCourse);

    void open() {
      final course = Course.fromJsonData(
        id: userCourse.courseId,
        data: userCourse.courseData ?? const {},
        completedLessons: userCourse.completedLessons,
        isCompleted: userCourse.isCompleted,
        fallbackName: view.title,
      );
      Navigator.of(context).push(
        shellPageRoute(
          context,
          builder: (_) => CourseDetailPage(
            course: course,
            userCourseId: userCourse.id,
          ),
        ),
      );
    }

    return (view: view, open: open);
  }

  /// Phone card — deliberately the same list tile the Kurzy tab renders, so
  /// the same course looks the same on both screens.
  Widget _buildDashboardCourseListCard(
    BuildContext context,
    UserCourse userCourse,
  ) {
    final (:view, :open) = _dashboardCourse(context, userCourse);

    return KurzyCourseCard(
      iconWidget: ClipOval(
        child: CourseCoverImage(
          url: view.coverImageUrl,
          width: 56,
          height: 56,
          fallback: Text(view.emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
      iconBackgroundColor: AppColors.surfaceLight.withValues(alpha: 0.48),
      title: view.title,
      description: view.description,
      badge: view.badge,
      lessonCount: view.lessonCount,
      durationHours: view.durationHours,
      currentProgress: view.currentProgress,
      totalProgress: view.totalProgress,
      status: view.status,
      hasUpdate: userCourse.hasUpdate,
      onTap: open,
    );
  }

  /// Tablet and desktop tile, where a card sits in a ~300px column.
  Widget _buildDashboardCourseCard(
    BuildContext context,
    UserCourse userCourse,
    Color headerColor,
  ) {
    final (:view, :open) = _dashboardCourse(context, userCourse);
    final isCompleted = userCourse.status == UserCourseStatus.completed;
    final cta = isCompleted
        ? AppStrings.courseCardReview
        : userCourse.hasStarted
            ? AppStrings.courseCardContinue
            : AppStrings.courseCardStart;

    return CourseGridCard(
      emoji: view.emoji,
      coverImageUrl: view.coverImageUrl,
      headerColor: headerColor,
      title: view.title,
      meta: '${AppStrings.lessonsCount(view.lessonCount)} · '
          '${AppStrings.durationHours(view.durationHours)}',
      pills: [
        if (userCourse.hasUpdate)
          CourseCardPill(
            label: AppStrings.courseCardUpdate,
            color: AppColors.primary,
          ),
        if (isCompleted)
          CourseCardPill(
            label: AppStrings.courseCardCompleted,
            color: AppColors.success,
          ),
      ],
      currentProgress: view.currentProgress,
      // The tile hides the bar at 0; the dashboard always wants it visible.
      totalProgress: view.totalProgress > 0 ? view.totalProgress : 1,
      progressIsComplete: isCompleted,
      footer: CourseGridCardButton(label: cta, onTap: open),
      onTap: open,
    );
  }

  // ── Right-hand rail (desktop only) ────────────────────────────────────

  List<Widget> _buildRail({
    required BuildContext context,
    required WidgetRef ref,
    required UserStats? stats,
    required List<UserCourse> visibleCourses,
  }) {
    var lessonsDone = 0;
    var lessonsTotal = 0;
    for (final uc in visibleCourses) {
      final total = _lessonCountOf(uc);
      // A course of unknown size contributes to neither sum. Counting its
      // finished lessons alone is what produced "3 z 0 lekcí" under a 0 % ring
      // (BR-NTB3JW).
      if (total <= 0) continue;
      lessonsDone += uc.completedLessons;
      lessonsTotal += total;
    }

    final current = _findCurrentLesson(visibleCourses);
    final startedCourse =
        current == null ? _lastTouchedCourse(visibleCourses) : null;

    return [
      ProgressRingCard(
        lessonsDone: lessonsDone,
        lessonsTotal: lessonsTotal,
        onDetailTap: () => _openAchievements(context, ref, stats),
      ),
      const SizedBox(height: 16),
      if (current == null)
        if (startedCourse == null)
          const ContinueLessonCard.empty()
        else
          ContinueLessonCard.course(
            courseTitle:
                startedCourse.courseName ?? AppStrings.defaultCourseName,
            // A quiz-only course has no lessons to have finished.
            lessonLabel: _lessonCountOf(startedCourse) > 0
                ? AppStrings.continueLessonAllDone
                : AppStrings.continueLessonQuizOnly,
            buttonLabel: AppStrings.continueLessonOpenCourse,
            onContinue: () => Navigator.of(context).push(
              shellPageRoute(
                context,
                builder: (_) => CourseDetailPage(
                  course: _courseFrom(startedCourse, startedCourse.courseData!),
                  userCourseId: startedCourse.id,
                ),
              ),
            ),
          )
      else
        ContinueLessonCard(
          courseTitle: current.course.title,
          lessonLabel: current.label,
          stepsDone: current.stepsDone,
          stepsTotal: current.stepsTotal,
          onContinue: () => Navigator.of(context).push(
            shellPageRoute(
              context,
              builder: (_) => LessonDetailPage(
                course: current.course,
                lesson: current.lesson,
                lessonIndex: current.lessonIndex,
                userCourseId: current.userCourse.id,
              ),
            ),
          ),
        ),
      const SizedBox(height: 16),
      // No `onShowAll`: there is no activity history screen to show, and a
      // second link that goes nowhere is the bug this card was just fixed for.
      RecentActivityCard(
        entries: _buildActivityEntries(context, visibleCourses),
      ),
    ];
  }

  /// How many lessons a course has.
  ///
  /// `UserCourse.totalLessons` mirrors the server's nullable `total_lessons`,
  /// which the sync collapses to 0 — so 0 means "no lessons" *and* "not
  /// recorded". The downloaded payload is the authoritative count, and
  /// [CourseCardView] already reads it that way; the rail did not, which is
  /// how the same course showed one lesson count on Kurzy and another on the
  /// dashboard (BR-NTB3JW).
  int _lessonCountOf(UserCourse uc) {
    final lessons = uc.courseData?['lessons'] as List<dynamic>?;
    return lessons?.length ?? uc.totalLessons;
  }

  /// The course the "Pokračuj v lekci" card points at when no lesson inside
  /// any course is still open — every lesson finished, or a quiz-only course.
  ///
  /// Restricted to courses whose payload is downloaded: the card's button
  /// opens the course detail page, which needs it.
  UserCourse? _lastTouchedCourse(List<UserCourse> courses) {
    final candidates = courses
        .where((uc) => uc.hasStarted && uc.courseData != null)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Pick the most recently touched unfinished course and work out which
  /// lesson inside it is still open.
  _CurrentLesson? _findCurrentLesson(List<UserCourse> courses) {
    final candidates = courses.where((uc) => uc.hasStarted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    for (final uc in candidates) {
      final target = _resumeTargetFor(uc);
      // A course whose lessons are all done is effectively finished, so fall
      // through to the next candidate rather than pointing at a done lesson.
      if (target != null) return target;
    }
    return null;
  }

  /// Where a single course resumes: its first lesson that still has unfinished
  /// blocks.
  ///
  /// Null when the course cannot be resumed *into a lesson* — not started,
  /// finished, quiz-only, content not downloaded, or every lesson already done.
  /// Callers fall back to the course detail page in that case.
  ///
  /// Shared by the "Pokračovat v lekci" rail card and the "Nedávná aktivita"
  /// rows, so the two can never send the learner to different lessons of the
  /// same course.
  _CurrentLesson? _resumeTargetFor(UserCourse uc) {
    final data = uc.courseData;
    if (!uc.hasStarted ||
        uc.isCompleted ||
        data == null ||
        data['only_quiz'] == true) {
      return null;
    }

    final course = _courseFrom(uc, data);
    if (course.lessons.isEmpty) return null;

    final progressLessons =
        uc.progressData['lessons'] as Map<String, dynamic>? ?? const {};

    for (var i = 0; i < course.lessons.length; i++) {
      final lesson = course.lessons[i];
      final total = lesson.blocks.length;
      if (total == 0) continue;

      final lessonProgress =
          progressLessons[lesson.id] as Map<String, dynamic>?;
      final done =
          (lessonProgress?['completed_blocks'] as List<dynamic>?)?.length ?? 0;
      if (done >= total) continue;

      return _CurrentLesson(
        userCourse: uc,
        course: course,
        lesson: lesson,
        lessonIndex: i,
        stepsDone: done,
        stepsTotal: total,
      );
    }
    return null;
  }

  /// The in-memory [Course] for a stored row, with its progress applied.
  Course _courseFrom(UserCourse uc, Map<String, dynamic> data) =>
      Course.fromJsonData(
        id: uc.courseId,
        data: data,
        completedLessons: uc.completedLessons,
        isCompleted: uc.isCompleted,
        fallbackName: uc.courseName,
      );

  /// Activity rows built from what the app actually records.
  ///
  /// There is no XP event log — only the aggregate `xpPoints` — so the rows
  /// carry no XP deltas yet. `updatedAt` is the closest thing to a timeline
  /// the local DB has.
  List<ActivityEntry> _buildActivityEntries(
    BuildContext context,
    List<UserCourse> courses,
  ) {
    final touched = courses.where((uc) => uc.hasStarted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return touched.take(3).map((uc) {
      final completed = uc.isCompleted;
      return ActivityEntry(
        icon: completed ? Icons.emoji_events_outlined : Icons.menu_book_rounded,
        iconColor: completed ? AppColors.orange : AppColors.primary,
        action: completed
            ? AppStrings.courseCardCompleted
            : AppStrings.sectionContinue,
        subject: uc.courseName ?? AppStrings.defaultCourseName,
        timeLabel: AppStrings.timeAgoFrom(uc.updatedAt),
        onTap: _activityTapFor(context, uc),
      );
    }).toList();
  }

  /// What one activity row does when tapped: back into the lesson the learner
  /// left off in, or the course detail page when there is no lesson to resume
  /// (a finished or quiz-only course — the row still says something useful
  /// there, it just opens the overview instead).
  ///
  /// Null only when the course content is not stored locally: there is nothing
  /// to open, and a row that opens a broken screen is no better than the dead
  /// row this replaces (BR-9NDW6D).
  VoidCallback? _activityTapFor(BuildContext context, UserCourse uc) {
    final data = uc.courseData;
    if (data == null) return null;

    // Resolved on tap rather than on build: [_resumeTargetFor] inflates the
    // whole course into lessons and blocks, and the dashboard rebuilds far more
    // often than these three rows are clicked.
    return () {
      final resume = _resumeTargetFor(uc);
      Navigator.of(context).push(
        shellPageRoute(
          context,
          builder: (_) => resume != null
              ? LessonDetailPage(
                  course: resume.course,
                  lesson: resume.lesson,
                  lessonIndex: resume.lessonIndex,
                  userCourseId: resume.userCourse.id,
                )
              : CourseDetailPage(
                  course: _courseFrom(uc, data),
                  userCourseId: uc.id,
                ),
        ),
      );
    };
  }
}
