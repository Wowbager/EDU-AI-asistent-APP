import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/block_model.dart';
import '../database/app_database.dart';
import '../sync/sync_queue.dart';
import '../../data/repositories/practice_repository.dart';
import '../util/silent_log.dart';
import 'core_providers.dart';
import 'practice_providers.dart';

/// Provider for managing bookmarked blocks across the app.
/// Bookmarks are persisted to SQLite and survive app restarts.
/// Key format: "courseId:blockId" (block-level) or "courseId:blockId:stepId" (step-level)
final bookmarkProvider = StateNotifierProvider<BookmarkNotifier, Map<String, ContentBlock>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final syncQueue = ref.watch(syncQueueProvider);
  return BookmarkNotifier(db, syncQueue, ref);
});

class BookmarkNotifier extends StateNotifier<Map<String, ContentBlock>> {
  final AppDatabase _db;
  final SyncQueue _syncQueue;
  final Ref _ref;
  final _uuid = const Uuid();
  String? _userId;

  /// Set of bookmark keys loaded from DB (courseId:blockId).
  /// Used to know which bookmarks exist in DB even when ContentBlock
  /// objects haven't been populated yet.
  final Set<String> _dbBookmarkKeys = {};

  BookmarkNotifier(this._db, this._syncQueue, this._ref) : super({});

  /// Clear all cached state. Call on logout to prevent data leaking
  /// to the next user session.
  void clear() {
    _userId = null;
    _dbBookmarkKeys.clear();
    state = {};
  }

  /// Initialize bookmarks for a user by loading from DB.
  /// Call this after the user is known (e.g. on login/app start).
  Future<void> initForUser(String userId) async {
    _userId = userId;
    final bookmarks = await _db.getAllBookmarks(userId);
    _dbBookmarkKeys.clear();
    for (final b in bookmarks) {
      _dbBookmarkKeys.add(_key(b.courseId, b.blockId));
    }
    // State starts empty — ContentBlock objects are populated when
    // courses are opened and blocks are available.
  }

  /// Generate a unique key for a block
  String _key(String courseId, String blockId) => '$courseId:$blockId';

  /// Add a block to bookmarks
  void addBookmark(String courseId, ContentBlock block, {String lessonId = ''}) {
    final key = _key(courseId, block.blockId);
    state = {...state, key: block};
    _dbBookmarkKeys.add(key);

    // Persist to DB. _userId may still be null right after a fresh PIN login
    // (initForUser runs on main-screen init, BEFORE the guest user exists) —
    // fall back to the active user from the DB so the bookmark and its FSRS
    // card aren't silently dropped.
    _persistBookmark(courseId, block, lessonId);
  }

  Future<void> _persistBookmark(
      String courseId, ContentBlock block, String lessonId) async {
    try {
      if (_userId == null) {
        final user = await _db.getActiveUser();
        if (user == null) {
          silentLog('bookmark_provider:add',
              'no active user — bookmark for ${block.blockId} not persisted');
          return;
        }
        _userId = user.id;
      }

      final bookmarkId = _uuid.v4();
      await _db.addBookmark(BookmarksTableCompanion(
        id: Value(bookmarkId),
        userId: Value(_userId!),
        courseId: Value(courseId),
        blockId: Value(block.blockId),
        lessonId: Value(lessonId),
      ));

      // Enqueue for server sync
      await _syncQueue.enqueue(
        tableName: 'bookmarks',
        recordId: bookmarkId,
        operation: SyncOperation.create,
        payload: {
          'course_id': courseId,
          'block_id': block.blockId,
          'lesson_id': lessonId,
        },
      );

      // Seed an FSRS practice card for this block (sourceType 'bookmark').
      // No-op if a card already exists, reactivates an inactive one. Covers
      // manual bookmarks and auto-bookmark-on-wrong.
      await PracticeRepository(db: _db).createCardFromBlock(
        userId: _userId!,
        courseId: courseId,
        lessonId: lessonId,
        block: block,
        sourceType: 'bookmark',
      );
      // Refresh the practice queue/count once the card is written so the
      // homepage "Procvičování" card appears without a manual refresh.
      _ref.invalidate(practiceQueueProvider);
      // The picker reads the card rows itself, so it doesn't cascade from the
      // queue — without this a bookmark in a new lesson never reached it, and
      // a picker hidden for having one area stayed hidden (BR-27AEMT).
      _ref.invalidate(practiceScopeProvider);
    } catch (e, st) {
      silentLog('bookmark_provider:seed_card', e, st);
    }
  }

  /// Remove a block from bookmarks
  void removeBookmark(String courseId, String blockId) {
    final key = _key(courseId, blockId);
    state = Map.from(state)..remove(key);
    _dbBookmarkKeys.remove(key);

    // Remove from DB.
    if (_userId != null) {
      _db.removeBookmark(_userId!, courseId, blockId);

      // Enqueue delete for server sync — use composite key as recordId
      _syncQueue.enqueue(
        tableName: 'bookmarks',
        recordId: '$courseId:$blockId',
        operation: SyncOperation.delete,
        payload: {
          'course_id': courseId,
          'block_id': blockId,
        },
      );
    }
  }

  /// Toggle bookmark status for a block
  void toggleBookmark(String courseId, ContentBlock block, {String lessonId = ''}) {
    final key = _key(courseId, block.blockId);
    if (state.containsKey(key) || _dbBookmarkKeys.contains(key)) {
      removeBookmark(courseId, block.blockId);
    } else {
      addBookmark(courseId, block, lessonId: lessonId);
    }
  }

