import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../consent/minor_mode.dart';
import '../services/auth_token_storage.dart';
import '../services/guest_auth_service.dart';
import '../services/practice_filter_store.dart';
import '../services/session_meta.dart';
import '../services/work_time_tracker.dart';
import '../../data/datasources/local/course_local_datasource.dart';
import '../../data/datasources/local/user_progress_local_datasource.dart';
import '../../data/datasources/local/user_stats_local_datasource.dart';
import '../../data/datasources/remote/course_remote_datasource.dart';
import '../../data/datasources/remote/avatar_remote_datasource.dart';
import '../../data/datasources/remote/mini_games_remote_datasource.dart';
import '../../data/datasources/remote/news_remote_datasource.dart';
import '../../data/datasources/remote/user_stats_remote_datasource.dart';
import '../../data/datasources/local/chat_local_datasource.dart';
import '../../data/datasources/remote/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository.dart';
import '../../models/chat_models.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/elo_repository.dart';
import '../../data/repositories/gpf_label_repository.dart';
import '../../data/repositories/avatar_repository.dart';
import '../../data/repositories/mini_games_repository.dart';
import '../../data/repositories/news_repository.dart';
import '../../models/avatar_model.dart';
import '../../models/mini_game_model.dart';
import '../../models/news_model.dart';
import '../../models/skill_display_model.dart';
import '../elo/elo_failure_reporter.dart';
import '../elo/skill_display_service.dart';
import '../network/api_endpoints.dart';
import '../../data/repositories/gamification_config_repository.dart';
import '../../data/repositories/user_course_repository.dart';
import '../../data/repositories/user_progress_repository.dart';
import '../../data/repositories/user_stats_repository.dart';
import '../../models/gamification_config_model.dart';
import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../theme/theme_config.dart';
import '../sync/sync_queue.dart';
import '../sync/sync_service.dart';
import 'package:eduai/core/util/silent_log.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Core Infrastructure Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for SharedPreferences.
/// Must be overridden with the actual instance during app initialization.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with the actual instance',
  );
});

/// Provider for the Drift database.
/// Singleton instance for the app lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for the auth-token storage (secure).
/// Must be overridden with the actual instance during app initialization.
final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  throw UnimplementedError(
    'authTokenStorageProvider must be overridden with the actual instance',
  );
});

/// Provider for the session metadata (shared_device flag, expiry,
/// last-active timestamp). Backed by SharedPreferences.
final sessionMetaProvider = Provider<SessionMeta>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SessionMeta(prefs);
});

/// Provider for the API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(authTokenStorageProvider);
  final session = ref.watch(sessionMetaProvider);
  final client = ApiClient(tokens, session: session, enableLogging: true);
  // Late-bind the 401 escalation. Reading the coordinator eagerly here would
  // create a dependency cycle (it depends on this client), so the read is
  // deferred to call time — by then this provider is already built.
  client.onUnauthorized = () {
    ref.read(logoutCoordinatorProvider).forceLogoutToLogin();
  };
  return client;
});

/// Bumped to ask the AuthWrapper to return to the login screen (pop any pushed
/// routes + show auth). Watched by AuthWrapper; incremented by
/// [LogoutCoordinator] once the local session has been torn down.
final forceAuthScreenProvider = StateProvider<int>((ref) => 0);

/// Bumped to ask MainScreen to push the login page as a *guest upgrade* — the
/// local session stays intact and the guest's progress is folded into the
/// account on the server once they log in.
///
/// Deliberately not [forceAuthScreenProvider]: that one runs after
/// [LogoutCoordinator.teardown] has wiped local data, which would cost a guest
/// everything they have done so far. Used when a guest hits a `logged_only`
/// course (BR-QJJXPN) from anywhere below MainScreen in the tree — a pushed
/// page cannot reach MainScreen's navigator directly.
final requestGuestLoginProvider = StateProvider<int>((ref) => 0);

/// Centralizes "the session is gone → go to login" so every trigger — a 401
/// from any authenticated endpoint, a null active user, shared-device
/// inactivity, or a manual logout — behaves identically: best-effort flush of
/// unsynced changes while the token is still valid, then revoke + wipe all
/// local data so nothing leaks to the next user on this (possibly shared)
/// device, then hand off to the UI to reset to login.
class LogoutCoordinator {
  LogoutCoordinator(this._ref, {Duration? navigationDeadline})
      : navigationDeadline = navigationDeadline ?? defaultNavigationDeadline;

