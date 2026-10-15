import 'dart:math';

import '../database/app_database.dart';
import 'practice_filter.dart';

/// Builds the daily practice queue from a student's cards.
///
/// Pure function — no database access, no side effects.
class QueueBuilder {
  const QueueBuilder._();

  /// Builds an ordered, capped list of cards to review today.
  ///
  /// Algorithm:
  ///   0. Drop cards outside the student's chosen scope ([filter]), then any
  ///      card already reviewed today — one review per card per day.
  ///   1. Partition cards into: overdue (state > 0, due <= now), new (state == 0).
  ///      All other cards (state > 0 but not yet due) are excluded.
  ///   2. Sort overdue by weight DESC then dueDate ASC (most-important / longest-overdue first).
  ///   3. Sort new by weight DESC; take up to [dailyNewLimit].
  ///   4. Merge: overdue first, then new.
  ///   5. Diversify courses (interleave cards from different courses within same weight bucket).
  ///   6. Cap at ([dailyReviewLimit] - [todayReviewCount]).
  ///   7. Return [] if no remaining slots.
  static List<PracticeCardsTableData> buildQueue({
    required List<PracticeCardsTableData> allCards,
    required int dailyNewLimit,
    required int dailyReviewLimit,
    int todayReviewCount = 0,
    PracticeFilter filter = PracticeFilter.all,
    Random? random,
  }) {
    final remainingSlots = dailyReviewLimit - todayReviewCount;
    if (remainingSlots <= 0) return [];

    final now = DateTime.now();

    // Shuffle before sorting so cards tied on every sort key (same weight,
    // same due date — the common case, since most cards share the default
    // weight) come out in a different order each session instead of being
    // stuck in DB insertion order.
    final shuffled = List<PracticeCardsTableData>.from(allCards)
      ..shuffle(random ?? Random());

    // 1. Partition
    final overdue = <PracticeCardsTableData>[];
    final newCards = <PracticeCardsTableData>[];

    for (final card in shuffled) {
      // 0a. Scope: the student may have narrowed practice to some subjects /
      // areas. Filtering here rather than after the build keeps the daily
      // limits meaningful — otherwise the caps would be spent on cards the
      // student excluded, and a narrow selection would come back near-empty.
      if (!filter.allowsCard(card)) continue;
      if (!isEligible(card, now)) continue;
      if (card.state == 0) {
        newCards.add(card);
      } else {
        overdue.add(card);
      }
    }

    // 2. Sort overdue: weight DESC, dueDate ASC.
    // Due dates compare at day granularity: cards due the same day are a tie
    // (kept in shuffled order) rather than being ordered by the millisecond
    // they happened to be created/scheduled.
    overdue.sort((a, b) {
      final weightCmp = b.weight.compareTo(a.weight);
      if (weightCmp != 0) return weightCmp;
      return _dayKey(a.dueDate).compareTo(_dayKey(b.dueDate));
    });

    // 3. Sort new: weight DESC; cap at dailyNewLimit
    newCards.sort((a, b) => b.weight.compareTo(a.weight));
    final cappedNew = newCards.take(dailyNewLimit).toList();

    // 4. Merge
    final merged = [...overdue, ...cappedNew];

    // 5. Diversify courses
    final diversified = _diversifyCourses(merged);

    // 6. Cap
    return diversified.take(remainingSlots).toList();
  }

  /// Default size of one bonus set — a short extra round, not a second full day.
  static const int bonusQueueSize = 10;

  /// Builds an extra set for a student who has already cleared everything due
  /// today (BR-A6HU52).
  ///
  /// [buildQueue] deliberately returns nothing once every due card has been
  /// answered — that is what keeps the dashboard count honest and stops a card
  /// reappearing seconds after it was reviewed. But a student who opens
  /// Procvičování again should still be offered something, so this builds a
  /// second-choice pool out of exactly the cards the daily rules exclude:
  ///
  ///   Tier 0 — still due today, but left out by the daily caps.
  ///   Tier 1 — scheduled in the future: soonest due first, and within the same
  ///            due day the ones the student has got wrong before (relearning
  ///            or lapsed) first.
  ///   Tier 2 — nothing left ahead: already-practised cards again, least
  ///            recently reviewed first.
  ///
  /// A lower tier only fills the slots the tier above it left. Scope [filter]
  /// and `is_active` still apply — a card the student switched off stays off.
  /// Course diversification is deliberately skipped: here the due-date order is
  /// the promise made to the student, and interleaving would break it.
  static List<PracticeCardsTableData> buildBonusQueue({
    required List<PracticeCardsTableData> allCards,
    int limit = bonusQueueSize,
    PracticeFilter filter = PracticeFilter.all,
    Random? random,
  }) {
    if (limit <= 0) return [];

    final now = DateTime.now();

    // Same reason as buildQueue: break insertion-order ties differently each
    // session so a bonus round isn't the identical list every time.
    final shuffled = List<PracticeCardsTableData>.from(allCards)
      ..shuffle(random ?? Random());

    final dueNow = <PracticeCardsTableData>[];
    final future = <PracticeCardsTableData>[];
    final done = <PracticeCardsTableData>[];

    for (final card in shuffled) {
      if (!card.isActive) continue;
      if (!filter.allowsCard(card)) continue;
      if (isEligible(card, now)) {
        dueNow.add(card);
      } else if (card.state != 0 && card.dueDate.isAfter(now)) {
        future.add(card);
      } else {
        done.add(card);
      }
    }

    // Tier 0 keeps the daily queue's own priority.
    dueNow.sort((a, b) {
      final weightCmp = b.weight.compareTo(a.weight);
      if (weightCmp != 0) return weightCmp;
      return _dayKey(a.dueDate).compareTo(_dayKey(b.dueDate));
    });

    future.sort((a, b) {
      final dueCmp = _dayKey(a.dueDate).compareTo(_dayKey(b.dueDate));
      if (dueCmp != 0) return dueCmp;
      final wrongCmp = _wrongRank(a).compareTo(_wrongRank(b));
      if (wrongCmp != 0) return wrongCmp;
      return b.weight.compareTo(a.weight);
    });

    done.sort((a, b) {
      final reviewCmp = _lastReviewKey(a).compareTo(_lastReviewKey(b));
      if (reviewCmp != 0) return reviewCmp;
      final wrongCmp = _wrongRank(a).compareTo(_wrongRank(b));
      if (wrongCmp != 0) return wrongCmp;
      return b.weight.compareTo(a.weight);
    });

    return [...dueNow, ...future, ...done].take(limit).toList();
  }

