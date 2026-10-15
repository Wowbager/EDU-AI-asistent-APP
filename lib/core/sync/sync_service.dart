import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../../data/datasources/local/chat_local_datasource.dart';
import '../../data/datasources/remote/chat_remote_datasource.dart';
import '../../data/repositories/gpf_label_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/practice_repository.dart';
import '../../models/course_model.dart';
import 'sync_queue.dart';
import 'sync_status.dart';
import 'package:eduai/core/util/silent_log.dart';

/// Current state of the sync service.
enum SyncState {
  /// Not syncing.
  idle,

  /// Currently syncing.
  syncing,

  /// Sync failed.
  error,
}

/// Orchestrates synchronization between local database and remote API.
///
/// Responsibilities:
/// - Process sync queue when connectivity is available
/// - Pull updates from server
/// - Handle conflicts (last-write-wins)
/// - Monitor connectivity changes to trigger sync
class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  final SyncQueue _syncQueue;

  StreamSubscription<ConnectivityState>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  final _stateController = StreamController<SyncState>.broadcast();
  SyncState _currentState = SyncState.idle;
  DateTime? _lastSyncTime;
  bool _syncRequestedWhileBusy = false;

  /// Interval for periodic sync checks (when on WiFi).
  static const Duration periodicSyncInterval = Duration(minutes: 15);

  /// Downloads a course's full JSON into the local DB, keyed on the local
  /// course row id. Injected (rather than constructing a CourseRepository here)
  /// so the sync engine stays testable and free of data-source wiring.
  final Future<bool> Function(String localCourseId)? _fetchCourseContent;

  SyncService({
    required AppDatabase db,
    required ApiClient apiClient,
    required ConnectivityService connectivity,
    SyncQueue? syncQueue,
    Future<bool> Function(String localCourseId)? fetchCourseContent,
  })  : _db = db,
        _apiClient = apiClient,
        _connectivity = connectivity,
        _syncQueue = syncQueue ?? SyncQueue(db),
        _fetchCourseContent = fetchCourseContent;

  /// Stream of sync state changes.
  Stream<SyncState> get stateStream => _stateController.stream;

  /// Current sync state.
  SyncState get currentState => _currentState;

  /// When the last successful sync completed.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// When the next periodic sync is expected.
  DateTime? get nextSyncTime =>
      _lastSyncTime?.add(periodicSyncInterval);

  /// Initialize the sync service and start monitoring connectivity.
  void initialize() {
    // Listen for connectivity changes.
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((state) {
      if (state.isOnline) {
        // Trigger sync when any connection becomes available.
        sync();
      }
    });

    // Start periodic sync timer.
    _periodicSyncTimer = Timer.periodic(periodicSyncInterval, (_) async {
      final state = await _connectivity.currentState;
      if (state.isOnline) {
        sync();
      }
    });

    // Initial sync if online.
    _checkAndSync();
  }

  Future<void> _checkAndSync() async {
    final state = await _connectivity.currentState;
    if (state.isOnline) {
      sync();
    }
  }

  /// Perform a full sync: push local changes, then pull remote updates.
  /// If called while already syncing, schedules a follow-up sync so
  /// newly enqueued items (e.g. from lesson completion) are pushed ASAP.
  Future<void> sync() async {
    if (_currentState == SyncState.syncing) {
      _syncRequestedWhileBusy = true;
      return;
    }

    _setState(SyncState.syncing);

    try {
      // 1. Push local changes.
      await _pushChanges();

      // 1b. Flush work-time heartbeats (BR-9SAH2R).
      await _flushWorkHeartbeats();

      // 2. Pull remote updates.
      await _pullUpdates();

      // 2b. Materialize the content of courses the account is enrolled in but
      // this device has never downloaded (BR-ZBJ99Z).
      await _fetchMissingEnrolledCourseContent();

      // 3. Reconcile FSRS practice cards (pull → seed → push). Runs after
      // _pullUpdates so course content and enrollments are present locally
      // (BR-WR4C8P).
      await _syncPracticeCards();

      // 4. Refresh cached GPF vector labels (Czech) from the backend so the
      // skills view stays in sync with the canonical labeling (BR-N2E9MF).
      await _refreshGpfLabels();

      _lastSyncTime = DateTime.now();
      _setState(SyncState.idle);
    } catch (e) {
      _setState(SyncState.error);
    }

    // If sync was requested while we were busy, do another round
    // to push any items that were enqueued during the previous sync.
    if (_syncRequestedWhileBusy) {
      _syncRequestedWhileBusy = false;
      sync();
    }
  }

  /// Download the full course JSON for every enrolled course this device only
  /// knows as catalog metadata.
  ///
  /// Enrollments arrive from the server on any device, but the content itself
  /// is only fetched when the user taps "download" on THIS device. Everything
  /// that resolves a practice card needs that content — seeding, the dashboard
  /// queue and the playable-block lookup all skip courses without it — so a
  /// second device showed an empty "Procvičování" until the course was manually
  /// downloaded, which looked like the account wasn't syncing (BR-ZBJ99Z).
  ///
  /// Best-effort: online-only, one attempt per course per sync, failures are
  /// logged and swallowed.
  Future<void> _fetchMissingEnrolledCourseContent() async {
    final fetch = _fetchCourseContent;
    if (fetch == null || !_apiClient.isAuthenticated) return;

    try {
      final activeUser = await _db.getActiveUser();
      if (activeUser == null) return;

      final enrollments = await _db.getUserCourses(activeUser.id);
      final seen = <String>{};
      for (final enrollment in enrollments) {
        final row = await _db.getCourseById(enrollment.courseId) ??
            await _db.getCourseByFieldCourseId(enrollment.courseId);
        if (row == null) continue;
        if (!seen.add(row.id)) continue;
        if (_hasCourseContent(row.data)) continue;
        await fetch(row.id);
      }
    } catch (e, st) {
      silentLog('sync:fetch_enrolled_course_content', e, st);
    }
  }

  /// Whether a stored course payload carries real lesson content (as opposed to
  /// the catalog metadata stub the course list pull writes).
  bool _hasCourseContent(String rawData) {
    if (rawData.isEmpty) return false;
    try {
      final data = jsonDecode(rawData);
      if (data is! Map<String, dynamic>) return false;
      final lessons = data['lessons'];
      if (lessons is! List || lessons.isEmpty) return false;
      final blocks = data['blocks'];
      return blocks is List && blocks.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Test-only hook that drives the user-course reconciliation in isolation,
  /// exercising the exact private path the sync engine runs (BR-SNUYF7 —
  /// enrollments for courses missing from the local catalog, e.g. private
  /// courses, must materialize rather than be dropped).
  @visibleForTesting
  Future<void> debugPullUserCourseUpdates() => _pullUserCourseUpdates();

  /// Test-only hook for the task calibration pull (BR-697NCA).
  @visibleForTesting
  Future<void> debugPullBlockStats() => _pullBlockStats();

  /// Test-only hook that pushes a single queued bookmark operation, so the
  /// wire payload can be asserted on (BR-952UKZ — the course reference must
  /// leave the device as a server course code, never a local Drift row id).
  @visibleForTesting
  Future<bool> debugProcessBookmarkOperation(
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) =>
      _processBookmarkOperation('debug', operation, payload);

  /// Refresh the cached GPF vector dimension labels from the backend. Requires
  /// auth; failures are swallowed so the bundled-asset / cached labels keep
  /// serving offline (BR-N2E9MF).
  Future<void> _refreshGpfLabels() async {
    if (!_apiClient.isAuthenticated) return;
    await GpfLabelRepository(_db, _apiClient).refreshFromServer();
  }

  /// Flush unsynced work-time heartbeats to the API in a single batch, then
  /// delete the accepted rows locally. Append-only telemetry — failures just
  /// leave rows for the next sync (BR-9SAH2R).
  Future<void> _flushWorkHeartbeats() async {
    if (!_apiClient.isAuthenticated) return;

    final rows = await _db.getUnsyncedWorkHeartbeats();
    if (rows.isEmpty) return;

    final payload = {
      'heartbeats': rows
          .map((r) => {
                'client_uuid': r.clientUuid,
                'course_id': r.courseId,
                if (r.lessonId != null) 'lesson_id': r.lessonId,
                'occurred_at': r.occurredAt.toUtc().toIso8601String(),
              })
          .toList(),
    };

    try {
      final result = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.workHeartbeats,
        data: payload,
      );
      if (result.isSuccess) {
        await _db.deleteWorkHeartbeats(rows.map((r) => r.clientUuid).toList());
      }
    } catch (_) {
      // Leave rows for the next sync cycle.
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Practice cards (FSRS) — bidirectional sync (BR-WR4C8P)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Reconcile FSRS practice cards with the server.
  ///
  /// Before this existed, practice cards were only ever created locally (on
  /// lesson completion) and never synced — so a guest who logged into an
  /// account kept only the cards from their guest session and never gained the
  /// account's full set. This runs a three-step reconciliation:
  ///   1. Pull the account's cards from the server (server wins only over
  ///      already-synced local rows; locally-pending rows are protected).
  ///   2. Seed cards for every default_practice block of the user's enrolled
  ///      courses, so the full admin-configured set is present.
  ///   3. Push all pending local cards in one bulk upsert.
  ///
  /// Self-contained and best-effort: any failure is logged and swallowed so it
  /// never fails the surrounding sync.
  Future<void> _syncPracticeCards() async {
    if (!_apiClient.isAuthenticated) return;

    final activeUser = await _db.getActiveUser();
    if (activeUser == null) return;

    try {
      await _pullPracticeCards(activeUser.id);
      await _seedPracticeCards(activeUser.id);
      await _pushPracticeCards(activeUser.id);
    } catch (e, st) {
      silentLog('sync:practice_cards', e, st);
    }
  }

  DateTime? _parseIsoDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Resolve a card's local course reference (a Drift row id such as
  /// `local-<uuid>`) to the server-facing course code (courses.course_id).
  /// Cards created by seeding/bookmarks store the local row id; pushing that
  /// raw would fill the server with ids no other device or the admin can map
  /// back to a course. Falls back to the stored value when it already is a
  /// course code (no local row with that id).
  Future<String> _resolveCourseCode(
    String cardCourseId,
    Map<String, String> cache,
  ) async {
    final cached = cache[cardCourseId];
    if (cached != null) return cached;
    final row = await _db.getCourseById(cardCourseId);
    final code =
        (row != null && row.courseId.isNotEmpty) ? row.courseId : cardCourseId;
    cache[cardCourseId] = code;
    return code;
  }

  /// Pull the account's practice cards and upsert them locally, keyed on
  /// (userId, blockId). Rows with pending local edits are left untouched so the
  /// subsequent push can carry them up (last-write-wins with local protection).
  Future<void> _pullPracticeCards(String userId) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.userPracticeCards,
    );
    if (result.isFailure || result.data == null) return;

    final list = result.data!['data'] as List<dynamic>? ?? [];
    for (final json in list) {
      final remote = json as Map<String, dynamic>;
      final blockId = remote['block_id'] as String? ?? '';
      if (blockId.isEmpty) continue;

      final existing = await _db.getPracticeCardByBlock(userId, blockId);
      // Protect locally-pending edits — they're pushed in _pushPracticeCards.
      if (existing != null &&
          SyncStatusExtension.fromInt(existing.syncStatus) ==
              SyncStatus.pending) {
        continue;
      }

      // Server stores the course code; local cards reference the Drift course
      // row id. Translate back so the queue's course grouping keeps working.
      // Legacy rows pushed before the translation existed may carry a local
      // row id — getCourseById covers those.
      final remoteCourseId = remote['course_id'] as String? ?? '';
      final localCourseRow = remoteCourseId.isEmpty
          ? null
          : (await _db.getCourseByFieldCourseId(remoteCourseId) ??
              await _db.getCourseById(remoteCourseId));

      await _db.upsertPracticeCard(PracticeCardsTableCompanion(
        id: Value(existing?.id ?? _generateLocalId()),
        serverId: Value(remote['id']?.toString()),
        userId: Value(userId),
        courseId: Value(
          existing?.courseId.isNotEmpty == true
              ? existing!.courseId
              : (localCourseRow?.id ?? remoteCourseId),
        ),
        lessonId: Value(remote['lesson_id'] as String? ?? ''),
        blockId: Value(blockId),
        sourceType: Value(remote['source_type'] as String? ?? 'lesson'),
        state: Value((remote['state'] as num?)?.toInt() ?? 0),
        dueDate:
            Value(_parseIsoDate(remote['due_date']) ?? DateTime.now().toUtc()),
        stability: Value((remote['stability'] as num?)?.toDouble() ?? 0.0),
        difficulty: Value((remote['difficulty'] as num?)?.toDouble() ?? 0.0),
        reps: Value((remote['reps'] as num?)?.toInt() ?? 0),
        lapses: Value((remote['lapses'] as num?)?.toInt() ?? 0),
        scheduledDays: Value((remote['scheduled_days'] as num?)?.toInt() ?? 0),
        elapsedDays: Value((remote['elapsed_days'] as num?)?.toInt() ?? 0),
        lastReview: Value(_parseIsoDate(remote['last_review'])),
        weight: Value((remote['weight'] as num?)?.toDouble() ?? 5.0),
        avgTimeSec: Value((remote['avg_time_sec'] as num?)?.toInt() ?? 20),
        skipCondition: Value(remote['skip_condition'] as String?),
        isActive: Value(remote['is_active'] as bool? ?? true),
        syncStatus: const Value(0),
        createdAt: Value(_parseIsoDate(remote['created_at']) ?? DateTime.now()),
        updatedAt: Value(_parseIsoDate(remote['updated_at']) ?? DateTime.now()),
      ));
    }
  }

  /// Seed cards for every default_practice block of the user's enrolled
  /// courses whose content is available locally. New cards are marked pending
  /// and pushed by [_pushPracticeCards] in the same cycle.
  Future<void> _seedPracticeCards(String userId) async {
    final enrollments = await _db.getUserCourses(userId);
    if (enrollments.isEmpty) return;

    final repo = PracticeRepository(db: _db);
    final seededLocalIds = <String>{};
    for (final enrollment in enrollments) {
      // A user course's courseId may be the local id or the field course_id.
      final row = await _db.getCourseById(enrollment.courseId) ??
          await _db.getCourseByFieldCourseId(enrollment.courseId);
      if (row == null) continue;
      if (!seededLocalIds.add(row.id)) continue;
      try {
        final data = jsonDecode(row.data) as Map<String, dynamic>;
        final course = Course.fromJsonData(id: row.id, data: data);
        await repo.seedCardsFromCourse(userId: userId, course: course);
      } catch (e, st) {
        silentLog('sync:seed_practice_cards', e, st);
      }
    }
  }

  /// Push all pending local practice cards to the server in one bulk upsert,
  /// then mark the pushed rows synced. Cards missing any server-required
  /// identifier are skipped (they can't be represented server-side and would
  /// otherwise 422 the whole batch).
  Future<void> _pushPracticeCards(String userId) async {
    final pending = await _db.getPendingSyncPracticeCards();
    if (pending.isEmpty) return;

    // Only the active user's cards — the POST is attributed to the
    // authenticated account, so pushing another local user's rows would
    // inflate that account's deck server-side.
    //
    // lessonId is deliberately NOT required: auto-bookmarking a wrong quiz
    // answer has no lesson context, and dropping those cards here left them
    // pending forever — which also made _pullPracticeCards skip them (pending
    // rows are protected), so they never left the device (BR-ZBJ99Z).
    final pushable = pending
        .where((c) =>
            c.userId == userId &&
            c.courseId.isNotEmpty &&
            c.blockId.isNotEmpty)
        .toList();
    if (pushable.isEmpty) return;

    // Translate local course row ids to server course codes so the server
    // (and admin) can attribute cards to courses.
    final courseCodeCache = <String, String>{};
    final cards = <Map<String, dynamic>>[];
    for (final c in pushable) {
      cards.add({
        'course_id': await _resolveCourseCode(c.courseId, courseCodeCache),
        'lesson_id': c.lessonId,
        'block_id': c.blockId,
        'source_type': c.sourceType,
        'state': c.state,
        'due_date': c.dueDate.toUtc().toIso8601String(),
        'stability': c.stability,
        'difficulty': c.difficulty,
        'reps': c.reps,
        'lapses': c.lapses,
        'scheduled_days': c.scheduledDays,
        'elapsed_days': c.elapsedDays,
        if (c.lastReview != null)
          'last_review': c.lastReview!.toUtc().toIso8601String(),
        'weight': c.weight,
        'avg_time_sec': c.avgTimeSec,
        if (c.skipCondition != null) 'skip_condition': c.skipCondition,
        'is_active': c.isActive,
      });
    }

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.userPracticeCards,
      data: {'cards': cards},
    );
    if (result.isFailure || result.data == null) return;

    // Map server ids back by block_id so we can record them locally.
    final serverIdByBlock = <String, String>{};
    for (final r in (result.data!['data'] as List<dynamic>? ?? [])) {
      final m = r as Map<String, dynamic>;
      final bid = m['block_id'] as String?;
      if (bid != null && m['id'] != null) {
        serverIdByBlock[bid] = m['id'].toString();
      }
    }

    for (final c in pushable) {
      await _db.markPracticeCardSynced(
        c.id,
        c.updatedAt,
        serverId: serverIdByBlock[c.blockId],
      );
    }
  }

  /// Push local changes from the sync queue to the server.
  /// Processes in rounds — handlers may enqueue follow-up operations
  /// (e.g. CREATE sets serverId, then queues an UPDATE for unsync'd progress).
  Future<void> _pushChanges() async {
    // Skip push if not authenticated — no point hitting the API without a token
    if (!_apiClient.isAuthenticated) {
      return;
    }

    // Clean up permanently failed entries so they don't block pulls forever.
    await _cleanupDeadEntries();

    const maxRounds = 3;
    for (var round = 0; round < maxRounds; round++) {
      final operations = await _syncQueue.getPendingOperations();
      if (operations.isEmpty) {
        break;
      }

      // Batch ELO interactions into a single request
      await _batchEloInteractions(operations);

      // Process remaining (non-ELO-interaction) operations individually
      final remaining = operations.where((op) => op.tableName_ != 'elo_interactions').toList();
      for (final op in remaining) {
        try {
          final success = await _processOperation(op);
          if (success) {
            await _syncQueue.markSynced(op.id);
          } else {
            // Non-exception failure (e.g. 422) — mark as failed so it
            // doesn't retry endlessly in the same sync cycle
            await _syncQueue.markFailed(op.id, 'Operation returned false');
            // Reset local record's syncStatus so the pull can overwrite it
            // with server data instead of being blocked forever.
            await _resetSyncStatusForRecord(op.tableName_, op.recordId);
          }
        } catch (e) {
          await _syncQueue.markFailed(op.id, e.toString());
          await _resetSyncStatusForRecord(op.tableName_, op.recordId);
        }
      }
    }
  }

  /// Remove permanently failed sync queue entries and reset the corresponding
  /// local records' syncStatus to synced so that _pullUpdates can overwrite them.
  Future<void> _cleanupDeadEntries() async {
    final dead = await _db.removeDeadSyncEntries();
    for (final entry in dead) {
      await _resetSyncStatusForRecord(entry.tableName_, entry.recordId);
    }
  }

  /// Reset a local record's syncStatus to synced after a push failure,
  /// so that _pullUpdates can overwrite it with server data.
  Future<void> _resetSyncStatusForRecord(String tableName, String recordId) async {
    if (tableName == 'user_courses') {
      await _db.updateUserCourseSyncFields(
        id: recordId,
        syncStatus: SyncStatus.synced.toInt(),
      );
    } else if (tableName == 'users') {
      await _db.updateUserSyncStatus(recordId, SyncStatus.synced.toInt());
    } else if (tableName == 'user_stats') {
      await _db.updateUserStatsSyncStatus(recordId, SyncStatus.synced.toInt());
    } else if (tableName == 'user_elo_profiles') {
      await _db.updateEloProfileSyncStatus(recordId, SyncStatus.synced.toInt());
    } else if (tableName == 'chat_sessions') {
      await _db.updateChatSessionSyncStatus(recordId, 'synced');
    } else if (tableName == 'chat_messages') {
      await _db.updateChatMessageSyncStatus(recordId, 'synced');
    } else if (tableName == 'user_avatar') {
      await _db.updateUserAvatarSyncStatus(recordId, SyncStatus.synced.toInt());
    }
  }

  /// Registry of sync operation handlers by table name.
  late final _handlers =
      <String, Future<bool> Function(String, SyncOperation, Map<String, dynamic>)>{
    'courses': _processCourseOperation,
    'user_courses': _processUserCourseOperation,
    'users': _processUserProfileOperation,
    'user_stats': _processUserStatsOperation,
    'user_progress': _processUserProgressOperation,
    'content_feedback': _processContentFeedbackOperation,
    'bookmarks': _processBookmarkOperation,
    'user_achievements': _processUserAchievementOperation,
    'user_elo_profiles': _processEloProfileOperation,
    'elo_interactions': _processEloInteractionOperation,
    'chat_messages': _processChatMessageOperation,
    'chat_sessions': _processChatSessionOperation,
    'user_avatar': _processUserAvatarOperation,
    'open_answers': _processOpenAnswerOperation,
  };

  /// Push one evaluated open answer (BR-P745Q8).
  ///
  /// BR-FFVVYR posted these straight from the widget and swallowed the error,
  /// so an answer given on a train never reached the teacher at all. Routing
  /// them through the queue is what makes "the student's attempt is not lost"
  /// true rather than aspirational.
  ///
  /// The queue key is the attempt's `client_uuid`, which is minted where the
  /// answer is given, not where it is sent. Two consequences, both wanted:
  /// a replay updates the same row server-side instead of duplicating it, and
  /// a retry — which is a new uuid — queues as its own entry rather than
  /// merging into the attempt it followed.
  Future<bool> _processOpenAnswerOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.create) return false;

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.openAnswers,
      data: {
        'answers': [payload],
      },
    );

    return result.isSuccess;
  }

  /// Push a queued outfit change (BR-7JRBCN).
  ///
  /// The queue entry carries the whole slot map, not a delta, so replaying an
  /// old entry can only ever restore a state the user actually chose — and the
  /// server validates ownership, so a stale entry naming an item the account
  /// lost is rejected rather than applied.
  Future<bool> _processUserAvatarOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.update) return false;

    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.userAvatar,
      data: payload,
    );

    if (result.isSuccess) {
      await _db.updateUserAvatarSyncStatus(localId, SyncStatus.synced.toInt());
      return true;
    }
    return false;
  }

  /// Process a single sync queue operation using the handler registry.
  Future<bool> _processOperation(SyncQueueTableData op) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    final operation = SyncOperationExtension.fromValue(op.operation);

    final handler = _handlers[op.tableName_];
    if (handler != null) {
      return handler(op.recordId, operation, payload);
    }

    return false;
  }

  /// Process a course sync operation.
  Future<bool> _processCourseOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    switch (operation) {
      case SyncOperation.create:
        final result = await _apiClient.post<Map<String, dynamic>>(
          ApiEndpoints.courses,
          data: payload,
        );

        if (result.isSuccess && result.data != null) {
          // Update local record with server ID.
          final serverId = result.data!['id'] as int;
          await _db.upsertCourse(
            CoursesTableCompanion(
              id: Value(localId),
              serverId: Value(serverId),
              syncStatus: Value(SyncStatus.synced.toInt()),
              serverUpdatedAt: Value(DateTime.parse(
                result.data!['updated_at'] as String,
              )),
            ),
          );
          return true;
        }
        return false;

      case SyncOperation.update:
        final course = await _db.getCourseById(localId);
        if (course == null || course.serverId == null) return false;

        final result = await _apiClient.put<Map<String, dynamic>>(
          ApiEndpoints.course(course.serverId!),
          data: payload,
        );

        if (result.isSuccess) {
          await _db.upsertCourse(
            CoursesTableCompanion(
              id: Value(localId),
              syncStatus: Value(SyncStatus.synced.toInt()),
              serverUpdatedAt: Value(DateTime.parse(
                result.data!['updated_at'] as String,
              )),
            ),
          );
          return true;
        }
        return false;

      case SyncOperation.delete:
        final course = await _db.getCourseById(localId);
        if (course == null || course.serverId == null) {
          // Never synced, just delete locally.
          await _db.deleteCourse(localId);
          return true;
        }

        final result = await _apiClient.delete<Map<String, dynamic>>(
          ApiEndpoints.course(course.serverId!),
        );

        if (result.isSuccess || result.statusCode == 404) {
          // Delete locally even if already deleted on server.
          await _db.deleteCourse(localId);
          return true;
        }
        return false;
    }
  }

  /// Process a user_courses sync operation.
  Future<bool> _processUserCourseOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    switch (operation) {
      case SyncOperation.create:
        final result = await _apiClient.post<Map<String, dynamic>>(
          ApiEndpoints.userCourses,
          data: payload,
        );

        // Course doesn't exist on server (bundled-only) — treat as success
        // so it doesn't retry endlessly.
        if (result.statusCode == 404) return true;

        if (result.isSuccess && result.data != null) {
          final serverData = result.data!['user_course'] as Map<String, dynamic>?
              ?? result.data!;
          final serverId = serverData['id'] as int;

          // Use UPDATE (not upsert) — the record already exists locally,
          // we just need to set serverId and mark as synced.
          await _db.updateUserCourseSyncFields(
            id: localId,
            serverId: serverId,
            syncStatus: SyncStatus.synced.toInt(),
          );

          // After serverId is established, check if there's unsync'd
          // progress that was saved while serverId was still null
          // (e.g. user completed a lesson before the CREATE was pushed).
          final freshRecord = await _db.getUserCourseById(localId);
          if (freshRecord != null && freshRecord.progressPercent > 0) {
            await _syncQueue.enqueue(
              tableName: 'user_courses',
              recordId: localId,
              operation: SyncOperation.update,
              payload: {
                'progress_percent': freshRecord.progressPercent,
                'status': freshRecord.status,
                'completed_lessons': freshRecord.completedLessons,
                'current_lesson_index': freshRecord.currentLessonIndex,
                'time_spent_seconds': freshRecord.timeSpentSeconds,
                'progress_data': jsonDecode(freshRecord.progressDataJson),
              },
            );
            // Mark as pending so _pullUserCourseUpdates won't overwrite
            // local progress before this UPDATE is pushed.
            await _db.updateUserCourseSyncFields(
              id: localId,
              syncStatus: SyncStatus.pending.toInt(),
            );
          }

          return true;
        }
        return false;

      case SyncOperation.update:
        final userCourse = await _db.getUserCourseById(localId);
        if (userCourse == null) {
          return false;
        }

        // Resolve the course's string identifier for the API URL.
        final course = await _db.getCourseById(userCourse.courseId);
        if (course == null) {
          return false;
        }

        final result = await _apiClient.put<Map<String, dynamic>>(
          ApiEndpoints.userCourse(course.courseId),
          data: payload,
        );

        if (result.isSuccess) {
          await _db.updateUserCourseSyncFields(
            id: localId,
            syncStatus: SyncStatus.synced.toInt(),
          );
          return true;
        }
        return false;

      case SyncOperation.delete:
        // For DELETE, the user_course may already be deleted locally.
        // Use course_id from the payload (stored at enqueue time).
        final courseIdentifier = payload['course_id'];
        if (courseIdentifier == null) return true;

        final result = await _apiClient.delete<Map<String, dynamic>>(
          ApiEndpoints.userCourse(courseIdentifier.toString()),
        );

        if (result.isSuccess || result.statusCode == 404) {
          return true;
        }
        return false;
    }
  }

  /// Process a user profile sync operation.
  Future<bool> _processUserProfileOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    // Profile only supports update — we never create/delete users from client.
    if (operation != SyncOperation.update) return false;

    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.updateProfile,
      data: payload,
    );

    if (result.isSuccess) {
      await _db.updateUserSyncStatus(localId, SyncStatus.synced.toInt());
      return true;
    }
    return false;
  }

  /// Process a user_stats sync operation.
  Future<bool> _processUserStatsOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.update) return false;

    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.userStats,
      data: payload,
    );

    if (result.isSuccess) {
      await _db.updateUserStatsSyncStatus(localId, SyncStatus.synced.toInt());
      return true;
    }
    return false;
  }

  /// Process a user_progress sync operation.
  /// Pushes lesson-level progress (answers, block states) to the server.
  Future<bool> _processUserProgressOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    // Only update is supported — progress is created locally and pushed.
    if (operation != SyncOperation.update) return false;

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.userProgress,
      data: {
        'progress': [payload],
      },
    );

    if (result.isSuccess && result.data != null) {
      // Extract server ID from response
      final progressList = result.data!['progress'] as List<dynamic>? ?? [];
      if (progressList.isNotEmpty) {
        final serverId = (progressList.first as Map<String, dynamic>)['id'] as int?;
        await _db.updateProgressSyncStatus(
          localId,
          SyncStatus.synced.toInt(),
          serverId: serverId,
        );
      } else {
        await _db.updateProgressSyncStatus(localId, SyncStatus.synced.toInt());
      }
      return true;
    }
    return false;
  }

  /// Process content feedback — fire-and-forget POST to server.
  Future<bool> _processContentFeedbackOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.create) return false;

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.contentFeedback,
      data: payload,
    );

    return result.isSuccess;
  }

  /// Course-code cache for bookmark pushes, shared across operations so a
  /// batch of bookmarks for one course costs a single lookup.
  final Map<String, String> _bookmarkCourseCodes = {};

  /// Process bookmark sync operations.
  ///
  /// Bookmarks are enqueued with whatever course reference the UI held — for
  /// in-app bookmarking that's the local Drift row id (`local-<uuid>`), which
  /// is per-device and unmappable anywhere else, so the server (and the admin
  /// panel reading it) ends up labelling groups with an internal id instead of
  /// the course (BR-952UKZ). Translate to the server course code on the wire,
  /// exactly as the practice-card push does (BR-ZBJ99Z).
  ///
  /// The *queued* payload deliberately keeps the local id: `_pendingBookmarkKeys`
  /// diffs it against local bookmark rows to protect un-pushed creates from the
  /// pull's full-replace (BR-YRT5ZM), and those rows are keyed locally.
  Future<bool> _processBookmarkOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    final wire = Map<String, dynamic>.from(payload);
    final courseId = payload['course_id'] as String? ?? '';
    if (courseId.isNotEmpty) {
      wire['course_id'] =
          await _resolveCourseCode(courseId, _bookmarkCourseCodes);
    }

    switch (operation) {
      case SyncOperation.create:
        final result = await _apiClient.post<Map<String, dynamic>>(
          ApiEndpoints.userBookmarks,
          data: wire,
        );
        return result.isSuccess;

      case SyncOperation.delete:
        // POST to /delete endpoint with composite key — app doesn't have server IDs
        final result = await _apiClient.post<Map<String, dynamic>>(
          ApiEndpoints.userBookmarksDelete,
          data: wire,
        );
        return result.isSuccess || result.statusCode == 404;

      case SyncOperation.update:
        // Bookmarks don't have updates — only create/delete
        return true;
    }
  }

  /// Process user achievement sync operations.
  /// Pushes earned achievements to the server (idempotent).
  Future<bool> _processUserAchievementOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.create) return false;

    // API expects {"achievements": [{"id": "...", "earned_at": "..."}]}
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.userAchievements,
      data: {
        'achievements': [
          {
            'id': payload['achievement_id'],
            'earned_at': payload['earned_at'],
          }
        ],
      },
    );

    if (result.isSuccess) {
      // Mark the local achievement record as synced
      await _db.markAchievementsSynced([localId]);
      return true;
    }
    return false;
  }

  /// Process ELO profile sync — PUT to server.
  Future<bool> _processEloProfileOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.update) return false;

    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.userEloProfile,
      data: payload,
    );

    if (result.isSuccess) {
      await _db.updateEloProfileSyncStatus(localId, SyncStatus.synced.toInt());
      return true;
    }
    return false;
  }

  /// Process ELO interaction log — POST to server (append-only).
  Future<bool> _processEloInteractionOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.create) return false;

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.eloInteractions,
      data: payload,
    );

    // On success the sync queue auto-cleans the entry.
    return result.isSuccess;
  }

  /// Batch-send all pending ELO interaction operations in a single request.
  /// Returns true if all were handled (batched or individually), false if
  /// some items remain unprocessed and should be retried by the normal loop.
  Future<void> _batchEloInteractions(List<SyncQueueTableData> allOps) async {
    final eloOps = allOps.where((op) => op.tableName_ == 'elo_interactions').toList();
    if (eloOps.isEmpty) return;

    final payloads = <Map<String, dynamic>>[];
    final createOps = <SyncQueueTableData>[];
    for (final op in eloOps) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        final operation = SyncOperationExtension.fromValue(op.operation);
        if (operation == SyncOperation.create) {
          payloads.add(payload);
          createOps.add(op);
        }
      } catch (e, st) { silentLog('sync_service', e, st); }
    }

    if (payloads.isEmpty) return;

    // Use batch endpoint for any number of interactions
    try {
      final result = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.eloInteractionsBatch,
        data: {'interactions': payloads},
      );

      if (result.isSuccess) {
        for (final op in createOps) {
          await _syncQueue.markSynced(op.id);
        }
        return;
      }
    } catch (e, st) { silentLog('sync_service', e, st); }

    // Batch failed — fall back to individual sends
    for (final op in createOps) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        final result = await _apiClient.post<Map<String, dynamic>>(
          ApiEndpoints.eloInteractions,
          data: payload,
        );
        if (result.isSuccess) {
          await _syncQueue.markSynced(op.id);
        }
      } catch (e, st) { silentLog('sync_service', e, st); }
    }
  }

  /// Process chat message sync — UPDATE pushes feedback to server.
  Future<bool> _processChatMessageOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.update) return false;

    // Look up the message to get its serverId.
    final rows = await (_db.select(_db.chatMessagesTable)
          ..where((m) => m.id.equals(localId))
          ..limit(1))
        .get();
    if (rows.isEmpty) return false;
    final message = rows.first;

    if (message.serverId == null) return false;

    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.chatMessageFeedback(message.serverId!),
      data: payload,
    );

    if (result.isSuccess) {
      await _db.updateChatMessageSyncStatus(localId, 'synced');
      return true;
    }
    return false;
  }

  /// Process chat session sync — DELETE removes session on server.
  Future<bool> _processChatSessionOperation(
    String localId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    if (operation != SyncOperation.delete) return false;

    final serverId = payload['server_id'] as int?;
    if (serverId == null) return false;

    final result = await _apiClient.delete<Map<String, dynamic>>(
      ApiEndpoints.chatSession(serverId),
    );

    return result.isSuccess || result.statusCode == 404;
  }

  /// Pull updates from the server.
  /// Each pull is wrapped in try/catch so one failure doesn't block others.
  Future<void> _pullUpdates() async {
    await _safePull(_pullCourseUpdates);
    await _safePull(_pullGamificationConfig);
    // User-specific pulls require authentication
    if (_apiClient.isAuthenticated) {
      await _safePull(_pullUserCourseUpdates);
      await _safePull(_pullUserStatsUpdates);
      await _safePull(_pullUserProgressUpdates);
      await _safePull(_pullBookmarkUpdates);
      await _safePull(_pullUserAchievements);
      await _safePull(_pullEloProfile);
      await _safePull(_pullBlockStats);
      await _safePull(_pullChatUpdates);
    }
  }

  Future<void> _safePull(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e, st) { silentLog('sync_service', e, st); }
  }

  /// Pull course updates from the server.
  Future<void> _pullCourseUpdates() async {
    // Get the most recent server update timestamp we have.
    final courses = await _db.getAllCourses();
    DateTime? lastUpdate;

    for (final course in courses) {
      if (course.serverUpdatedAt != null) {
        if (lastUpdate == null ||
            course.serverUpdatedAt!.isAfter(lastUpdate)) {
          lastUpdate = course.serverUpdatedAt;
        }
      }
    }

    // Fetch updates from server.
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.coursesCheckUpdates,
      queryParameters: lastUpdate != null
          ? {'since': lastUpdate.toIso8601String()}
          : null,
    );

    if (result.isSuccess && result.data != null) {
      final updatedCourses = result.data!['data'] as List<dynamic>?;

      if (updatedCourses != null) {
        for (final courseData in updatedCourses) {
          await _mergeServerCourse(courseData as Map<String, dynamic>);
        }
      }
    }
  }

  /// Pull user course updates from the server.
  Future<void> _pullUserCourseUpdates() async {
    final activeUser = await _db.getActiveUser();
    if (activeUser == null) return;

    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.userCourses,
    );

    if (result.isFailure || result.data == null) return;

    final userCoursesJson =
        result.data!['user_courses'] as List<dynamic>? ?? [];

    for (final json in userCoursesJson) {
      final remoteData = json as Map<String, dynamic>;
      final serverId = remoteData['id'] as int;

      // API now returns course_id as string identifier and server_id as numeric FK.
      // Handle both old (numeric course_id) and new formats for backwards compatibility.
      final courseIdRaw = remoteData['course_id'];
      final courseNumericId = remoteData['server_id'] as int?
          ?? (courseIdRaw is int ? courseIdRaw : null);
      final courseStringId = courseIdRaw is String ? courseIdRaw : null;

      // Find the local course — try numeric server ID first, then string course_id.
      CoursesTableData? localCourse;
      if (courseNumericId != null) {
        localCourse = await _db.getCourseByServerId(courseNumericId);
      }
      localCourse ??= courseStringId != null
          ? await _db.getCourseByFieldCourseId(courseStringId)
          : null;

      // Enrollment must always materialize. When the local catalog row is
      // missing, create it from the embedded `course` payload instead of
      // dropping the enrollment. This happens for PRIVATE courses (hidden from
      // the student `/courses` catalog) and whenever the catalog pull ran
      // unauthenticated or failed — after logout `clearAllData()` wipes the
      // catalog, so on re-login those enrollments would silently vanish from
      // the list even though the server still holds them with progress
      // (BR-SNUYF7). `/user/courses` embeds the full course (incl. `data`), so
      // we have everything needed to build a usable local row.
      if (localCourse == null) {
        final embedded = remoteData['course'] as Map<String, dynamic>?;
        final embName = (embedded?['name'] as String?)?.trim();
        final embCourseId =
            (embedded?['course_id'] as String?)?.trim() ?? courseStringId;
        if (embedded == null || embCourseId == null || embCourseId.isEmpty) {
          continue; // nothing to identify the course by — skip.
        }
        final newLocalId = _generateLocalId();
        await _db.upsertCourse(
          CoursesTableCompanion(
            id: Value(newLocalId),
            serverId: Value(courseNumericId),
            courseId: Value(embCourseId),
            // Never store a hardcoded placeholder or the raw code as name —
            // empty lets the UI resolve it later (mirrors _mergeServerCourse).
            name: Value(embName?.isNotEmpty == true ? embName! : ''),
            version: Value(embedded['version'] as int? ?? 1),
            status: Value(embedded['status'] as String? ?? 'published'),
            language: Value(embedded['language'] as String? ?? 'en'),
            data: embedded['data'] != null
                ? Value(jsonEncode(embedded['data']))
                : const Value.absent(),
            syncStatus: Value(SyncStatus.synced.toInt()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        localCourse = await _db.getCourseById(newLocalId);
        if (localCourse == null) continue;
      }

      // Repair the local courses row from the embedded `course` payload —
      // this fixes legacy rows where `name` was poisoned with the raw code
      // and keeps title/version/status in sync without waiting for the next
      // /courses pull.
      final embeddedCourse =
          remoteData['course'] as Map<String, dynamic>?;
      if (embeddedCourse != null && localCourse.syncStatus != SyncStatus.pending.toInt()) {
        final embeddedName = (embeddedCourse['name'] as String?)?.trim();
        final embeddedCourseId = (embeddedCourse['course_id'] as String?)?.trim();
        final embeddedVersion = embeddedCourse['version'] as int?;
        final embeddedStatus = embeddedCourse['status'] as String?;
        final embeddedLanguage = embeddedCourse['language'] as String?;

        // Only update if the catalog payload would change something, to
        // avoid noisy writes on every sync.
        final nameChanged = embeddedName != null &&
            embeddedName.isNotEmpty &&
            embeddedName != localCourse.name;
        final courseIdChanged = embeddedCourseId != null &&
            embeddedCourseId.isNotEmpty &&
            embeddedCourseId != localCourse.courseId;
        final versionChanged =
            embeddedVersion != null && embeddedVersion != localCourse.version;
        final statusChanged =
            embeddedStatus != null && embeddedStatus != localCourse.status;
        final langChanged =
            embeddedLanguage != null && embeddedLanguage != localCourse.language;

        if (nameChanged || courseIdChanged || versionChanged || statusChanged || langChanged) {
          await _db.upsertCourse(
            CoursesTableCompanion(
              id: Value(localCourse.id),
              serverId: Value(courseNumericId ?? localCourse.serverId),
              courseId: courseIdChanged
                  ? Value(embeddedCourseId)
                  : const Value.absent(),
              name: nameChanged ? Value(embeddedName) : const Value.absent(),
              version: versionChanged
                  ? Value(embeddedVersion)
                  : const Value.absent(),
              status: statusChanged
                  ? Value(embeddedStatus)
                  : const Value.absent(),
              language: langChanged
                  ? Value(embeddedLanguage)
                  : const Value.absent(),
              syncStatus: Value(SyncStatus.synced.toInt()),
              updatedAt: Value(DateTime.now()),
            ),
          );
          // Re-read so the rest of the loop sees the patched row.
          localCourse = await _db.getCourseById(localCourse.id) ?? localCourse;
        }
      }

      // The course cover set in admin lives in the course JSON, which the
      // metadata repair above and _mergeServerCourse never write. A bundled
      // course (the onboarding guide) is seeded from a JSON with no cover and
      // stays `pending`, so neither ever reached it either — and as every
      // logout wipes the device, a child on a shared device always saw the
      // emoji (BR-NZ7JUN). The embedded `data` is the stored course JSON, so
      // take the cover from there. A student never edits a course, so the
      // pending flag has nothing to protect here.
      final embeddedData = embeddedCourse?['data'];
      if (embeddedData is Map) {
        localCourse =
            await _carryCourseCover(localCourse, embeddedData['header_image']);
      }

      // Find existing local user course — first by server ID, then by
      // userId+courseId (handles code-entry records that don't have serverId yet),
      // then by course identity across sibling course rows. The last fallback
      // fixes BR-MFZF5R: after a course update the enrollment can be pinned to a
      // twin `courses` row, so a plain (userId, resolvedRow.id) lookup misses and
      // a duplicate enrollment would otherwise be minted below.
      var existingLocal = await _db.getUserCourseByServerId(serverId);
      existingLocal ??= await _db.getUserCourseByUserAndCourse(
        activeUser.id,
        localCourse.id,
      );
      existingLocal ??= await _db.findUserCourseByCourseIdentity(
        activeUser.id,
        serverId: courseNumericId ?? localCourse.serverId,
        courseId: courseStringId ?? localCourse.courseId,
      );

      // Skip records with pending local changes.
      if (existingLocal != null &&
          existingLocal.syncStatus == SyncStatus.pending.toInt()) {
        continue;
      }

      final remoteProgress = remoteData['progress_percent'] as int? ?? 0;
      final remoteCompleted = remoteData['completed_lessons'] as int? ?? 0;
      final localProgress = existingLocal?.progressPercent ?? 0;
      final localCompleted = existingLocal?.completedLessons ?? 0;

      // Never regress progress — take the higher value between local and remote.
      final mergedProgress = remoteProgress >= localProgress
          ? remoteProgress : localProgress;
      final mergedCompleted = remoteCompleted >= localCompleted
          ? remoteCompleted : localCompleted;

      // Determine status — never downgrade from 'completed'.
      final remoteStatus = remoteData['status'] as String? ?? 'downloaded';
      final localStatus = existingLocal?.status;
      final mergedStatus = localStatus == 'completed' && remoteStatus != 'completed'
          ? 'completed' : remoteStatus;

      // For progressDataJson: if server returns null/missing, keep local data.
      // If both exist, prefer the one with more entries (more complete).
      final Value<String> mergedProgressDataJson;
      if (remoteData['progress_data'] != null) {
        final remoteJson = jsonEncode(remoteData['progress_data']);
        final localJson = existingLocal?.progressDataJson ?? '{}';
        // If local has richer data (more keys), keep it.
        // Server may return progress_data as a List or Map — only compare
        // lengths when both sides are Maps.
        final remoteRaw = remoteData['progress_data'];
        final remoteMap = remoteRaw is Map<String, dynamic> ? remoteRaw : null;
        final localDecoded = localJson != '{}' ? jsonDecode(localJson) : null;
        final localMap = localDecoded is Map<String, dynamic> ? localDecoded : null;
        if (remoteMap != null && localMap != null && localMap.length > remoteMap.length) {
          mergedProgressDataJson = Value(localJson);
        } else {
          mergedProgressDataJson = Value(remoteJson);
        }
      } else {
        // Server didn't return progress_data — keep whatever we have locally.
        if (existingLocal != null) {
          mergedProgressDataJson = const Value.absent();
        } else {
          mergedProgressDataJson = const Value('{}');
        }
      }

      // Keep local currentLessonIndex/timeSpent if they're ahead.
      final remoteIndex = remoteData['current_lesson_index'] as int? ?? 0;
      final localIndex = existingLocal?.currentLessonIndex ?? 0;
      final remoteTime = remoteData['time_spent_seconds'] as int? ?? 0;
      final localTime = existingLocal?.timeSpentSeconds ?? 0;

      if (mergedProgress > remoteProgress || mergedCompleted > remoteCompleted) {
      }

      // Preserve "last user interaction" semantics for ordering. The local
      // updateUserCourseProgress path stamps updatedAt = DateTime.now() on
      // real user actions; we MUST NOT clobber that on every periodic pull.
      // Use the max of local updatedAt and the server-reported updated_at
      // (which itself reflects the last activity persisted server-side).
      DateTime? remoteUpdatedAt;
      try {
        final raw = remoteData['updated_at'];
        if (raw is String && raw.isNotEmpty) {
          remoteUpdatedAt = DateTime.parse(raw).toUtc();
        }
      } catch (_) {}
      final DateTime resolvedUpdatedAt;
      if (existingLocal == null) {
        resolvedUpdatedAt = remoteUpdatedAt ?? DateTime.now();
      } else if (remoteUpdatedAt != null &&
          remoteUpdatedAt.isAfter(existingLocal.updatedAt)) {
        resolvedUpdatedAt = remoteUpdatedAt;
      } else {
        resolvedUpdatedAt = existingLocal.updatedAt;
      }

      await _db.upsertUserCourse(
        UserCoursesTableCompanion(
          id: Value(existingLocal?.id ?? _generateLocalId()),
          serverId: Value(serverId),
          userId: Value(activeUser.id),
          courseId: Value(localCourse.id),
          status: Value(mergedStatus),
          progressPercent: Value(mergedProgress),
          completedLessons: Value(mergedCompleted),
          totalLessons: Value(remoteData['total_lessons'] as int? ?? 0),
          currentLessonIndex: Value(remoteIndex >= localIndex ? remoteIndex : localIndex),
          timeSpentSeconds: Value(remoteTime >= localTime ? remoteTime : localTime),
          progressDataJson: mergedProgressDataJson,
          // downloadedVersion=0 means synced from server but full course
          // data not yet downloaded from R2. The knihovna page uses this
          // to show a download button instead of "Staženo".
          downloadedVersion: existingLocal != null
              ? const Value.absent()
              : const Value(0),
          syncStatus: Value(SyncStatus.synced.toInt()),
          updatedAt: Value(resolvedUpdatedAt),
        ),
      );
    }

    // Safety net (BR-MFZF5R): collapse any twin course rows and duplicate
    // enrollments left behind by earlier syncs so the library shows one card
    // per course. Progress is preserved — the richest copy wins.
    await _db.deduplicateCourses();
    await _db.deduplicateUserCourses(activeUser.id);
  }

  /// Pull user stats updates from the server.
  Future<void> _pullUserStatsUpdates() async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.userStats,
    );

    if (result.isFailure || result.data == null) return;

    final statsJson =
        result.data!['stats'] as Map<String, dynamic>?;
    if (statsJson == null) return;

    final serverId = statsJson['id'] as int;
    final activeUser = await _db.getActiveUser();
    if (activeUser == null) return;

    final existingStats = await _db.getUserStats(activeUser.id);

    // Skip if local has pending changes.
    if (existingStats != null &&
        existingStats.syncStatus == SyncStatus.pending.toInt()) {
      return;
    }

    await _db.upsertUserStats(
      UserStatsTableCompanion(
        id: Value(existingStats?.id ?? _generateLocalId()),
        serverId: Value(serverId),
        userId: Value(activeUser.id),
        level: Value(statsJson['level'] as int? ?? 1),
        xpPoints: Value(statsJson['xp_points'] as int? ?? 0),
        coursesCount: Value(statsJson['courses_count'] as int? ?? 0),
        streakDays: Value(statsJson['streak_days'] as int? ?? 0),
        achievementsCount:
            Value(statsJson['achievements_count'] as int? ?? 0),
        lastStreakDate: Value(
          statsJson['last_streak_date'] != null
              ? DateTime.parse(statsJson['last_streak_date'] as String)
              : null,
        ),
        dailyXpDate: Value(
          statsJson['daily_xp_date'] != null
              ? DateTime.parse(statsJson['daily_xp_date'] as String)
              : null,
        ),
        dailyXpAmount: Value(statsJson['daily_xp_amount'] as int? ?? 0),
        syncStatus: Value(SyncStatus.synced.toInt()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Pull user progress (lesson-level answers/block states) from server.
  Future<void> _pullUserProgressUpdates() async {
    final activeUser = await _db.getActiveUser();
    if (activeUser == null) return;

    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.userProgress,
    );

    if (result.isFailure || result.data == null) return;

    final progressList =
        result.data!['progress'] as List<dynamic>? ?? [];

    for (final json in progressList) {
      final remote = json as Map<String, dynamic>;
      final serverId = remote['id'] as int;
      final remoteCourseId = remote['course_id'] as String;
      final remoteLessonId = remote['lesson_id'] as String;

      // Resolve string course_id → local courseId (UUID).
      final course = await _db.getCourseByFieldCourseId(remoteCourseId);
      if (course == null) continue; // Course not downloaded locally yet

      // Check if we already have this lesson's progress locally.
      final existing = await _db.getLessonProgress(activeUser.id, remoteLessonId);

      // Skip if local has pending changes.
      if (existing != null &&
          existing.syncStatus == SyncStatus.pending.toInt()) {
        continue;
      }

      // Never regress progress — keep local data if it's more complete.
      final remotePercent = remote['progress_percent'] as int? ?? 0;
      final localPercent = existing?.progressPercent ?? 0;
      final remoteCompleted = remote['is_completed'] as bool? ?? false;
      final localCompleted = existing?.isCompleted ?? false;

      // For progressData: keep local if server returns null or local has more data.
      final Value<String> mergedProgressData;
      if (remote['progress_data'] != null) {
        final remoteJson = jsonEncode(remote['progress_data']);
        final localJson = existing?.progressData ?? '{}';
        // Server may return progress_data as a List or Map — only compare
        // lengths when both sides are Maps.
        final remoteRaw = remote['progress_data'];
        final remoteMap = remoteRaw is Map<String, dynamic> ? remoteRaw : null;
        final localDecoded = localJson != '{}' ? jsonDecode(localJson) : null;
        final localMap = localDecoded is Map<String, dynamic> ? localDecoded : null;
        mergedProgressData = (remoteMap != null && localMap != null && localMap.length > remoteMap.length)
            ? Value(localJson)
            : Value(remoteJson);
      } else if (existing != null) {
        mergedProgressData = const Value.absent();
      } else {
        mergedProgressData = const Value('{}');
      }

      await _db.upsertProgress(
        UserProgressTableCompanion(
          id: Value(existing?.id ?? _generateLocalId()),
          serverId: Value(serverId),
          userId: Value(activeUser.id),
          courseId: Value(course.id),
          lessonId: Value(remoteLessonId),
          progressPercent: Value(remotePercent >= localPercent ? remotePercent : localPercent),
          isCompleted: Value(remoteCompleted || localCompleted),
          lastPosition: Value(remote['last_position'] as int? ?? existing?.lastPosition ?? 0),
          timeSpentSeconds: Value(remote['time_spent_seconds'] as int? ?? existing?.timeSpentSeconds ?? 0),
          progressData: mergedProgressData,
          startedAt: Value(
            remote['started_at'] != null
                ? DateTime.parse(remote['started_at'] as String)
                : existing?.startedAt,
          ),
          completedAt: Value(
            remote['completed_at'] != null
                ? DateTime.parse(remote['completed_at'] as String)
                : existing?.completedAt,
          ),
          syncStatus: Value(SyncStatus.synced.toInt()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Pull bookmark updates from the server.
  /// Full replace: server is the source of truth for bookmarks.
  Future<void> _pullBookmarkUpdates() async {
    final activeUser = await _db.getActiveUser();
    if (activeUser == null) return;

    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.userBookmarks,
    );

    if (result.isFailure || result.data == null) return;

    final bookmarksList =
        result.data!['data'] as List<dynamic>? ?? [];

    // Collect server bookmark keys for diffing
    final serverKeys = <String>{};

    for (final json in bookmarksList) {
      final remote = json as Map<String, dynamic>;
      final courseId = remote['course_id'] as String? ?? '';
      final blockId = remote['block_id'] as String? ?? '';
      final lessonId = remote['lesson_id'] as String? ?? '';

      if (courseId.isEmpty || blockId.isEmpty) continue;
      serverKeys.add('$courseId:$blockId');

      // Check if we already have this bookmark locally
      final exists = await _db.isBookmarked(activeUser.id, courseId, blockId);
      if (!exists) {
        await _db.addBookmark(
          BookmarksTableCompanion(
            id: Value(_generateLocalId()),
            userId: Value(activeUser.id),
            courseId: Value(courseId),
            blockId: Value(blockId),
            lessonId: Value(lessonId),
          ),
        );
      }
    }

    // Remove local bookmarks not on server — but protect bookmarks that still
    // have an un-pushed CREATE in the sync queue (e.g. created in a guest
    // session moments before logging into an account, when the push hasn't
    // landed yet). Without this guard the full-replace would drop them before
    // _pushChanges ever uploads them to the now-active account (BR-YRT5ZM).
    final pendingKeys = await _pendingBookmarkKeys();
    final localBookmarks = await _db.getAllBookmarks(activeUser.id);
    for (final local in localBookmarks) {
      final key = '${local.courseId}:${local.blockId}';
      if (!serverKeys.contains(key) && !pendingKeys.contains(key)) {
        await _db.removeBookmark(activeUser.id, local.courseId, local.blockId);
      }
    }
  }

  /// Keys ("courseId:blockId") of bookmarks that still have an un-pushed CREATE
  /// in the sync queue. Used so [_pullBookmarkUpdates]'s full-replace never
  /// deletes a bookmark the server hasn't received yet (BR-YRT5ZM).
  Future<Set<String>> _pendingBookmarkKeys() async {
    final ops = await _syncQueue.getPendingOperations(limit: 1000);
    final keys = <String>{};
    for (final op in ops) {
      if (op.tableName_ != 'bookmarks') continue;
      if (SyncOperationExtension.fromValue(op.operation) !=
          SyncOperation.create) {
        continue;
      }
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        final courseId = payload['course_id'] as String? ?? '';
        final blockId = payload['block_id'] as String? ?? '';
        if (courseId.isNotEmpty && blockId.isNotEmpty) {
          keys.add('$courseId:$blockId');
        }
      } catch (_) {}
    }
    return keys;
  }

  /// Pull gamification config from server (public endpoint).
  Future<void> _pullGamificationConfig() async {
    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.gamificationConfig,
      );

      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        final version = data['version'] as int? ?? 1;

        // Check if we already have this version cached.
        final cached = await _db.getGamificationConfig();
        if (cached != null && cached.version >= version) {
          return; // Already up to date
        }

        await _db.saveGamificationConfig(
          version: version,
          configJson: jsonEncode(data),
        );
      }
    } catch (e, st) { silentLog('sync_service', e, st); }
  }

  /// Pull user's earned achievements from the server.
  Future<void> _pullUserAchievements() async {
    final activeUser = await _db.getActiveUser();
    if (activeUser == null) return;

    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.userAchievements,
      );

      if (result.isFailure || result.data == null) return;

      final achievementsList =
          result.data!['achievements'] as List<dynamic>? ?? [];

      for (final json in achievementsList) {
        final remote = json as Map<String, dynamic>;
        final achievementId = remote['achievement_id'] as String? ?? '';
        if (achievementId.isEmpty) continue;

        final earnedAtStr = remote['earned_at'] as String?;
        final earnedAt = earnedAtStr != null
            ? DateTime.tryParse(earnedAtStr) ?? DateTime.now()
            : DateTime.now();

        // Insert — will be a no-op if already exists (UNIQUE constraint).
        await _db.insertAchievement(
          id: _generateLocalId(),
          userId: activeUser.id,
          achievementId: achievementId,
          earnedAt: earnedAt,
          syncStatus: 0, // Already on server
        );
      }

    } catch (e, st) { silentLog('sync_service', e, st); }
  }

  /// Pull the user's ELO profile from the server.
  /// Skips if local profile has pending changes (to avoid overwriting unsent updates).
  Future<void> _pullEloProfile() async {
    final activeUser = await _db.getActiveUser();
    if (activeUser == null) return;

    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.userEloProfile,
      );

      if (result.isFailure || result.data == null) return;

      final serverData = result.data!;
      final serverElo = serverData['profil_elo'];
      final serverPocet = serverData['profil_pocet'];

      // Server might return null if no profile exists yet
      if (serverElo == null || serverPocet == null) return;

      // Check if local profile has pending changes — don't overwrite
      final localRows = await (_db.select(_db.userEloProfileTable)
            ..where((t) => t.userId.equals(activeUser.id)))
          .get();

      if (localRows.isNotEmpty &&
          localRows.first.syncStatus == SyncStatus.pending.toInt()) {
        return;
      }

      final now = DateTime.now();
      final eloJson = jsonEncode(serverElo);
      final pocetJson = jsonEncode(serverPocet);

      if (localRows.isNotEmpty) {
        // Update existing profile with server data
        await (_db.update(_db.userEloProfileTable)
              ..where((t) => t.id.equals(localRows.first.id)))
            .write(UserEloProfileTableCompanion(
          profilElo: Value(eloJson),
          profilPocet: Value(pocetJson),
          syncStatus: Value(SyncStatus.synced.toInt()),
          updatedAt: Value(now),
        ));
      } else {
        // Create new local profile from server data
        await _db.into(_db.userEloProfileTable).insert(
          UserEloProfileTableCompanion(
            id: Value(_generateLocalId()),
            userId: Value(activeUser.id),
            profilElo: Value(eloJson),
            profilPocet: Value(pocetJson),
            syncStatus: Value(SyncStatus.synced.toInt()),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

    } catch (e, st) { silentLog('sync_service', e, st); }
  }

  /// Pull the server's task calibration (BR-697NCA) for every downloaded
  /// course — the blocks the student can answer, the global quiz included.
  /// Cached locally so an offline answer still runs on the last calibrated
  /// difficulty; each course pulls only what changed since its newest row.
  Future<void> _pullBlockStats() async {
    try {
      for (final courseId in await _db.getDownloadedCourseIds()) {
        final since = await _db.getBlockStatsCursor(courseId);
        final result = await _apiClient.get<Map<String, dynamic>>(
          ApiEndpoints.blockStats,
          queryParameters: {
            'course_id': courseId,
            if (since != null) 'updated_since': since.toUtc().toIso8601String(),
          },
        );

        if (result.isFailure || result.data == null) continue;

        final data = result.data!;
        final meta = data['meta'];
        if (meta is! Map || meta['task_calibration'] != true) {
          // Nothing published — calibration switched off, or an API from
          // before it. Drop the cache so the course's own elo_vector applies.
          await _db.deleteBlockStatsForCourse(courseId);
          continue;
        }

        final stats = data['data'] as List<dynamic>?;
        if (stats == null) continue;

        for (final stat in stats) {
          if (stat is! Map<String, dynamic>) continue;
          final blockId = stat['block_id'] as String?;
          final updatedAt = DateTime.tryParse(stat['updated_at'] as String? ?? '');
          if (blockId == null || updatedAt == null) continue;

          await _db.upsertBlockStats(
            blockId: blockId,
            courseId: courseId,
            // Null until the server has calibrated (or counted) anything.
            itemPocet: jsonEncode(stat['item_pocet'] ?? const []),
            eloVector: jsonEncode(stat['elo_vector'] ?? const []),
            serverUpdatedAt: updatedAt,
          );
        }
      }
    } catch (e, st) { silentLog('sync_service', e, st); }
  }

  /// Pull chat session and message history from server.
  Future<void> _pullChatUpdates() async {
    try {
      final user = await _db.getActiveUser();
      if (user == null) return;

      final chatRepo = ChatRepository(
        localDataSource: ChatLocalDataSource(_db),
        remoteDataSource: ChatRemoteDataSource(_apiClient),
        connectivity: _connectivity,
        syncQueue: _syncQueue,
      );

      await chatRepo.pullHistory(user.id);
    } catch (e) {
      print('[SyncService] Chat pull failed: $e');
    }
  }

  /// Merge a server course with local data.
  /// Only updates metadata (name, version, status, language).
  /// NEVER touches the `data` column — course content (blocks/lessons)
  /// is exclusively managed by downloadFullCourseJson() from R2.
  /// Sync only handles metadata + user state.
  Future<void> _mergeServerCourse(Map<String, dynamic> serverData) async {
    final serverId = serverData['id'] as int;
    final serverUpdatedAt = DateTime.parse(serverData['updated_at'] as String);

    // Find local record by server ID, or by course_id string (for bundled courses
    // that were imported without a serverId).
    final courseIdStr = serverData['course_id'] as String;
    var localCourse = await _db.getCourseByServerId(serverId);
    localCourse ??= await _db.getCourseByFieldCourseId(courseIdStr);

    if (localCourse == null) {
      // New course from server — create a catalog entry with metadata only.
      // Full course data (blocks/lessons) will be downloaded from R2
      // when the user adds the course from the library (knihovna).
      await _db.upsertCourse(
        CoursesTableCompanion(
          id: Value(_generateLocalId()),
          serverId: Value(serverId),
          courseId: Value(courseIdStr),
          // Store empty when API has no name — never a hardcoded placeholder
          // (it sticks in the DB and shows as "Kurz" in listings) and never
          // the raw course_id, which leaks the internal code into UI.
          // The UI hides courses whose name is unknown until it resolves.
          name: Value(
            (serverData['name'] as String?)?.trim().isNotEmpty == true
                ? serverData['name'] as String
                : '',
          ),
          version: Value(serverData['version'] as int? ?? 1),
          status: Value(serverData['status'] as String? ?? 'published'),
          language: Value(serverData['language'] as String? ?? 'en'),
          // data: left as default '{}' — will be populated by R2 download
          syncStatus: Value(SyncStatus.synced.toInt()),
          serverUpdatedAt: Value(serverUpdatedAt),
          updatedAt: Value(serverUpdatedAt),
        ),
      );
    } else {
      // Existing course — only update metadata, never touch data column.
      if (localCourse.syncStatus == SyncStatus.pending.toInt()) {
        if (serverUpdatedAt.isAfter(localCourse.updatedAt)) {
          // Server wins for metadata only.
          final serverName = serverData['name'] as String?;
          await _db.upsertCourse(
            CoursesTableCompanion(
              id: Value(localCourse.id),
              serverId: Value(serverId),
              courseId: Value(serverData['course_id'] as String),
              name: serverName != null ? Value(serverName) : const Value.absent(),
              version: Value(serverData['version'] as int? ?? 1),
              status: Value(serverData['status'] as String? ?? 'published'),
              language: serverData['language'] != null
                  ? Value(serverData['language'] as String)
                  : const Value.absent(),
              syncStatus: Value(SyncStatus.synced.toInt()),
              serverUpdatedAt: Value(serverUpdatedAt),
              updatedAt: Value(serverUpdatedAt),
            ),
          );
          await _syncQueue.clearForRecord('courses', localCourse.id);
        }
      } else {
        // No local pending changes — update metadata only.
        final serverName = serverData['name'] as String?;
        await _db.upsertCourse(
          CoursesTableCompanion(
            id: Value(localCourse.id),
            serverId: Value(serverId),
            courseId: Value(serverData['course_id'] as String),
            name: serverName != null ? Value(serverName) : const Value.absent(),
            version: Value(serverData['version'] as int? ?? 1),
            status: Value(serverData['status'] as String? ?? 'published'),
            language: serverData['language'] != null
                ? Value(serverData['language'] as String)
                : const Value.absent(),
            syncStatus: Value(SyncStatus.synced.toInt()),
            serverUpdatedAt: Value(serverUpdatedAt),
            updatedAt: Value(serverUpdatedAt),
          ),
        );
      }
    }
  }

  /// Store [cover] (a server `header_image`) in [course]'s JSON when it is not
  /// there yet. Only the cover changes — content, version and sync status stay
  /// as they are. Returns the row as stored.
  Future<CoursesTableData> _carryCourseCover(
    CoursesTableData course,
    Object? cover,
  ) async {
    if (cover is! Map || cover['url'] == null) return course;

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(course.data);
      if (decoded is! Map<String, dynamic>) return course;
      data = decoded;
    } catch (e, st) {
      silentLog('sync_service', e, st);
      return course;
    }
    if (jsonEncode(data['header_image']) == jsonEncode(cover)) return course;

    data['header_image'] = cover;
    await (_db.update(_db.coursesTable)..where((t) => t.id.equals(course.id)))
        .write(CoursesTableCompanion(data: Value(jsonEncode(data))));
    return await _db.getCourseById(course.id) ?? course;
  }

  static const _uuid = Uuid();

  /// Generate a collision-resistant local ID for offline-created entities.
  String _generateLocalId() => 'local-${_uuid.v4()}';

  void _setState(SyncState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// Force a sync now, regardless of connectivity.
  Future<void> forceSync() async {
    await sync();
  }

  /// Get the count of pending sync operations.
  Future<int> getPendingCount() {
    return _syncQueue.getPendingCount();
  }

  /// Check if there are pending sync operations.
  Future<bool> hasPendingChanges() {
    return _syncQueue.hasPendingOperations();
  }

  /// Dispose of the service.
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _stateController.close();
  }
}
