// Per-domain ELO movement across one quiz block (BR-JCUJVR).
//
// The end-of-quiz feedback popup reports, for each of the five GPF domains,
// how far the student's rating moved over the block:
//
//   delta_domain = average(after) - average(before)
//
// averaged over the subconstructs of that domain.
//
// **Only dimensions that hold a rating in BOTH snapshots count.** A dimension
// the student meets for the first time goes null → value inside
// [EloEngine.updateTask]'s first-contact branch, which *seeds* an initial
// rating and deliberately skips the student update. Counting that as movement
// would report a jump from nothing to ~6.0 as if it were learning.
//
// Pure Dart, no Flutter — the arithmetic is unit-tested directly.
library;

import 'gpf_structure.dart';

/// How far one GPF domain moved over a block.
class DomainEloDelta {
  /// The domain this covers. Its Czech display name is resolved separately via
  /// `GpfLabelRepository.domainNames()` — see [GpfDomain].
  final GpfDomain domain;

  /// Average rating change across the comparable dimensions, in ELO points.
  /// Positive = improvement, negative = decline.
  final double delta;

  /// How many of the domain's dimensions had a rating in both snapshots.
  final int dimensionCount;

  const DomainEloDelta({
    required this.domain,
    required this.delta,
    required this.dimensionCount,
  });

  bool get isImprovement => delta > 0;
}

/// Compute the per-domain ELO movement between two profile snapshots.
///
/// [before] and [after] are 35-element profile vectors (`profil_elo`), nullable
/// per dimension. Returns one entry per domain that actually moved, in
/// [GpfStructure.domains] display order.
///
/// Domains are dropped when nothing in them is comparable, and when the average
/// works out to exactly zero — an untouched dimension contributes an exact 0.0,
/// so an all-zero domain means the block never touched it. That keeps the popup
/// to the domains the student just practised instead of listing five zeroes.
List<DomainEloDelta> computeDomainEloDeltas({
  required List<double?> before,
  required List<double?> after,
}) {
  final results = <DomainEloDelta>[];

  for (final domain in GpfStructure.domains) {
    var sum = 0.0;
    var count = 0;

    for (final index in domain.indices) {
      if (index >= before.length || index >= after.length) continue;
      final b = before[index];
      final a = after[index];
      if (b == null || a == null) continue;
      if (b.isNaN || a.isNaN) continue;
      sum += a - b;
      count++;
    }

    if (count == 0) continue;
    final delta = sum / count;
    if (delta == 0.0) continue;

    results.add(DomainEloDelta(
      domain: domain,
      delta: delta,
      dimensionCount: count,
    ));
  }

  return results;
}