  /// Check if a block is bookmarked
  bool isBookmarked(String courseId, String blockId) {
    return state.containsKey(_key(courseId, blockId)) ||
        _dbBookmarkKeys.contains(_key(courseId, blockId));
  }

  /// Key prefixes to match a course by. A bookmark row may be keyed by the
  /// local Drift course row id (`local-<uuid>`, what in-app bookmarking passes)
  /// or by the server course code (`A34-Funkce_c1_v3`, what the server returns
  /// and what a *different* device's row id can never match). Callers pass both
  /// so a course's bookmarks are found under either scheme (BR-ZBJ99Z).
  List<String> _prefixes(String courseId, Iterable<String> alsoMatch) {
    final ids = <String>{courseId, ...alsoMatch}..removeWhere((c) => c.isEmpty);
    return ids.map((c) => '$c:').toList();
  }

  /// Check if the course has any bookmarks (in DB or in-memory)
  bool hasBookmarksForCourse(String courseId,
      {Iterable<String> alsoMatch = const []}) {
    final prefixes = _prefixes(courseId, alsoMatch);
    bool matches(String k) => prefixes.any(k.startsWith);
    return _dbBookmarkKeys.any(matches) || state.keys.any(matches);
  }

  /// Get all bookmarked blocks for a course.
  ///
  /// Reads the in-memory [state], which only holds blocks that were hydrated
  /// (see [hydrateForCourse]) — a DB bookmark whose ContentBlock hasn't been
  /// resolved yet is invisible here. Use [hasBookmarksForCourse] when you only
  /// need to know whether bookmarks exist.
  List<ContentBlock> getBookmarksForCourse(String courseId,
      {Iterable<String> alsoMatch = const []}) {
    final prefixes = _prefixes(courseId, alsoMatch);
    return state.entries
        .where((e) => prefixes.any(e.key.startsWith))
        .map((e) => e.value)
        .toList();
  }

  /// Get all bookmarked question blocks for a course (for Cvičení)
  List<ContentBlock> getBookmarkedQuestionBlocks(String courseId) {
    return getBookmarksForCourse(courseId)
        .where((block) =>
            block.type == BlockType.question ||
            block.type == BlockType.quiz ||
            (block.type == BlockType.exercise && block.atomicQuestion != null))
        .toList();
  }

  /// Restore in-memory ContentBlock objects for a course from a block list.
  /// Call this when opening a course so bookmarked blocks have their
  /// ContentBlock data available for getBookmarksForCourse().
  ///
  /// Handles both block-level bookmarks (key = courseId:blockId) and
  /// step-level bookmarks (key = courseId:blockId:stepId) by finding
  /// the base block and extracting the specific step's content.
  void hydrateForCourse(String courseId, List<ContentBlock> allBlocks,
      {Iterable<String> alsoMatch = const []}) {
    final newEntries = <String, ContentBlock>{};
    final prefixes = _prefixes(courseId, alsoMatch);

    // Build blockId → ContentBlock lookup
    final blockMap = <String, ContentBlock>{};
    for (final block in allBlocks) {
      blockMap[block.blockId] = block;
    }

    for (final dbKey in _dbBookmarkKeys) {
      final prefix = prefixes.firstWhere(
        dbKey.startsWith,
        orElse: () => '',
      );
      if (prefix.isEmpty) continue;

      // Skip if already hydrated in state (user added during this session)
      if (state.containsKey(dbKey)) {
        final existing = state[dbKey]!;
        // Only skip if it has actual content (not a bare shell)
        if (existing.content != null ||
            existing.steps.isNotEmpty ||
            existing.atomicQuestion != null ||
            existing.atomicImage != null) {
          continue;
        }
      }

      final bookmarkBlockId = dbKey.substring(prefix.length);

      // Try direct match (block-level bookmark)
      final directBlock = blockMap[bookmarkBlockId];
      if (directBlock != null) {
        newEntries[dbKey] = directBlock;
        continue;
      }

      // Try composite key: baseBlockId:stepId (step-level bookmark)
      final colonIdx = bookmarkBlockId.indexOf(':');
      if (colonIdx > 0) {
        final baseBlockId = bookmarkBlockId.substring(0, colonIdx);
        final stepId = bookmarkBlockId.substring(colonIdx + 1);
        final baseBlock = blockMap[baseBlockId];
        if (baseBlock != null) {
          // Find the specific step
          BlockStep? step;
          for (final s in baseBlock.steps) {
            if (s.stepId == stepId) {
              step = s;
              break;
            }
          }
          if (step != null) {
            // Create a ContentBlock representing this bookmarked step
            newEntries[dbKey] = ContentBlock(
              blockId: bookmarkBlockId,
              type: baseBlock.type,
              content: step.htmlContent ?? step.displayText,
              atomicImage: step.image,
              atomicVideo: step.video,
            );
          }
        }
      }
    }

    if (newEntries.isNotEmpty) {
      state = {...state, ...newEntries};
    }
  }

  /// Clear all bookmarks for a course
  void clearBookmarksForCourse(String courseId) {
    state = Map.fromEntries(
      state.entries.where((e) => !e.key.startsWith('$courseId:')),
    );
    _dbBookmarkKeys.removeWhere((k) => k.startsWith('$courseId:'));

    if (_userId != null) {
      _db.deleteBookmarksForCourse(_userId!, courseId);
    }
  }

  /// Clear all bookmarks
  void clearAll() {
    state = {};
    _dbBookmarkKeys.clear();
  }
}
