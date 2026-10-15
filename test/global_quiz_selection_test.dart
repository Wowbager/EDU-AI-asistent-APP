// "Global Quiz v1": after the entry dialog narrows domains/courses, the
// selection matches questions to the student's ELO profile — rough band on
// the averages, then the Pilot 2 engine's draw: nearest-20 by mean squared
// difference, random 10 without replacement (BR-Y2XNB9). Every filter must
// relax on shortage rather than starve the quiz.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/elo/elo_engine.dart';
import 'package:eduai/core/elo/gpf_structure.dart';
import 'package:eduai/core/gamification/global_quiz.dart';
import 'package:eduai/core/gamification/global_quiz_selection.dart';
import 'package:eduai/models/course_model.dart';

Map<String, dynamic>? _template;

/// One exercise block cloned from the bundled fixture, with its GPF vectors
/// replaced. [comps] maps dimension index → task ELO; every listed dimension
/// gets relation 2.
ContentBlock _block(String id, {Map<int, double>? comps}) {
  _template ??= (jsonDecode(
    File('assets/courses/EDU_ONBOARDING_APP.json').readAsStringSync(),
  ) as Map<String, dynamic>)['blocks']
      .cast<Map<String, dynamic>>()
      .firstWhere((b) => b['type'] == 'exercise') as Map<String, dynamic>;

  final json = Map<String, dynamic>.from(_template!);
  json['block_id'] = id;
  if (comps == null) {
    json.remove('gpf');
  } else {
    json['gpf'] = {
      'relation_vector': List<double>.generate(
          kGpfDimensions, (i) => comps.containsKey(i) ? 2.0 : 0.0),
      'elo_vector':
          List<double?>.generate(kGpfDimensions, (i) => comps[i]),
    };
  }
  return ContentBlock.fromJson(json);
}

/// A 35-dim student profile: null everywhere except [comps].
List<double?> _student(Map<int, double> comps) =>
    List<double?>.generate(kGpfDimensions, (i) => comps[i]);

