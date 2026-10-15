import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/sync/sync_queue.dart';
import '../../core/sync/sync_status.dart';
import 'package:eduai/core/util/silent_log.dart';

/// Status values for user courses.
enum UserCourseStatus {
  downloaded,
  inProgress,
  completed,
}

extension UserCourseStatusExtension on UserCourseStatus {
  String toApiString() {
    switch (this) {
      case UserCourseStatus.downloaded:
        return 'downloaded';
      case UserCourseStatus.inProgress:
        return 'in_progress';
      case UserCourseStatus.completed:
        return 'completed';
    }
  }

  static UserCourseStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return UserCourseStatus.inProgress;
      case 'completed':
        return UserCourseStatus.completed;
      default:
        return UserCourseStatus.downloaded;
    }
  }
}

/// User course model for use in the UI layer.
class UserCourse {
  final String id;
  final int? serverId;
  final String userId;
  final String courseId;
  final UserCourseStatus status;
  final int progressPercent;
  final int completedLessons;
  final int totalLessons;
  final int currentLessonIndex;
  final int timeSpentSeconds;
  final Map<String, dynamic> progressData;
  final int downloadedVersion;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Course details (populated from join).
  final String? courseName;
  final Map<String, dynamic>? courseData;
  final int? currentCourseVersion;
  /// Publication status from the courses table (e.g. "published", "private", "draft").
  final String? courseStatus;
  /// Catalog identifier from the `courses.course_id` column (e.g.
  /// "ZS_MAT_ZLOMKY_5"). Distinct from [courseId], which is the local UUID
  /// of the parent courses row.
  final String? catalogCourseId;

  UserCourse({
    required this.id,
    this.serverId,
    required this.userId,
    required this.courseId,
    required this.status,
    required this.progressPercent,
    required this.completedLessons,
    required this.totalLessons,
    required this.currentLessonIndex,
    required this.timeSpentSeconds,
    required this.progressData,
    required this.downloadedVersion,
    this.startedAt,
    this.completedAt,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.courseName,
    this.courseData,
    this.currentCourseVersion,
    this.courseStatus,
    this.catalogCourseId,
  });

  /// Whether an update is available (server has newer version).
  bool get hasUpdate => currentCourseVersion != null && currentCourseVersion! > downloadedVersion;

  factory UserCourse.fromTableData(
    UserCoursesTableData data, {
    CoursesTableData? course,
  }) {
    Map<String, dynamic> progressData = {};
    try {
      progressData = jsonDecode(data.progressDataJson) as Map<String, dynamic>;
    } catch (e, st) { silentLog('user_course_repository', e, st); }

    Map<String, dynamic>? courseData;
    if (course != null) {
      try {
        courseData = jsonDecode(course.data) as Map<String, dynamic>;
      } catch (e, st) { silentLog('user_course_repository', e, st); }
    }

    return UserCourse(
      id: data.id,
      serverId: data.serverId,
      userId: data.userId,
      courseId: data.courseId,
      status: UserCourseStatusExtension.fromString(data.status),
      progressPercent: data.progressPercent,
      completedLessons: data.completedLessons,
      totalLessons: data.totalLessons,
      currentLessonIndex: data.currentLessonIndex,
      timeSpentSeconds: data.timeSpentSeconds,
      progressData: progressData,
      downloadedVersion: data.downloadedVersion,
      startedAt: data.startedAt,
      completedAt: data.completedAt,
      syncStatus: SyncStatusExtension.fromInt(data.syncStatus),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      courseName: course?.name,
      courseData: courseData,
      currentCourseVersion: course?.version,
      courseStatus: course?.status,
      catalogCourseId: course?.courseId,
    );
  }

  /// Whether this user course has local changes not yet synced.
  bool get isPending => syncStatus == SyncStatus.pending;

  /// Whether this user course is synced with the server.
  bool get isSynced => syncStatus == SyncStatus.synced;

  /// Whether the course has been started.
  bool get isStarted => status != UserCourseStatus.downloaded;

  /// Whether the course is completed.
  bool get isCompleted => status == UserCourseStatus.completed;

  /// Whether the course is flagged "only once" — typically a test.
  ///
  /// The one place the course lists ask the question, so the rule stays
  /// greppable instead of being a raw JSON lookup repeated per screen. Such a
  /// course is hidden from the dashboard and the library, cannot be re-entered
  /// after completion, and none of its blocks feed practice (BR-E495XK).
  bool get isOnlyOnce => courseData?['only_once'] == true;

