// Queue rule 5: skip_condition ("GPF_mastery > 0.8") evaluation.
//
// Pure Dart — runs in milliseconds:
//   flutter test test/skip_condition_evaluator_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/practice/skip_condition_evaluator.dart';
import 'package:eduai/models/block_model.dart';

ContentBlock blockWithGpf(List<double?> relation) {
  return ContentBlock.fromJson({
    'block_id': 'B1',
    'type': 'exercise',
    'gpf': {'relation_vector': relation},
  });
}

/// 35-element ELO vector, null everywhere except the given index:value pairs.
List<double?> elo(Map<int, double> values) {
  final v = List<double?>.filled(35, null);
  values.forEach((i, e) => v[i] = e);
  return v;
}

void main() {
  final block = blockWithGpf([
    // dims 0 and 2 covered
    2.0, 0.0, 1.0, ...List.filled(32, 0.0),
  ]);

  group('masteryFor', () {
    test('mean ELO over covered dimensions, normalized to 0-1', () {
      // dims 0+2 covered; ELO 9 and 7 → mean 8 → 0.8
      final m = SkipConditionEvaluator.masteryFor(
          block: block, profilElo: elo({0: 9, 2: 7, 5: 1}));
      expect(m, closeTo(0.8, 1e-9));
    });

    test('null when no ELO data for covered dimensions', () {
      expect(
          SkipConditionEvaluator.masteryFor(
              block: block, profilElo: elo({5: 10})),
          isNull);
    });

    test('null when block has no GPF vector', () {
      final noGpf = ContentBlock.fromJson({'block_id': 'B2', 'type': 'exercise'});
      expect(
          SkipConditionEvaluator.masteryFor(
              block: noGpf, profilElo: elo({0: 10})),
          isNull);
    });
  });

  group('shouldSkip', () {
    test('skips when mastery satisfies the condition', () {
      expect(
          SkipConditionEvaluator.shouldSkip(
            condition: 'GPF_mastery > 0.7',
            block: block,
            profilElo: elo({0: 9, 2: 7}), // mastery 0.8
          ),
          isTrue);
    });

    test('does not skip below the threshold', () {
      expect(
          SkipConditionEvaluator.shouldSkip(
            condition: 'GPF_mastery > 0.8',
            block: block,
            profilElo: elo({0: 5, 2: 5}), // mastery 0.5
          ),
          isFalse);
    });

    test('supports all comparison operators', () {
      final p = elo({0: 8, 2: 8}); // mastery 0.8
      expect(
          SkipConditionEvaluator.shouldSkip(
              condition: 'GPF_mastery >= 0.8', block: block, profilElo: p),
          isTrue);
      expect(
          SkipConditionEvaluator.shouldSkip(
              condition: 'GPF_mastery < 0.9', block: block, profilElo: p),
          isTrue);
      expect(
          SkipConditionEvaluator.shouldSkip(
              condition: 'GPF_mastery <= 0.5', block: block, profilElo: p),
          isFalse);
      expect(
          SkipConditionEvaluator.shouldSkip(
              condition: 'GPF_mastery != 0.8', block: block, profilElo: p),
          isFalse);
    });

    test('never skips without mastery data', () {
      expect(
          SkipConditionEvaluator.shouldSkip(
            condition: 'GPF_mastery > 0.1',
            block: block,
            profilElo: const [],
          ),
          isFalse);
    });

    test('never skips on empty or malformed expressions', () {
      final p = elo({0: 10, 2: 10});
      for (final cond in [null, '', '  ', 'always', 'mastery>0.5', 'GPF_mastery >']) {
        expect(
            SkipConditionEvaluator.shouldSkip(
                condition: cond, block: block, profilElo: p),
            isFalse,
            reason: 'condition "$cond" must not skip');
      }
    });
  });
}