  /// 0 for a card the student has answered wrong at some point, 1 otherwise —
  /// a sort key, so "wrong ones first" is a plain ascending compare. State 3 is
  /// relearning (the last answer was "Again"); lapses counts earlier ones.
  static int _wrongRank(PracticeCardsTableData card) =>
      (card.state == 3 || card.lapses > 0) ? 0 : 1;

  /// Sort key for "least recently practised first"; never-reviewed cards sort
  /// ahead of everything else.
  static int _lastReviewKey(PracticeCardsTableData card) =>
      card.lastReview?.millisecondsSinceEpoch ?? -1;

  /// Whether [card] could enter today's queue at all, ignoring scope, ordering
  /// and the daily caps.
  ///
  /// Shared with the practice picker so the per-area counts it shows are the
  /// same notion of "waiting for you today" the queue itself uses — a count
  /// that disagreed with what pressing Start produces reads as a bug.
  static bool isEligible(PracticeCardsTableData card, DateTime now) {
    if (!card.isActive) return false;
    // One review per card per day. FSRS learning steps reschedule an "Again"
    // card ~1 minute out, so without this the card the student just answered
    // reappears on the dashboard seconds after they finished — and two devices
    // on the same account disagree purely on when each last recomputed its
    // queue (BR-ZBJ99Z). The card still comes back tomorrow, driven by its
    // FSRS due date.
    if (card.lastReview != null && _isSameDay(card.lastReview!, now)) {
      return false;
    }
    if (card.state == 0) return true;
    // Seen cards wait for their FSRS due date.
    return !card.dueDate.isAfter(now);
  }

  /// Interleaves cards from different courses within the same weight bucket to
  /// provide variety during a session.
  ///
  /// Cards are grouped into weight buckets (rounded to 1 decimal place).
  /// Within each bucket, cards are interleaved round-robin by courseId so that
  /// no single course dominates consecutive positions.
  static List<PracticeCardsTableData> _diversifyCourses(
      List<PracticeCardsTableData> cards) {
    if (cards.isEmpty) return cards;

    // Group into buckets while preserving within-bucket order. A bucket is
    // one "tie" of the queue sort: same weight (rounded to 1 dp) and — for
    // already-scheduled cards — the same due day. Interleaving only within a
    // bucket keeps the weight/due-date priority produced by buildQueue.
    final buckets = <String, List<PracticeCardsTableData>>{};
    final bucketOrder = <String>[];

    for (final card in cards) {
      final weightBucket = (card.weight * 10).roundToDouble() / 10;
      final dueBucket = card.state == 0 ? 'new' : '${_dayKey(card.dueDate)}';
      final bucket = '$weightBucket|$dueBucket';
      if (!buckets.containsKey(bucket)) {
        buckets[bucket] = [];
        bucketOrder.add(bucket);
      }
      buckets[bucket]!.add(card);
    }

    final result = <PracticeCardsTableData>[];

    for (final bucket in bucketOrder) {
      final bucketCards = buckets[bucket]!;

      // Group by courseId within the bucket
      final byCourse = <String, List<PracticeCardsTableData>>{};
      final courseOrder = <String>[];
      for (final card in bucketCards) {
        if (!byCourse.containsKey(card.courseId)) {
          byCourse[card.courseId] = [];
          courseOrder.add(card.courseId);
        }
        byCourse[card.courseId]!.add(card);
      }

      // Interleave round-robin
      int maxLen = byCourse.values.fold(0, (m, l) => m > l.length ? m : l.length);
      for (int i = 0; i < maxLen; i++) {
        for (final courseId in courseOrder) {
          final list = byCourse[courseId]!;
          if (i < list.length) {
            result.add(list[i]);
          }
        }
      }
    }

    return result;
  }

  /// True when both instants fall on the same local calendar day.
  static bool _isSameDay(DateTime a, DateTime b) => _dayKey(a) == _dayKey(b);

  /// Day-granularity sort key (yyyymmdd) so same-day due dates tie.
  static int _dayKey(DateTime d) {
    final local = d.toLocal();
    return local.year * 10000 + local.month * 100 + local.day;
  }
}
