import '../../data/repositories/practice_repository.dart';
import '../database/app_database.dart';
import 'fsrs_bridge.dart';
import 'practice_filter.dart';
import 'queue_builder.dart';

/// Holds the result of reviewing a single card.
class ReviewResult {
  final PracticeCardsTableData updatedCard;
  final ReviewLogsTableData log;
  final int xpEarned;

  const ReviewResult({
    required this.updatedCard,
    required this.log,
    required this.xpEarned,
  });
}

/// Summarises a completed practice session.
class SessionSummary {
  final int totalCards;
  final int correctCount; // grade 3 or 4
  final int totalXp;
  final int totalTime; // seconds

  const SessionSummary({
    required this.totalCards,
    required this.correctCount,
    required this.totalXp,
    required this.totalTime,
  });

  /// Fraction of cards answered correctly (grade 3-4).
  double get successRate =>
      totalCards == 0 ? 0.0 : correctCount / totalCards;
}

/// Orchestrates a practice session: queue generation, card review, and FSRS
/// state updates.
class PracticeService {
  final PracticeRepository _repo;

  PracticeService({required PracticeRepository repo}) : _repo = repo;

  // ═══════════════════════════════════════════════════════════════════════════
  // Queue
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate today's practice queue for [userId].
  ///
  /// Loads the student's FSRS profile for daily limits (falling back to
  /// sensible defaults), fetches all active cards, and delegates to
  /// [QueueBuilder.buildQueue].
  ///
  /// [filter] is the student's chosen scope (subjects → areas). It is applied
  /// inside the builder, before the daily caps, so a narrowed selection gets
  /// the full daily allowance rather than the leftovers.
  Future<List<PracticeCardsTableData>> generateQueue(
    String userId, {
    PracticeFilter filter = PracticeFilter.all,
  }) async {
    final profile = await _repo.getFsrsProfile(userId);
    final todayCount = await _repo.getTodayReviewCount(userId);
    final allCards = await _repo.getPracticeableCards(userId);

    // Use profile limits if available; otherwise fall back to sane defaults.
    final dailyNewLimit = profile?.dailyNewLimit ?? 20;
    final dailyReviewLimit = profile?.dailyReviewLimit ?? 100;

    return QueueBuilder.buildQueue(
      allCards: allCards,
      dailyNewLimit: dailyNewLimit,
      dailyReviewLimit: dailyReviewLimit,
      todayReviewCount: todayCount,
      filter: filter,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Review
  // ═══════════════════════════════════════════════════════════════════════════

  /// Review a [card] with a 1-4 [rating] and persist the updated FSRS state.
  ///
  /// Returns a [ReviewResult] containing the updated card row, the persisted
  /// review log, and the XP earned.
  Future<ReviewResult> reviewCard({
    required PracticeCardsTableData card,
    required int rating,
    required DateTime shownAt,
    required String userId,
  }) async {
    final now = DateTime.now();

    // Build scheduler from user profile (or defaults).
    final profile = await _repo.getFsrsProfile(userId);
    final scheduler = FsrsBridge.buildScheduler(profile);

    // Convert DB card → fsrs.Card and run the scheduler.
    final fsrsCard = FsrsBridge.toFsrsCard(card);
    final fsrsRating = FsrsBridge.toFsrsRating(rating);
    final result = scheduler.reviewCard(fsrsCard, fsrsRating, reviewDateTime: now.toUtc());
    final reviewed = result.card;

    // Persist updated card.
    final updatedCompanion = FsrsBridge.fromFsrsCard(
      reviewed,
      card.id,
      previousReps: card.reps,
      previousLapses: card.lapses,
      rating: rating,
    );
    await _repo.updateCard(updatedCompanion);

    // Fetch the persisted card row.
    final updatedCard = await _repo.getCardByBlock(card.userId, card.blockId);

    // Build and persist review log.
    final responseTimeSec = now.difference(shownAt).inSeconds;
    final scheduledDays = reviewed.due.difference(now.toUtc()).inDays;
    final logCompanion = FsrsBridge.buildReviewLog(
      cardId: card.id,
      userId: userId,
      rating: rating,
      shownAt: shownAt,
      reviewedAt: now,
      responseTimeSec: responseTimeSec,
      repetitionNumber: card.reps + 1,
      stabilityAfter: reviewed.stability ?? 0.0,
      difficultyAfter: reviewed.difficulty ?? 0.0,
      nextDueDate: reviewed.due.toLocal(),
      intervalDays: scheduledDays,
    );
    await _repo.insertReviewLog(logCompanion);

    // Fetch the persisted log row.
    final logs = await _repo.getLogsForCard(card.id);
    final log = logs.first;

    // Calculate XP earned based on rating.
    final xpEarned = switch (rating) {
      4 => 10,
      3 => 8,
      2 => 5,
      _ => 1, // rating == 1
    };

    return ReviewResult(
      updatedCard: updatedCard!,
      log: log,
      xpEarned: xpEarned,
    );
  }
}