  /// How long a caller waits for [teardown] before returning the user to the
  /// login screen regardless.
  ///
  /// [teardown] flushes over the network and wipes the whole local database;
  /// none of that is instant and the Drift transaction has no timeout of its
  /// own. Hanging the navigation off its completion meant that a step which
  /// stalled left the app signed out but still rendering the signed-in shell —
  /// the previous student's screen, minus their data — with nothing to retry
  /// it, because teardown has by then cleared `shared_device` and
  /// `InactivityWatcher` no longer considers the session idle-expiring
  /// (BR-VUESR3). Waiting is still the normal case: a healthy teardown
  /// finishes well inside this, so the login screen is reached only after the
  /// local data is genuinely gone.
  static const Duration defaultNavigationDeadline = Duration(seconds: 20);

  /// Overridable in tests, which cannot wait 20 real seconds.
  final Duration navigationDeadline;

  final Ref _ref;
  bool _running = false;

  /// Tear down the session and local data. Navigation is left to the UI layer.
  /// Re-entrancy-guarded, so concurrent 401s collapse into a single teardown.
  Future<void> teardown() async {
    if (_running) return;
    _running = true;
    try {
      final api = _ref.read(apiClientProvider);
      final session = _ref.read(sessionMetaProvider);
      final guest = _ref.read(guestAuthServiceProvider);
      final db = _ref.read(appDatabaseProvider);

      // 1. Best-effort flush of unsynced local changes while the token is still
      //    valid. At the 15-min inactivity mark the 30-min token is usually
      //    still alive/refreshable; a truly dead token can't be attributed
      //    server-side, so this is best-effort and time-boxed.
      try {
        if (api.isAuthenticated) {
          final sync = _ref.read(syncServiceProvider);
          if (await sync.hasPendingChanges()) {
            await sync.forceSync().timeout(const Duration(seconds: 8));
          }
        }
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }

      // 2. Best-effort server-side token revoke. Time-boxed like the flush
      //    above: Dio's own 30s receive timeout is longer than anyone should
      //    keep looking at the previous student's screen, and everything that
      //    actually protects them (steps 3-5) is still queued behind this.
      try {
        if (api.isAuthenticated) {
          await api
              .post(ApiEndpoints.logout)
              .timeout(const Duration(seconds: 8));
        }
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }

      // 3. Clear session metadata + token; force a fresh guest identity next time.
      try {
        await session.clear();
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }
      try {
        guest.markForceNewGuest();
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }
      try {
        await api.clearAuthToken();
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }
      // Clear the minor-mode flag so it never leaks onto whichever account
      // logs in next on this (possibly shared) device.
      try {
        await _ref.read(minorModeProvider.notifier).clear();
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }
      // Same for the practice scope (which subjects/areas the student chose to
      // practise): it lives in SharedPreferences, so step 4 below doesn't
      // touch it, and the next student would start with someone else's
      // selection silently narrowing their queue.
      try {
        await PracticeFilterStore(_ref.read(sharedPreferencesProvider)).clear();
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }

      // 4. Wipe all local data so the next user sees nothing of the previous one.
      try {
        await db.clearAllData();
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }
      // The rows are gone, but [activeUserProvider] still holds the departing
      // user and never re-reads on its own, so everything built on it — the
      // avatar above all — kept drawing them for the next student (BR-SPR9WH).
      try {
        _ref.invalidate(activeUserProvider);
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }

      // 5. Reset the palette. It lives in SharedPreferences + a static config
      //    rather than Drift, so step 4 doesn't touch it and the next user
      //    would keep seeing the previous user's colours (BR-P4JUDT).
      try {
        await ThemeManager.resetToDefault();
      } catch (e, st) {
        silentLog('logout_coordinator', e, st);
      }
    } finally {
      _running = false;
    }
  }

  /// Tear down, then request the UI return to the login screen.
  ///
  /// The request is made from a `finally` and behind [navigationDeadline], so
  /// no way for [teardown] to end — throwing, or never returning at all — can
  /// strand the user inside the app after their data has been wiped. A
  /// teardown still running past the deadline is left to finish on its own;
  /// nothing here cancels it.
  Future<void> forceLogoutToLogin() async {
    try {
      await teardown().timeout(navigationDeadline);
    } catch (e, st) {
      silentLog('logout_coordinator', e, st);
    } finally {
      _ref.read(forceAuthScreenProvider.notifier).state++;
    }
  }
}

