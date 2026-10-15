import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/block_step_engine.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

// Regression tests for BR-FR3M93: fixing an answer in the middle used to be
// impossible. The engine rebuilds the renderer on every keystroke, the renderer
// built a fresh TextEditingController inside build() with the selection pinned
// to the end of the text, and TextField adopted it — so one typed character
// threw the caret to the end of the field.

ContentBlock _openBlock({bool formative = false}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_OPEN_CARET',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'question': {
          'type': 'open',
          'question': 'Doplň přísloví',
          'correct_answer': 'jablko nepadá daleko od stromu',
          // Local grading keeps the test off the network; the field itself is
          // the same widget either way.
          'ai_evaluation': formative,
          'show_answers': true,
        },
      },
    ],
  });
}

ContentBlock _numericBlock() {
  return ContentBlock.fromJson({
    'block_id': 'TEST_NUMERIC_CARET',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'question': {
          'type': 'numeric',
          'question': 'Kolik je 100 + 23?',
          'correct_number': 123,
          'show_answers': true,
        },
      },
    ],
  });
}

Widget _lessonHarness(ContentBlock block) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockStepEngine(
            block: block,
            onBlockCompleted: (
                    {int earnedXp = 0,
                    double scoreKoef = 1.0,
                    String? mark}) {},
          ),
        ),
      ),
    );

/// Deliver an edit the way the platform does: the whole new string plus where
/// the caret ended up. `enterText` always appends and parks the caret at the
/// end, which is precisely the behaviour under test.
Future<void> typeAt(
  WidgetTester tester, {
  required String text,
  required int caret,
}) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    ),
  );
  await tester.pumpAndSettle();
}

/// The active question is the last field on screen — answered steps stay above
/// it as read-only history cards.
TextEditingController _fieldController(WidgetTester tester,
    {bool active = false}) {
  final fields = find.byType(TextField);
  final field =
      tester.widget<TextField>(active ? fields.last : fields.first);
  final controller = field.controller;
  expect(controller, isNotNull, reason: 'the answer field owns a controller');
  return controller!;
}

/// Host that re-renders a step on demand — stands in for BlockStepEngine when
/// the point is a change coming from outside the field.
class _RendererHarness extends StatefulWidget {
  const _RendererHarness({required this.step});
  final BlockStep step;

  @override
  State<_RendererHarness> createState() => _RendererHarnessState();
}

class _RendererHarnessState extends State<_RendererHarness> {
  late BlockStep _step = widget.step;
  StepAnswerState _answer = const StepAnswerState(textAnswer: '');

  void setAnswer(String text) =>
      setState(() => _answer = StepAnswerState(textAnswer: text));

  /// Move to another question, the way the engine does when the block advances.
  void setStep(BlockStep step) => setState(() {
        _step = step;
        _answer = const StepAnswerState(textAnswer: '');
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StepContentRenderer(
            step: _step,
            answerState: _answer,
            onTextAnswerChanged: (text) => setAnswer(text),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('editing an open answer in the middle keeps the caret there',
      (tester) async {
    await tester.pumpWidget(_lessonHarness(_openBlock()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'jablko nepaní');
    await tester.pumpAndSettle();

    // Fix the typo: insert "d" after "nepa", caret lands right after it.
    await typeAt(tester, text: 'jablko nepadní', caret: 12);

    final controller = _fieldController(tester);
    expect(controller.text, 'jablko nepadní');
    expect(
      controller.selection.baseOffset,
      12,
      reason: 'the caret must stay where the student is typing, not jump to '
          'the end of the answer (BR-FR3M93)',
    );
  });

  testWidgets('a formative (AI-evaluated) answer keeps the caret too',
      (tester) async {
    await tester.pumpWidget(_lessonHarness(_openBlock(formative: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Protoze plati zakon');
    await tester.pumpAndSettle();

    await typeAt(tester, text: 'Protoze platí zakon', caret: 13);

    final controller = _fieldController(tester);
    expect(controller.text, 'Protoze platí zakon');
    expect(controller.selection.baseOffset, 13);
  });

  testWidgets('editing a numeric answer in the middle keeps the caret there',
      (tester) async {
    await tester.pumpWidget(_lessonHarness(_numericBlock()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '13');
    await tester.pumpAndSettle();

    // Insert the missing middle digit: 13 → 123.
    await typeAt(tester, text: '123', caret: 2);

    final controller = _fieldController(tester);
    expect(controller.text, '123');
    expect(controller.selection.baseOffset, 2);
  });

  testWidgets('a change made outside the field still reaches it',
      (tester) async {
    final step = _openBlock().steps.first;
    await tester.pumpWidget(_RendererHarness(step: step));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nejaka odpoved');
    await tester.pumpAndSettle();
    expect(_fieldController(tester).text, 'nejaka odpoved');

    // What "try again" does: the host drops the answer, and the field has to
    // follow — owning the controller must not mean ignoring the host.
    final host = tester.state<_RendererHarnessState>(
      find.byType(_RendererHarness),
    );
    host.setAnswer('');
    await tester.pumpAndSettle();

    final controller = _fieldController(tester);
    expect(controller.text, '');
    expect(controller.selection.baseOffset, 0);
  });

  testWidgets('each step gets its own field state', (tester) async {
    final block = ContentBlock.fromJson({
      'block_id': 'TEST_TWO_OPEN',
      'type': 'question',
      'steps': [
        {
          'id': 's1',
          'type': 'question',
          'order': 1,
          'question': {
            'type': 'open',
            'question': 'Prvni otazka',
            'correct_answer': 'ano',
            'ai_evaluation': false,
            'show_answers': false,
          },
        },
        {
          'id': 's2',
          'type': 'question',
          'order': 2,
          'question': {
            'type': 'open',
            'question': 'Druha otazka',
            'correct_answer': 'ne',
            'ai_evaluation': false,
            'show_answers': false,
          },
        },
      ],
    });

    await tester.pumpWidget(_RendererHarness(step: block.steps.first));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ano');
    await tester.pumpAndSettle();
    expect(_fieldController(tester).text, 'ano');

    tester
        .state<_RendererHarnessState>(find.byType(_RendererHarness))
        .setStep(block.steps[1]);
    await tester.pumpAndSettle();

    // The next question starts blank: field state is keyed per step, so a
    // controller cannot carry the previous answer over.
    expect(_fieldController(tester).text, '');
  });
}
