import 'dart:math';

import 'package:eduai/core/elo/elo_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pilot 2 asymmetric bidirectional ELO engine (BR-P2UAT2).
///
/// The numeric fixtures here are mirrored in the backend port
/// (eduai-api/tests/Unit/EloEngineTest.php) — the admin ELO backfill replays
/// interactions with the PHP class, so both must land on the same numbers.
void main() {
  List<double?> nullProfile() => List<double?>.filled(kGpfDimensions, null);
  List<int> zeros() => List<int>.filled(kGpfDimensions, 0);
  List<double> noRelation() => List<double>.filled(kGpfDimensions, 0.0);

  /// One active dimension [k] with student [r], task [d], counters [n]/[m].
  EloUpdateResult runOne({
    required double? r,
    required double d,
    required double score,
    int n = 0,
    int m = 0,
    int k = 3,
    double relation = 2.0,
    bool skipEloUpdate = false,
  }) {
    final profil = nullProfile()..[k] = r;
    final profilPocet = zeros()..[k] = n;
    final rel = noRelation()..[k] = relation;
    final elo = nullProfile()..[k] = d;
    final itemPocet = zeros()..[k] = m;
    return EloEngine.updateTask(
      profilElo: profil,
      profilPocet: profilPocet,
      relationVector: rel,
      eloVector: elo,
      itemPocet: itemPocet,
      score: score,
      skipEloUpdate: skipEloUpdate,
    );
  }

  group('expected-score curves', () {
    test('student sees 0.50 and task 0.75 when rating equals difficulty', () {
      expect(
        EloEngine.expectedForStudent(studentRating: 6.0, taskDifficulty: 6.0),
        closeTo(0.5, 1e-12),
      );
      expect(
        EloEngine.expectedForTask(studentRating: 6.0, taskDifficulty: 6.0),
        closeTo(0.75, 1e-12),
      );
    });

    test('biases are derived from the targets, not stored separately', () {
      expect(kPilot2EloConfig.studentBias, closeTo(0.0, 1e-12));
      expect(kPilot2EloConfig.taskBias, closeTo(log(3), 1e-12));
    });
  });

  group('K-factors', () {
    test('student K decays to the 0.3 asymptote, never to zero', () {
      expect(EloEngine.studentK(0), closeTo(1.0, 1e-12));
      expect(EloEngine.studentK(3), closeTo(0.3 + 0.7 / 1.3, 1e-12));
      expect(EloEngine.studentK(1000000), closeTo(0.3, 1e-5));
    });

    test('task K uses the plain reciprocal and converges to zero', () {
      expect(EloEngine.taskK(0), closeTo(1.0, 1e-12));
      expect(EloEngine.taskK(5), closeTo(1 / 1.5, 1e-12));
      expect(EloEngine.taskK(1000000), closeTo(0.0, 1e-5));
    });

    test('negative counters are rejected', () {
      expect(() => EloEngine.studentK(-1), throwsArgumentError);
      expect(() => EloEngine.taskK(-1), throwsArgumentError);
    });
  });

  group('updateTask — numeric fixtures shared with the PHP port', () {
    test('matched ratings, first success: student +0.5, task -0.25', () {
      final res = runOne(r: 6.0, d: 6.0, score: 1.0);
      expect(res.profilElo[3], closeTo(6.5, 1e-9));
      expect(res.eloVector[3], closeTo(5.75, 1e-9));
      expect(res.profilPocet[3], 1);
      expect(res.itemPocet[3], 1);
      expect(res.updatedIndices, [3]);
    });

    test('weaker student fails a harder task', () {
      final res = runOne(r: 5.0, d: 7.0, score: 0.0, n: 3, m: 5);
      expect(res.profilElo[3], closeTo(4.774502962, 1e-9));
      expect(res.eloVector[3], closeTo(7.349755409, 1e-9));
      expect(res.profilPocet[3], 4);
      expect(res.itemPocet[3], 6);
    });

    test('strong student half-scores an easy, well-calibrated task', () {
      final res = runOne(r: 8.0, d: 4.0, score: 0.5, n: 20, m: 50);
      expect(res.profilElo[3], closeTo(7.796908225, 1e-9));
      expect(res.eloVector[3], closeTo(4.076139245, 1e-9));
    });

    test('ratings stay clamped to 0..10', () {
      final top = runOne(r: 10.0, d: 0.0, score: 1.0);
      expect(top.profilElo[3], 10.0);
      final bottom = runOne(r: 0.0, d: 10.0, score: 0.0);
      expect(bottom.profilElo[3], 0.0);
    });
  });

  group('updateTask — gating rules', () {
    test('only relation == 2 is active; 1 and 0 are ignored', () {
      for (final relation in [0.0, 1.0]) {
        final res = runOne(r: 6.0, d: 6.0, score: 1.0, relation: relation);
        expect(res.updatedIndices, isEmpty);
        expect(res.profilElo[3], 6.0);
        expect(res.profilPocet[3], 0);
      }
    });

    test('a null task rating in an active dimension is skipped', () {
      final profil = nullProfile()..[3] = 6.0;
      final rel = noRelation()..[3] = 2.0;
      final res = EloEngine.updateTask(
        profilElo: profil,
        profilPocet: zeros(),
        relationVector: rel,
        eloVector: nullProfile(),
        itemPocet: zeros(),
        score: 1.0,
      );
      expect(res.updatedIndices, isEmpty);
    });

    test('first contact seeds the student and touches nothing else', () {
      final win = runOne(r: null, d: 7.5, score: 0.5);
      expect(win.profilElo[3], 7.5);
      expect(win.profilPocet[3], 0);
      expect(win.eloVector[3], 7.5);
      expect(win.itemPocet[3], 0);
      expect(win.updatedIndices, [3]);

      final lose = runOne(r: null, d: 7.5, score: 0.25);
      expect(lose.profilElo[3], kDefaultStudentRating);
      expect(lose.profilPocet[3], 0);
    });

    test('skipEloUpdate returns everything unchanged (gaming attempt)', () {
      final res = runOne(r: 6.0, d: 6.0, score: 1.0, n: 2, m: 4,
          skipEloUpdate: true);
      expect(res.profilElo[3], 6.0);
      expect(res.profilPocet[3], 2);
      expect(res.eloVector[3], 6.0);
      expect(res.itemPocet[3], 4);
      expect(res.updatedIndices, isEmpty);
    });

    test('callers keep their original vectors', () {
      final profil = nullProfile()..[3] = 6.0;
      final pocet = zeros();
      final rel = noRelation()..[3] = 2.0;
      final elo = nullProfile()..[3] = 6.0;
      final item = zeros();
      EloEngine.updateTask(
        profilElo: profil,
        profilPocet: pocet,
        relationVector: rel,
        eloVector: elo,
        itemPocet: item,
        score: 1.0,
      );
      expect(profil[3], 6.0);
      expect(pocet[3], 0);
      expect(elo[3], 6.0);
      expect(item[3], 0);
    });
  });

  // Each interaction the app logs records which configuration produced its
  // snapshots (BR-EBNMBF), so the label has to come from the run itself.
  group('updateTask — config version', () {
    test('the default run reports the Pilot 2 configuration', () {
      expect(runOne(r: 6.0, d: 6.0, score: 1.0).configVersion,
          kPilot2EloConfigVersion);
      expect(
          runOne(r: 6.0, d: 6.0, score: 1.0, skipEloUpdate: true)
              .configVersion,
          kPilot2EloConfigVersion);
    });

    test('a run with another configuration reports that one', () {
      const other = EloConfig(
        version: 'pilot2-elo-test',
        lambda: 0.5,
        targetStudentAtMatch: 0.50,
        targetTaskAtMatch: 0.75,
        k0Student: 1.0,
        kMinStudent: 0.3,
        alphaStudent: 0.1,
        k0Task: 1.0,
        alphaTask: 0.1,
      );
      final res = EloEngine.updateTask(
        profilElo: nullProfile()..[3] = 6.0,
        profilPocet: zeros(),
        relationVector: noRelation()..[3] = 2.0,
        eloVector: nullProfile()..[3] = 6.0,
        itemPocet: zeros(),
        score: 1.0,
        config: other,
      );
      expect(res.configVersion, 'pilot2-elo-test');
    });
  });

  group('updateTask — validation', () {
    test('rejects vectors that are not exactly 35 wide', () {
      expect(
        () => EloEngine.updateTask(
          profilElo: nullProfile(),
          profilPocet: zeros(),
          relationVector: List<double>.filled(34, 0.0),
          eloVector: nullProfile(),
          itemPocet: zeros(),
          score: 1.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a score outside 0..1 and a non-discrete relation', () {
      expect(() => runOne(r: 6.0, d: 6.0, score: 1.5), throwsArgumentError);
      expect(() => runOne(r: 6.0, d: 6.0, score: 1.0, relation: 1.5),
          throwsArgumentError);
    });
  });

  group('GamingGuard', () {
    test('fixed 2 s threshold until a task has 10 valid attempts', () {
      final nine = List<double>.filled(9, 30.0);
      final fast = GamingGuard.classify(
        responseTimeSeconds: 1.9,
        previousValidNonGamingReactionTimesSeconds: nine,
      );
      expect(fast.isGaming, isTrue);
      expect(fast.usedStartupThreshold, isTrue);
      expect(fast.thresholdSeconds, 2.0);
      expect(fast.referenceCount, 9);

      final ok = GamingGuard.classify(
        responseTimeSeconds: 2.0,
        previousValidNonGamingReactionTimesSeconds: nine,
      );
      expect(ok.isGaming, isFalse);
    });

    test('robust log-time median/MAD threshold once history exists', () {
      const ref = [5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0];
      final res = GamingGuard.classify(
        responseTimeSeconds: 2.5,
        previousValidNonGamingReactionTimesSeconds: ref,
      );
      expect(res.usedStartupThreshold, isFalse);
      expect(res.thresholdSeconds, closeTo(2.562702376, 1e-9));
      expect(res.isGaming, isTrue);
    });

    test('a flat history collapses MAD to zero; threshold is the median', () {
      final ref = List<double>.filled(12, 10.0);
      final res = GamingGuard.classify(
        responseTimeSeconds: 9.0,
        previousValidNonGamingReactionTimesSeconds: ref,
      );
      expect(res.thresholdSeconds, closeTo(10.0, 1e-9));
      expect(res.isGaming, isTrue);
    });

    test('threshold never drops below 2 s', () {
      final ref = List<double>.filled(10, 0.5);
      final res = GamingGuard.classify(
        responseTimeSeconds: 1.0,
        previousValidNonGamingReactionTimesSeconds: ref,
      );
      expect(res.thresholdSeconds, 2.0);
    });

    test('negative or non-finite times are rejected', () {
      expect(
        () => GamingGuard.classify(
          responseTimeSeconds: -0.1,
          previousValidNonGamingReactionTimesSeconds: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => GamingGuard.classify(
          responseTimeSeconds: 3.0,
          previousValidNonGamingReactionTimesSeconds: const [double.nan],
        ),
        throwsArgumentError,
      );
    });
  });

  group('task selection', () {
    TaskCandidate candidate(String id, Map<int, double> difficulties) {
      final rel = noRelation();
      final elo = nullProfile();
      difficulties.forEach((k, d) {
        rel[k] = 2.0;
        elo[k] = d;
      });
      return TaskCandidate(blockId: id, relationVector: rel, eloVector: elo);
    }

    test('distance is the mean squared gap over active dimensions', () {
      final profil = nullProfile()
        ..[0] = 5.0
        ..[1] = 7.0;
      final d = EloEngine.candidateDistance(
        profilElo: profil,
        candidate: candidate('a', {0: 6.0, 1: 4.0, 2: 6.0}),
      );
      // (1^2 + 3^2 + 0^2) / 3 — index 2 falls back to the 6.0 default.
      expect(d, closeTo(10 / 3, 1e-12));
    });

    test('a candidate with no active dimension is unrankable', () {
      expect(
        EloEngine.candidateDistance(
          profilElo: nullProfile(),
          candidate: candidate('none', const {}),
        ),
        isNull,
      );
      expect(
        EloEngine.rankCandidates(
          profilElo: nullProfile(),
          candidates: [candidate('none', const {})],
        ),
        isEmpty,
      );
    });

    test('rankCandidates orders closest first; selectTask returns it', () {
      final profil = nullProfile()..[0] = 6.0;
      final pool = [
        candidate('far', {0: 9.0}),
        candidate('near', {0: 6.5}),
        candidate('mid', {0: 7.5}),
      ];
      final ranked = EloEngine.rankCandidates(
        profilElo: profil,
        candidates: pool,
      );
      expect(ranked.map((r) => r.candidate.blockId), ['near', 'mid', 'far']);
      expect(EloEngine.selectTask(profilElo: profil, candidates: pool), 1);
    });

    test('random subset samples distinct tasks from the top-N only', () {
      final profil = nullProfile()..[0] = 6.0;
      // 30 candidates, difficulty i/10 away from the student. Only the 20
      // closest may ever be picked.
      final pool = List.generate(
        30,
        (i) => candidate('c$i', {0: 6.0 + i / 10}),
      );
      final picks = EloEngine.selectRandomSubsetFromTopCandidates(
        profilElo: profil,
        candidates: pool,
        count: 5,
        topN: 20,
        random: Random(42),
      );
      expect(picks, hasLength(5));
      expect(picks.toSet(), hasLength(5));
      expect(picks.every((i) => i < 20), isTrue);

      final single = EloEngine.selectRandomFromTopCandidates(
        profilElo: profil,
        candidates: pool,
        topN: 20,
        random: Random(7),
      );
      expect(single, isNotNull);
      expect(single, lessThan(20));
    });

    test('a short pool returns everything it has', () {
      final profil = nullProfile()..[0] = 6.0;
      final pool = [candidate('a', {0: 6.0}), candidate('b', {0: 7.0})];
      final picks = EloEngine.selectRandomSubsetFromTopCandidates(
        profilElo: profil,
        candidates: pool,
        count: 5,
      );
      expect(picks.toSet(), {0, 1});
      expect(
        EloEngine.selectRandomSubsetFromTopCandidates(
          profilElo: profil,
          candidates: const [],
        ),
        isEmpty,
      );
    });
  });
}