/// Provider for the logout coordinator.
final logoutCoordinatorProvider = Provider<LogoutCoordinator>((ref) {
  return LogoutCoordinator(ref);
});

/// Provider for the active work-time tracker (BR-9SAH2R). Records heartbeats
/// while the user is genuinely working on a learning screen.
final workTimeTrackerProvider = Provider<WorkTimeTracker>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WorkTimeTracker(db);
});

/// Provider for the connectivity service.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ═══════════════════════════════════════════════════════════════════════════════
// Guest Auth Service Provider
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the guest authentication service.
final guestAuthServiceProvider = Provider<GuestAuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return GuestAuthService(apiClient: apiClient, prefs: prefs);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Sync Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the sync queue.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SyncQueue(db);
});

/// Provider for the sync service.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final syncQueue = ref.watch(syncQueueProvider);

  final service = SyncService(
    db: db,
    apiClient: apiClient,
    connectivity: connectivity,
    syncQueue: syncQueue,
    // Read lazily: the repository is only needed when an enrolled course is
    // missing its content, and reading it eagerly here would build the whole
    // course data-source graph on every app start (BR-ZBJ99Z).
    fetchCourseContent: (localCourseId) =>
        ref.read(courseRepositoryProvider).downloadFullCourseJson(localCourseId),
  );

  // Initialize the sync service to start listening for connectivity changes.
  service.initialize();

  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for sync state changes.
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.stateStream;
});

/// Provider for pending sync count.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.getPendingCount();
});

// ═══════════════════════════════════════════════════════════════════════════════
// Data Source Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the local course data source.
final courseLocalDataSourceProvider = Provider<CourseLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CourseLocalDataSource(db);
});

/// Provider for the remote course data source.
final courseRemoteDataSourceProvider = Provider<CourseRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CourseRemoteDataSource(apiClient);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Repository Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the course repository.
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  final localDataSource = ref.watch(courseLocalDataSourceProvider);
  final remoteDataSource = ref.watch(courseRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final syncQueue = ref.watch(syncQueueProvider);

  return CourseRepository(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    connectivity: connectivity,
    syncQueue: syncQueue,
  );
});

// ═══════════════════════════════════════════════════════════════════════════════
// Connectivity Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Stream provider for connectivity state changes.
final connectivityStateProvider = StreamProvider<ConnectivityState>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.onConnectivityChanged;
});

/// Provider for current connectivity state.
final currentConnectivityProvider = FutureProvider<ConnectivityState>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.currentState;
});

/// Provider for whether the device is online.
final isOnlineProvider = FutureProvider<bool>((ref) async {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.isOnline;
});

// ═══════════════════════════════════════════════════════════════════════════════
// Course Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Stream provider for all courses.
final coursesStreamProvider = StreamProvider<List<Course>>((ref) {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.watchAllCourses();
});

/// Future provider for all courses (one-time fetch).
final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.getAllCourses();
});

/// Provider family for a single course by ID.
final courseByIdProvider = FutureProvider.family<Course?, String>((ref, id) async {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.getCourseById(id);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Auth State Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for authentication state.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.isAuthenticated;
});

/// Provider for the current auth token.
final authTokenProvider = Provider<String?>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.getAuthToken();
});

// ═══════════════════════════════════════════════════════════════════════════════
// User Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the currently active user.
///
/// Reads the row once and caches it for the life of the app — this provider is
/// not autoDispose — so whoever changes *which account is signed in* has to
/// invalidate it. [activeUserStreamProvider] below re-reads itself because it
/// is a live Drift query; this one does not, and it is the one the avatar and
/// the practice queue are built on. Left cached across a logout it kept handing
/// out the departing student, so the next one on the device wore their avatar
/// until the app was restarted — on the web build, until the browser was closed
/// (BR-SPR9WH). The name and e-mail beside it came from the stream and were
/// already correct, which is why only the avatar looked wrong.
final activeUserProvider = FutureProvider<UsersTableData?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.getActiveUser();
});

/// Stream provider for active user changes.
final activeUserStreamProvider = StreamProvider<UsersTableData?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchActiveUser();
});

