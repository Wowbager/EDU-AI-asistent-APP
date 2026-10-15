// Gaming (guessing) filter — flags attempts answered implausibly fast.
//
// The practice spec ("Mechanismus rozpoznání gamingu") derives a per-task
// robust threshold from the log-times of that task's previous valid attempts
// (median − 3·MAD in ln-scale), but only once a task holds 10+ valid attempts;
// until then a fixed 2-second floor applies. Both halves of that rule live in
// GamingGuard.classify (core/elo/elo_engine.dart); this filter routes every
// verdict through it (BR-H3TCRE). Callers without a task's reference times
// pass none, which is exactly the cold-start rule — the fixed floor.
//
// A gamed attempt is *not* a wrong answer: it is an unevaluated one. It stays
// in the block's answer log, but must not move ELO or FSRS, and the feedback
// popup reports it as "Tipováno" instead of right/wrong.
library;

import '../elo/elo_engine.dart';

/// Whether an attempt opened at [openedAt] and answered at [answeredAt] was
/// too fast to be a real attempt.
///
/// [referenceTimesSeconds] are the task's previous valid, non-gaming reaction
/// times (display → submit, in seconds). With fewer than ten of them the fixed
/// [GamingGuard.minimumThresholdSeconds] (2 s) applies; from ten on, the
/// robust median/MAD threshold of [GamingGuard.classify]. Unusable entries
/// (negative or non-finite) are dropped rather than failing the answer.
///
/// [openedAt] null (the open timestamp was never captured) means no verdict —
/// never flag what cannot be measured.
bool isGamingAttempt({
  required DateTime? openedAt,
  required DateTime answeredAt,
  Iterable<double> referenceTimesSeconds = const [],
}) {
  if (openedAt == null) return false;
  final elapsed = answeredAt.difference(openedAt);
  // An answer stamped before its open is clock skew, not a slow answer —
  // count it as zero time, as the plain Duration comparison always did.
  final seconds = elapsed.isNegative
      ? 0.0
      : elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  return GamingGuard.classify(
    responseTimeSeconds: seconds,
    previousValidNonGamingReactionTimesSeconds: [
      for (final t in referenceTimesSeconds)
        if (t.isFinite && t >= 0.0) t,
    ],
  ).isGaming;
}

/// Lesson form of [isGamingAttempt], read off the ISO-8601 pair the lesson
/// persists as `block_timestamps[blockId]`: [openedAt] (block shown) and
/// [confirmedAt] (answer submitted). The admin ELO backfill reads that same
/// pair back and applies the same rule (EloBackfillController), so a recompute
/// skips exactly the blocks the lesson skipped live (BR-3N79C3). That replay
/// has no per-task reference, so lessons stay on the fixed 2 s floor.
///
/// A missing or unparsable timestamp means no verdict.
bool isGamingLessonAttempt({
  required String? openedAt,
  required String? confirmedAt,
}) {
  final answeredAt = confirmedAt == null ? null : DateTime.tryParse(confirmedAt);
  if (answeredAt == null) return false;
  return isGamingAttempt(
    openedAt: openedAt == null ? null : DateTime.tryParse(openedAt),
    answeredAt: answeredAt,
  );
}
