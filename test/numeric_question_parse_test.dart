// Numeric question grading (BR-KUCTS8).
//
// A V2 `question` step with `type: numeric` is graded in the step engine as
// `(answer - correctNumber).abs() <= tolerance`. Both operands come from the
// question JSON, so if parsing drops them the guard `correctNumber != null`
// never passes and every answer — including the right one — scores as wrong.
// These tests pin the two fields to the parse path that actually runs.
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';

Map<String, dynamic> _numericStep({
  num? correctNumber,
  num? tolerance,
}) =>
    {
      'id': 'S1',
      'type': 'question',
      'text': 'Kolik je 6 * 7?',
      'question': {
        'type': 'numeric',
        if (correctNumber != null) 'correct_number': correctNumber,
        if (tolerance != null) 'tolerance': tolerance,
      },
    };

/// Mirrors the comparison in `_applyAnswer` (block_step_engine.dart) so a
/// parsed config can be graded without standing up the widget.
bool _grade(EvaluationConfig config, String typed) {
  final answer = double.tryParse(typed.trim().replaceAll(',', '.'));
  if (answer == null || config.correctNumber == null) return false;
  return (answer - config.correctNumber!).abs() <= config.tolerance;
}

void main() {
  group('numeric question parsing', () {
    test('carries correct_number and tolerance onto the config', () {
      final step = BlockStep.fromJson(_numericStep(correctNumber: 42, tolerance: 0.5));
      final config = step.evaluationConfig!;

      expect(config.type, 'numeric');
      expect(config.correctNumber, 42);
      expect(config.tolerance, 0.5);
    });

    test('defaults tolerance to 0 when the author omits it', () {
      final step = BlockStep.fromJson(_numericStep(correctNumber: 42));

      expect(step.evaluationConfig!.correctNumber, 42);
      expect(step.evaluationConfig!.tolerance, 0);
    });

    test('leaves correctNumber null when correct_number is missing', () {
      final step = BlockStep.fromJson(_numericStep());

      expect(step.evaluationConfig!.correctNumber, isNull);
    });
  });

  group('numeric question grading', () {
    test('accepts the exact answer', () {
      final config = BlockStep.fromJson(_numericStep(correctNumber: 42)).evaluationConfig!;

      expect(_grade(config, '42'), isTrue);
      expect(_grade(config, ' 42 '), isTrue);
      expect(_grade(config, '43'), isFalse);
    });

    test('accepts answers inside the tolerance window', () {
      final config =
          BlockStep.fromJson(_numericStep(correctNumber: 42, tolerance: 0.5)).evaluationConfig!;

      expect(_grade(config, '41.5'), isTrue);
      expect(_grade(config, '42.5'), isTrue);
      expect(_grade(config, '42.6'), isFalse);
    });

    test('accepts a Czech decimal comma', () {
      final config =
          BlockStep.fromJson(_numericStep(correctNumber: 2.5, tolerance: 0.1)).evaluationConfig!;

      expect(_grade(config, '2,5'), isTrue);
      expect(_grade(config, '2,45'), isTrue);
      expect(_grade(config, '2,9'), isFalse);
    });

    test('scores as wrong when the author left out correct_number', () {
      final config = BlockStep.fromJson(_numericStep()).evaluationConfig!;

      expect(_grade(config, '42'), isFalse);
    });
  });
}