/// Provider for checking if a user is logged in locally.
final isUserLoggedInProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(activeUserProvider.future);
  return user != null;
});

/// May this account be offered "sign up for full access"?
///
/// The one predicate behind every registration affordance — the sidebar's
/// guest card, the e-mail-validation banner, and the profile page's
/// Log In/Log Out button. It used to be spelled out at each of those call
/// sites as a bare `email.isEmpty`, which is wrong twice over, and fixing one
/// copy left the others behind (BR-7CDXBR):
///
/// * A **minor** (self-service "Samoobsluha" classroom) has no e-mail by
///   design. The server rejects their self-registration and never merges
///   guest data into a minor's account, so the prompt is a dead end
///   (BR-8FDF37).
/// * A **student signed in with a login code** — school or self-service —
///   also has no e-mail: `AdminClassroomController` and `ConsentService`
///   mint those accounts without one. They already hold a real server-side
///   identity, which `auth_page` records locally by setting
///   `isEmailValidated` on an e-mail-less row. That flag, not the e-mail
///   column, is what separates them from an anonymous guest
///   (`createGuestUser` leaves it false).
///
/// Registered-but-unverified users are false here and keep their prompt
/// anyway: theirs is "verify your e-mail", which
/// `showEmailValidationBannerProvider` owns.
final canOfferSignupProvider = Provider<bool>((ref) {
  // The minor flag is restored from SharedPreferences before the first frame
  // and must never fail open, so it is checked ahead of the user row — which
  // is still loading at that point.
  if (ref.watch(minorModeProvider)) return false;

  // No local row is an anonymous visitor, same as an empty-email guest. Kept
  // deliberately: every call site used to read `(user?.email ?? '').isEmpty`,
  // which said the same thing, and the sidebar card and the banner have to
  // agree about this case as much as about any other.
  final user = ref.watch(activeUserStreamProvider).valueOrNull;
  if (user == null) return true;

  return user.email.isEmpty && !user.isEmailValidated;
});

// ═══════════════════════════════════════════════════════════════════════════
// User Course Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the user course repository.
final userCourseRepositoryProvider = Provider<UserCourseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final syncQueue = ref.watch(syncQueueProvider);

  return UserCourseRepository(
    db: db,
    syncQueue: syncQueue,
  );
});

/// Stream provider for user's courses.
/// Automatically watches the active user and their courses.
final userCoursesStreamProvider = StreamProvider<List<UserCourse>>((ref) {
  final userAsync = ref.watch(activeUserStreamProvider);
  final repository = ref.watch(userCourseRepositoryProvider);

  // If no user, return empty stream.
  final user = userAsync.valueOrNull;
  if (user == null) {
    return Stream.value(<UserCourse>[]);
  }

  // Return the user's courses stream.
  return repository.watchUserCourses(user.id);
});

/// Future provider for user's courses (one-time fetch).
final userCoursesProvider = FutureProvider<List<UserCourse>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final repository = ref.watch(userCourseRepositoryProvider);

  final user = await db.getActiveUser();
  if (user == null) return [];

  return repository.getUserCourses(user.id);
});

/// Provider family for checking if user has a specific course.
final hasUserCourseProvider = FutureProvider.family<bool, String>((ref, courseId) async {
  final db = ref.watch(appDatabaseProvider);
  final repository = ref.watch(userCourseRepositoryProvider);

  final user = await db.getActiveUser();
  if (user == null) return false;

  return repository.hasUserCourse(user.id, courseId);
});

// ═══════════════════════════════════════════════════════════════════════════
// User Progress Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the user progress local data source.
final userProgressLocalDataSourceProvider = Provider<UserProgressLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return UserProgressLocalDataSource(db);
});

/// Provider for the user progress repository.
final userProgressRepositoryProvider = Provider<UserProgressRepository>((ref) {
  final localDataSource = ref.watch(userProgressLocalDataSourceProvider);
  final syncQueue = ref.watch(syncQueueProvider);
  final db = ref.watch(appDatabaseProvider);
  return UserProgressRepository(
    localDataSource: localDataSource,
    syncQueue: syncQueue,
    db: db,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// User Stats Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the user stats local data source.
final userStatsLocalDataSourceProvider = Provider<UserStatsLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return UserStatsLocalDataSource(db);
});

/// Provider for the user stats remote data source.
final userStatsRemoteDataSourceProvider = Provider<UserStatsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserStatsRemoteDataSource(apiClient);
});