  /// Whether the user has any recorded progress but hasn't finished the course.
  ///
  /// Used by the dashboard "Pokračovat" section. It deliberately does NOT rely
  /// on [completedLessons] alone: block/quiz-based courses never increment it
  /// (only lesson completion does), so a genuinely-started course would
  /// otherwise fall through both the Pokračovat and the Rychlé kvízy sections
  /// and become invisible (BR-ZBW7TB).
  bool get hasStarted {
    if (isCompleted) return false;
    if (completedLessons > 0 ||
        currentLessonIndex > 0 ||
        progressPercent > 0 ||
        status == UserCourseStatus.inProgress) {
      return true;
    }
    final lessons = progressData['lessons'];
    if (lessons is Map && lessons.isNotEmpty) return true;
    if (progressData['quiz_in_progress'] == true) return true;
    if (progressData.containsKey('quiz_current_index')) return true;
    return false;
  }
}

/// Repository for user course operations.
/// Implements offline-first pattern: reads from local, writes queue for sync.
class UserCourseRepository {
  final AppDatabase _db;
  final SyncQueue _syncQueue;
  final _uuid = const Uuid();

  UserCourseRepository({
    required AppDatabase db,
    required SyncQueue syncQueue,
  })  : _db = db,
        _syncQueue = syncQueue;

  // ═══════════════════════════════════════════════════════════════════════════
  // Read Operations (always from local)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all user courses for a user.
  Future<List<UserCourse>> getUserCourses(String userId, {UserCourseStatus? status}) async {
    final userCoursesData = await _db.getUserCourses(userId, status: status?.toApiString());
    return _enrichWithCourseData(userCoursesData);
  }

  /// Watch all user courses for a user as a stream.
  Stream<List<UserCourse>> watchUserCourses(String userId, {UserCourseStatus? status}) {
    return _db.watchUserCourses(userId, status: status?.toApiString()).asyncMap(
      (userCoursesData) => _enrichWithCourseData(userCoursesData),
    );
  }

  /// Get a user course by local ID.
  Future<UserCourse?> getUserCourseById(String id) async {
    final data = await _db.getUserCourseById(id);
    if (data == null) return null;

    final course = await _db.getCourseById(data.courseId);
    return UserCourse.fromTableData(data, course: course);
  }

  /// Check if a user has a specific course.
  Future<bool> hasUserCourse(String userId, String courseId) async {
    final existing = await _db.getUserCourseByUserAndCourse(userId, courseId);
    return existing != null;
  }

