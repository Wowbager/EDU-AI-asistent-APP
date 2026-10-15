import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../models/course_model.dart';

const _uuid = Uuid();

/// Repository for practice cards, review logs, and FSRS profiles.
/// Wraps AppDatabase CRUD methods and adds higher-level operations.
class PracticeRepository {
  final AppDatabase _db;

  PracticeRepository({required AppDatabase db}) : _db = db;

  // ═══════════════════════════════════════════════════════════════════════════
  // Practice Card Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all active practice cards for a user.
  Future<List<PracticeCardsTableData>> getActiveCards(String userId) {
    return _db.getActivePracticeCards(userId);
  }

  /// Active cards the student may actually be offered: [getActiveCards] minus
  /// everything belonging to a course flagged `only_once` — typically a test,
  /// whose blocks must not resurface in practice or the quiz (BR-E495XK).
  ///
  /// Filtering the *source* rather than the built queue is deliberate: the
  /// daily caps in [QueueBuilder] would otherwise be spent on cards that get
  /// dropped afterwards, and the offer would come back short. Rows are only
  /// filtered, never deleted — existing queues are left as they are, and a
  /// course that loses the flag brings its cards straight back.
  Future<List<PracticeCardsTableData>> getPracticeableCards(
      String userId) async {
    final cards = await getActiveCards(userId);
    if (cards.isEmpty) return cards;
    final excluded = await _db.getOnlyOnceCourseKeys();
    if (excluded.isEmpty) return cards;
    return cards.where((c) => !excluded.contains(c.courseId)).toList();
  }

  /// Get due practice cards for a user (dueDate <= now).
  Future<List<PracticeCardsTableData>> getDueCards(String userId) {
    return _db.getDuePracticeCards(userId);
  }

  /// Get new (state=0) practice cards for a user.
  Future<List<PracticeCardsTableData>> getNewCards(String userId, {int limit = 10}) {
    return _db.getNewPracticeCards(userId, limit: limit);
  }

  /// Get a practice card by userId and blockId.
  Future<PracticeCardsTableData?> getCardByBlock(String userId, String blockId) {
    return _db.getPracticeCardByBlock(userId, blockId);
  }

  /// Find the card to review for a block the practice player resolved.
  ///
  /// Card blockIds and player blockIds disagree around V2 steps: a bookmark
  /// may store the base block ("X") while the player emits a step block
  /// ("X:s1"), or the other way round. An exact lookup then misses and the
  /// review used to be silently dropped. Falls back to the oldest-due card
  /// among the base id and all "base:step" variants of [blockId].
  Future<PracticeCardsTableData?> getCardForResolvedBlock(
      String userId, String blockId) async {
    final exact = await _db.getPracticeCardByBlock(userId, blockId);
    if (exact != null) return exact;
    final baseId =
        blockId.contains(':') ? blockId.split(':').first : blockId;
    final variants = await _db.getPracticeCardsForBaseBlock(userId, baseId);
    return variants.isEmpty ? null : variants.first;
  }

  /// Apply a partial update to an existing card (keyed on the companion's id).
  ///
  /// Must stay a real UPDATE: the FSRS review path passes a companion carrying
  /// only the rescheduling fields, and routing it through
  /// `insertOnConflictUpdate` made drift validate it as an INSERT — the absent
  /// required identity columns threw InvalidDataException before any SQL ran,
  /// so every review was silently lost (the "practice never persists" bug).
  Future<void> updateCard(PracticeCardsTableCompanion card) {
    return _db.updatePracticeCardById(card);
  }