/// Provider for the user stats repository.
final userStatsRepositoryProvider = Provider<UserStatsRepository>((ref) {
  final localDataSource = ref.watch(userStatsLocalDataSourceProvider);
  final remoteDataSource = ref.watch(userStatsRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final syncQueue = ref.watch(syncQueueProvider);

  return UserStatsRepository(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    connectivity: connectivity,
    syncQueue: syncQueue,
  );
});

/// Stream provider for active user's stats.
/// Automatically watches the active user and their stats.
final userStatsStreamProvider = StreamProvider<UserStats?>((ref) {
  final userAsync = ref.watch(activeUserStreamProvider);
  final repository = ref.watch(userStatsRepositoryProvider);

  // If no user, return null stream.
  final user = userAsync.valueOrNull;
  if (user == null) {
    return Stream.value(null);
  }

  // Return the user's stats stream.
  return repository.watchUserStats(user.id);
});

/// Future provider for user's stats (one-time fetch).
final userStatsProvider = FutureProvider<UserStats?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final repository = ref.watch(userStatsRepositoryProvider);

  final user = await db.getActiveUser();
  if (user == null) return null;

  return repository.getOrCreateUserStats(user.id);
});

// ═══════════════════════════════════════════════════════════════════════════
// Gamification Config & Achievements Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the gamification config repository.
final gamificationConfigRepositoryProvider = Provider<GamificationConfigRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);
  return GamificationConfigRepository(db: db, apiClient: apiClient);
});

/// Future provider for the gamification config.
final gamificationConfigProvider = FutureProvider<GamificationConfig?>((ref) {
  final repository = ref.watch(gamificationConfigRepositoryProvider);
  return repository.getConfig();
});

/// Stream provider for the active user's earned achievement IDs.
final earnedAchievementsProvider = StreamProvider<List<String>>((ref) {
  final userAsync = ref.watch(activeUserStreamProvider);
  final db = ref.watch(appDatabaseProvider);

  final user = userAsync.valueOrNull;
  if (user == null) return Stream.value(<String>[]);

  return db.watchEarnedAchievements(user.id).map(
    (list) => list.map((a) => a.achievementId).toList(),
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// ELO / Adaptive Learning Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the ELO repository (student adaptive-learning profile).
final eloRepositoryProvider = Provider<EloRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EloRepository(db: db);
});

/// Sends a debug report when a block's ELO update fails (BR-S9SVNM).
/// Kept for the app's lifetime so each broken block is reported once per run;
/// the API client is read at send time so a re-login is picked up.
final eloFailureReporterProvider = Provider<EloFailureReporter>((ref) {
  return EloFailureReporter(
    send: (payload) async {
      final result = await ref
          .read(apiClientProvider)
          .post<dynamic>(ApiEndpoints.debugReports, data: payload);
      return result.isSuccess;
    },
  );
});

/// Provider for the GPF label repository (Czech vector dimension labels).
final gpfLabelRepositoryProvider = Provider<GpfLabelRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(apiClientProvider);
  return GpfLabelRepository(db, api);
});

/// Provider for computed skill cards from the user's ELO profile.
/// Tries local DB first; if no local profile, fetches from API directly.
/// Callers should use `ref.refresh(skillDisplayProvider)` before reading
/// to ensure fresh data (e.g. after sync or on page open).
final skillDisplayProvider = FutureProvider<List<SkillDisplay>>((ref) async {
  final user = await ref.watch(activeUserProvider.future);
  if (user == null) return [];

  final eloRepo = ref.watch(eloRepositoryProvider);

  // Czech domain labels from the backend canonical vector labeling (cached in
  // Drift, bundled-asset fallback). Kept offline-safe. See BR-N2E9MF.
  final domainNames =
      await ref.watch(gpfLabelRepositoryProvider).domainNames();

  // Try local DB first.
  var profile = await eloRepo.getProfile(user.id);

  // If no local profile, try fetching from API directly.
  if (profile == null) {
    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.userEloProfile,
      );
      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        final serverElo = data['profil_elo'] as List<dynamic>?;
        final serverPocet = data['profil_pocet'] as List<dynamic>?;
        if (serverElo != null && serverPocet != null) {
          final profilElo = serverElo
              .map((e) => e == null ? null : (e as num).toDouble())
              .toList();
          final profilPocet =
              serverPocet.map((e) => (e as num).toInt()).toList();
          // Persist locally for future use.
          await eloRepo.saveProfile(user.id, profilElo, profilPocet);
          return SkillDisplayService.computeSkills(
            profilElo: profilElo,
            profilPocet: profilPocet,
            domainNames: domainNames,
          );
        }
      }
    } catch (e, st) { silentLog('core_providers', e, st); }
    return [];
  }

  return SkillDisplayService.computeSkills(
    profilElo: profile.profilElo,
    profilPocet: profile.profilPocet,
    domainNames: domainNames,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// Chat Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the chat local data source.
final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChatLocalDataSource(db);
});

