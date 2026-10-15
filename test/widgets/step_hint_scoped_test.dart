import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/block_step_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// BR-JHDNB3: a step that carries its own hint/help must show that, not the
// block's shared one. Hint/help used to resolve through the block's own
// `currentStepIndex`, which BlockStepEngine never writes back — it stays frozen
// at 0 — so every step answered with the first step's hint, or fell through to
// the block's shared text when the first step had none.

/// A display block shaped like the reported one: a plain first step, a second
/// step with its own hint (and optionally its own help), and shared block-level
/// hint/help underneath.
ContentBlock _displayBlock({
  String? blockHint = 'Společná nápověda bloku.',
  String? blockHelp = 'Společné vysvětlení bloku.',
  String? stepHint = 'Nápověda ke kroku s videem.',
  String? stepHelp,
}) {
  return ContentBlock.fromJson({
    'block_id': 'FA9KIMC96Y',
    'type': 'display',
    if (blockHint != null) 'hint': blockHint,
    if (blockHelp != null) 'help': blockHelp,
    'steps': [
      {'id': 's1', 'type': 'text', 'order': 1, 'content': 'Úvod do tématu'},
      {
        'id': 's2',
        'type': 'text',
        'order': 2,
        'content': 'Podívej se na video',
        if (stepHint != null) 'hint': stepHint,
        if (stepHelp != null) 'help': stepHelp,
      },
    ],
  });
}

Widget _wrap(
  ContentBlock block, {
  required void Function(String? stepId) onHintRequested,
  int currentStepIndex = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BlockStepEngine(
          block: block,
          savedProgress: StepProgressData(
            blockId: block.blockId,
            currentStepIndex: currentStepIndex,
          ),
          onHintRequested: onHintRequested,
          onBlockCompleted: (
              {int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {},
        ),
      ),
    ),
  );
}

void main() {
  group('step-scoped hint/help resolution', () {
    test("a step's own hint wins over the block's shared one", () {
      final block = _displayBlock();

      expect(block.hintForStep('s2'), 'Nápověda ke kroku s videem.');
      // The step without its own hint still gets the block's.
      expect(block.hintForStep('s1'), 'Společná nápověda bloku.');

      // The cursor-based accessor is what the mentor sheet used to read. The
      // block's cursor never leaves 0 while the engine owns the live index, so
      // it answers with the shared hint whichever step is on screen — that is
      // the reported bug, and the reason resolution now takes a step id.
      expect(block.currentStepIndex, 0);
      expect(block.currentHint, 'Společná nápověda bloku.');
    });

    test('hint and help fall back to the block independently', () {
      final block = _displayBlock(stepHelp: null);

      // Own hint, but no own help — help comes from the block.
      expect(block.hintForStep('s2'), 'Nápověda ke kroku s videem.');
      expect(block.helpForStep('s2'), 'Společné vysvětlení bloku.');

      final bothOwn = _displayBlock(stepHelp: 'Vysvětlení ke kroku s videem.');
      expect(bothOwn.helpForStep('s2'), 'Vysvětlení ke kroku s videem.');
    });

    test('a step hint is offered even when the block has none', () {
      final block = _displayBlock(blockHint: null, blockHelp: null);

      expect(block.hasHintForStep('s2'), isTrue);
      expect(block.hasHintForStep('s1'), isFalse);
    });

    test('an unknown step id and an atomic block fall back to the block', () {
      final block = _displayBlock();
      expect(block.hintForStep('s99'), 'Společná nápověda bloku.');
      expect(block.hintForStep(null), 'Společná nápověda bloku.');

      final atomic = ContentBlock.fromJson({
        'block_id': 'ATOMIC',
        'type': 'display',
        'content': 'Text',
        'hint': 'Atomická nápověda.',
      });
      expect(atomic.hintForStep(null), 'Atomická nápověda.');
    });
  });

  group('BlockStepEngine hint button', () {
    testWidgets('reports the step it was tapped on, not the block cursor',
        (tester) async {
      String? reported;
      var calls = 0;
      final block = _displayBlock();

      await tester.pumpWidget(_wrap(
        block,
        currentStepIndex: 1,
        onHintRequested: (stepId) {
          reported = stepId;
          calls++;
        },
      ));
      await tester.pumpAndSettle();

      // The finished first step stays on screen as history, so both cards carry
      // a "?": s1 offers the block's shared hint, s2 its own. The active card
      // is the last one.
      final hintButtons = find.byIcon(Icons.help_outline);
      expect(hintButtons, findsNWidgets(2));

      await tester.tap(hintButtons.last);
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(reported, 's2');
      expect(block.hintForStep(reported), 'Nápověda ke kroku s videem.');
    });

    testWidgets('shows a "?" on a step whose hint is its own only',
        (tester) async {
      String? reported;
      // No shared hint anywhere — only s2 has one. The old block-level flag was
      // read off step 0 and hid the button on every card.
      final block = _displayBlock(blockHint: null, blockHelp: null);

      await tester.pumpWidget(_wrap(
        block,
        currentStepIndex: 1,
        onHintRequested: (stepId) => reported = stepId,
      ));
      await tester.pumpAndSettle();

      // Only s2's card offers it; s1 has nothing to show.
      final hintButtons = find.byIcon(Icons.help_outline);
      expect(hintButtons, findsOneWidget);

      await tester.tap(hintButtons);
      await tester.pumpAndSettle();

      expect(reported, 's2');
    });

    testWidgets('offers no "?" when neither the step nor the block has a hint',
        (tester) async {
      final block = _displayBlock(
        blockHint: null,
        blockHelp: null,
        stepHint: null,
      );

      await tester.pumpWidget(_wrap(
        block,
        currentStepIndex: 1,
        onHintRequested: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsNothing);
    });
  });
}
