import 'package:eduai/core/util/silent_log.dart';

import '../../models/block_model.dart';

/// Evaluates a practice card's authoring-time skip condition (queue rule 5).
///
/// Supported expression form (from the admin V2 docs):
///   `GPF_mastery <op> <number>`   e.g. `GPF_mastery > 0.8`
/// with the operator one of `>`, `>=`, `<`, `<=`, `==`, `!=`.
///
/// GPF_mastery is the student's mean ELO (1–10, normalized to 0–1) over the
/// GPF dimensions the block actually covers (relationVector > 0). When the
/// block has no GPF vector, the student has no ELO data for those dimensions
/// yet, or the expression is malformed, the condition evaluates to FALSE —
/// without data we never skip practice material.
///
/// Pure Dart — no Flutter or database dependencies.
class SkipConditionEvaluator {
  const SkipConditionEvaluator._();

  static final _exprPattern = RegExp(
    r'^\s*GPF_mastery\s*(>=|<=|==|!=|>|<)\s*([0-9]*\.?[0-9]+)\s*$',
    caseSensitive: false,
  );

  /// True when [condition] is satisfied and the block should be skipped.
  static bool shouldSkip({
    required String? condition,
    required ContentBlock block,
    required List<double?> profilElo,
  }) {
    if (condition == null || condition.trim().isEmpty) return false;

    final match = _exprPattern.firstMatch(condition);
    if (match == null) {
      silentLog('skip_condition',
          'unsupported expression "$condition" — not skipping');
      return false;
    }

    final mastery = masteryFor(block: block, profilElo: profilElo);
    if (mastery == null) return false; // no data — don't skip

    final op = match.group(1)!;
    final threshold = double.parse(match.group(2)!);
    switch (op) {
      case '>':
        return mastery > threshold;
      case '>=':
        return mastery >= threshold;
      case '<':
        return mastery < threshold;
      case '<=':
        return mastery <= threshold;
      case '==':
        return mastery == threshold;
      case '!=':
        return mastery != threshold;
    }
    return false;
  }

  /// Student mastery 0–1 for the dimensions [block] covers, or null when the
  /// block has no GPF relation vector or the student has no ELO for any of
  /// its dimensions.
  static double? masteryFor({
    required ContentBlock block,
    required List<double?> profilElo,
  }) {
    final relation = block.gpf?.relationVector;
    if (relation == null || relation.isEmpty) return null;

    var sum = 0.0;
    var count = 0;
    for (var i = 0; i < relation.length && i < profilElo.length; i++) {
      final rel = relation[i];
      if (rel == null || rel <= 0) continue;
      final elo = profilElo[i];
      if (elo == null) continue;
      sum += elo;
      count++;
    }
    if (count == 0) return null;

    // ELO is 1–10 → normalize to 0–1.
    return (sum / count) / 10.0;
  }
}
