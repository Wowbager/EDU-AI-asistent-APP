import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import 'package:eduai/core/util/silent_log.dart';

/// Local data source for courses using Drift/SQLite.
class CourseLocalDataSource {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  CourseLocalDataSource(this._db);

  /// Expose the database for operations that need direct access (e.g. dedup).
  AppDatabase get database => _db;

  /// Get all courses from local database.
  Future<List<CoursesTableData>> getAllCourses() {
    return _db.getAllCourses();
  }

  /// Watch all courses as a stream.
  Stream<List<CoursesTableData>> watchAllCourses() {
    return _db.watchAllCourses();
  }

  /// Get a course by local ID.
  Future<CoursesTableData?> getCourseById(String id) {
    return _db.getCourseById(id);
  }

  /// Get a course by server ID.
  Future<CoursesTableData?> getCourseByServerId(int serverId) {
    return _db.getCourseByServerId(serverId);
  }

  /// Get a course by its course_id field (not the local ID).
  Future<CoursesTableData?> getCourseByFieldCourseId(String courseId) {
    return _db.getCourseByFieldCourseId(courseId);
  }

  /// Find a course by its PIN/code stored in the JSON data field.
  /// Scans all local courses and checks their data for matching 'pin' or 'code'.
  Future<CoursesTableData?> findCourseByCode(String code) async {
    final normalized = code.toUpperCase();
    final allCourses = await getAllCourses();
    for (final course in allCourses) {
      try {
        final data = jsonDecode(course.data) as Map<String, dynamic>;
        final courseCode = data['code']?.toString().toUpperCase();
        final coursePin = data['pin']?.toString().toUpperCase();
        if (courseCode == normalized || coursePin == normalized) {
          return course;
        }
      } catch (_) {
        // Skip courses with unparseable data
      }
    }
    return null;
  }

  /// Get courses that need to be synced.
  Future<List<CoursesTableData>> getPendingSyncCourses() {
    return _db.getAllCourses(syncStatus: SyncStatus.pending.toInt());
  }