/// Provider for the chat remote data source.
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRemoteDataSource(apiClient);
});

/// Provider for the chat repository.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final local = ref.watch(chatLocalDataSourceProvider);
  final remote = ref.watch(chatRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final syncQueue = ref.watch(syncQueueProvider);
  return ChatRepository(
    localDataSource: local,
    remoteDataSource: remote,
    connectivity: connectivity,
    syncQueue: syncQueue,
  );
});

/// Mentors offered in the new-chat picker.
///
/// Server-driven so a mentor added in the admin shows up without an app
/// release; the repository falls back to the mentors built into this build
/// when the request fails or the device is offline.
final chatMentorsProvider = FutureProvider<List<ChatMentor>>((ref) {
  return ref.watch(chatRepositoryProvider).fetchMentors();
});

/// Mentors bound to one course, hidden ones included.
///
/// Keyed by the LOCAL course id (the drift row's UUID), because that is what
/// the course screens carry; the server id it needs is resolved here. A course
/// that was never synced has no server id and therefore no mentors.
final courseChatMentorsProvider =
    FutureProvider.family<List<ChatMentor>, String>((ref, localCourseId) async {
  final row = await ref.watch(courseLocalDataSourceProvider).getCourseById(localCourseId);
  final serverId = row?.serverId;
  if (serverId == null) return const [];

  return ref.watch(chatRepositoryProvider).fetchMentors(courseId: serverId);
});

/// Stream of chat sessions for the active user.
final chatSessionsStreamProvider = StreamProvider<List<ChatSessionsTableData>>((ref) {
  final userAsync = ref.watch(activeUserStreamProvider);
  final local = ref.watch(chatLocalDataSourceProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return Stream.value([]);
  return local.watchSessions(user.id);
});

/// Stream of messages for a specific chat session.
final chatMessagesStreamProvider =
    StreamProvider.family<List<ChatMessagesTableData>, String>((ref, sessionId) {
  final local = ref.watch(chatLocalDataSourceProvider);
  return local.watchMessages(sessionId);
});

// ═══════════════════════════════════════════════════════════════════════════
// News (Novinky) Providers — online-only, no local storage
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the news remote data source.
final newsRemoteDataSourceProvider = Provider<NewsRemoteDataSource>((ref) {
  return NewsRemoteDataSource(ref.watch(apiClientProvider));
});

/// Provider for the news repository.
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository(ref.watch(newsRemoteDataSourceProvider));
});

/// Future provider for the news list. As a side-effect it updates the
/// unread-count provider so the bottom-nav badge stays in sync.
final newsListProvider = FutureProvider<List<NewsItem>>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  final result = await repository.fetchList();
  // Update unread count after the current build completes to avoid mutating
  // another provider during this provider's build.
  Future.microtask(
    () => ref.read(unreadNewsCountProvider.notifier).set(result.unreadCount),
  );
  return result.items;
});

/// Notifier holding the unread news count for the bottom-nav badge.
class UnreadNewsCount extends Notifier<int> {
  @override
  int build() => 0;

  /// Set the count directly (e.g. from a list/read response).
  void set(int count) => state = count;

  /// Fetch the news list and update the count from the server.
  Future<void> refresh() async {
    try {
      final result = await ref.read(newsRepositoryProvider).fetchList();
      state = result.unreadCount;
    } catch (e, st) {
      silentLog('news:unread-refresh', e, st);
    }
  }
}

