import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/widgets/block_action_buttons.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// What a student sees of a card, step by step. Three things the engine got wrong:
//
//  * the "?" was decided by the owner from `block.hasHint`, read once when it built
//    the engine. `currentHint` reads `steps[currentStepIndex]`, and nothing moved
//    that index, so every step of a card offered the first step's hint;
//  * a question or exercise card drew all of its steps from the start. A question
//    below the current one looked answerable and ignored every tap;
//  * a step a `go_to` skipped was drawn as history, because the history was
//    "every step before the current one".

Map<String, dynamic> _text(String id, String content, {String? hint}) =>
    {'id': id, 'type': 'text', 'content': content, if (hint != null) 'hint': hint};

Map<String, dynamic> _choice(String id, String prompt, List<String> options, {String? hint}) => {
      'id': id,
      'type': 'question',
      'content': prompt,
      if (hint != null) 'hint': hint,
      'question': {
        'type': 'multiple_choice',
        'options': [
          for (var i = 0; i < options.length; i++)
            {'id': '${id}_o$i', 'text': options[i], 'is_correct': i == 0},
        ],
      },
    };

ContentBlock _block(String type, List<Map<String, dynamic>> steps, {String? hint}) =>
    ContentBlock.fromJson({
      'block_id': 'B1',
      'type': type,
      if (hint != null) 'hint': hint,
      'steps': [
        for (var i = 0; i < steps.length; i++) {...steps[i], 'order': i + 1},
      ],
    });

Future<void> _pump(
  WidgetTester tester,
  ContentBlock block, {
  List<String>? hints,
  List<List<int>>? shown,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BlockStepEngine(
          block: block,
          onBlockCompleted: ({int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {},
          onHintRequested: () => hints?.add(block.currentHint ?? ''),
          onStepShown: (_, onScreen) => shown?.add(onScreen),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byType(BlockMainButton).last);
  await tester.pumpAndSettle();
}

Finder get _questionMark => find.byIcon(Icons.help_outline);

void main() {
  group('the hint is the step on screen', () {
    testWidgets('a later step\'s own hint is offered on that step', (tester) async {
      final hints = <String>[];
      final block = _block('display', [
        _text('s1', 'Úvod'),
        _text('s2', 'Druhý krok', hint: 'Nápověda ke druhému'),
      ]);
      await _pump(tester, block, hints: hints);
      expect(_questionMark, findsNothing, reason: 'step 1 has no hint, nor has the card');

      await _next(tester);
      expect(block.currentStepIndex, 1, reason: 'the engine keeps the block on its step');
      expect(_questionMark, findsOneWidget, reason: 'on the current step, not on the history');
      await tester.tap(_questionMark);
      expect(hints, ['Nápověda ke druhému']);
    });

    testWidgets('a step without its own falls back to the card\'s', (tester) async {
      final hints = <String>[];
      final block = _block('display', [
        _text('s1', 'Úvod', hint: 'Vlastní'),
        _text('s2', 'Druhý krok', hint: ''),
      ], hint: 'Ke kartě');
      await _pump(tester, block, hints: hints);
      await tester.tap(_questionMark);
      await _next(tester);
      await tester.tap(_questionMark);
      expect(hints, ['Vlastní', 'Ke kartě'], reason: 'an empty step hint does not hide the card\'s');
    });

    testWidgets('a question card offers the hint of the question being answered', (tester) async {
      final hints = <String>[];
      final block = _block('question', [
        _text('s1', 'Zadání'),
        _choice('q1', 'První otázka', ['A1', 'B1'], hint: 'K první'),
        _choice('q2', 'Druhá otázka', ['A2', 'B2'], hint: 'Ke druhé'),
      ]);
      await _pump(tester, block, hints: hints);
      await tester.tap(_questionMark);
      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();
      await _next(tester); // check
      await _next(tester); // continue
      await tester.tap(_questionMark);
      expect(hints, ['K první', 'Ke druhé']);
    });
  });

  group('a question card reveals its questions as they come', () {
    testWidgets('only the question to answer, with the text before it', (tester) async {
      final shown = <List<int>>[];
      final block = _block('exercise', [
        _text('s1', 'Zadání'),
        _choice('q1', 'První otázka', ['A1', 'B1']),
        _text('s3', 'Mezitext'),
        _choice('q2', 'Druhá otázka', ['A2', 'B2']),
      ]);
      await _pump(tester, block, shown: shown);
      expect(find.text('Zadání'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('Mezitext'), findsNothing);
      expect(find.text('A2'), findsNothing, reason: 'a question below is not drawn before its turn');
      expect(shown.last, [0, 1]);

      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();
      await _next(tester);
      await _next(tester);
      expect(find.text('A1'), findsOneWidget, reason: 'the answered question stays above');
      expect(find.text('Mezitext'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      expect(shown.last, [0, 1, 2, 3]);
    });

    testWidgets('an unanswered number field says to type, not to pick', (tester) async {
      await _pump(tester, _block('question', [
        {
          'id': 'q1',
          'type': 'question',
          'content': 'Kolik je 2 + 2?',
          'question': {'type': 'numeric', 'correct_number': 4},
        },
      ]));
      await tester.tap(find.byType(BlockMainButton));
      await tester.pump();
      expect(find.text('Nejprve napiš odpověď'), findsOneWidget);
    });
  });

  testWidgets('a step a go_to skipped is not drawn as history', (tester) async {
    final shown = <List<int>>[];
    await _pump(
      tester,
      _block('display', [
        {..._text('s1', 'Začátek'), 'go_to': 's3'},
        _text('s2', 'Přeskočený'),
        _text('s3', 'Cíl'),
      ]),
      shown: shown,
    );
    await _next(tester);
    expect(find.text('Cíl'), findsOneWidget);
    expect(find.text('Přeskočený'), findsNothing);
    expect(shown.last, [0, 2]);

    await _next(tester);
    expect(find.text('Přeskočený'), findsNothing, reason: 'nor once the card is finished');
  });
}
