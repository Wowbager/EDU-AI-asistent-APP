import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/connectivity/connectivity_service.dart';
import '../core/network/api_endpoints.dart';
import '../core/providers/core_providers.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';
import 'bookmarks_list_page.dart';
import 'package:eduai/core/util/silent_log.dart';
import '../widgets/page_header.dart';
import '../core/layout/breakpoints.dart';

/// Debug/About page showing app info and system status.
class AboutPage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onFactoryReset;

  const AboutPage({super.key, this.onBack, this.onFactoryReset});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  // Debug info state
  String _appVersion = '';
  bool _isDatabaseInitialized = false;
  int _coursesCount = 0;
  int _pendingSyncCount = 0;
  String _syncStatus = 'Unknown';
  DateTime? _lastSyncTime;
  DateTime? _nextSyncTime;
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() => _isCheckingStatus = true);

    // Load version separately so it always shows
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      _appVersion = AppStrings.aboutVersionUnavailable;
    }

    try {
      // Check database
      final db = ref.read(appDatabaseProvider);
      final courses = await db.getAllCourses();
      _isDatabaseInitialized = true;
      _coursesCount = courses.length;

      // Check sync status
      final syncService = ref.read(syncServiceProvider);
      _pendingSyncCount = await syncService.getPendingCount();
      _syncStatus = syncService.currentState.name;
      _lastSyncTime = syncService.lastSyncTime;
      _nextSyncTime = syncService.nextSyncTime;

    } catch (e) {
      _isDatabaseInitialized = false;
    }

    if (mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  String _mapConnectivityState(ConnectivityState state) {
    switch (state) {
      case ConnectivityState.wifi:
        return AppStrings.aboutConnWifi;
      case ConnectivityState.mobile:
        return AppStrings.aboutConnMobile;
      case ConnectivityState.ethernet:
        return AppStrings.aboutConnEthernet;
      case ConnectivityState.offline:
        return AppStrings.aboutConnOffline;
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final time = '$h:$m';

    if (diff.isNegative) {
      // Future time (next sync)
      final remaining = dt.difference(now);
      if (remaining.inMinutes < 1) return AppStrings.aboutTimeSoon();
      return AppStrings.aboutTimeInMinutes(remaining.inMinutes, time);
    }

    // Past time (last sync)
    if (diff.inSeconds < 60) return AppStrings.aboutTimeJustNow();
    if (diff.inMinutes < 60) return AppStrings.aboutTimeMinutesAgo(diff.inMinutes, time);
    return AppStrings.aboutTimeToday(time);
  }

  String _mapSyncState(String state) {
    switch (state) {
      case 'idle':
        return AppStrings.aboutSyncReady;
      case 'syncing':
        return AppStrings.aboutSyncSyncing;
      case 'error':
        return AppStrings.aboutSyncError;
      default:
        return state;
    }
  }

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    final userAsync = ref.watch(activeUserStreamProvider);
    final activeUser = userAsync.valueOrNull;
    final hasLocalSession = activeUser != null;
    final isGuest = hasLocalSession && activeUser.email.isEmpty;
    final isApiAuthenticated = ref.watch(isAuthenticatedProvider);
    final connectivityAsync = ref.watch(currentConnectivityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDebugInfo,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // App Info Section
                    _buildSectionHeader(AppStrings.aboutSectionAppInfo),
                    _buildInfoCard([
                      _buildInfoRow(AppStrings.aboutLabelName, AppStrings.aboutAppName),
                      _buildInfoRow(AppStrings.aboutLabelVersion, _appVersion),
                      _buildInfoRow(AppStrings.aboutLabelBuild, AppStrings.aboutBuildValue),
                      _buildInfoRow(AppStrings.aboutLabelFlutter, AppStrings.aboutFlutterValue),
                    ]),

                    const SizedBox(height: 24),

                    // System Status Section
                    _buildSectionHeader(AppStrings.aboutSectionStatus),
                    _buildInfoCard([
                      _buildStatusRow(
                        AppStrings.aboutDatabase,
                        _isDatabaseInitialized ? AppStrings.aboutDatabaseReady : AppStrings.aboutDatabaseNotInit,
                        _isDatabaseInitialized,
                      ),
                      _buildStatusRow(
                        AppStrings.aboutUserLoggedIn,
                        hasLocalSession
                            ? (isGuest ? AppStrings.aboutGuestPin : AppStrings.aboutYes)
                            : AppStrings.aboutNo,
                        hasLocalSession,
                      ),
                      _buildStatusRow(
                        AppStrings.aboutApiAuth,
                        isApiAuthenticated ? AppStrings.aboutYes : AppStrings.aboutNo,
                        isApiAuthenticated,
                      ),
                      connectivityAsync.when(
                        data: (state) => _buildStatusRow(
                          AppStrings.aboutConnection,
                          _mapConnectivityState(state),
                          state != ConnectivityState.offline,
                        ),
                        loading: () => _buildInfoRow(AppStrings.aboutConnection, AppStrings.aboutConnectionChecking),
                        error: (_, __) => _buildStatusRow(AppStrings.aboutConnection, AppStrings.aboutConnectionError, false),
                      ),
                      _buildStatusRow(
                        AppStrings.aboutSyncState,
                        _mapSyncState(_syncStatus),
                        _syncStatus == 'idle',
                      ),
                      _buildInfoRow(
                        AppStrings.aboutLastSync,
                        _lastSyncTime != null
                            ? _formatDateTime(_lastSyncTime!)
                            : AppStrings.aboutSyncNever,
                      ),
                      _buildInfoRow(
                        AppStrings.aboutNextSync,
                        _nextSyncTime != null
                            ? _formatDateTime(_nextSyncTime!)
                            : '—',
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Database Stats Section
                    _buildSectionHeader(AppStrings.aboutSectionDbStats),
                    _buildInfoCard([
                      _buildInfoRow(AppStrings.aboutCoursesCount, '$_coursesCount'),
                      _buildInfoRow(AppStrings.aboutPendingSync, '$_pendingSyncCount'),
                    ]),

                    const SizedBox(height: 24),

                    // Actions Section
                    _buildSectionHeader(AppStrings.aboutSectionActions),
                    _buildActionCard(),

                    const SizedBox(height: 32),

                    // API Info Section
                    _buildSectionHeader(AppStrings.aboutSectionApiConfig),
                    _buildInfoCard([
                      _buildInfoRow(AppStrings.aboutBaseUrl, ApiEndpoints.baseUrl.replaceFirst('https://', '')),
                      _buildInfoRow(AppStrings.aboutAuth, AppStrings.aboutAuthValue),
                    ]),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: PageHeader(
        title: AppStrings.aboutTitle,
        onBack: widget.onBack,
        actions: [
          if (_isCheckingStatus)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.subtitle(),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        boxShadow: AppDecorations.shadowLight,
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.labelMedium(),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isGood ? AppColors.success : AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTextStyles.labelMedium(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        boxShadow: AppDecorations.shadowLight,
      ),
      child: Column(
        children: [
          _buildActionButton(
            icon: Icons.bookmark,
            label: AppStrings.aboutSavedBookmarks,
            onTap: _openBookmarksList,
          ),
          const Divider(height: 1),
          _buildActionButton(
            icon: Icons.sync,
            label: AppStrings.aboutForceSync,
            onTap: _forceSync,
          ),
          const Divider(height: 1),
          _buildActionButton(
            icon: Icons.cleaning_services_outlined,
            label: AppStrings.aboutClearSyncQueue,
            onTap: _clearSyncQueue,
            isDestructive: true,
          ),
          const Divider(height: 1),
          _buildActionButton(
            icon: Icons.refresh,
            label: AppStrings.aboutRefreshStatus,
            onTap: _loadDebugInfo,
          ),
          const Divider(height: 1),
          _buildActionButton(
            icon: Icons.bug_report_outlined,
            label: AppStrings.aboutSendDebugReport,
            onTap: _sendDebugReport,
          ),
          const Divider(height: 1),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: AppStrings.aboutClearAuthToken,
            onTap: _clearAuthToken,
            isDestructive: true,
          ),
          const Divider(height: 1),
          _buildActionButton(
            icon: Icons.library_books_outlined,
            label: AppStrings.aboutClearCourses,
            onTap: _clearLocalCourses,
            isDestructive: true,
          ),
          const Divider(height: 1),
          _buildActionButton(
            icon: Icons.restart_alt,
            label: AppStrings.aboutFactoryReset,
            onTap: _factoryReset,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppDecorations.radiusM,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive
                  ? AppColors.error
                  : AppColors.primaryDark,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.bodySmall(
                color: isDestructive
                    ? AppColors.error
                    : AppColors.primaryDark,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.primaryDark32,
            ),
          ],
        ),
      ),
    );
  }

  void _openBookmarksList() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BookmarksListPage()),
    );
  }

  Future<void> _sendDebugReport() async {
    // 1. Check connectivity
    final connectivity = ref.read(connectivityServiceProvider);
    final online = await connectivity.isOnline;
    if (!online) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutDebugReportOffline),
            backgroundColor: AppColors.orange,
          ),
        );
      }
      return;
    }

    // 2. Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.aboutDebugReportTitle,
          style: AppTextStyles.subtitle(),
        ),
        content: Text(AppStrings.aboutDebugReportMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.aboutDebugReportSend),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 3. Show "sending" indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.aboutDebugReportSending),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      // 4. Collect diagnostic data
      final payload = await _collectDebugData();

      // 5. Send directly via API
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.debugReports,
        data: payload,
        fromJson: (d) => d as Map<String, dynamic>,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutDebugReportSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutDebugReportError(result.error ?? 'Unknown')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutDebugReportError('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _collectDebugData() async {
    final db = ref.read(appDatabaseProvider);
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

    // App version
    String appVersion = '';
    String buildNumber = '';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    } catch (e, st) { silentLog('about_page', e, st); }

    // Auth info
    Map<String, dynamic>? authInfo;
    try {
      final apiClient = ref.read(apiClientProvider);
      authInfo = {
        'is_authenticated': apiClient.isAuthenticated,
        'has_token': apiClient.getAuthToken() != null,
      };
    } catch (e, st) { silentLog('about_page', e, st); }

    // User info
    Map<String, dynamic>? userInfo;
    try {
      final user = await db.getActiveUser();
      if (user != null) {
        userInfo = {
          'id': user.id,
          'email': user.email,
          'name': user.name,
          'is_guest': user.email.isEmpty,
        };
      }
    } catch (e, st) { silentLog('about_page', e, st); }

    // User stats
    Map<String, dynamic>? userStatsInfo;
    try {
      final user = await db.getActiveUser();
      if (user != null) {
        final stats = await db.getUserStats(user.id);
        if (stats != null) {
          userStatsInfo = {
            'level': stats.level,
            'xp_points': stats.xpPoints,
            'courses_count': stats.coursesCount,
            'streak_days': stats.streakDays,
            'achievements_count': stats.achievementsCount,
            'daily_xp_date': stats.dailyXpDate?.toIso8601String(),
            'daily_xp_amount': stats.dailyXpAmount,
            'sync_status': stats.syncStatus,
          };
        }
      }
    } catch (e, st) { silentLog('about_page', e, st); }

    // Connectivity
    String connectivityState = 'unknown';
    try {
      final conn = ref.read(connectivityServiceProvider);
      final state = await conn.currentState;
      connectivityState = state.name;
    } catch (e, st) { silentLog('about_page', e, st); }

    // Database info
    Map<String, dynamic>? databaseInfo;
    try {
      final courses = await db.getAllCourses();
      final user = await db.getActiveUser();
      List<Map<String, dynamic>>? userCoursesData;
      if (user != null) {
        final userCourses = await db.getUserCourses(user.id);
        userCoursesData = userCourses.map((uc) => {
          'id': uc.id,
          'course_id': uc.courseId,
          'server_id': uc.serverId,
          'status': uc.status,
          'progress_percent': uc.progressPercent,
          'completed_lessons': uc.completedLessons,
          'downloaded_version': uc.downloadedVersion,
          'sync_status': uc.syncStatus,
        }).toList();
      }
      databaseInfo = {
        'courses_count': courses.length,
        'user_courses_count': userCoursesData?.length ?? 0,
        'courses': courses.map((c) => {
          'id': c.id,
          'course_id': c.courseId,
          'server_id': c.serverId,
          'name': c.name,
          'sync_status': c.syncStatus,
          'updated_at': c.updatedAt.toIso8601String(),
        }).toList(),
        'user_courses': userCoursesData ?? [],
      };
    } catch (e, st) { silentLog('about_page', e, st); }

    // Sync info
    Map<String, dynamic>? syncInfo;
    try {
      final syncService = ref.read(syncServiceProvider);
      final syncQueue = ref.read(syncQueueProvider);
      final pendingOps = await syncQueue.getPendingOperations(limit: 100);
      syncInfo = {
        'current_state': syncService.currentState.name,
        'last_sync_time': syncService.lastSyncTime?.toIso8601String(),
        'next_sync_time': syncService.nextSyncTime?.toIso8601String(),
        'pending_count': pendingOps.length,
        'queue_entries': pendingOps.map((op) => {
          'id': op.id,
          'table_name': op.tableName_,
          'record_id': op.recordId,
          'operation': op.operation,
          'retry_count': op.retryCount,
          'last_error': op.lastError,
          'created_at': op.createdAt.toIso8601String(),
          'scheduled_at': op.scheduledAt.toIso8601String(),
        }).toList(),
      };
    } catch (e, st) { silentLog('about_page', e, st); }

    // ELO profile
    Map<String, dynamic>? eloInfo;
    try {
      final user = await db.getActiveUser();
      if (user != null) {
        final eloRepo = ref.read(eloRepositoryProvider);
        final profile = await eloRepo.getProfile(user.id);
        if (profile != null) {
          eloInfo = {
            'profil_elo': profile.profilElo,
            'profil_pocet': profile.profilPocet,
            'sync_status': profile.syncStatus.index,
          };
        }
      }
    } catch (e, st) { silentLog('about_page', e, st); }

    // Practice / FSRS cards — surfaces whether cards were ever seeded so a
    // "bookmarks but no Procvičování" report can be diagnosed without guessing.
    Map<String, dynamic>? practiceInfo;
    try {
      final user = await db.getActiveUser();
      if (user != null) {
        final activeCards = await db.getActivePracticeCards(user.id);
        final dueCount = await db.countDuePracticeCards(user.id);
        final bookmarks = await db.getAllBookmarks(user.id);
        practiceInfo = {
          'active_cards': activeCards.length,
          'due_cards': dueCount,
          'bookmarks': bookmarks.length,
          'cards': activeCards
              .map((c) => {
                    'block_id': c.blockId,
                    'course_id': c.courseId,
                    'source_type': c.sourceType,
                    'state': c.state,
                    'due_date': c.dueDate.toIso8601String(),
                    'is_active': c.isActive,
                  })
              .toList(),
        };
      }
    } catch (e, st) { silentLog('about_page', e, st); }

    return {
      'app_version': appVersion.isNotEmpty ? '$appVersion+$buildNumber' : 'unknown',
      'platform': platform,
      'os_version': null,
      'device_model': null,
      'report_data': {
        'timestamp': DateTime.now().toIso8601String(),
        'app': {
          'version': appVersion,
          'build_number': buildNumber,
        },
        'device': {
          'platform': platform,
          'is_web': kIsWeb,
        },
        'auth': authInfo,
        'user': userInfo,
        'user_stats': userStatsInfo,
        'connectivity': connectivityState,
        'database': databaseInfo,
        'sync': syncInfo,
        'elo': eloInfo,
        'practice': practiceInfo,
      },
    };
  }

  Future<void> _clearSyncQueue() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final count = await db.clearEntireSyncQueue();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutSyncQueueCleared(count)),
            backgroundColor: AppColors.success,
          ),
        );
        _loadDebugInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.genericError('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _forceSync() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.forceSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutSyncCompleted),
            backgroundColor: AppColors.success,
          ),
        );
        _loadDebugInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutSyncErrorMsg('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _clearAuthToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.aboutClearTokenTitle,
          style: AppTextStyles.subtitle(),
        ),
        content: Text(
          AppStrings.aboutClearTokenMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(AppStrings.actionDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.clearAuthToken();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.aboutTokenCleared),
            backgroundColor: AppColors.success,
          ),
        );
        _loadDebugInfo();
      }
    }
  }

  Future<void> _clearLocalCourses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.aboutClearCoursesTitle,
          style: AppTextStyles.subtitle(),
        ),
        content: Text(
          AppStrings.aboutClearCoursesMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(AppStrings.actionDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = ref.read(appDatabaseProvider);
        final user = await db.getActiveUser();

        if (user != null) {
          final deletedCount = await db.deleteAllUserCoursesForUser(user.id);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.aboutCoursesCleared(deletedCount)),
                backgroundColor: AppColors.success,
              ),
            );
            _loadDebugInfo();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.aboutNoUser),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.genericError('$e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _factoryReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.aboutFactoryResetTitle,
          style: AppTextStyles.subtitle(),
        ),
        content: Text(
          AppStrings.aboutFactoryResetMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(AppStrings.aboutDeleteAll),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 1. Clear all database tables
        final db = ref.read(appDatabaseProvider);
        await db.clearAllData();

        // 2. Clear auth token + device_id from SharedPreferences
        final apiClient = ref.read(apiClientProvider);
        await apiClient.clearAuthToken();
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.remove('guest_device_id');

        // 3. Reset the palette — it lives in SharedPreferences, not Drift, so
        //    step 1 leaves it behind (BR-P4JUDT).
        await ThemeManager.resetToDefault();

        // 4. Navigate to auth screen
        if (mounted) {
          final resetCallback = widget.onFactoryReset;
          Navigator.of(context).popUntil((route) => route.isFirst);
          resetCallback?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.genericError('$e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