  /// Create a new course locally.
  /// Returns the local ID of the created course.
  Future<String> createCourse({
    required String courseId,
    required String name,
    String? status,
    String? language,
    Map<String, dynamic>? data,
  }) async {
    final localId = _uuid.v4();
    final now = DateTime.now();

    await _db.upsertCourse(
      CoursesTableCompanion(
        id: Value(localId),
        courseId: Value(courseId),
        name: Value(name),
        status: Value(status ?? 'draft'),
        language: Value(language ?? 'en'),
        data: Value(jsonEncode(data ?? {})),
        syncStatus: Value(SyncStatus.pending.toInt()),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return localId;
  }

  /// Update an existing course.
  Future<void> updateCourse({
    required String id,
    String? courseId,
    String? name,
    int? version,
    String? status,
    String? language,
    Map<String, dynamic>? data,
  }) async {
    final existing = await getCourseById(id);
    if (existing == null) {
      throw Exception('Course not found: $id');
    }

    final now = DateTime.now();

    await _db.upsertCourse(
      CoursesTableCompanion(
        id: Value(id),
        serverId: Value(existing.serverId),
        courseId: Value(courseId ?? existing.courseId),
        name: Value(name ?? existing.name),
        version: Value(version ?? existing.version),
        status: Value(status ?? existing.status),
        language: Value(language ?? existing.language),
        data: Value(data != null ? jsonEncode(data) : existing.data),
        syncStatus: Value(SyncStatus.pending.toInt()),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
        serverUpdatedAt: Value(existing.serverUpdatedAt),
      ),
    );
  }

  /// Delete a course locally.
  Future<void> deleteCourse(String id) {
    return _db.deleteCourse(id);
  }

  /// Insert or update a course from server data.
  /// If existingLocalId is provided and the existing course has full data
  /// (with blocks), but the new data is metadata-only, preserve the existing data.
  Future<void> upsertFromServer({
    required int serverId,
    required String courseId,
    required String name,
    required int version,
    required String status,
    required String language,
    required Map<String, dynamic> data,
    required DateTime serverUpdatedAt,
    String? existingLocalId,
  }) async {
    final localId = existingLocalId ?? _uuid.v4();

    // Check if we should preserve existing data with blocks
    String dataToStore = jsonEncode(data);
    if (existingLocalId != null) {
      final existing = await getCourseById(existingLocalId);
      if (existing != null) {
        try {
          final existingData = jsonDecode(existing.data) as Map<String, dynamic>;
          final existingHasBlocks = existingData['blocks'] != null &&
              (existingData['blocks'] as List<dynamic>).isNotEmpty;
          final newHasBlocks = data['blocks'] != null &&
              (data['blocks'] as List<dynamic>).isNotEmpty;

          // If existing has blocks but new data doesn't, preserve existing data
          // but update metadata fields
          if (existingHasBlocks && !newHasBlocks) {
            // Merge: keep existing data, but update metadata from server
            existingData['emoji'] = data['emoji'] ?? existingData['emoji'];
            existingData['description'] = data['description'] ?? existingData['description'];
            existingData['author'] = data['author'] ?? existingData['author'];
            // Lesson unlocking is a course setting, not content: carry it over
            // from the listing so flipping it in admin reaches students who
            // already downloaded the course, without waiting for them to run
            // the update (BR-K47WYE). Served by the courses.open_all_lessons
            // column, so no JSON decode server-side.
            if (data['open_all_lessons'] != null) {
              existingData['open_all_lessons'] = data['open_all_lessons'];
            }
            // Same reasoning for only_once: marking a course as a test has to
            // reach students who already downloaded it, otherwise its blocks
            // keep feeding their practice queue (BR-E495XK). Also served by a
            // column, so no JSON decode server-side.
            if (data['only_once'] != null) {
              existingData['only_once'] = data['only_once'];
            }
            // A cover swapped in admin should reach students who already
            // downloaded the course, same as the emoji above (BR-YKYXC6).
            if (data['header_image'] != null) {
              existingData['header_image'] = data['header_image'];
            }
            dataToStore = jsonEncode(existingData);
          }
        } catch (e, st) { silentLog('course_local_datasource', e, st); }
      }
    }

    await _db.upsertCourse(
      CoursesTableCompanion(
        id: Value(localId),
        serverId: Value(serverId),
        courseId: Value(courseId),
        name: Value(name),
        version: Value(version),
        status: Value(status),
        language: Value(language),
        data: Value(dataToStore),
        syncStatus: Value(SyncStatus.synced.toInt()),
        updatedAt: Value(serverUpdatedAt),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  /// Mark a course as synced with server ID.
  Future<void> markSynced(String localId, int serverId, DateTime serverUpdatedAt) {
    return _db.upsertCourse(
      CoursesTableCompanion(
        id: Value(localId),
        serverId: Value(serverId),
        syncStatus: Value(SyncStatus.synced.toInt()),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  /// Mark a course as having a conflict.
  Future<void> markConflict(String localId) {
    return _db.upsertCourse(
      CoursesTableCompanion(
        id: Value(localId),
        syncStatus: Value(SyncStatus.conflict.toInt()),
      ),
    );
  }

  /// Get course data as a map (for syncing).
  Future<Map<String, dynamic>?> getCourseDataForSync(String id) async {
    final course = await getCourseById(id);
    if (course == null) return null;

    return {
      'course_id': course.courseId,
      'name': course.name,
      'version': course.version,
      'status': course.status,
      'language': course.language,
      'data': jsonDecode(course.data),
    };
  }

  /// Parse JSON data field from a course.
  Map<String, dynamic> parseCourseData(CoursesTableData course) {
    try {
      return jsonDecode(course.data) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Update only the data field of a course (without changing sync status).
  /// Used when downloading full JSON from R2.
  Future<void> updateCourseData(String id, Map<String, dynamic> data) async {
    final existing = await getCourseById(id);
    if (existing == null) {
      throw Exception('Course not found: $id');
    }

    final encodedData = jsonEncode(data);

    await _db.upsertCourse(
      CoursesTableCompanion(
        id: Value(id),
        serverId: Value(existing.serverId),
        courseId: Value(existing.courseId),
        name: Value(existing.name),
        version: Value(existing.version),
        status: Value(existing.status),
        language: Value(existing.language),
        data: Value(encodedData),
        syncStatus: Value(existing.syncStatus), // Keep existing sync status
        createdAt: Value(existing.createdAt),
        updatedAt: Value(existing.updatedAt),
        serverUpdatedAt: Value(existing.serverUpdatedAt),
      ),
    );
  }
}
