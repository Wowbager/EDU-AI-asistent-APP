import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'tables/block_stats_table.dart';
import 'tables/bookmarks_table.dart';
import 'tables/courses_table.dart';
import 'tables/gamification_config_table.dart';
import 'tables/lessons_table.dart';
import 'tables/user_achievements_table.dart';
import 'tables/user_progress_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/users_table.dart';
import 'tables/user_courses_table.dart';
import 'tables/user_elo_profile_table.dart';
import 'tables/chat_messages_table.dart';
import 'tables/chat_sessions_table.dart';
import 'tables/user_stats_table.dart';
import 'tables/practice_cards_table.dart';
import 'tables/review_logs_table.dart';
import 'tables/student_fsrs_profiles_table.dart';
import 'tables/work_heartbeats_table.dart';
import 'tables/gpf_dimensions_table.dart';
import 'tables/avatar_items_table.dart';
import 'tables/user_avatar_table.dart';
import 'package:eduai/core/util/silent_log.dart';

part 'app_database.g.dart';

/// The main Drift database for the app.
/// Provides offline-first data storage with SQLite.
@DriftDatabase(tables: [
  CoursesTable,
  LessonsTable,
  UserProgressTable,
  SyncQueueTable,
  UsersTable,
  UserCoursesTable,
  UserStatsTable,
  BookmarksTable,
  UserEloProfileTable,
  GamificationConfigTable,
  UserAchievementsTable,
  BlockStatsTable,
  ChatSessionsTable,
  ChatMessagesTable,
  PracticeCardsTable,
  ReviewLogsTable,
  StudentFsrsProfilesTable,
  WorkHeartbeatsTable,
  GpfDimensionsTable,
  AvatarItemsTable,
  UserAvatarTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(
    name: 'eduai',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  ));

  /// For testing: allows injecting a custom query executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Add users table in version 2.
        if (from < 2) {
          await m.createTable(usersTable);
        }
        // Add user_courses table in version 3.
        if (from < 3) {
          await m.createTable(userCoursesTable);
        }
        // Add downloadedVersion column to user_courses in version 4.
        if (from < 4) {
          await m.addColumn(userCoursesTable, userCoursesTable.downloadedVersion);
        }
        // Add user_stats table in version 5.
        if (from < 5) {
          await m.createTable(userStatsTable);
        }
        // Add bookmarks table in version 6.
        if (from < 6) {
          await m.createTable(bookmarksTable);
        }
        // Add lessonId column to bookmarks in version 7.
        // Wrapped in try-catch because createTable (from < 6) already
        // includes lessonId in the current table definition.
        if (from < 7) {
          try {
            await m.addColumn(bookmarksTable, bookmarksTable.lessonId);
          } catch (_) {
            // Column already exists (fresh install or from < 6 path)
          }
        }
        // Add user_elo_profiles table in version 8.
        if (from < 8) {
          await m.createTable(userEloProfileTable);
        }
        // Add daily XP tracking columns to user_stats in version 9.
        if (from < 9) {
          try {
            await m.addColumn(userStatsTable, userStatsTable.dailyXpDate);
          } catch (e, st) { silentLog('app_database', e, st); }
          try {
            await m.addColumn(userStatsTable, userStatsTable.dailyXpAmount);
          } catch (e, st) { silentLog('app_database', e, st); }
        }
        // Add gamification config + user achievements tables in version 10.
        if (from < 10) {
          await m.createTable(gamificationConfigTable);
          await m.createTable(userAchievementsTable);
        }
        // Add block_stats table for caching item_pocet + elo_vector in version 11.
        if (from < 11) {
          await m.createTable(blockStatsTable);
        }
        // Add chat_sessions and chat_messages tables in version 12.
        if (from < 12) {
          await m.createTable(chatSessionsTable);
          await m.createTable(chatMessagesTable);
        }
        // Add practice_cards, review_logs, student_fsrs_profiles in version 13.
        if (from < 13) {
          await m.createTable(practiceCardsTable);
          await m.createTable(reviewLogsTable);
          await m.createTable(studentFsrsProfilesTable);
        }
        // Add work_heartbeats table for work-time tracking in version 14.
        if (from < 14) {
          await m.createTable(workHeartbeatsTable);
        }
        // Add gpf_dimensions label cache in version 15 (BR-N2E9MF).
        if (from < 15) {
          await m.createTable(gpfDimensionsTable);
        }
        // Add avatar catalog cache + per-user outfit in version 16 (BR-7JRBCN).
        if (from < 16) {
          await m.createTable(avatarItemsTable);
          await m.createTable(userAvatarTable);
        }
        // Add measured content bounds to avatar_items in version 17.
        //
        // A separate version rather than folding the columns into 16: version
        // 16 already shipped to stage without them, so those devices would
        // otherwise keep a table the queries no longer match and every avatar
        // read would fail with "no such column". The try/catch covers the
        // from < 16 path, where createTable already included them.
        if (from < 17) {
          for (final column in [
            avatarItemsTable.boundsLeft,
            avatarItemsTable.boundsTop,
            avatarItemsTable.boundsRight,
            avatarItemsTable.boundsBottom,
          ]) {
            try {
              await m.addColumn(avatarItemsTable, column);
            } catch (e, st) {
              silentLog('app_database', e, st);
            }
          }
        }
        // Denormalise the course-level only_once flag into a column in
        // version 18 (BR-E495XK), so the practice queue can filter tests out
        // without decoding every course JSON.
        //
        // Backfill runs as SQL rather than a Dart decode loop: a stored course
        // blob contains all its blocks (including base64 images) and decoding
        // the whole library during a migration would be needlessly heavy. The
        // data column is always written by jsonEncode, so the key/value pair
        // has no whitespace; the padded pattern only guards against a blob
        // that arrived pre-encoded from elsewhere.
        if (from < 18) {
          try {
            await m.addColumn(coursesTable, coursesTable.onlyOnce);
            await customStatement(
              "UPDATE courses SET only_once = 1 "
              "WHERE data LIKE '%\"only_once\":true%' "
              "OR data LIKE '%\"only_once\": true%'",
            );
          } catch (e, st) {
            silentLog('app_database', e, st);
          }
        }
        // Drop chat messages duplicated by the send/pull race in version 19
        // (BR-M7EQY8). The write path now dedupes on server_id, but rows
        // already on a device stay there — the student keeps seeing their
        // question twice until the local database is wiped.
        if (from < 19) {
          try {
            await dedupeChatMessagesByServerId();
          } catch (e, st) {
            silentLog('app_database', e, st);
          }
        }
        // Add the EDUX coin wallet to user_stats in version 20 (BR-HK9828).
        // Both columns default to 0, so an existing device starts at zero and
        // the first sync pulls the server's total over it.
        if (from < 20) {
          for (final column in [
            userStatsTable.coinsEarned,
            userStatsTable.coinsBalance,
          ]) {
            try {
              await m.addColumn(userStatsTable, column);
            } catch (e, st) {
              silentLog('app_database', e, st);
            }
          }
        }
        // block_stats becomes a pure read cache of the server's task
        // calibration in version 21 (BR-697NCA). Until now the lesson wrote
        // its own locally computed D and counts into it; the app now reads
        // the cached D back, so those rows would pass for calibrated values.
        // Clear them, and add the column the per-course pull cursor keys on.
        if (from < 21) {
          try {
            await m.addColumn(blockStatsTable, blockStatsTable.courseId);
          } catch (e, st) {
            silentLog('app_database', e, st);
          }
          await delete(blockStatsTable).go();
        }
      },
    );
  }

  /// Collapse chat messages that share a `server_id` down to one row each.
  ///
  /// Keeps the longest content per `server_id`: for a duplicated pair that is
  /// the assistant row the stream actually filled (its twin is the empty
  /// placeholder), and two copies of a user message are identical anyway.
  /// SQLite resolves the bare `rowid` from the row that produced `max()`,
  /// which is what makes the sub-select pick a specific winner.
  Future<void> dedupeChatMessagesByServerId() {
    return customStatement(
      'DELETE FROM chat_messages '
      'WHERE server_id IS NOT NULL AND rowid NOT IN ('
      '  SELECT rowid FROM ('
      '    SELECT rowid, max(length(content)) FROM chat_messages'
      '    WHERE server_id IS NOT NULL GROUP BY server_id'
      '  )'
      ')',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Work Heartbeat Operations (BR-9SAH2R)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert one activity heartbeat.
  Future<void> insertWorkHeartbeat(WorkHeartbeatsTableCompanion row) async {
    await into(workHeartbeatsTable).insert(row, mode: InsertMode.insertOrIgnore);
  }

  /// Heartbeats not yet accepted by the server, oldest first, capped.
  Future<List<WorkHeartbeatsTableData>> getUnsyncedWorkHeartbeats({int limit = 500}) {
    return (select(workHeartbeatsTable)
          ..where((t) => t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)])
          ..limit(limit))
        .get();
  }

  /// Delete heartbeats the server has accepted (by client_uuid).
  Future<void> deleteWorkHeartbeats(List<String> clientUuids) async {
    if (clientUuids.isEmpty) return;
    await (delete(workHeartbeatsTable)
          ..where((t) => t.clientUuid.isIn(clientUuids)))
        .go();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GPF Dimension Label Operations (BR-N2E9MF)
  // ═══════════════════════════════════════════════════════════════════════════

  /// All cached GPF dimension labels, ordered by vector index.
  Future<List<GpfDimensionsTableData>> getGpfDimensions() {
    return (select(gpfDimensionsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.dimensionIndex)]))
        .get();
  }

  /// Replace the cached GPF dimension labels with [rows] in one transaction.
  Future<void> replaceGpfDimensions(
      List<GpfDimensionsTableCompanion> rows) async {
    await transaction(() async {
      await delete(gpfDimensionsTable).go();
      await batch((b) => b.insertAll(gpfDimensionsTable, rows));
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Course Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all courses, optionally filtered by sync status.
  Future<List<CoursesTableData>> getAllCourses({int? syncStatus}) {
    final query = select(coursesTable);
    if (syncStatus != null) {
      query.where((c) => c.syncStatus.equals(syncStatus));
    }
    return query.get();
  }

  /// Watch all courses as a stream.
  Stream<List<CoursesTableData>> watchAllCourses() {
    return select(coursesTable).watch();
  }

  /// Get a course by local ID.
  Future<CoursesTableData?> getCourseById(String id) {
    return (select(coursesTable)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a course by server ID.
  Future<CoursesTableData?> getCourseByServerId(int serverId) async {
    final results = await (select(coursesTable)
          ..where((c) => c.serverId.equals(serverId))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  /// Get a course by its course_id field (not the local ID).
  /// If duplicates exist, prefers the one with a serverId (server-linked).
  Future<CoursesTableData?> getCourseByFieldCourseId(String courseId) async {
    final results = await (select(coursesTable)
          ..where((c) => c.courseId.equals(courseId)))
        .get();
    if (results.isEmpty) return null;
    if (results.length == 1) return results.first;
    // Multiple matches — prefer the one linked to the server.
    return results.firstWhere(
      (c) => c.serverId != null,
      orElse: () => results.first,
    );
  }

  /// Insert or update a course.
  ///
  /// Keeps the denormalised [CoursesTable.onlyOnce] column in step with the
  /// `data` JSON it is derived from. Doing it here rather than at the ~14 call
  /// sites means no write path can forget it and silently let a test's blocks
  /// back into practice (BR-E495XK). Partial upserts that carry no `data`
  /// (markSynced, markConflict) leave the flag alone.
  Future<void> upsertCourse(CoursesTableCompanion course) {
    return into(coursesTable).insertOnConflictUpdate(
      course.data.present
          ? course.copyWith(onlyOnce: Value(_readOnlyOnce(course.data.value)))
          : course,
    );
  }

  /// Whether a course JSON blob carries `only_once: true`.
  static bool _readOnlyOnce(String data) {
    try {
      return (jsonDecode(data) as Map<String, dynamic>)['only_once'] == true;
    } catch (_) {
      // Unparseable blob: treat as a normal course rather than hiding it.
      return false;
    }
  }

  /// Every id spelling under which an `only_once` course may be referenced.
  ///
  /// A practice card's `courseId` is either the local row id or the course's
  /// own `course_id` field (see `playablePracticeProvider`), so both go in.
  /// Selects two small columns — never the `data` blob.
  Future<Set<String>> getOnlyOnceCourseKeys() async {
    final rows = await (selectOnly(coursesTable)
          ..addColumns([coursesTable.id, coursesTable.courseId])
          ..where(coursesTable.onlyOnce.equals(true)))
        .get();
    return {
      for (final row in rows) ...[
        row.read(coursesTable.id)!,
        row.read(coursesTable.courseId)!,
      ],
    };
  }

  /// Whether [courseId] — in either id spelling — names an `only_once` course.
  Future<bool> isOnlyOnceCourse(String courseId) async {
    final row = await (selectOnly(coursesTable)
          ..addColumns([coursesTable.onlyOnce])
          ..where(coursesTable.onlyOnce.equals(true) &
              (coursesTable.id.equals(courseId) |
                  coursesTable.courseId.equals(courseId)))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Delete a course by local ID.
  Future<int> deleteCourse(String id) {
    return (delete(coursesTable)..where((c) => c.id.equals(id))).go();
  }

  /// Remove duplicate courses that share the same courseId string.
  /// Keeps the server-linked copy (has serverId), deletes the local-only copy.
  /// Migrates any user_courses pointing at the deleted copy to the kept one.
  Future<int> deduplicateCourses() async {
    final allCourses = await getAllCourses();

    // Group by courseId string.
    final grouped = <String, List<CoursesTableData>>{};
    for (final c in allCourses) {
      grouped.putIfAbsent(c.courseId, () => []).add(c);
    }

    var removed = 0;
    for (final entry in grouped.entries) {
      if (entry.value.length <= 1) continue;

      // Sort: prefer serverId != null first, then most recent updatedAt.
      final sorted = List<CoursesTableData>.from(entry.value)
        ..sort((a, b) {
          if (a.serverId != null && b.serverId == null) return -1;
          if (a.serverId == null && b.serverId != null) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });

      final keeper = sorted.first;
      final duplicates = sorted.sublist(1);

      for (final dup in duplicates) {
        // Re-point enrollments from the duplicate onto the keeper, but collapse
        // instead of colliding: if the user already has an enrollment on the
        // keeper course, drop the duplicate's enrollment rather than create a
        // second (userId, courseId) row — which would later crash lookups.
        final dupEnrollments = await (select(userCoursesTable)
              ..where((uc) => uc.courseId.equals(dup.id)))
            .get();
        for (final enr in dupEnrollments) {
          final keeperEnrollment = await (select(userCoursesTable)
                ..where((uc) =>
                    uc.userId.equals(enr.userId) & uc.courseId.equals(keeper.id)))
              .get();
          if (keeperEnrollment.isEmpty) {
            await (update(userCoursesTable)..where((uc) => uc.id.equals(enr.id)))
                .write(UserCoursesTableCompanion(courseId: Value(keeper.id)));
          } else {
            await deleteUserCourse(enr.id);
          }
        }

        // Migrate user_progress referencing the duplicate.
        await (update(userProgressTable)
              ..where((p) => p.courseId.equals(dup.id)))
            .write(UserProgressTableCompanion(courseId: Value(keeper.id)));

        // Delete the duplicate.
        await deleteCourse(dup.id);
        removed++;
      }
    }
    return removed;
  }

  /// Get courses updated after a timestamp (for sync).
  Future<List<CoursesTableData>> getCoursesUpdatedAfter(DateTime timestamp) {
    return (select(coursesTable)..where((c) => c.updatedAt.isBiggerThanValue(timestamp)))
        .get();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Lesson Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all lessons for a course.
  Future<List<LessonsTableData>> getLessonsForCourse(String courseId) {
    return (select(lessonsTable)
          ..where((l) => l.courseId.equals(courseId))
          ..orderBy([(l) => OrderingTerm.asc(l.orderIndex)]))
        .get();
  }

  /// Watch lessons for a course as a stream.
  Stream<List<LessonsTableData>> watchLessonsForCourse(String courseId) {
    return (select(lessonsTable)
          ..where((l) => l.courseId.equals(courseId))
          ..orderBy([(l) => OrderingTerm.asc(l.orderIndex)]))
        .watch();
  }

  /// Get a lesson by local ID.
  Future<LessonsTableData?> getLessonById(String id) {
    return (select(lessonsTable)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert or update a lesson.
  Future<void> upsertLesson(LessonsTableCompanion lesson) {
    return into(lessonsTable).insertOnConflictUpdate(lesson);
  }

  /// Delete a lesson by local ID.
  Future<int> deleteLesson(String id) {
    return (delete(lessonsTable)..where((l) => l.id.equals(id))).go();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // User Progress Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get progress for a user and course.
  Future<UserProgressTableData?> getCourseProgress(
      String userId, String courseId) {
    return (select(userProgressTable)
          ..where((p) => p.userId.equals(userId) & p.courseId.equals(courseId) & p.lessonId.isNull()))
        .getSingleOrNull();
  }

  /// Get progress for a user and lesson.
  Future<UserProgressTableData?> getLessonProgress(
      String userId, String lessonId) {
    return (select(userProgressTable)
          ..where((p) => p.userId.equals(userId) & p.lessonId.equals(lessonId)))
        .getSingleOrNull();
  }

  /// Get all progress for a user.
  Future<List<UserProgressTableData>> getAllProgressForUser(String userId) {
    return (select(userProgressTable)..where((p) => p.userId.equals(userId)))
        .get();
  }

  /// Watch progress for a specific course.
  Stream<UserProgressTableData?> watchCourseProgress(
      String userId, String courseId) {
    return (select(userProgressTable)
          ..where((p) => p.userId.equals(userId) & p.courseId.equals(courseId) & p.lessonId.isNull()))
        .watchSingleOrNull();
  }

  /// Insert or update progress.
  Future<void> upsertProgress(UserProgressTableCompanion progress) {
    return into(userProgressTable).insertOnConflictUpdate(progress);
  }

  /// Get a progress record by local ID.
  Future<UserProgressTableData?> getProgressById(String id) {
    return (select(userProgressTable)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get progress records that need syncing.
  Future<List<UserProgressTableData>> getPendingSyncProgress() {
    return (select(userProgressTable)..where((p) => p.syncStatus.equals(1)))
        .get();
  }

  /// Update sync status for a progress record.
  Future<void> updateProgressSyncStatus(String id, int syncStatus, {int? serverId}) {
    return (update(userProgressTable)..where((p) => p.id.equals(id))).write(
      UserProgressTableCompanion(
        syncStatus: Value(syncStatus),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sync Queue Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add an operation to the sync queue.
  Future<int> addToSyncQueue(SyncQueueTableCompanion entry) {
    return into(syncQueueTable).insert(entry);
  }

  /// Get pending sync operations, ordered by priority and creation time.
  Future<List<SyncQueueTableData>> getPendingSyncOperations({int limit = 50}) {
    return (select(syncQueueTable)
          ..where((s) => s.scheduledAt.isSmallerOrEqualValue(DateTime.now()))
          ..orderBy([
            (s) => OrderingTerm.asc(s.priority),
            (s) => OrderingTerm.asc(s.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  /// Update a sync queue entry (e.g., after failed attempt).
  Future<bool> updateSyncQueueEntry(int id, SyncQueueTableCompanion entry) {
    return (update(syncQueueTable)..where((s) => s.id.equals(id)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Remove an entry from the sync queue (after successful sync).
  Future<int> removeSyncQueueEntry(int id) {
    return (delete(syncQueueTable)..where((s) => s.id.equals(id))).go();
  }

  /// Get count of pending operations (only those ready to process).
  Future<int> getPendingSyncCount() async {
    final count = countAll();
    final query = selectOnly(syncQueueTable)
      ..addColumns([count])
      ..where(syncQueueTable.scheduledAt.isSmallerOrEqualValue(DateTime.now()));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Remove dead sync entries: those that have failed 3+ times (likely
  /// permanent errors, not transient). Returns removed entries so callers
  /// can reset local syncStatus.
  Future<List<SyncQueueTableData>> removeDeadSyncEntries() async {
    final dead = await (select(syncQueueTable)
          ..where((s) => s.retryCount.isBiggerOrEqualValue(3)))
        .get();
    for (final entry in dead) {
      await (delete(syncQueueTable)..where((s) => s.id.equals(entry.id))).go();
    }
    return dead;
  }

  /// Clear the entire sync queue (for debug/testing).
  Future<int> clearEntireSyncQueue() {
    return delete(syncQueueTable).go();
  }

  /// Clear all sync queue entries for a specific record.
  Future<int> clearSyncQueueForRecord(String tableName, String recordId) {
    return (delete(syncQueueTable)
          ..where((s) => s.tableName_.equals(tableName) & s.recordId.equals(recordId)))
        .go();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // User Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the currently active/logged in user.
  Future<UsersTableData?> getActiveUser() {
    return (select(usersTable)..where((u) => u.isActive.equals(true)))
        .getSingleOrNull();
  }

  /// Get a user by ID.
  Future<UsersTableData?> getUserById(String id) {
    return (select(usersTable)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a user by email.
  Future<UsersTableData?> getUserByEmail(String email) {
    return (select(usersTable)..where((u) => u.email.equals(email)))
        .getSingleOrNull();
  }

  /// Insert or update a user.
  Future<void> upsertUser(UsersTableCompanion user) {
    return into(usersTable).insertOnConflictUpdate(user);
  }

  /// Create a new user and set as active.
  Future<void> createAndActivateUser(UsersTableCompanion user) async {
    // Deactivate all other users first.
    await (update(usersTable)..where((u) => u.isActive.equals(true)))
        .write(const UsersTableCompanion(isActive: Value(false)));

    // Insert the new user as active.
    await into(usersTable).insertOnConflictUpdate(user);
  }

  /// Create a guest user and set as active.
  /// Returns the guest user's ID.
  Future<String> createGuestUser() async {
    final guestId = const Uuid().v4();
    final now = DateTime.now();

    // Deactivate all other users first.
    await (update(usersTable)..where((u) => u.isActive.equals(true)))
        .write(const UsersTableCompanion(isActive: Value(false)));

    // Create guest user
    await into(usersTable).insert(
      UsersTableCompanion(
        id: Value(guestId),
        email: const Value(''),
        name: const Value('Host'),
        avatarIndex: const Value(0),
        selectedSubjects: const Value('[0]'),
        isEmailValidated: const Value(false),
        isActive: const Value(true),
        syncStatus: const Value(1),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return guestId;
  }

  /// Set a user as active (log in).
  Future<void> setActiveUser(String userId) async {
    // Deactivate all users.
    await (update(usersTable)..where((u) => u.isActive.equals(true)))
        .write(const UsersTableCompanion(isActive: Value(false)));

    // Activate the specified user.
    await (update(usersTable)..where((u) => u.id.equals(userId)))
        .write(const UsersTableCompanion(isActive: Value(true)));
  }

  /// Log out the current user (deactivate).
  Future<void> logoutUser() {
    return (update(usersTable)..where((u) => u.isActive.equals(true)))
        .write(const UsersTableCompanion(isActive: Value(false)));
  }

  /// Update user profile.
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    int? avatarIndex,
    String? selectedSubjects,
  }) {
    return (update(usersTable)..where((u) => u.id.equals(userId))).write(
      UsersTableCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        avatarIndex: avatarIndex != null ? Value(avatarIndex) : const Value.absent(),
        selectedSubjects: selectedSubjects != null ? Value(selectedSubjects) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update user name by user ID.
  Future<void> updateUserName(String userId, String name) {
    return (update(usersTable)..where((u) => u.id.equals(userId))).write(
      UsersTableCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update user sync status.
  Future<void> updateUserSyncStatus(String userId, int syncStatus) {
    return (update(usersTable)..where((u) => u.id.equals(userId))).write(
      UsersTableCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Watch the active user as a stream.
  Stream<UsersTableData?> watchActiveUser() {
    return (select(usersTable)..where((u) => u.isActive.equals(true)))
        .watchSingleOrNull();
  }

  /// Mark a user's email as validated.
  Future<void> markEmailValidated(String userId) {
    return (update(usersTable)..where((u) => u.id.equals(userId))).write(
      UsersTableCompanion(
        isEmailValidated: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update a user's email address (e.g. when a guest registers).
  Future<void> updateUserEmail(String userId, String email) {
    return (update(usersTable)..where((u) => u.id.equals(userId))).write(
      UsersTableCompanion(
        email: Value(email),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // User Course Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all user courses for a specific user.
  Future<List<UserCoursesTableData>> getUserCourses(String userId, {String? status}) {
    final query = select(userCoursesTable)..where((uc) => uc.userId.equals(userId));
    if (status != null) {
      query.where((uc) => uc.status.equals(status));
    }
    return (query..orderBy([(uc) => OrderingTerm.desc(uc.updatedAt)])).get();
  }

  /// Watch all user courses for a specific user as a stream.
  Stream<List<UserCoursesTableData>> watchUserCourses(String userId, {String? status}) {
    final query = select(userCoursesTable)..where((uc) => uc.userId.equals(userId));
    if (status != null) {
      query.where((uc) => uc.status.equals(status));
    }
    return (query..orderBy([(uc) => OrderingTerm.desc(uc.updatedAt)])).watch();
  }

  /// Get a user course by local ID.
  Future<UserCoursesTableData?> getUserCourseById(String id) {
    return (select(userCoursesTable)..where((uc) => uc.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a user course by user and course ID.
  /// Tolerant of duplicate rows (which historic dedup runs could leave behind):
  /// prefers the server-linked enrollment, then the most recently updated.
  Future<UserCoursesTableData?> getUserCourseByUserAndCourse(String userId, String courseId) async {
    final results = await (select(userCoursesTable)
          ..where((uc) => uc.userId.equals(userId) & uc.courseId.equals(courseId)))
        .get();
    if (results.isEmpty) return null;
    if (results.length == 1) return results.first;
    // Multiple matches — pick the best copy rather than throwing.
    final sorted = List<UserCoursesTableData>.from(results)
      ..sort((a, b) {
        if (a.serverId != null && b.serverId == null) return -1;
        if (a.serverId == null && b.serverId != null) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted.first;
  }

  /// Insert or update a user course.
  Future<void> upsertUserCourse(UserCoursesTableCompanion userCourse) {
    return into(userCoursesTable).insertOnConflictUpdate(userCourse);
  }

  /// Get a user course by server ID.
  Future<UserCoursesTableData?> getUserCourseByServerId(int serverId) async {
    final results = await (select(userCoursesTable)
          ..where((uc) => uc.serverId.equals(serverId))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  /// Find an existing enrollment for [userId] on ANY local course row that
  /// shares the given course [serverId] or [courseId] string.
  ///
  /// A course update can leave two local `courses` rows for the same logical
  /// course (same server course id, possibly a new local UUID / courseId
  /// string). When the enrollment is pinned to the "old" row, a lookup keyed on
  /// the freshly-resolved row's id misses and a duplicate enrollment gets
  /// minted (BR-MFZF5R). Matching through every sibling course row prevents it.
  Future<UserCoursesTableData?> findUserCourseByCourseIdentity(
    String userId, {
    int? serverId,
    String? courseId,
  }) async {
    final courseIds = <String>{};
    if (serverId != null) {
      final byServer = await (select(coursesTable)
            ..where((c) => c.serverId.equals(serverId)))
          .get();
      courseIds.addAll(byServer.map((c) => c.id));
    }
    if (courseId != null) {
      final byCode = await (select(coursesTable)
            ..where((c) => c.courseId.equals(courseId)))
          .get();
      courseIds.addAll(byCode.map((c) => c.id));
    }
    if (courseIds.isEmpty) return null;

    final rows = await (select(userCoursesTable)
          ..where((uc) =>
              uc.userId.equals(userId) & uc.courseId.isIn(courseIds)))
        .get();
    if (rows.isEmpty) return null;
    final sorted = List<UserCoursesTableData>.from(rows)
      ..sort(_richestEnrollmentFirst);
    return sorted.first;
  }

  /// Collapse duplicate enrollments that resolve to the same logical course.
  ///
  /// Two enrollments are duplicates when their course rows share a server
  /// course id, or (lacking one) the same courseId string. Keeps the richest
  /// copy — completed status, then highest progress, then server-linked, then
  /// most recently updated — and deletes the rest. Returns the number removed.
  ///
  /// This is the read-side safety net for BR-MFZF5R: even if a twin enrollment
  /// was already written, only one card is left standing and progress is never
  /// lost to an empty duplicate.
  Future<int> deduplicateUserCourses(String userId) async {
    final enrollments = await (select(userCoursesTable)
          ..where((uc) => uc.userId.equals(userId)))
        .get();
    if (enrollments.length < 2) return 0;

    // Resolve each enrollment's logical-course identity key.
    final courseById = <String, CoursesTableData?>{};
    for (final e in enrollments) {
      courseById.putIfAbsent(e.courseId, () => null);
    }
    for (final id in courseById.keys.toList()) {
      courseById[id] = await getCourseById(id);
    }

    String identityKey(UserCoursesTableData e) {
      final course = courseById[e.courseId];
      if (course?.serverId != null) return 's:${course!.serverId}';
      if (course != null && course.courseId.isNotEmpty) {
        return 'c:${course.courseId}';
      }
      return 'f:${e.courseId}';
    }

    final grouped = <String, List<UserCoursesTableData>>{};
    for (final e in enrollments) {
      grouped.putIfAbsent(identityKey(e), () => []).add(e);
    }

    var removed = 0;
    for (final group in grouped.values) {
      if (group.length <= 1) continue;
      final sorted = List<UserCoursesTableData>.from(group)
        ..sort(_richestEnrollmentFirst);
      for (final dup in sorted.sublist(1)) {
        await deleteUserCourse(dup.id);
        removed++;
      }
    }
    return removed;
  }

  /// Comparator ordering the "best" enrollment copy first: completed status,
  /// then higher progress, then more completed lessons, then server-linked,
  /// then most recently updated.
  static int _richestEnrollmentFirst(
      UserCoursesTableData a, UserCoursesTableData b) {
    final aDone = a.status == 'completed' ? 1 : 0;
    final bDone = b.status == 'completed' ? 1 : 0;
    if (aDone != bDone) return bDone - aDone;
    if (a.progressPercent != b.progressPercent) {
      return b.progressPercent - a.progressPercent;
    }
    if (a.completedLessons != b.completedLessons) {
      return b.completedLessons - a.completedLessons;
    }
    final aServer = a.serverId != null ? 1 : 0;
    final bServer = b.serverId != null ? 1 : 0;
    if (aServer != bServer) return bServer - aServer;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  /// Delete a user course by local ID.
  Future<int> deleteUserCourse(String id) {
    return (delete(userCoursesTable)..where((uc) => uc.id.equals(id))).go();
  }

  /// Delete a user course by user and course ID.
  Future<int> deleteUserCourseByUserAndCourse(String userId, String courseId) {
    return (delete(userCoursesTable)
          ..where((uc) => uc.userId.equals(userId) & uc.courseId.equals(courseId)))
        .go();
  }

  /// Delete all user courses for a user (clears local library).
  Future<int> deleteAllUserCoursesForUser(String userId) {
    return (delete(userCoursesTable)..where((uc) => uc.userId.equals(userId))).go();
  }

  /// Update user course progress.
  Future<void> updateUserCourseProgress({
    required String id,
    int? progressPercent,
    String? status,
    int? completedLessons,
    int? currentLessonIndex,
    int? timeSpentSeconds,
    String? progressDataJson,
  }) {
    return (update(userCoursesTable)..where((uc) => uc.id.equals(id))).write(
      UserCoursesTableCompanion(
        progressPercent: progressPercent != null ? Value(progressPercent) : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
        completedLessons: completedLessons != null ? Value(completedLessons) : const Value.absent(),
        currentLessonIndex: currentLessonIndex != null ? Value(currentLessonIndex) : const Value.absent(),
        timeSpentSeconds: timeSpentSeconds != null ? Value(timeSpentSeconds) : const Value.absent(),
        progressDataJson: progressDataJson != null ? Value(progressDataJson) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value(1), // Mark as pending sync
      ),
    );
  }

  /// Update sync-related fields on a user course (serverId, syncStatus).
  /// Uses UPDATE (not upsert) so only the specified columns are touched.
  Future<void> updateUserCourseSyncFields({
    required String id,
    int? serverId,
    int? syncStatus,
  }) {
    return (update(userCoursesTable)..where((uc) => uc.id.equals(id))).write(
      UserCoursesTableCompanion(
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
        syncStatus: syncStatus != null ? Value(syncStatus) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get user courses that need syncing.
  Future<List<UserCoursesTableData>> getPendingSyncUserCourses() {
    return (select(userCoursesTable)..where((uc) => uc.syncStatus.equals(1))).get();
  }

  /// Update the downloaded version of a user course (after updating to newer version).
  Future<void> updateUserCourseDownloadedVersion({
    required String id,
    required int downloadedVersion,
  }) {
    return (update(userCoursesTable)..where((uc) => uc.id.equals(id))).write(
      UserCoursesTableCompanion(
        downloadedVersion: Value(downloadedVersion),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // User Stats Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get stats for a specific user.
  Future<UserStatsTableData?> getUserStats(String userId) {
    return (select(userStatsTable)..where((s) => s.userId.equals(userId)))
        .getSingleOrNull();
  }

  /// Watch stats for a specific user as a stream.
  Stream<UserStatsTableData?> watchUserStats(String userId) {
    return (select(userStatsTable)..where((s) => s.userId.equals(userId)))
        .watchSingleOrNull();
  }

  /// Insert or update user stats.
  Future<void> upsertUserStats(UserStatsTableCompanion stats) {
    return into(userStatsTable).insertOnConflictUpdate(stats);
  }

  /// Get user stats by local ID.
  Future<UserStatsTableData?> getUserStatsByLocalId(String id) {
    return (select(userStatsTable)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  /// Update user stats fields.
  Future<void> updateUserStats({
    required String id,
    int? level,
    int? xpPoints,
    int? coursesCount,
    int? streakDays,
    int? achievementsCount,
    DateTime? lastStreakDate,
    DateTime? dailyXpDate,
    int? dailyXpAmount,
    int? coinsEarned,
    int? coinsBalance,
  }) {
    return (update(userStatsTable)..where((s) => s.id.equals(id))).write(
      UserStatsTableCompanion(
        level: level != null ? Value(level) : const Value.absent(),
        xpPoints: xpPoints != null ? Value(xpPoints) : const Value.absent(),
        coursesCount: coursesCount != null ? Value(coursesCount) : const Value.absent(),
        streakDays: streakDays != null ? Value(streakDays) : const Value.absent(),
        achievementsCount: achievementsCount != null ? Value(achievementsCount) : const Value.absent(),
        lastStreakDate: lastStreakDate != null ? Value(lastStreakDate) : const Value.absent(),
        dailyXpDate: dailyXpDate != null ? Value(dailyXpDate) : const Value.absent(),
        dailyXpAmount: dailyXpAmount != null ? Value(dailyXpAmount) : const Value.absent(),
        coinsEarned: coinsEarned != null ? Value(coinsEarned) : const Value.absent(),
        coinsBalance: coinsBalance != null ? Value(coinsBalance) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value(1), // Mark as pending sync
      ),
    );
  }

  /// Update sync status for user stats.
  Future<void> updateUserStatsSyncStatus(String id, int syncStatus) {
    return (update(userStatsTable)..where((s) => s.id.equals(id))).write(
      UserStatsTableCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete user stats by user ID.
  Future<int> deleteUserStats(String userId) {
    return (delete(userStatsTable)..where((s) => s.userId.equals(userId))).go();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Bookmark Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all bookmarks for a user and course.
  Future<List<BookmarksTableData>> getBookmarksForCourse(
      String userId, String courseId) {
    return (select(bookmarksTable)
          ..where(
              (b) => b.userId.equals(userId) & b.courseId.equals(courseId))
          ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
        .get();
  }

  /// Get all bookmarks for a user.
  Future<List<BookmarksTableData>> getAllBookmarks(String userId) {
    return (select(bookmarksTable)
          ..where((b) => b.userId.equals(userId))
          ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
        .get();
  }

  /// Watch all bookmarks for a user.
  Stream<List<BookmarksTableData>> watchAllBookmarks(String userId) {
    return (select(bookmarksTable)
          ..where((b) => b.userId.equals(userId))
          ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
        .watch();
  }

  /// Add a bookmark.
  Future<void> addBookmark(BookmarksTableCompanion bookmark) {
    return into(bookmarksTable).insertOnConflictUpdate(bookmark);
  }

  /// Remove a bookmark by user, course, and block.
  Future<int> removeBookmark(String userId, String courseId, String blockId) {
    return (delete(bookmarksTable)
          ..where((b) =>
              b.userId.equals(userId) &
              b.courseId.equals(courseId) &
              b.blockId.equals(blockId)))
        .go();
  }

  /// Check if a block is bookmarked.
  Future<bool> isBookmarked(String userId, String courseId, String blockId) async {
    final result = await (select(bookmarksTable)
          ..where((b) =>
              b.userId.equals(userId) &
              b.courseId.equals(courseId) &
              b.blockId.equals(blockId)))
        .getSingleOrNull();
    return result != null;
  }

  /// Delete all bookmarks for a user and course.
  Future<int> deleteBookmarksForCourse(String userId, String courseId) {
    return (delete(bookmarksTable)
          ..where(
              (b) => b.userId.equals(userId) & b.courseId.equals(courseId)))
        .go();
  }

  /// Migrate all user-scoped data from one userId to another.
  /// Used when a guest logs in with an existing server account — the new
  /// user record gets a fresh UUID, but course progress, stats, and
  /// bookmarks still reference the old guest UUID.
  Future<void> migrateUserData(String oldUserId, String newUserId) async {
    await transaction(() async {
      await customUpdate(
        'UPDATE user_courses SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {userCoursesTable},
      );
      await customUpdate(
        'UPDATE user_progress SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {userProgressTable},
      );
      await customUpdate(
        'UPDATE user_stats SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {userStatsTable},
      );
      await customUpdate(
        'UPDATE bookmarks SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {bookmarksTable},
      );
      await customUpdate(
        'UPDATE user_achievements SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {userAchievementsTable},
      );
      await customUpdate(
        'UPDATE chat_sessions SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {chatSessionsTable},
      );
      await customUpdate(
        'UPDATE practice_cards SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {practiceCardsTable},
      );
      await customUpdate(
        'UPDATE review_logs SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {reviewLogsTable},
      );
      await customUpdate(
        'UPDATE student_fsrs_profiles SET user_id = ? WHERE user_id = ?',
        variables: [Variable(newUserId), Variable(oldUserId)],
        updates: {studentFsrsProfilesTable},
      );
    });
  }

  /// Delete ALL data from ALL tables. Full factory reset.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(reviewLogsTable).go();
      await delete(practiceCardsTable).go();
      await delete(studentFsrsProfilesTable).go();
      await delete(chatMessagesTable).go();
      await delete(chatSessionsTable).go();
      await delete(userAchievementsTable).go();
      // The worn outfit and the owned items are per-user data, so they go with
      // the rest of it; the `avatar_items` catalog below is public artwork and
      // stays cached (BR-SPR9WH).
      await delete(userAvatarTable).go();
      await delete(gamificationConfigTable).go();
      await delete(bookmarksTable).go();
      await delete(userEloProfileTable).go();
      await delete(blockStatsTable).go();
      await delete(workHeartbeatsTable).go();
      await delete(syncQueueTable).go();
      await delete(userProgressTable).go();
      await delete(userStatsTable).go();
      await delete(userCoursesTable).go();
      await delete(lessonsTable).go();
      await delete(coursesTable).go();
      await delete(usersTable).go();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Gamification Config Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the cached gamification config (single-row table).
  Future<GamificationConfigTableData?> getGamificationConfig() {
    return (select(gamificationConfigTable)
          ..where((c) => c.id.equals('config')))
        .getSingleOrNull();
  }

  /// Save (upsert) gamification config.
  Future<void> saveGamificationConfig({
    required int version,
    required String configJson,
  }) {
    return into(gamificationConfigTable).insertOnConflictUpdate(
      GamificationConfigTableCompanion(
        id: const Value('config'),
        version: Value(version),
        configJson: Value(configJson),
        downloadedAt: Value(DateTime.now()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // User Achievements Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all earned achievements for a user.
  Future<List<UserAchievementsTableData>> getEarnedAchievements(String userId) {
    return (select(userAchievementsTable)
          ..where((a) => a.userId.equals(userId))
          ..orderBy([(a) => OrderingTerm.desc(a.earnedAt)]))
        .get();
  }

  /// Watch all earned achievements for a user.
  Stream<List<UserAchievementsTableData>> watchEarnedAchievements(String userId) {
    return (select(userAchievementsTable)
          ..where((a) => a.userId.equals(userId))
          ..orderBy([(a) => OrderingTerm.desc(a.earnedAt)]))
        .watch();
  }

  /// Insert a newly earned achievement. Returns false if already exists.
  Future<bool> insertAchievement({
    required String id,
    required String userId,
    required String achievementId,
    required DateTime earnedAt,
    int syncStatus = 1,
  }) async {
    try {
      await into(userAchievementsTable).insert(
        UserAchievementsTableCompanion(
          id: Value(id),
          userId: Value(userId),
          achievementId: Value(achievementId),
          earnedAt: Value(earnedAt),
          syncStatus: Value(syncStatus),
        ),
      );
      return true;
    } catch (_) {
      // UNIQUE constraint violation — already earned
      return false;
    }
  }

  /// Get achievements that need syncing to the server.
  Future<List<UserAchievementsTableData>> getUnsyncedAchievements(String userId) {
    return (select(userAchievementsTable)
          ..where((a) => a.userId.equals(userId) & a.syncStatus.equals(1)))
        .get();
  }

  /// Update sync status for a user ELO profile record.
  Future<void> updateEloProfileSyncStatus(String id, int syncStatus) {
    return (update(userEloProfileTable)..where((t) => t.id.equals(id))).write(
      UserEloProfileTableCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark achievements as synced.
  Future<void> markAchievementsSynced(List<String> ids) async {
    for (final id in ids) {
      await (update(userAchievementsTable)..where((a) => a.id.equals(id)))
          .write(const UserAchievementsTableCompanion(
        syncStatus: Value(0),
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Block Stats Operations (read cache of the server's task calibration)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get cached block stats for a specific block.
  Future<BlockStatsTableData?> getBlockStats(String blockId) {
    return (select(blockStatsTable)
          ..where((t) => t.blockId.equals(blockId)))
        .getSingleOrNull();
  }

  /// Cached block stats for [blockIds].
  Future<List<BlockStatsTableData>> getBlockStatsFor(Iterable<String> blockIds) {
    final ids = blockIds.toSet();
    if (ids.isEmpty) return Future.value(const []);
    return (select(blockStatsTable)..where((t) => t.blockId.isIn(ids))).get();
  }

  /// Store one row of the server's calibration as pulled for [courseId].
  Future<void> upsertBlockStats({
    required String blockId,
    required String courseId,
    required String itemPocet,
    required String eloVector,
    required DateTime serverUpdatedAt,
  }) {
    return into(blockStatsTable).insertOnConflictUpdate(
      BlockStatsTableCompanion(
        blockId: Value(blockId),
        courseId: Value(courseId),
        itemPocet: Value(itemPocet),
        eloVector: Value(eloVector),
        updatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  /// The server `updated_at` of the newest row pulled for [courseId] — the
  /// cursor of that course's next pull; null pulls everything.
  Future<DateTime?> getBlockStatsCursor(String courseId) async {
    final latest = blockStatsTable.updatedAt.max();
    final row = await (selectOnly(blockStatsTable)
          ..addColumns([latest])
          ..where(blockStatsTable.courseId.equals(courseId)))
        .getSingleOrNull();
    return row?.read(latest);
  }

  /// Drop the cached calibration pulled for [courseId].
  Future<void> deleteBlockStatsForCourse(String courseId) {
    return (delete(blockStatsTable)..where((t) => t.courseId.equals(courseId)))
        .go();
  }

  /// `course_id`s of the courses whose content is on the device — catalog
  /// entries keep `data` at '{}' until the course is downloaded. Compared in
  /// SQL so no course blob is loaded.
  Future<List<String>> getDownloadedCourseIds() async {
    final query = selectOnly(coursesTable, distinct: true)
      ..addColumns([coursesTable.courseId])
      ..where(coursesTable.data.equals('{}').not());
    final rows = await query.get();
    return [for (final row in rows) row.read(coursesTable.courseId)!];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Practice Card Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all active practice cards for a user, ordered by weight descending.
  Future<List<PracticeCardsTableData>> getActivePracticeCards(String userId) {
    return (select(practiceCardsTable)
          ..where((c) => c.userId.equals(userId) & c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.desc(c.weight)]))
        .get();
  }

  /// Get due practice cards for a user (dueDate <= now).
  Future<List<PracticeCardsTableData>> getDuePracticeCards(String userId) {
    return (select(practiceCardsTable)
          ..where((c) =>
              c.userId.equals(userId) &
              c.isActive.equals(true) &
              c.dueDate.isSmallerOrEqualValue(DateTime.now().toUtc())))
        .get();
  }

  /// Get new (state=0) practice cards for a user, ordered by weight DESC, with optional limit.
  Future<List<PracticeCardsTableData>> getNewPracticeCards(
      String userId, {int limit = 10}) {
    return (select(practiceCardsTable)
          ..where((c) =>
              c.userId.equals(userId) &
              c.state.equals(0) &
              c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.desc(c.weight)])
          ..limit(limit))
        .get();
  }

  /// Get a single practice card by userId and blockId.
  Future<PracticeCardsTableData?> getPracticeCardByBlock(
      String userId, String blockId) {
    return (select(practiceCardsTable)
          ..where((c) => c.userId.equals(userId) & c.blockId.equals(blockId)))
        .getSingleOrNull();
  }

  /// All practice cards of a user (debug/diagnostics).
  Future<List<PracticeCardsTableData>> getAllPracticeCardsForUser(
      String userId) {
    return (select(practiceCardsTable)..where((c) => c.userId.equals(userId)))
        .get();
  }

  /// Get the practice cards whose blockId is [blockId] itself or a step of it
  /// ("blockId:stepId"). Step-level bookmarks store the suffixed form while
  /// the practice player resolves back to the base block, so a review has to
  /// find the card through this widened match (oldest due first).
  Future<List<PracticeCardsTableData>> getPracticeCardsForBaseBlock(
      String userId, String blockId) {
    return (select(practiceCardsTable)
          ..where((c) =>
              c.userId.equals(userId) &
              (c.blockId.equals(blockId) | c.blockId.like('$blockId:%')))
          ..orderBy([(c) => OrderingTerm.asc(c.dueDate)]))
        .get();
  }

  /// Insert or update a practice card. The companion must carry every
  /// required column — drift validates it as an INSERT even when the row
  /// exists. For partial updates use [updatePracticeCardById].
  Future<void> upsertPracticeCard(PracticeCardsTableCompanion card) {
    return into(practiceCardsTable).insertOnConflictUpdate(card);
  }

  /// Apply a partial companion to an existing practice card, keyed on id.
  /// Unlike [upsertPracticeCard] this never inserts, so absent columns are
  /// simply left untouched instead of failing insert validation.
  Future<void> updatePracticeCardById(PracticeCardsTableCompanion card) {
    return (update(practiceCardsTable)..where((c) => c.id.equals(card.id.value)))
        .write(card);
  }

  /// Get practice cards that need syncing to the server (syncStatus=1).
  Future<List<PracticeCardsTableData>> getPendingSyncPracticeCards() {
    return (select(practiceCardsTable)
          ..where((c) => c.syncStatus.equals(1)))
        .get();
  }

  /// Mark a practice card as synced (syncStatus=0) after a successful push,
  /// optionally recording the server id. Guarded on [sentUpdatedAt] so a card
  /// that was re-edited locally while the push was in flight stays pending and
  /// is re-pushed on the next cycle.
  Future<void> markPracticeCardSynced(
    String id,
    DateTime sentUpdatedAt, {
    String? serverId,
  }) {
    return (update(practiceCardsTable)
          ..where((c) => c.id.equals(id) & c.updatedAt.equals(sentUpdatedAt)))
        .write(PracticeCardsTableCompanion(
      syncStatus: const Value(0),
      serverId: serverId != null ? Value(serverId) : const Value.absent(),
    ));
  }

  /// Count due practice cards for a user (isActive=true, dueDate <= now).
  Future<int> countDuePracticeCards(String userId) async {
    final count = countAll();
    final query = selectOnly(practiceCardsTable)
      ..addColumns([count])
      ..where(practiceCardsTable.userId.equals(userId) &
          practiceCardsTable.isActive.equals(true) &
          practiceCardsTable.dueDate
              .isSmallerOrEqualValue(DateTime.now().toUtc()));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Review Log Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert a review log entry.
  Future<void> insertReviewLog(ReviewLogsTableCompanion log) {
    return into(reviewLogsTable).insert(log);
  }

  /// Get all review logs for a card, ordered by reviewedAt descending.
  Future<List<ReviewLogsTableData>> getReviewLogsForCard(String cardId) {
    return (select(reviewLogsTable)
          ..where((l) => l.cardId.equals(cardId))
          ..orderBy([(l) => OrderingTerm.desc(l.reviewedAt)]))
        .get();
  }

  /// Get review logs that need syncing to the server (syncStatus=1).
  Future<List<ReviewLogsTableData>> getPendingSyncReviewLogs() {
    return (select(reviewLogsTable)
          ..where((l) => l.syncStatus.equals(1)))
        .get();
  }

  /// Count reviews done today (UTC) for a user.
  Future<int> getTodayReviewCount(String userId) async {
    final now = DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    final count = countAll();
    final query = selectOnly(reviewLogsTable)
      ..addColumns([count])
      ..where(reviewLogsTable.userId.equals(userId) &
          reviewLogsTable.reviewedAt.isBiggerOrEqualValue(todayStart));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FSRS Profile Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the FSRS profile for a user.
  Future<StudentFsrsProfilesTableData?> getFsrsProfile(String userId) {
    return (select(studentFsrsProfilesTable)
          ..where((p) => p.userId.equals(userId)))
        .getSingleOrNull();
  }

  /// Insert or update a student FSRS profile.
  Future<void> upsertFsrsProfile(StudentFsrsProfilesTableCompanion profile) {
    return into(studentFsrsProfilesTable).insertOnConflictUpdate(profile);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Chat Session Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Watch all chat sessions for a user, ordered by most recent message.
  Stream<List<ChatSessionsTableData>> watchChatSessions(String userId) {
    return (select(chatSessionsTable)
          ..where((s) => s.userId.equals(userId))
          ..orderBy([(s) => OrderingTerm.desc(s.lastMessageAt)]))
        .watch();
  }

  /// Watch all messages for a chat session, ordered chronologically.
  Stream<List<ChatMessagesTableData>> watchChatMessages(String sessionId) {
    return (select(chatMessagesTable)
          ..where((m) => m.sessionId.equals(sessionId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  /// Get a chat session by local ID.
  Future<ChatSessionsTableData?> getChatSessionById(String id) {
    return (select(chatSessionsTable)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a chat session by server ID (for pull dedup).
  Future<ChatSessionsTableData?> getChatSessionByServerId(int serverId) async {
    final results = await (select(chatSessionsTable)
          ..where((s) => s.serverId.equals(serverId))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  /// Get a chat message by server ID (for pull dedup).
  Future<ChatMessagesTableData?> getChatMessageByServerId(int serverId) async {
    final results = await (select(chatMessagesTable)
          ..where((m) => m.serverId.equals(serverId))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  /// Update sync status for a chat session.
  Future<void> updateChatSessionSyncStatus(String id, String status) {
    return (update(chatSessionsTable)..where((s) => s.id.equals(id))).write(
      ChatSessionsTableCompanion(
        syncStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update sync status for a chat message.
  Future<void> updateChatMessageSyncStatus(String id, String status) {
    return (update(chatMessagesTable)..where((m) => m.id.equals(id))).write(
      ChatMessagesTableCompanion(
        syncStatus: Value(status),
      ),
    );
  }

  /// Delete a chat session and all its messages.
  Future<void> deleteChatSession(String id) async {
    await (delete(chatMessagesTable)..where((m) => m.sessionId.equals(id))).go();
    await (delete(chatSessionsTable)..where((s) => s.id.equals(id))).go();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Avatar Operations (BR-7JRBCN)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Whole catalog, in paint order.
  Future<List<AvatarItemsTableData>> getAvatarItems() {
    return (select(avatarItemsTable)
          ..orderBy([
            (i) => OrderingTerm.asc(i.layer),
            (i) => OrderingTerm.asc(i.code),
          ]))
        .get();
  }

  Future<AvatarItemsTableData?> getAvatarItem(String code) {
    return (select(avatarItemsTable)..where((i) => i.code.equals(code)))
        .getSingleOrNull();
  }

  /// Upsert a catalog row, preserving the cached SVG unless the caller
  /// supplies a new one.
  ///
  /// Metadata refreshes (a renamed item, a changed layer) must not throw away
  /// artwork the device already downloaded — losing it would leave the avatar
  /// half-drawn until the next connection.
  Future<void> upsertAvatarItem(AvatarItemsTableCompanion item) {
    return into(avatarItemsTable).insertOnConflictUpdate(item);
  }

  /// Store downloaded artwork against a catalog row, with the content bounds
  /// measured from it.
  Future<void> setAvatarItemSvg(
    String code,
    String svg, {
    double? boundsLeft,
    double? boundsTop,
    double? boundsRight,
    double? boundsBottom,
  }) {
    return (update(avatarItemsTable)..where((i) => i.code.equals(code))).write(
      AvatarItemsTableCompanion(
        svgSource: Value(svg),
        boundsLeft: Value(boundsLeft),
        boundsTop: Value(boundsTop),
        boundsRight: Value(boundsRight),
        boundsBottom: Value(boundsBottom),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Record an item's measured content box without touching its artwork.
  Future<void> setAvatarItemBounds(String code, Rect bounds) {
    return (update(avatarItemsTable)..where((i) => i.code.equals(code))).write(
      AvatarItemsTableCompanion(
        boundsLeft: Value(bounds.left),
        boundsTop: Value(bounds.top),
        boundsRight: Value(bounds.right),
        boundsBottom: Value(bounds.bottom),
      ),
    );
  }

  /// Drop catalog rows the server no longer lists.
  Future<void> deleteAvatarItemsExcept(List<String> keepCodes) async {
    if (keepCodes.isEmpty) return;
    await (delete(avatarItemsTable)..where((i) => i.code.isNotIn(keepCodes))).go();
  }

  Future<UserAvatarTableData?> getUserAvatar(String userId) {
    return (select(userAvatarTable)..where((a) => a.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<void> upsertUserAvatar(UserAvatarTableCompanion avatar) {
    return into(userAvatarTable).insertOnConflictUpdate(avatar);
  }

  /// Mark the outfit synced after the server accepted it.
  Future<void> updateUserAvatarSyncStatus(String userId, int status) {
    return (update(userAvatarTable)..where((a) => a.userId.equals(userId)))
        .write(UserAvatarTableCompanion(syncStatus: Value(status)));
  }
}