  /// Deactivate a practice card (sets isActive=false, syncStatus=1).
  Future<void> deactivateCard(String cardId) {
    return _db.updatePracticeCardById(PracticeCardsTableCompanion(
      id: Value(cardId),
      isActive: const Value(false),
      syncStatus: const Value(1),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Reactivate a practice card (sets isActive=true, syncStatus=1).
  Future<void> reactivateCard(String cardId) {
    return _db.updatePracticeCardById(PracticeCardsTableCompanion(
      id: Value(cardId),
      isActive: const Value(true),
      syncStatus: const Value(1),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Count due practice cards for a user.
  Future<int> countDueCards(String userId) {
    return _db.countDuePracticeCards(userId);
  }

  /// Get practice cards that need syncing to the server.
  Future<List<PracticeCardsTableData>> getPendingSyncCards() {
    return _db.getPendingSyncPracticeCards();
  }

  /// Create a practice card from a content block.
  ///
  /// - If the card already exists and is active, returns null (no-op).
  /// - If the card already exists but is inactive and [sourceType] == 'bookmark',
  ///   reactivates it and returns the updated card.
  /// - Otherwise, creates a new card seeded with FSRS data from [block.fsrs] if present.
  Future<PracticeCardsTableData?> createCardFromBlock({
    required String userId,
    required String courseId,
    required String lessonId,
    required ContentBlock block,
    required String sourceType,
  }) async {
    // Tests never feed the practice deck. Guarding here covers every entry
    // point at once — lesson completion, sync seeding, and the auto-bookmark
    // fired by a wrong answer inside the test itself (BR-E495XK).
    if (await _db.isOnlyOnceCourse(courseId)) return null;

    final existing = await _db.getPracticeCardByBlock(userId, block.blockId);

    if (existing != null) {
      if (existing.isActive) {
        // Already exists and is active — no-op
        return null;
      }
      // Inactive card: reactivate if triggered by bookmark
      if (sourceType == 'bookmark') {
        await reactivateCard(existing.id);
        return _db.getPracticeCardByBlock(userId, block.blockId);
      }
      return null;
    }

    // Create a new card
    final now = DateTime.now();
    final cardId = _uuid.v4();
    final fsrs = block.fsrs;

    final companion = PracticeCardsTableCompanion(
      id: Value(cardId),
      userId: Value(userId),
      courseId: Value(courseId),
      lessonId: Value(lessonId),
      blockId: Value(block.blockId),
      sourceType: Value(sourceType),
      state: const Value(0),
      dueDate: Value(fsrs?.dueDate?.toUtc() ?? now.toUtc()),
      stability: Value(fsrs?.stability ?? 0.0),
      difficulty: Value(fsrs?.difficulty ?? 0.0),
      reps: Value(fsrs?.reps ?? 0),
      lapses: Value(fsrs?.lapses ?? 0),
      scheduledDays: const Value(0),
      elapsedDays: const Value(0),
      lastReview: Value(fsrs?.lastReview),
      weight: Value(fsrs?.weight ?? 5.0),
      skipCondition: Value(fsrs?.skipCondition),
      isActive: const Value(true),
      syncStatus: const Value(1),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _db.upsertPracticeCard(companion);
    return _db.getPracticeCardByBlock(userId, block.blockId);
  }

  /// Create practice cards from all blocks in a lesson that have defaultPractice=true.
  ///
  /// Returns the count of newly created cards.
  Future<int> createCardsFromLesson({
    required String userId,
    required String courseId,
    required String lessonId,
    required List<ContentBlock> blocks,
  }) async {
    int created = 0;
    for (final block in blocks) {
      if (!block.defaultPractice) continue;
      final card = await createCardFromBlock(
        userId: userId,
        courseId: courseId,
        lessonId: lessonId,
        block: block,
        sourceType: 'lesson',
      );
      if (card != null) created++;
    }
    return created;
  }

  /// Seed practice cards for EVERY default_practice block of a course,
  /// independent of lesson-completion state, so the full admin-configured set
  /// is practiceable after login — not just the blocks completed in the prior
  /// (guest) session. Idempotent: [createCardFromBlock] no-ops on blocks that
  /// already have an active card. Returns the count of newly created cards.
  ///
  /// Note: this deliberately drops the "only completed blocks" gating that the
  /// per-lesson completion path relies on (see [Course.getDefaultPracticeBlocks]
  /// `completedBlockIds`). Introduced for BR-WR4C8P.
  Future<int> seedCardsFromCourse({
    required String userId,
    required Course course,
  }) async {
    // Read off the course itself, so a test is skipped whole — before the
    // per-block lookups, and even when its row was written before the
    // only_once column existed (BR-E495XK).
    if (course.onlyOnce) return 0;

    int created = 0;
    for (final lesson in course.lessons) {
      created += await createCardsFromLesson(
        userId: userId,
        courseId: course.id,
        lessonId: lesson.id,
        blocks: course.getBlocksForLesson(lesson.id),
      );
    }
    return created;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Review Log Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert a review log entry.
  Future<void> insertReviewLog(ReviewLogsTableCompanion log) {
    return _db.insertReviewLog(log);
  }

  /// Get all review logs for a card.
  Future<List<ReviewLogsTableData>> getLogsForCard(String cardId) {
    return _db.getReviewLogsForCard(cardId);
  }

  /// Count reviews done today for a user.
  Future<int> getTodayReviewCount(String userId) {
    return _db.getTodayReviewCount(userId);
  }

  /// Get review logs that need syncing.
  Future<List<ReviewLogsTableData>> getPendingSyncLogs() {
    return _db.getPendingSyncReviewLogs();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FSRS Profile Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the FSRS profile for a user.
  Future<StudentFsrsProfilesTableData?> getFsrsProfile(String userId) {
    return _db.getFsrsProfile(userId);
  }

  /// Insert or update a student FSRS profile.
  Future<void> saveFsrsProfile(StudentFsrsProfilesTableCompanion profile) {
    return _db.upsertFsrsProfile(profile);
  }
}
