import 'package:eduai/core/elo/domain_elo_delta.dart';
import 'package:eduai/core/elo/elo_engine.dart';
import 'package:eduai/core/elo/gpf_structure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-domain ELO movement shown in the end-of-quiz feedback (BR-JCUJVR).
void main() {
  /// A 35-slot profile vector with every dimension unset.
  List<double?> emptyProfile() => List<double?>.filled(kGpfDimensions, null);

  /// Domain "M" (Míra v geometrii) — indices 17..21, small enough to hand-check.
  final m = GpfStructure.domainByCode('M')!;

  test('averages the movement across a domain', () {
    final before = emptyProfile();
    final after = emptyProfile();
    for (final i in m.indices) {
      before[i] = 6.0;
      after[i] = 6.0;
    }
    // Two of the five dimensions moved: +1.0 and +0.5 → average 1.5/5 = 0.3.
    after[m.indices[0]] = 7.0;
    after[m.indices[1]] = 6.5;

    final deltas = computeDomainEloDeltas(before: before, after: after);

    expect(deltas, hasLength(1));
    expect(deltas.single.domain.code, 'M');
    expect(deltas.single.delta, closeTo(0.3, 1e-9));
    expect(deltas.single.dimensionCount, 5);
    expect(deltas.single.isImprovement, isTrue);
  });

  test('reports a decline as a negative delta', () {
    final before = emptyProfile();
    final after = emptyProfile();
    before[m.indices[0]] = 6.0;
    after[m.indices[0]] = 5.0;

    final deltas = computeDomainEloDeltas(before: before, after: after);

    expect(deltas.single.delta, closeTo(-1.0, 1e-9));
    expect(deltas.single.isImprovement, isFalse);
  });

  test('a first-contact dimension (null → value) is not movement', () {
    // EloEngine seeds an initial rating on first contact and skips the student
    // update; counting null → 6.0 would report a phantom +6.0 jump.
    final before = emptyProfile();
    final after = emptyProfile();
    after[m.indices[0]] = kDefaultStudentRating;

    expect(computeDomainEloDeltas(before: before, after: after), isEmpty);
  });

  test('a seeded dimension is excluded but its neighbours still count', () {
    final before = emptyProfile();
    final after = emptyProfile();
    before[m.indices[0]] = 6.0;
    after[m.indices[0]] = 6.5; // comparable, moved
    after[m.indices[1]] = 6.0; // seeded this block, no "before"

    final deltas = computeDomainEloDeltas(before: before, after: after);

    expect(deltas.single.dimensionCount, 1);
    expect(deltas.single.delta, closeTo(0.5, 1e-9));
  });

  test('untouched domains are dropped instead of listed as zero', () {
    final before = emptyProfile();
    final after = emptyProfile();
    for (var i = 0; i < kGpfDimensions; i++) {
      before[i] = 6.0;
      after[i] = 6.0;
    }
    after[m.indices[0]] = 6.5;

    final deltas = computeDomainEloDeltas(before: before, after: after);

    expect(deltas.map((d) => d.domain.code), ['M']);
  });

  test('returns domains in GpfStructure display order', () {
    final before = emptyProfile();
    final after = emptyProfile();
    for (final code in ['A', 'N', 'G']) {
      final domain = GpfStructure.domainByCode(code)!;
      before[domain.indices.first] = 6.0;
      after[domain.indices.first] = 6.5;
    }

    final deltas = computeDomainEloDeltas(before: before, after: after);

    expect(deltas.map((d) => d.domain.code), ['N', 'G', 'A']);
  });

  test('an empty or short profile yields nothing rather than throwing', () {
    expect(
      computeDomainEloDeltas(before: const [], after: const []),
      isEmpty,
    );
    expect(
      computeDomainEloDeltas(before: const [6.0], after: const [6.5, 7.0]),
      hasLength(1),
    );
  });

  test('a real EloEngine update produces a matching domain delta', () {
    final before = emptyProfile();
    for (var i = 0; i < kGpfDimensions; i++) {
      before[i] = 6.0;
    }
    final relation = List<double>.filled(kGpfDimensions, 0.0);
    final taskElo = emptyProfile();
    relation[m.indices[0]] = 2.0;
    taskElo[m.indices[0]] = 6.0;

    final result = EloEngine.updateTask(
      profilElo: before,
      profilPocet: List<int>.filled(kGpfDimensions, 0),
      relationVector: relation,
      eloVector: taskElo,
      itemPocet: List<int>.filled(kGpfDimensions, 0),
      score: 1.0,
    );

    final deltas =
        computeDomainEloDeltas(before: before, after: result.profilElo);

    expect(deltas.map((d) => d.domain.code), ['M']);
    expect(deltas.single.delta, greaterThan(0));
  });
}
