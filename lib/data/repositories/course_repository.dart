import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/database/app_database.dart';
import '../../core/media/course_image_urls.dart';
import '../../core/media/lesson_image_cache.dart';
import '../../core/sync/sync_queue.dart';
import '../../core/sync/sync_status.dart';
import '../datasources/local/bundled_courses_datasource.dart';
import '../datasources/local/course_local_datasource.dart';
import '../datasources/remote/course_remote_datasource.dart';
import 'package:eduai/core/util/silent_log.dart';

/// Course model for use in the UI layer.
class Course {
  final String id;
  final int? serverId;
  final String courseId;
  final String name;
  final int version;
  final String status;
  final String language;
  final Map<String, dynamic> data;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  Course({
    required this.id,
    this.serverId,
    required this.courseId,
    required this.name,
    required this.version,
    required this.status,
    required this.language,
    required this.data,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Course.fromTableData(CoursesTableData data, Map<String, dynamic> parsedData) {
    return Course(
      id: data.id,
      serverId: data.serverId,
      courseId: data.courseId,
      name: data.name,
      version: data.version,
      status: data.status,
      language: data.language,
      data: parsedData,
      syncStatus: SyncStatusExtension.fromInt(data.syncStatus),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  /// Whether this course has local changes not yet synced.
  bool get isPending => syncStatus == SyncStatus.pending;

  /// Whether this course has a sync conflict.
  bool get hasConflict => syncStatus == SyncStatus.conflict;

  /// Whether this course is synced with the server.
  bool get isSynced => syncStatus == SyncStatus.synced;

  /// Whether this course exists only locally.
  bool get isLocalOnly => serverId == null;
}

/// Repository for course operations.
/// Implements offline-first pattern: reads from local, writes queue for sync.
/// Also supports bundled courses shipped with the app for offline access.
class CourseRepository {
  final CourseLocalDataSource _localDataSource;
  final CourseRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivity;
  final SyncQueue _syncQueue;
  final BundledCoursesDataSource _bundledDataSource;
  final Uuid _uuid = const Uuid();

  CourseRepository({
    required CourseLocalDataSource localDataSource,
    required CourseRemoteDataSource remoteDataSource,
    required ConnectivityService connectivity,
    required SyncQueue syncQueue,
    BundledCoursesDataSource? bundledDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _connectivity = connectivity,
        _syncQueue = syncQueue,
        _bundledDataSource = bundledDataSource ?? BundledCoursesDataSource();

  // ═══════════════════════════════════════════════════════════════════════════
  // Bundled Course Seeding
  // ═══════════════════════════════════════════════════════════════════════════

  /// Import all bundled courses from assets into the local database.
  /// Safe to call multiple times — skips courses already present.
  /// Also cleans up any duplicate course records.
  /// Returns the list of successfully imported/existing Course objects.
  Future<List<Course>> ensureBundledCoursesLoaded() async {
    final ids = await _bundledDataSource.getBundledCourseIds();
    final courses = <Course>[];
    for (final id in ids) {
      final data = await _bundledDataSource.loadCourse(id);
      if (data != null) {
        final course = await _importBundledCourse(data);
        if (course != null) courses.add(course);
      }
    }

    // Clean up duplicates that may have been created before the dedup
    // lookup fix (bundled + synced copies of the same course).
    await deduplicateCourses();
    return courses;
  }

  /// Remove duplicate course records that share the same courseId string.
  /// Keeps server-linked copies, migrates user_courses references.
  Future<int> deduplicateCourses() async {
    final db = _localDataSource.database;
    return db.deduplicateCourses();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Read Operations (always from local)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all courses from local database.
  Future<List<Course>> getAllCourses() async {
    final coursesData = await _localDataSource.getAllCourses();
    return coursesData.map((data) {
      final parsedData = _localDataSource.parseCourseData(data);
      return Course.fromTableData(data, parsedData);
    }).toList();
  }

  /// Watch all courses as a stream.
  Stream<List<Course>> watchAllCourses() {
    return _localDataSource.watchAllCourses().map((coursesData) {
      return coursesData.map((data) {
        final parsedData = _localDataSource.parseCourseData(data);
        return Course.fromTableData(data, parsedData);
      }).toList();
    });
  }

  /// Get a course by local ID.
  Future<Course?> getCourseById(String id) async {
    final data = await _localDataSource.getCourseById(id);
    if (data == null) return null;

    final parsedData = _localDataSource.parseCourseData(data);
    return Course.fromTableData(data, parsedData);
  }

  /// Get a course by its courseId identifier field (e.g., "EDU_ONBOARDING_APP").
  Future<Course?> getCourseByIdentifier(String courseId) async {
    final data = await _localDataSource.getCourseByFieldCourseId(courseId);
    if (data == null) return null;

    final parsedData = _localDataSource.parseCourseData(data);
    return Course.fromTableData(data, parsedData);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Write Operations (local + queue for sync)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new course.
  /// Stores locally immediately and queues for server sync.
  Future<String> createCourse({
    required String courseId,
    required String name,
    String status = 'draft',
    String language = 'en',
    Map<String, dynamic>? data,
  }) async {
    // Save locally.
    final localId = await _localDataSource.createCourse(
      courseId: courseId,
      name: name,
      status: status,
      language: language,
      data: data,
    );

    // Queue for sync.
    final payload = await _localDataSource.getCourseDataForSync(localId);
    if (payload != null) {
      await _syncQueue.enqueue(
        tableName: 'courses',
        recordId: localId,
        operation: SyncOperation.create,
        payload: payload,
      );
    }

    return localId;
  }

  /// Update an existing course.
  /// Updates locally immediately and queues for server sync.
  Future<void> updateCourse({
    required String id,
    String? courseId,
    String? name,
    int? version,
    String? status,
    String? language,
    Map<String, dynamic>? data,
  }) async {
    // Update locally.
    await _localDataSource.updateCourse(
      id: id,
      courseId: courseId,
      name: name,
      version: version,
      status: status,
      language: language,
      data: data,
    );

    // Queue for sync.
    final payload = await _localDataSource.getCourseDataForSync(id);
    if (payload != null) {
      final course = await _localDataSource.getCourseById(id);
      final operation =
          course?.serverId == null ? SyncOperation.create : SyncOperation.update;

      await _syncQueue.enqueue(
        tableName: 'courses',
        recordId: id,
        operation: operation,
        payload: payload,
      );
    }
  }

  /// Delete a course.
  /// Marks for deletion locally and queues for server sync.
  Future<void> deleteCourse(String id) async {
    final course = await _localDataSource.getCourseById(id);

    if (course == null) return;

    if (course.serverId == null) {
      // Never synced - just delete locally.
      await _localDataSource.deleteCourse(id);
      await _syncQueue.clearForRecord('courses', id);
    } else {
      // Queue delete operation, then delete locally.
      await _syncQueue.enqueue(
        tableName: 'courses',
        recordId: id,
        operation: SyncOperation.delete,
        payload: {'server_id': course.serverId},
      );
      await _localDataSource.deleteCourse(id);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sync Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Refresh courses from the server.
  /// Only fetches if online; otherwise returns current local data.
  Future<List<Course>> refreshCourses() async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      final result = await _remoteDataSource.getAllCourses();

      if (result.isSuccess && result.data != null) {
        // Update local database with server data.
        for (final remoteCourse in result.data!) {
          // Look up by serverId first, then by courseId string (for bundled courses)
          var existingLocal =
              await _localDataSource.getCourseByServerId(remoteCourse.id);
          existingLocal ??=
              await _localDataSource.getCourseByFieldCourseId(remoteCourse.courseId);

          await _localDataSource.upsertFromServer(
            serverId: remoteCourse.id,
            courseId: remoteCourse.courseId,
            name: remoteCourse.name,
            version: remoteCourse.version,
            status: remoteCourse.status,
            language: remoteCourse.language,
            data: remoteCourse.data,
            serverUpdatedAt: remoteCourse.updatedAt,
            existingLocalId: existingLocal?.id,
          );
        }
      }
    }

    return getAllCourses();
  }

  /// Check for updates since last sync.
  /// Returns true if there were updates.
  Future<bool> checkForUpdates(DateTime? lastSyncTime) async {
    final isOnline = await _connectivity.isOnline;
    if (!isOnline) return false;

    final result = await _remoteDataSource.checkUpdates(since: lastSyncTime);

    if (result.isFailure) return false;

    final updates = result.data!;
    var hasUpdates = false;

    // Process updated courses.
    for (final remoteCourse in updates.updatedCourses) {
      // Look up by serverId first, then by courseId string (for bundled courses)
      var existingLocal =
          await _localDataSource.getCourseByServerId(remoteCourse.id);
      existingLocal ??=
          await _localDataSource.getCourseByFieldCourseId(remoteCourse.courseId);

      // Check for conflicts.
      if (existingLocal != null &&
          existingLocal.syncStatus == SyncStatus.pending.toInt()) {
        // Local has pending changes - apply last-write-wins.
        if (remoteCourse.updatedAt.isAfter(existingLocal.updatedAt)) {
          // Server wins.
          await _localDataSource.upsertFromServer(
            serverId: remoteCourse.id,
            courseId: remoteCourse.courseId,
            name: remoteCourse.name,
            version: remoteCourse.version,
            status: remoteCourse.status,
            language: remoteCourse.language,
            data: remoteCourse.data,
            serverUpdatedAt: remoteCourse.updatedAt,
            existingLocalId: existingLocal.id,
          );
          await _syncQueue.clearForRecord('courses', existingLocal.id);
        }
        // else: Local wins, keep pending.
      } else {
        // No conflict - just update.
        await _localDataSource.upsertFromServer(
          serverId: remoteCourse.id,
          courseId: remoteCourse.courseId,
          name: remoteCourse.name,
          version: remoteCourse.version,
          status: remoteCourse.status,
          language: remoteCourse.language,
          data: remoteCourse.data,
          serverUpdatedAt: remoteCourse.updatedAt,
          existingLocalId: existingLocal?.id,
        );
      }

      hasUpdates = true;
    }

    // Process deleted courses.
    for (final deletedId in updates.deletedCourseIds) {
      final local = await _localDataSource.getCourseByServerId(deletedId);
      if (local != null) {
        await _localDataSource.deleteCourse(local.id);
        await _syncQueue.clearForRecord('courses', local.id);
        hasUpdates = true;
      }
    }

    return hasUpdates;
  }

  /// Get count of courses with pending sync.
  Future<int> getPendingSyncCount() async {
    final pending = await _localDataSource.getPendingSyncCourses();
    return pending.length;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Full Course Download from R2
  // ═══════════════════════════════════════════════════════════════════════════

  /// Find a course by its access code.
  /// Checks bundled courses first, then local DB, then falls back to API.
  /// Returns the course if found, null otherwise.
  Future<Course?> findCourseByCode(String code) async {
    // Step 1: Check bundled courses first (offline-first)
    final bundledCourse = await _bundledDataSource.loadCourseByCode(code);
    if (bundledCourse != null) {
      return _importBundledCourse(bundledCourse);
    }

    // Step 2: Check local database for previously downloaded courses
    final localMatch = await _localDataSource.findCourseByCode(code);
    if (localMatch != null) {
      final parsedData = _localDataSource.parseCourseData(localMatch);
      return Course.fromTableData(localMatch, parsedData);
    }

    // Step 3: Try API if online
    final isOnline = await _connectivity.isOnline;
    if (!isOnline) {
      return null;
    }

    final result = await _remoteDataSource.findCourseByCode(code);
    if (result.isFailure || result.data == null) return null;

    final remoteCourse = result.data!;

    // Store the PIN in course data so future local lookups work
    final dataWithPin = Map<String, dynamic>.from(remoteCourse.data);
    if (dataWithPin['pin'] == null && dataWithPin['code'] == null) {
      dataWithPin['pin'] = code;
    }

    // Check if we already have this course locally (by serverId, then courseId string)
    var existingLocal = await _localDataSource.getCourseByServerId(remoteCourse.id);
    existingLocal ??= await _localDataSource.getCourseByFieldCourseId(remoteCourse.courseId);

    // Upsert into local database
    await _localDataSource.upsertFromServer(
      serverId: remoteCourse.id,
      courseId: remoteCourse.courseId,
      name: remoteCourse.name,
      version: remoteCourse.version,
      status: remoteCourse.status,
      language: remoteCourse.language,
      data: dataWithPin,
      serverUpdatedAt: remoteCourse.updatedAt,
      existingLocalId: existingLocal?.id,
    );

    // Get the local course
    final localCourse = existingLocal ?? await _localDataSource.getCourseByServerId(remoteCourse.id);
    if (localCourse == null) return null;

    final parsedData = _localDataSource.parseCourseData(localCourse);
    return Course.fromTableData(localCourse, parsedData);
  }

  /// Import a course from the resolve-code API response into the local DB.
  /// [code] is the user-entered code (stored as PIN for future local lookups).
  /// [courseJson] is the course object returned by POST /api/resolve-code.
  Future<Course?> importFromResolvedCode(
    String code,
    Map<String, dynamic> courseJson,
  ) async {
    final remoteCourse = RemoteCourse.fromJson(courseJson);

    final dataWithPin = Map<String, dynamic>.from(remoteCourse.data);
    if (dataWithPin['pin'] == null && dataWithPin['code'] == null) {
      dataWithPin['pin'] = code;
    }

    var existingLocal =
        await _localDataSource.getCourseByServerId(remoteCourse.id);
    existingLocal ??=
        await _localDataSource.getCourseByFieldCourseId(remoteCourse.courseId);

    await _localDataSource.upsertFromServer(
      serverId: remoteCourse.id,
      courseId: remoteCourse.courseId,
      name: remoteCourse.name,
      version: remoteCourse.version,
      status: remoteCourse.status,
      language: remoteCourse.language,
      data: dataWithPin,
      serverUpdatedAt: remoteCourse.updatedAt,
      existingLocalId: existingLocal?.id,
    );

    final localCourse = existingLocal ??
        await _localDataSource.getCourseByServerId(remoteCourse.id);
    if (localCourse == null) return null;

    final parsedData = _localDataSource.parseCourseData(localCourse);
    return Course.fromTableData(localCourse, parsedData);
  }

  /// Import a bundled course into the local database.
  /// Returns the Course object after import.
  /// Always updates with bundled data to ensure latest content.
  Future<Course?> _importBundledCourse(Map<String, dynamic> bundledData) async {
    final courseId = bundledData['course_id'] as String? ?? _uuid.v4();
    final name = bundledData['name'] as String? ?? 'Bundled Course';
    final version = bundledData['version'] as int? ?? 1;
    final language = bundledData['language'] as String? ?? 'cs';


    // Check if already imported
    final existing = await _localDataSource.getCourseByFieldCourseId(courseId);
    if (existing != null) {
      // Only overwrite with bundled data if bundled version >= existing version.
      // This prevents bundled (e.g. v6) from overwriting a newer API download (v7).
      final existingVersion = existing.version;
      if (version >= existingVersion) {
        await _localDataSource.updateCourseData(
            existing.id, _keepServerCover(bundledData, existing.data));
        await _localDataSource.updateCourse(id: existing.id, version: version);
      } else if (!_dataHasLessons(existing.data)) {
        // The existing row carries no real content — a metadata-only catalog
        // row seeded by sync (`data = '{}'`) or an interrupted download. Restore
        // bundled content as a stopgap so the course is at least openable
        // offline instead of rendering the "corrupted" screen. Keep the higher
        // server version so a later R2 download still fetches the authoritative
        // newer content.
        await _localDataSource.updateCourseData(
            existing.id, _keepServerCover(bundledData, existing.data));
      }

      // Re-fetch to get current data (either updated or preserved)
      final updated = await _localDataSource.getCourseById(existing.id);
      if (updated == null) return null;

      final parsedData = _localDataSource.parseCourseData(updated);
      return Course.fromTableData(updated, parsedData);
    }

    // Create new local course from bundled data
    final localId = await _localDataSource.createCourse(
      courseId: courseId,
      name: name,
      status: 'published',
      language: language,
      data: bundledData,
    );

    // Set version
    await _localDataSource.updateCourse(id: localId, version: version);

    final newCourse = await _localDataSource.getCourseById(localId);
    if (newCourse == null) return null;

    final parsedData = _localDataSource.parseCourseData(newCourse);
    return Course.fromTableData(newCourse, parsedData);
  }

  /// Check if the server has a newer version of a course (metadata only).
  /// Updates local metadata (name, version, status) but does NOT download
  /// the full course content from R2. Returns true if a newer version exists.
  /// Silently returns false if offline, no serverId, or API fails.
  Future<bool> checkCourseVersionOnly(String localId) async {
    final course = await _localDataSource.getCourseById(localId);
    if (course == null) return false;

    final isOnline = await _connectivity.isOnline;
    if (!isOnline || course.serverId == null) return false;

    try {
      final result = await _remoteDataSource.getCourse(course.serverId!);
      if (result.isFailure || result.data == null) return false;

      final remoteCourse = result.data!;
      if (remoteCourse.version <= course.version) return false;

      // Update local metadata (name, version, etc.) — preserves blocks via upsertFromServer guard
      await _localDataSource.upsertFromServer(
        serverId: remoteCourse.id,
        courseId: remoteCourse.courseId,
        name: remoteCourse.name,
        version: remoteCourse.version,
        status: remoteCourse.status,
        language: remoteCourse.language,
        data: remoteCourse.data,
        serverUpdatedAt: remoteCourse.updatedAt,
        existingLocalId: localId,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if the server has a newer version of a course and download it.
  /// Returns true if a newer version was found and downloaded.
  /// Silently returns false if offline, no serverId, or API fails.
  Future<bool> checkAndUpdateCourseVersion(String localId) async {
    final course = await _localDataSource.getCourseById(localId);
    if (course == null) return false;

    final isOnline = await _connectivity.isOnline;
    if (!isOnline || course.serverId == null) return false;

    try {
      final result = await _remoteDataSource.getCourse(course.serverId!);
      if (result.isFailure || result.data == null) return false;

      final remoteCourse = result.data!;
      if (remoteCourse.version <= course.version) return false;


      // Update local metadata (name, version, etc.) — preserves blocks via upsertFromServer guard
      await _localDataSource.upsertFromServer(
        serverId: remoteCourse.id,
        courseId: remoteCourse.courseId,
        name: remoteCourse.name,
        version: remoteCourse.version,
        status: remoteCourse.status,
        language: remoteCourse.language,
        data: remoteCourse.data,
        serverUpdatedAt: remoteCourse.updatedAt,
        existingLocalId: localId,
      );

      // Download full content from R2
      await downloadFullCourseJson(localId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Bring a course's stored content up to the server's latest version before
  /// it is opened. Returns true when newer content was downloaded and stored.
  ///
  /// Compares the version inside the stored content, not `courses.version`:
  /// sync bumps the latter from the catalog without fetching any content, and
  /// the bundled repair in [_importBundledCourse] keeps the server's higher
  /// version over bundled lessons — so the row's number can claim content it
  /// does not hold. A bundled row the first sync has not linked yet (no
  /// serverId) is matched to its server course by `course_id` (BR-6CEUUB).
  ///
  /// Silently returns false if offline or the API fails; what is on the device
  /// stays as it is.
  Future<bool> refreshOutdatedContent(String localId) async {
    final course = await _localDataSource.getCourseById(localId);
    if (course == null) return false;

    final isOnline = await _connectivity.isOnline;
    if (!isOnline) return false;

    try {
      RemoteCourse? remoteCourse;
      if (course.serverId != null) {
        final result = await _remoteDataSource.getCourse(course.serverId!);
        if (result.isSuccess) remoteCourse = result.data;
      } else {
        final result = await _remoteDataSource.getAllCourses();
        if (result.isSuccess) {
          remoteCourse = result.data
              ?.where((c) => c.courseId == course.courseId)
              .firstOrNull;
        }
      }
      if (remoteCourse == null) return false;

      final storedVersion = _contentVersion(course.data) ?? course.version;
      if (remoteCourse.version <= storedVersion) return false;

      final download = await _remoteDataSource.downloadCourseJson(remoteCourse.id);
      if (download.isFailure || download.data == null) return false;
      if (!_validateCourseJson(download.data!)) return false;

      // Metadata and content land together, so the row never carries a
      // version its lessons do not match.
      await _localDataSource.upsertFromServer(
        serverId: remoteCourse.id,
        courseId: remoteCourse.courseId,
        name: remoteCourse.name,
        version: remoteCourse.version,
        status: remoteCourse.status,
        language: remoteCourse.language,
        data: download.data!,
        serverUpdatedAt: remoteCourse.updatedAt,
        existingLocalId: localId,
      );
      return true;
    } catch (e, st) {
      silentLog('course_repository', e, st);
      return false;
    }
  }

  /// Download full course JSON from R2 and update local storage.
  /// If online, checks server for a newer version first.
  /// Falls back to bundled data, then R2 download.
  /// Returns false if download fails or JSON is invalid (missing lessons/blocks).
  Future<bool> downloadFullCourseJson(String localId) async {

    // Get local course to find course_id
    final course = await _localDataSource.getCourseById(localId);
    if (course == null) return false;

    // Step 0: If online, check server for a newer version and update metadata.
    // This ensures the version comparison below uses the true latest version,
    // not just the local version (which might still be the bundled version).
    final isOnline = await _connectivity.isOnline;
    int courseVersion = course.version;
    int? serverId = course.serverId;

    if (isOnline && serverId != null) {
      try {
        final serverResult = await _remoteDataSource.getCourse(serverId);
        if (serverResult.isSuccess && serverResult.data != null) {
          final remoteCourse = serverResult.data!;
          if (remoteCourse.version > courseVersion) {
            await _localDataSource.upsertFromServer(
              serverId: remoteCourse.id,
              courseId: remoteCourse.courseId,
              name: remoteCourse.name,
              version: remoteCourse.version,
              status: remoteCourse.status,
              language: remoteCourse.language,
              data: remoteCourse.data,
              serverUpdatedAt: remoteCourse.updatedAt,
              existingLocalId: localId,
            );
            courseVersion = remoteCourse.version;
            serverId = remoteCourse.id;
          }
        }
      } catch (e, st) { silentLog('course_repository', e, st); }
    }

    // Step 1: Check if this course is bundled
    final bundledData = await _bundledDataSource.loadCourse(course.courseId);
    final bundledVersion = bundledData != null
        ? (bundledData['version'] as int? ?? 0)
        : 0;

    // Only use bundled if its version matches or exceeds the (potentially updated) course version.
    if (bundledData != null && bundledVersion >= courseVersion) {
      if (!_validateCourseJson(bundledData)) {
        return false;
      }
      await _localDataSource.updateCourseData(localId, bundledData);
      _cacheImages(bundledData);
      return true;
    }
    if (bundledData != null) {
    }

    // Step 2: Try API/R2 if online
    if (!isOnline || serverId == null) {
      // Offline or no server ID — fall back to bundled if available (even if stale)
      if (bundledData != null && _validateCourseJson(bundledData)) {
        await _localDataSource.updateCourseData(localId, bundledData);
        _cacheImages(bundledData);
        return true;
      }
      return false;
    }

    // Download full JSON from R2
    final result = await _remoteDataSource.downloadCourseJson(serverId!);
    if (result.isFailure || result.data == null) {
      // API failed — fall back to bundled if available
      if (bundledData != null && _validateCourseJson(bundledData)) {
        await _localDataSource.updateCourseData(localId, bundledData);
        _cacheImages(bundledData);
        return true;
      }
      return false;
    }

    // Validate JSON structure before saving
    if (!_validateCourseJson(result.data!)) {
      return false;
    }

    // Update local course with full data (without changing sync status)
    await _localDataSource.updateCourseData(localId, result.data!);
    _cacheImages(result.data!);

    return true;
  }

  /// Downloads the course's pictures in the background, so it still has them
  /// offline — the JSON alone only carries their URLs (BR-BX9AA4). Never
  /// awaited: the course is usable the moment its text is stored.
  void _cacheImages(Map<String, dynamic> courseData) {
    unawaited(LessonImageCache.instance.prefetch(courseImageUrls(courseData)));
  }

  /// Whether a raw course `data` JSON string carries at least one lesson.
  /// A metadata-only catalog row (`{}`) or an interrupted download has none,
  /// which is what drives CourseDetailPage's "corrupted course" screen.
  bool _dataHasLessons(String rawData) {
    try {
      final data = jsonDecode(rawData) as Map<String, dynamic>;
      final lessons = data['lessons'];
      return lessons is List && lessons.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// [bundledData] with the cover (`header_image`) already stored in
  /// [existingRawData] carried over. The bundled JSON has no cover; the one
  /// in the row came from the server (sync or the Knihovna listing), and
  /// laying bundled content back down on every start must not drop it
  /// (BR-NZ7JUN).
  Map<String, dynamic> _keepServerCover(
    Map<String, dynamic> bundledData,
    String existingRawData,
  ) {
    if (bundledData['header_image'] != null) return bundledData;
    try {
      final existing = jsonDecode(existingRawData);
      final cover = existing is Map ? existing['header_image'] : null;
      if (cover == null) return bundledData;
      return {...bundledData, 'header_image': cover};
    } catch (_) {
      return bundledData;
    }
  }

  /// The `version` a raw course `data` JSON string carries — the version of
  /// the content itself, as exported to R2 or bundled. Null for a
  /// metadata-only row (`{}`) or unreadable data.
  int? _contentVersion(String rawData) {
    try {
      final data = jsonDecode(rawData) as Map<String, dynamic>;
      return (data['version'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Validate that course JSON has the expected structure:
  /// - Must have a non-empty `lessons` array
  /// - Each lesson must have a `blocks` array (can be empty for metadata-only lessons)
  bool _validateCourseJson(Map<String, dynamic> data) {
    final lessons = data['lessons'];
    if (lessons == null || lessons is! List || lessons.isEmpty) {
      return false;
    }

    // Check that at least the first lesson has blocks
    final firstLesson = lessons.first;
    if (firstLesson is! Map<String, dynamic>) {
      return false;
    }

    final blocks = firstLesson['blocks'];
    if (blocks == null || blocks is! List) {
      return false;
    }

    return true;
  }
}
