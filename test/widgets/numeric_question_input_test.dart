// BR-WAEZE3 — a `type: numeric` question accepted letters on web, because
// `keyboardType` is only a soft-keyboard hint and a physical keyboard bypasses
// it. The typed text then failed `double.tryParse` and was silently graded
// wrong. These tests pin the filter to the field that actually renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

void main() {
  const numericStep = BlockStep(
    stepId: 's1',
    type: StepType.question,
    evaluationConfig: EvaluationConfig(
      type: 'numeric',
      question: 'Jakou četnost má v datech hodnota a?',
      correctNumber: 4,
    ),
  );

  const openStep = BlockStep(
    stepId: 's1',
    type: StepType.question,
    evaluationConfig: EvaluationConfig(
      type: 'open',
      question: 'Jak se jmenuje tento pojem?',
      correctAnswer: 'medián',
    ),
  );

  Future<String?> enter(WidgetTester tester, BlockStep step, String text) async {
    String? reported;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StepContentRenderer(
            step: step,
            onTextAnswerChanged: (value) => reported = value,
          ),
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    return reported;
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('numeric question drops letters', (tester) async {
    await enter(tester, numericStep, 'ggggg');

    expect(fieldText(tester), '');
  });

  testWidgets('numeric question keeps a decimal comma', (tester) async {
    final reported = await enter(tester, numericStep, '12,5');

    expect(fieldText(tester), '12,5');
    expect(reported, '12,5');
  });

  testWidgets('numeric question keeps a negative answer', (tester) async {
    await enter(tester, numericStep, '-3');

    expect(fieldText(tester), '-3');
  });

  testWidgets('numeric question strips letters out of a mixed answer',
      (tester) async {
    final reported = await enter(tester, numericStep, '4 kusy');

    expect(fieldText(tester), '4');
    expect(reported, '4');
  });

  testWidgets('open question still accepts text', (tester) async {
    final reported = await enter(tester, openStep, 'medián');

    expect(reported, 'medián');
  });
}