/// Provider for the unread news count.
final unreadNewsCountProvider =
    NotifierProvider<UnreadNewsCount, int>(UnreadNewsCount.new);

// ═══════════════════════════════════════════════════════════════════════════
// Mini games (Minihry) Providers — metadata cached in prefs, entitlement online
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the mini games remote data source.
final miniGamesRemoteDataSourceProvider =
    Provider<MiniGamesRemoteDataSource>((ref) {
  return MiniGamesRemoteDataSource(ref.watch(apiClientProvider));
});

/// Provider for the mini games repository.
final miniGamesRepositoryProvider = Provider<MiniGamesRepository>((ref) {
  return MiniGamesRepository(
    ref.watch(miniGamesRemoteDataSourceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

/// Future provider for the mini games listing.
final miniGamesListProvider = FutureProvider<MiniGameList>((ref) async {
  return ref.watch(miniGamesRepositoryProvider).fetchList();
});

// ═══════════════════════════════════════════════════════════════════════════
// Avatar Providers (BR-7JRBCN) — catalog + artwork cached in Drift, so the
// composed avatar renders offline on every platform including web.
// ═══════════════════════════════════════════════════════════════════════════

final avatarRemoteDataSourceProvider = Provider<AvatarRemoteDataSource>((ref) {
  return AvatarRemoteDataSource(ref.watch(apiClientProvider));
});

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  return AvatarRepository(
    ref.watch(avatarRemoteDataSourceProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(syncQueueProvider),
  );
});

/// The active user's avatar: catalog, inventory and worn outfit.
///
/// Refreshes from the server on read and falls back to the cache; a signed-out
/// device still resolves the bundled default outfit, so there is always
/// something to draw.
class AvatarController extends AsyncNotifier<AvatarState> {
  @override
  Future<AvatarState> build() async {
    final user = await ref.watch(activeUserProvider.future);
    final repository = ref.watch(avatarRepositoryProvider);

    if (user == null) {
      // No account yet — show the free starting outfit rather than nothing.
      return repository.readLocal('');
    }

    final cached = await repository.readLocal(user.id);

    // Nothing worth painting yet (a genuine first run) — wait for the fetch
    // rather than flashing an empty catalog and an "offline" notice at a
    // device that is perfectly online.
    if (!cached.catalog.any((item) => !item.isDefault)) {
      return repository.load(user.id);
    }

    // Otherwise paint from local storage straight away: the catalog and its
    // artwork are already on the device, and blocking on the refresh only
    // bought a blank onboarding "vibe" step and an empty shop for as long as
    // the network took (BR-VCD7JD).
    _refreshInBackground(repository, user.id);
    return cached.copyWith(fromCache: true);
  }

  /// Pull the server's copy without holding up the first frame; the state is
  /// replaced once it lands, and a failure just leaves the cache showing.
  void _refreshInBackground(AvatarRepository repository, String userId) {
    // `build` has not published its value yet, so the notifier may well be
    // disposed (a rebuild, or the shop's retry button) before this lands —
    // assigning `state` then throws.
    var disposed = false;
    ref.onDispose(() => disposed = true);

    unawaited(() async {
      try {
        final refreshed = await repository.load(userId);
        if (!disposed) state = AsyncValue.data(refreshed);
      } catch (e, st) {
        silentLog('avatar:refresh-background', e, st);
      }
    }());
  }

  Future<void> equip(AvatarItem item) async {
    final user = await ref.read(activeUserProvider.future);
    if (user == null) return;

    final repository = ref.read(avatarRepositoryProvider);
    state = AsyncValue.data(await repository.equip(user.id, item));
  }

  Future<void> unequip(AvatarSlot slot) async {
    final user = await ref.read(activeUserProvider.future);
    if (user == null) return;

    final repository = ref.read(avatarRepositoryProvider);
    state = AsyncValue.data(await repository.unequip(user.id, slot));
  }

  /// Acquire [item]. Throws when offline — only the server can grant it.
  Future<void> purchase(AvatarItem item) async {
    final user = await ref.read(activeUserProvider.future);
    if (user == null) return;

    final repository = ref.read(avatarRepositoryProvider);
    state = AsyncValue.data(await repository.purchase(user.id, item));
  }
}

final avatarControllerProvider =
    AsyncNotifierProvider<AvatarController, AvatarState>(AvatarController.new);