  /// Enrich user courses with course data.
  Future<List<UserCourse>> _enrichWithCourseData(List<UserCoursesTableData> userCourses) async {
    final result = <UserCourse>[];
    for (final uc in userCourses) {
      final course = await _db.getCourseById(uc.courseId);
      result.add(UserCourse.fromTableData(uc, course: course));
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Write Operations (local + queue for sync)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start/download a course for a user.
  /// Creates a local entry and queues for server sync.
  Future<String> startCourse({
    required String userId,
    required String courseId,
  }) async {

    // Check if already exists.
    final existing = await _db.getUserCourseByUserAndCourse(userId, courseId);
    if (existing != null) {
      return existing.id;
    }

    // Get course to determine total lessons.
    final course = await _db.getCourseById(courseId);
    int totalLessons = 0;
    if (course != null) {
      try {
        final courseData = jsonDecode(course.data) as Map<String, dynamic>;
        final lessons = courseData['lessons'] as List<dynamic>?;
        totalLessons = lessons?.length ?? 0;
      } catch (e, st) { silentLog('user_course_repository', e, st); }
    }

    final localId = _uuid.v4();
    final now = DateTime.now();
    final downloadedVersion = course?.version ?? 1;

    try {
      await _db.upsertUserCourse(
        UserCoursesTableCompanion(
          id: Value(localId),
          userId: Value(userId),
          courseId: Value(courseId),
          status: const Value('downloaded'),
          progressPercent: const Value(0),
          completedLessons: const Value(0),
          totalLessons: Value(totalLessons),
          currentLessonIndex: const Value(0),
          timeSpentSeconds: const Value(0),
          progressDataJson: const Value('{}'),
          downloadedVersion: Value(downloadedVersion),
          syncStatus: const Value(1), // Pending sync
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    } catch (e, stack) {
      rethrow;
    }

    // Queue for sync — send the string course_id the API expects.
    if (course != null) {
      await _syncQueue.enqueue(
        tableName: 'user_courses',
        recordId: localId,
        operation: SyncOperation.create,
        payload: {'course_id': course.courseId},
      );
    }

    return localId;
  }

  /// Update progress for a user course.
  Future<void> updateProgress({
    required String id,
    int? progressPercent,
    UserCourseStatus? status,
    int? completedLessons,
    int? currentLessonIndex,
    int? addTimeSpentSeconds,
    Map<String, dynamic>? progressData,
  }) async {
    final existing = await _db.getUserCourseById(id);
    if (existing == null) {
      return;
    }

    // Calculate new time spent.
    final newTimeSpent = addTimeSpentSeconds != null
        ? existing.timeSpentSeconds + addTimeSpentSeconds
        : null;

    // Determine new status based on progress.
    String? newStatus = status?.toApiString();
    if (progressPercent != null) {
      if (progressPercent >= 100 && existing.status != 'completed') {
        newStatus = 'completed';
      } else if (progressPercent > 0 && existing.status == 'downloaded') {
        newStatus = 'in_progress';
      }
    }

    await _db.updateUserCourseProgress(
      id: id,
      progressPercent: progressPercent,
      status: newStatus,
      completedLessons: completedLessons,
      currentLessonIndex: currentLessonIndex,
      timeSpentSeconds: newTimeSpent,
      progressDataJson: progressData != null ? jsonEncode(progressData) : null,
    );

    // Queue for sync if server ID is already known.
    // If serverId is null (e.g. code-entry path before CREATE sync),
    // the record stays with syncStatus=1 (pending). The CREATE handler
    // in SyncService will detect unsync'd progress and queue an UPDATE
    // once serverId is established.
    final updated = await _db.getUserCourseById(id);
    if (updated?.serverId != null) {
      await _syncQueue.enqueue(
        tableName: 'user_courses',
        recordId: id,
        operation: SyncOperation.update,
        payload: _buildSyncPayload(updated!),
      );
    }
  }

  /// Update a downloaded course to a newer version.
  /// Re-downloads the course JSON and updates downloadedVersion.
  Future<void> updateCourseVersion({
    required String id,
    required int newVersion,
  }) async {
    final existing = await _db.getUserCourseById(id);
    if (existing == null) return;

    await _db.updateUserCourseDownloadedVersion(
      id: id,
      downloadedVersion: newVersion,
    );
  }

  /// Remove a course from user's library.
  Future<void> removeCourse(String id) async {
    final existing = await _db.getUserCourseById(id);
    if (existing == null) return;

    if (existing.serverId == null) {
      // Never synced - just delete locally.
      await _db.deleteUserCourse(id);
      await _syncQueue.clearForRecord('user_courses', id);
    } else {
      // Look up the course's string identifier for the API URL.
      final course = await _db.getCourseById(existing.courseId);

      // Queue delete operation, then delete locally.
      await _syncQueue.enqueue(
        tableName: 'user_courses',
        recordId: id,
        operation: SyncOperation.delete,
        payload: {'course_id': course?.courseId ?? ''},
      );
      await _db.deleteUserCourse(id);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sync Operations
  // ═══════════════════════════════════════════════════════════════════════════

  // NOTE: pulling user courses from the server lives in
  // SyncService._pullUserCourseUpdates — the single source of truth wired into
  // the sync engine. An older syncFromServer() duplicate used to live here but
  // was unused (no callers) and carried the BR-SNUYF7 bug where enrollments
  // whose local catalog row was missing (private courses) were silently
  // dropped; it was removed to avoid a second copy drifting out of sync.

  /// Build payload for sync operations.
  Map<String, dynamic> _buildSyncPayload(UserCoursesTableData data) {
    return {
      'progress_percent': data.progressPercent,
      'status': data.status,
      'completed_lessons': data.completedLessons,
      'current_lesson_index': data.currentLessonIndex,
      'time_spent_seconds': data.timeSpentSeconds,
      'progress_data': jsonDecode(data.progressDataJson),
    };
  }

  /// Get count of user courses with pending sync.
  Future<int> getPendingSyncCount() async {
    final pending = await _db.getPendingSyncUserCourses();
    return pending.length;
  }
}