void main() {
  group('selectGlobalQuizBlocks', () {
    test('a pool at or under the limit is returned whole', () {
      final pool = [for (var i = 0; i < 7; i++) _block('b$i')];
      final picked = selectGlobalQuizBlocks(
        pool: pool,
        studentElo: _student(const {}),
        random: Random(1),
      );
      expect(picked.map((b) => b.blockId).toSet(),
          pool.map((b) => b.blockId).toSet());
    });

    test('domain filter keeps only blocks touching the chosen domain', () {
      // N is indices 0–16, A is 29–34.
      final pool = [
        for (var i = 0; i < 12; i++) _block('n$i', comps: const {0: 6.0}),
        for (var i = 0; i < 12; i++) _block('a$i', comps: const {29: 6.0}),
      ];
      final picked = selectGlobalQuizBlocks(
        pool: pool,
        studentElo: _student(const {0: 6.0, 29: 6.0}),
        domainCodes: const {'N'},
        random: Random(2),
      );
      expect(picked, hasLength(globalQuizLength));
      expect(picked.every((b) => b.blockId.startsWith('n')), isTrue);
    });

    test('tasks a point below the student are dropped', () {
      final pool = [
        for (var i = 0; i < 15; i++) _block('easy$i', comps: const {0: 2.0}),
        for (var i = 0; i < 12; i++) _block('fit$i', comps: const {0: 6.0}),
      ];
      final picked = selectGlobalQuizBlocks(
        pool: pool,
        studentElo: _student(const {0: 6.0}),
        random: Random(3),
      );
      expect(picked, hasLength(globalQuizLength));
      expect(picked.every((b) => b.blockId.startsWith('fit')), isTrue);
    });

    test('tasks are matched on the calibrated difficulty (BR-697NCA)', () {
      // Authored at 6.0 like the student, but the server calibrated the
      // "easy" ones down to 2.0 — a point below the student, so they drop,
      // exactly as if the content had said 2.0.
      final pool = [
        for (var i = 0; i < 15; i++) _block('easy$i', comps: const {0: 6.0}),
        for (var i = 0; i < 12; i++) _block('fit$i', comps: const {0: 6.0}),
      ];
      final picked = selectGlobalQuizBlocks(
        pool: pool,
        studentElo: _student(const {0: 6.0}),
        calibratedTaskElo: {
          for (var i = 0; i < 15; i++) 'easy$i': _student(const {0: 2.0}),
        },
        random: Random(3),
      );
      expect(picked, hasLength(globalQuizLength));
      expect(picked.every((b) => b.blockId.startsWith('fit')), isTrue);
    });

    test('the band relaxes rather than starve the quiz', () {
      // Nothing but too-easy tasks: the lower band must give way.
      final pool = [
        for (var i = 0; i < 12; i++) _block('easy$i', comps: const {0: 2.0}),
      ];
      final picked = selectGlobalQuizBlocks(
        pool: pool,
        studentElo: _student(const {0: 6.0}),
        random: Random(4),
      );
      expect(picked, hasLength(globalQuizLength));
    });

    test('the draw stays inside the 20 nearest candidates', () {
      // 20 exact matches (distance 0) and 10 slightly-off ones: the window is
      // exactly the exact matches, so nothing else may be drawn.
      final pool = [
        for (var i = 0; i < 20; i++) _block('near$i', comps: const {0: 6.0}),
        for (var i = 0; i < 10; i++) _block('far$i', comps: const {0: 6.9}),
      ];
      for (var seed = 0; seed < 5; seed++) {
        final picked = selectGlobalQuizBlocks(
          pool: pool,
          studentElo: _student(const {0: 6.0}),
          random: Random(seed),
        );
        expect(picked, hasLength(globalQuizLength));
        expect(picked.every((b) => b.blockId.startsWith('near')), isTrue,
            reason: 'seed $seed drew outside the candidate window');
      }
    });

    test('ranks by the MEAN squared difference, not the sum (BR-Y2XNB9)', () {
      // "wide" touches four dimensions, each 0.5 off: sum 1.0, mean 0.25.
      // "narrow" touches one, 0.6 off: sum 0.36, mean 0.36. A sum ranks the
      // narrow tasks first and lets them into the window; Pilot 2's mean
      // ranks all 20 wide tasks ahead of them, so nothing narrow is drawn.
      const wide = {0: 6.5, 1: 6.5, 2: 6.5, 3: 6.5};
      final pool = [
        for (var i = 0; i < 20; i++) _block('wide$i', comps: wide),
        for (var i = 0; i < 10; i++) _block('narrow$i', comps: const {0: 6.6}),
      ];
      for (var seed = 0; seed < 5; seed++) {
        final picked = selectGlobalQuizBlocks(
          pool: pool,
          studentElo: _student(const {0: 6.0, 1: 6.0, 2: 6.0, 3: 6.0}),
          random: Random(seed),
        );
        expect(picked, hasLength(globalQuizLength));
        expect(picked.every((b) => b.blockId.startsWith('wide')), isTrue,
            reason: 'seed $seed let a sum-favoured narrow task in');
      }
    });

    test('the draw is EloEngine.selectRandomSubsetFromTopCandidates', () {
      // 30 in-band tasks at graded distances, alternating one and three
      // active dimensions so a sum and a mean disagree on the order: the quiz
      // must be exactly the engine's draw over them — same ranking, same
      // top-20 window, same sampling without replacement for a given random
      // source.
      final pool = [
        for (var i = 0; i < 30; i++)
          _block('t$i', comps: {
            for (final k in i.isEven ? const [0] : const [0, 1, 2])
              k: 6.0 + i * 0.05,
          }),
      ];
      final student = _student(const {0: 6.0, 1: 6.0, 2: 6.0});

      for (var seed = 0; seed < 5; seed++) {
        final expected = EloEngine.selectRandomSubsetFromTopCandidates(
          profilElo: student,
          candidates: [
            for (final b in pool)
              TaskCandidate(
                blockId: b.blockId,
                relationVector: [
                  for (final r in b.gpf!.relationVector!) r ?? 0.0,
                ],
                eloVector: b.gpf!.eloVector!,
              ),
          ],
          count: globalQuizLength,
          topN: kGlobalQuizCandidateWindow,
          random: Random(seed),
        ).map((i) => pool[i].blockId).toList();

        final picked = selectGlobalQuizBlocks(
          pool: pool,
          studentElo: student,
          random: Random(seed),
        );
        expect(picked.map((b) => b.blockId).toList(), expected,
            reason: 'seed $seed diverged from the engine');
      }
    });

    test('vectors the engine would reject never throw', () {
      // Engine input is strict (35 slots, relation 0/1/2, ELO 0..10). A short
      // block vector is fitted and still ranked; out-of-contract values make
      // the block unrankable fill-up; a short profile is padded.
      Map<String, dynamic> gpfJson(List<double?> relation, List<double?> elo) =>
          {'relation_vector': relation, 'elo_vector': elo};
      ContentBlock raw(String id, Map<String, dynamic> gpf) {
        final json = Map<String, dynamic>.from(_template!);
        json['block_id'] = id;
        json['gpf'] = gpf;
        return ContentBlock.fromJson(json);
      }

      _block('warm-up'); // loads the template
      final pool = [
        for (var i = 0; i < 6; i++) _block('ok$i', comps: const {0: 6.0}),
        for (var i = 0; i < 3; i++)
          raw('short$i', gpfJson([2.0, 0.0], [6.0, null])),
        raw('oddRelation', gpfJson([3.0], [6.0])),
        raw('oddElo', gpfJson([2.0], [12.0])),
        raw('nan', gpfJson([2.0], [double.nan])),
      ];

      final picked = selectGlobalQuizBlocks(
        pool: pool,
        studentElo: const [6.0, 6.0], // written by an older build
        random: Random(6),
      );
      expect(picked, hasLength(globalQuizLength));
      expect(picked.map((b) => b.blockId).toSet(), hasLength(globalQuizLength));
      // The fitted short blocks are ranked, so they make the quiz outright.
      expect(picked.map((b) => b.blockId),
          containsAll(['short0', 'short1', 'short2']));
    });

    test('unrankable blocks fill up a thin ranked pool', () {
      final pool = [
        for (var i = 0; i < 4; i++) _block('vec$i', comps: const {0: 6.0}),
        for (var i = 0; i < 8; i++) _block('plain$i'),
      ];
      final picked = selectGlobalQuizBlocks(
        pool: pool,
        studentElo: _student(const {0: 6.0}),
        random: Random(5),
      );
      expect(picked, hasLength(globalQuizLength));
      expect(picked.map((b) => b.blockId).toSet(), hasLength(globalQuizLength),
          reason: 'fill-up must not repeat a block');
    });
  });

  group('representedDomains', () {
    test('reports exactly the domains the pool touches', () {
      final pool = [
        _block('n', comps: const {0: 6.0}),
        _block('a', comps: const {29: 6.0}),
        _block('plain'),
      ];
      expect(representedDomains(pool), {'N', 'A'});
    });

    test('relation below 2 does not count as touching', () {
      final block = _block('weak', comps: const {0: 6.0});
      // Rebuild with relation 1 on the same dimension.
      final json = Map<String, dynamic>.from(_template!);
      json['block_id'] = 'weak1';
      json['gpf'] = {
        'relation_vector':
            List<double>.generate(kGpfDimensions, (i) => i == 0 ? 1.0 : 0.0),
        'elo_vector':
            List<double?>.generate(kGpfDimensions, (i) => i == 0 ? 6.0 : null),
      };
      final weak = ContentBlock.fromJson(json);
      expect(blockTouchesDomain(block, GpfStructure.domains.first), isTrue);
      expect(blockTouchesDomain(weak, GpfStructure.domains.first), isFalse);
    });

    test('relevance is the engine\'s relation == 2 test (BR-Y2XNB9)', () {
      ContentBlock withDim0(String id, double relation, double? elo) {
        final json = Map<String, dynamic>.from(_template!);
        json['block_id'] = id;
        json['gpf'] = {
          'relation_vector': List<double>.generate(
              kGpfDimensions, (i) => i == 0 ? relation : 0.0),
          'elo_vector': List<double?>.generate(
              kGpfDimensions, (i) => i == 0 ? elo : null),
        };
        return ContentBlock.fromJson(json);
      }

      final numbers = GpfStructure.domains.first;
      _block('warm-up'); // loads the template
      // The old `r > 1 && e > 0` test dropped a 0.0 task rating, which the
      // engine treats as a valid difficulty…
      expect(blockTouchesDomain(withDim0('zero', 2.0, 0.0), numbers), isTrue);
      // …and accepted relations the engine rejects outright.
      expect(blockTouchesDomain(withDim0('r3', 3.0, 6.0), numbers), isFalse);
      expect(blockTouchesDomain(withDim0('r15', 1.5, 6.0), numbers), isFalse);
      // A relation-2 dimension with no task ELO is not active either.
      expect(blockTouchesDomain(withDim0('noElo', 2.0, null), numbers), isFalse);
    });
  });
}
