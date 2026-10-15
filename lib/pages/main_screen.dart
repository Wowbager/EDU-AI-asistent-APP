import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/gamification/dashboard_tiers.dart';
import '../core/strings/app_strings.dart';
import '../core/strings/locale_manager.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/bookmark_provider.dart';
import '../core/providers/navigation_providers.dart';
import '../core/providers/practice_providers.dart';
import '../core/sync/sync_service.dart';
import '../core/util/classroom_join_flow.dart';
import '../core/util/markdown_link_handler.dart';
import '../core/util/silent_log.dart';
import '../routing/deep_link.dart';
import '../routing/tab_routes.dart';
import '../data/repositories/consent_repository.dart';
import '../data/repositories/oauth_repository.dart';
import '../data/repositories/user_stats_repository.dart';
import '../utils/achievement_stats.dart';
import '../widgets/adaptive_shell.dart';
import '../widgets/nav_destinations.dart';
import '../widgets/shell_banners.dart';
import 'about_page.dart';
import 'achievements_page.dart';
import 'auth_page.dart';
import 'chaty_page.dart';
import 'consent/consent_request_page.dart';
import 'edit_profile_page.dart';
import 'doplnky_page.dart';
import 'knihovna_page.dart';
import 'kurzy_page.dart';
import 'novinky_page.dart';
import 'prehled_page.dart';
import 'privacy_page.dart';
import 'profile_page.dart';
import 'quiz_page.dart';
import 'shop_page.dart';
import 'terms_page.dart';
import 'theme_selector_page.dart';
import '../core/util/shell_route.dart';

class MainScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLogout;
  final void Function(String email)? onGuestLogin;

  /// Forwarded to the [AuthPage] pushed from the profile (guest → login).
  /// Without it a successful OAuth exchange is silently dropped (BR: Google
  /// SSO "returns to login and nothing happens").
  final ValueChanged<OAuthExchangeResult>? onOAuthSuccess;

  /// Forwarded the same way for a login code typed on that pushed AuthPage.
  /// A guest who came in on a course PIN and then signs in as a student may
  /// be entering their account for the very first time, and that first entry
  /// is where the onboarding belongs — dropping the verdict here would mean
  /// they never get it (BR-YXVMKY).
  final void Function(bool profileSetupRequired)? onPinLoginComplete;

  const MainScreen({
    super.key,
    this.onLogout,
    this.onGuestLogin,
    this.onOAuthSuccess,
    this.onPinLoginComplete,
  });

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver, ThemeAwareState {
  /// Selected tab, read from [mainTabIndexProvider] so the sidebar drawn by
  /// pushed pages can switch tabs while this screen sits underneath.
  int get _selectedIndex => ref.read(mainTabIndexProvider);

  /// Quiz progress cache keyed by courseId — survives quiz page pop/re-push.
  final Map<String, QuizProgress> _quizProgressCache = {};

  /// Index of the Novinky (news) tab in [pages] / the bottom nav.
  static const int _newsTabIndex = 4;

  /// How often to poll the server for news while the app is in the foreground.
  /// Lightweight stand-in for push until real notifications exist.
  static const Duration _newsPollInterval = Duration(seconds: 60);

  Timer? _newsPollTimer;

  /// Watches the sync engine so caches that a sync can change (practice queue,
  /// bookmarks) refresh when it finishes — see [_watchSyncCompletion].
  StreamSubscription<SyncState>? _syncStateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initBookmarks();
    _watchSyncCompletion();
    _seedBundledCourses();
    // Populate the news badge on launch.
    ref.read(unreadNewsCountProvider.notifier).refresh();
    _startNewsPolling();
    // Open a course that arrived via a /course|/pin deep link, now that the app
    // is authenticated and on the main screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingDeepLink());
    // And a class that arrived via a /join deep link (BR-TT6TD7).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _consumePendingClassroomJoin());
    // And whatever a pushed page's sidebar asked for while this screen was not
    // there to hear it (BR-CMP2PX).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _consumePendingShellIntent());
  }

  @override
  void dispose() {
    _newsPollTimer?.cancel();
    _syncStateSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Foreground again — pull the latest news and resume polling.
      _refreshNews();
      _startNewsPolling();
    } else if (state == AppLifecycleState.paused) {
      // Backgrounded — stop polling to avoid needless requests.
      _newsPollTimer?.cancel();
    }
  }

  /// (Re)start the foreground news poll timer.
  void _startNewsPolling() {
    _newsPollTimer?.cancel();
    _newsPollTimer = Timer.periodic(_newsPollInterval, (_) => _refreshNews());
  }

  /// Refresh news state: update the unread badge (works on any tab) and
  /// invalidate the cached list so a visible Novinky tab refetches.
  void _refreshNews() {
    if (!mounted) return;
    ref.read(unreadNewsCountProvider.notifier).refresh();
    ref.invalidate(newsListProvider);
  }

  Future<void> _consumePendingDeepLink() async {
    final code = ref.read(pendingDeepLinkCodeProvider);
    if (code == null || code.isEmpty) return;
    // Consume once so it doesn't reopen on later rebuilds.
    ref.read(pendingDeepLinkCodeProvider.notifier).state = null;

    if (!mounted) return;
    // Same path as a /pin link tapped inside rendered markdown, so a deep link
    // opened from outside the app and one tapped inside it behave identically.
    // The tab does move here, though: a deep link drops the user into a course
    // with no tab context, so the shell has to point at Kurzy (BR-48B7DY).
    await openCourseByCode(context, ref, code, selectCoursesTab: true);
  }

  bool _joiningClassroom = false;

  /// Run the /join/:code flow if a code is parked. Also re-run from [build]
  /// when the code arrives while this screen is up, or when the account
  /// becomes able to join (loaded, or a guest who just logged in) — see
  /// [joinClassroomFromDeepLink] for what each state does.
  Future<void> _consumePendingClassroomJoin() async {
    if (_joiningClassroom || !mounted) return;
    _joiningClassroom = true;
    try {
      await joinClassroomFromDeepLink(context, ref);
    } finally {
      _joiningClassroom = false;
    }
  }

  Future<void> _initBookmarks() async {
    final db = ref.read(appDatabaseProvider);
    final user = await db.getActiveUser();
    if (user != null) {
      ref.read(bookmarkProvider.notifier).initForUser(user.id);
    }
  }

  /// Refresh the practice/bookmark caches whenever a sync finishes.
  ///
  /// A sync pulls the account's FSRS cards from the server, seeds new ones and
  /// materializes enrollments — but the practice queue, its count and the
  /// bookmark cache are cached Riverpod providers that nothing recomputes. On a
  /// second device that meant the dashboard kept showing the pre-sync numbers
  /// until the app was restarted, which read as "the devices don't sync"
  /// (BR-ZBJ99Z). Cheap: only fires on the syncing → idle edge.
  void _watchSyncCompletion() {
    _syncStateSub =
        ref.read(syncServiceProvider).stateStream.listen((state) {
      if (state != SyncState.idle) return;
      _refreshAfterSync();
    });
  }

  Future<void> _refreshAfterSync() async {
    if (!mounted) return;
    try {
      final db = ref.read(appDatabaseProvider);
      final user = await db.getActiveUser();
      if (!mounted) return;
      if (user != null) {
        await ref.read(bookmarkProvider.notifier).initForUser(user.id);
        if (!mounted) return;
      }
      ref.invalidate(practiceQueueProvider);
      ref.invalidate(playablePracticeProvider);
      ref.invalidate(dueCardsCountProvider);
      // Cards pulled from the server (a fresh sign-in, another device) must
      // reach the practice picker too, not only the queue (BR-27AEMT).
      ref.invalidate(practiceScopeProvider);
    } catch (e, st) {
      silentLog('main_screen:refresh_after_sync', e, st);
    }
  }

  Future<void> _seedBundledCourses() async {
    final courseRepo = ref.read(courseRepositoryProvider);
    final courses = await courseRepo.ensureBundledCoursesLoaded();

    // Auto-enroll the active user in bundled courses so they appear in Kurzy.
    final db = ref.read(appDatabaseProvider);
    final user = await db.getActiveUser();
    if (user == null || courses.isEmpty) return;

    final userCourseRepo = ref.read(userCourseRepositoryProvider);
    for (final course in courses) {
      final alreadyEnrolled = await userCourseRepo.hasUserCourse(user.id, course.id);
      if (!alreadyEnrolled) {
        await userCourseRepo.startCourse(userId: user.id, courseId: course.id);
      }
    }
  }

  /// Push the login page as a *guest upgrade*: the local session is left alone,
  /// so nothing the guest has done is lost, and the server folds their progress
  /// into the account once they log in.
  ///
  /// Student (isEmailValidated) → email/SSO form; pure guest → PIN screen
  /// (which can switch to email from there).
  ///
  /// Reached both from the profile's "log in" row and, via
  /// [requestGuestLoginProvider], from anywhere below this screen in the tree —
  /// a page pushed on top of MainScreen cannot get at this navigator itself
  /// (BR-QJJXPN).
  void _pushGuestUpgradeLogin() {
    final navigator = Navigator.of(context);
    final isStudent =
        ref.read(activeUserStreamProvider).valueOrNull?.isEmailValidated ?? false;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => AuthPage(
          startInLoginMode: isStudent,
          guestUpgrade: true,
          onEmailSubmit: (email) {
            // Pop all routes, then trigger email verification flow
            navigator.popUntil((route) => route.isFirst);
            widget.onGuestLogin?.call(email);
          },
          onPinLoginComplete: (profileSetupRequired) {
            navigator.popUntil((route) => route.isFirst);
            widget.onPinLoginComplete?.call(profileSetupRequired);
          },
          onOAuthSuccess: (exchange) {
            navigator.popUntil((route) => route.isFirst);
            widget.onOAuthSuccess?.call(exchange);
          },
          onBack: () => navigator.pop(),
          onNeedsParentalConsent: (country) {
            // AuthPage is pushed as its own route here (unlike
            // root_navigator.dart's state-swap AuthWrapper), so the consent
            // request is a further push on the same navigator, not another
            // enum state.
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ConsentRequestPage(
                  country: country,
                  onSubmit: (email) =>
                      ref.read(consentRepositoryProvider).requestConsent(
                            email: email,
                            locale: LocaleManager.current.code,
                            country: country,
                          ),
                  // Pop back to the already-pushed AuthPage, which is showing
                  // the normal PIN/code screen — that is where the child types
                  // the code their parent read out (POST /api/resolve-code).
                  onEnterCode: () => navigator.pop(),
                  onBack: () => navigator.pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    // Opening the Novinky tab: drop the cached list so it refetches and shows
    // anything published since the last fetch.
    if (index == _newsTabIndex) {
      _refreshNews();
    }
    // Moves the URL as well as the tab, so the browser records the section and
    // its back button walks between tabs (BR-7RNBZ9).
    goToMainTab(context, ref, index);
  }

  void openDoplnky() {
    // Refetch on every open: entitlement (attempts left, cooldown) goes stale
    // the moment the user plays anywhere else.
    ref.invalidate(miniGamesListProvider);
    Navigator.of(context).push(
      shellPageRoute(
        context,
        builder: (_) => const DoplnkyPage(),
      ),
    );
  }

  /// Carry out whatever a pushed page's sidebar asked for, if anything.
  ///
  /// Read-and-clear rather than a listener alone: a course opened straight from
  /// a PIN login is pushed by `AuthPage`, so this screen is not mounted while
  /// that sidebar is on display — and popping the course is what completes the
  /// login and mounts it. The tap's intent has to survive that gap, or the
  /// register card and the account block do nothing and leave the user looking
  /// at the Kurzy tab the PIN selected (BR-CMP2PX).
  void _consumePendingShellIntent() {
    if (!mounted) return;
    final intent = takePendingShellIntent(ref);
    switch (intent) {
      case null:
        return;
      case ShellIntent.openProfile:
        openProfile();
      case ShellIntent.openGuestLogin:
        _pushGuestUpgradeLogin();
      case ShellIntent.logout:
        _handleShellLogout();
      case ShellIntent.openDoplnky:
        openDoplnky();
    }
  }

  /// Sidebar destinations that open a route instead of switching tabs.
  void _openPushDestination(NavPush push) {
    switch (push) {
      case NavPush.doplnky:
        openDoplnky();
    }
  }

  void openProfile() {
    final userAsync = ref.read(activeUserStreamProvider);
    final userName = userAsync.valueOrNull?.name ?? AppStrings.defaultUserName;
    final userEmail = userAsync.valueOrNull?.email ?? '';
    // A minor and a code-login student both have no email, same as a guest —
    // but unlike a guest they must never be offered the "Log In" button's
    // registration form (a minor has no account to register and the server
    // never merges guest data into one; a code-login student already has a
    // real account). Treat them as NOT a guest here so the button
    // shows/performs a real logout instead (BR-8FDF37, BR-7CDXBR).
    final canOfferSignup = ref.read(canOfferSignupProvider);
    final avatarIndex = userAsync.valueOrNull?.avatarIndex ?? 0;
    final navigator = Navigator.of(context);

    // Get user stats from provider.
    final statsAsync = ref.read(userStatsStreamProvider);
    final stats = statsAsync.valueOrNull;

    navigator.push(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, secondaryAnimation) => ProfilePage(
          userName: userName,
          userEmail: userEmail,
          avatarIndex: avatarIndex,
          isGuest: canOfferSignup,
          level: stats?.level ?? 1,
          xpPoints: stats?.xpPoints ?? 0,
          coursesCount: stats?.coursesCount ?? 0,
          streakDays: stats?.streakDays ?? 1,
          achievementsCount: stats?.achievementsCount ?? 0,
          onBack: () => navigator.pop(),
          onAchievementsTap: () {
            _navigateToAchievements(navigator, stats);
          },
          onLibraryTap: () {
            navigator.push(
              shellPageRoute(
      context,
                builder: (_) => const KnihovnaPage(),
              ),
            );
          },
          onAboutTap: () {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => AboutPage(
                  onFactoryReset: widget.onLogout,
                ),
              ),
            );
          },
          onTermsTap: () {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => const TermsPage(),
              ),
            );
          },
          onPrivacyTap: () {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => const PrivacyPage(),
              ),
            );
          },
          // Pushes above the profile page on the root navigator, same as the
          // library shortcut.
          onDoplnkyTap: openDoplnky,
          // The avatar editor is the shop screen; from here it is a direct
          // account action, not a step inside Doplňky (BR-KB7XSJ).
          onAvatarTap: () {
            navigator.push(
              shellPageRoute(
                context,
                builder: (_) => const ShopPage(fromAccount: true),
              ),
            );
          },
          onEditProfileTap: () async {
            final result = await navigator.push<String>(
              MaterialPageRoute(
                builder: (_) => EditProfilePage(
                  userName: userName,
                  userEmail: userEmail,
                ),
              ),
            );
            return result;
          },
          onThemeTap: () {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ThemeSelectorPage(
                  onBack: () => navigator.pop(),
                  // Belt and braces next to [ThemeAwareState]: the selector
                  // reports every apply/save, so the screen behind it is never
                  // left painted in the previous palette (BR-W3XQ5K).
                  onThemeChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            );
          },
          onLogoutTap: () {
            // A minor is indistinguishable from a guest by an empty email —
            // that is exactly what makes their account pseudonymous — so the
            // guest-upgrade path must exclude them explicitly (BR-8FDF37),
            // and a code-login student for the same reason (BR-7CDXBR).
            if (canOfferSignup) {
              _pushGuestUpgradeLogin();
            } else {
              navigator.pop();
              widget.onLogout?.call();
            }
          },
        ),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  /// Sidebar logout: guests are sent to the upgrade flow, real accounts sign
  /// out.
  void _handleShellLogout() {
    final email = ref.read(activeUserStreamProvider).valueOrNull?.email ?? '';
    if (email.isEmpty) {
      _pushGuestUpgradeLogin();
    } else {
      widget.onLogout?.call();
    }
  }

  void _navigateToAchievements(NavigatorState navigator, UserStats? stats) async {
    final config = ref.read(gamificationConfigProvider).valueOrNull;
    final earnedIds = ref.read(earnedAchievementsProvider).valueOrNull ?? <String>[];

    // Refresh skills to get latest data (may fetch from API if not synced yet).
    ref.invalidate(skillDisplayProvider);
    final skills = await ref.read(skillDisplayProvider.future);

    // Count lessons/courses/quizzes from user courses
    final userCourses = ref.read(userCoursesStreamProvider).valueOrNull ?? [];
    final counts = countAchievementStats(userCourses);

    if (!mounted) return;
    navigator.push(
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
  Widget build(BuildContext context) {
    // A guest somewhere below this screen asked to log in (e.g. tapped through
    // to a logged_only course). Only this widget owns a navigator that can put
    // the auth page above whatever is currently pushed.
    ref.listen<int>(requestGuestLoginProvider, (_, _) => _pushGuestUpgradeLogin());

    // /join/:code (BR-TT6TD7): a link opened while this screen is up, or one
    // parked until the account could act on it (see the initState call).
    ref.listen<String?>(pendingClassroomJoinCodeProvider, (_, code) {
      if (code == null) return;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _consumePendingClassroomJoin());
    });
    ref.listen<ClassroomJoinEligibility>(classroomJoinEligibilityProvider,
        (_, _) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _consumePendingClassroomJoin());
    });

    // Every registration affordance below is gated on this one predicate:
    // a minor can never self-register (the server rejects it and never merges
    // guest data into a minor's account), and a code-login student already
    // has a real account. ShellBanners and DetailShell read the same provider,
    // so the sidebar card and the banner can no longer disagree (BR-7CDXBR).
    final canOfferSignup = ref.watch(canOfferSignupProvider);
    final userAsync = ref.watch(activeUserStreamProvider);
    final userName = userAsync.valueOrNull?.name;
    final selectedIndex = ref.watch(mainTabIndexProvider);
    // Drives the dashboard greeting's tier line. Watched (not read) so the
    // subtitle moves up as XP lands.
    final xp = ref.watch(userStatsStreamProvider).valueOrNull?.xpPoints ?? 0;

    // Same idea as [requestGuestLoginProvider] above, for every action a
    // pushed page's sidebar offers. That page cannot reach the profile/logout
    // callbacks — they close over this widget's navigator and the app-level
    // handlers — so it records the intent and this drains it once the pushed
    // route has popped. The slot is also drained on mount (see
    // [_consumePendingShellIntent]), for the intents recorded before this
    // screen existed.
    ref.listen<ShellIntent?>(pendingShellIntentProvider, (_, intent) {
      if (intent == null) return;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _consumePendingShellIntent());
    });

    final List<Widget> pages = [
      PrehledPage(onOpenDrawer: openProfile, onOpenDoplnky: openDoplnky, userName: userName, quizProgressCache: _quizProgressCache),
      const ChatyPage(),
      KnihovnaPage(onBack: () => _onItemTapped(0)),
      const KurzyPage(),
      const NovinkyPage(),
    ];

    return PopScope(
      // Only allow system pop (exit) when on the home tab.
      // On other tabs, intercept and switch to home first.
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Not on home tab — go to home instead of exiting
          _onItemTapped(0);
        }
      },
      // Replaces the interim `ContentWidth(browsing)` cap from BR-UWJD4M: the
      // tab pages now have their own wide-screen layouts, so the shell picks
      // the navigation chrome and each page decides how its content reflows.
      child: AdaptiveShell(
        selectedIndex: selectedIndex,
        onItemTapped: _onItemTapped,
        onPushTapped: _openPushDestination,
        title: _shellTitle(userName),
        subtitle: _shellSubtitle(xp),
        // Chat (tab 1) draws its own heading beside the "new chat" button in
        // the conversation column, so the shell's bar would be a second copy —
        // and it spans both panes, which pushed the open conversation down
        // instead of letting it start at the top edge (BR-7VMQ2U).
        showTopBar: selectedIndex != 1,
        // Minors and code-login students have no email by design, so a plain
        // isEmpty test would class them as guests and offer them registration
        // — a dead end the server would reject anyway (BR-8FDF37, BR-7CDXBR).
        isGuest: canOfferSignup,
        onProfileTap: openProfile,
        onRegisterTap: _pushGuestUpgradeLogin,
        banners: [
          // const SyncStatusBanner(),
          ShellBanners(
            onLogout: () => widget.onLogout?.call(),
            // Rebuild so the banner re-reads the now-cleared shared flag
            // and hides itself after "this is my device".
            onConverted: () {
              if (mounted) setState(() {});
            },
            onOAuthSuccess: widget.onOAuthSuccess,
          ),
        ],
        child: pages[selectedIndex],
      ),
    );
  }

  /// Title for the desktop top bar. The dashboard greets by name the way the
  /// phone layout's welcome card does; the other tabs just name themselves.
  String _shellTitle(String? userName) {
    switch (_selectedIndex) {
      case 0:
        final name = (userName ?? '').trim();
        return name.isEmpty
            ? '${AppStrings.welcomeGreeting}!'
            : '${AppStrings.welcomeGreeting}, $name! 👋';
      case 1:
        return AppStrings.navChat;
      case 2:
        return AppStrings.libraryTitle;
      case 3:
        return AppStrings.kurzyTitle;
      default:
        return AppStrings.navNovinky;
    }
  }

  String? _shellSubtitle(int xp) {
    switch (_selectedIndex) {
      case 0:
        // Mirrors the phone welcome card: one tier ladder, two layouts
        // (BR-ERUJBY).
        return DashboardTiers.greetingSubtitle(xp);
      case 3:
        return AppStrings.shellKurzySubtitle;
      default:
        return null;
    }
  }
}

