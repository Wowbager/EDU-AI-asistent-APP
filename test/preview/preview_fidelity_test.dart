import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/preview/preview_expanded_block.dart';
import 'package:eduai/preview/preview_lesson_player.dart';
import 'package:eduai/preview/preview_mode.dart';
import 'package:eduai/preview/preview_ref.dart';
import 'package:eduai/widgets/block_action_buttons.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

// The preview is the editor's claim about what a student will see. Two ways it
// broke that claim, and a third it never kept:
//
//  * focusing a step in the editor widened the card's border, so the focused
//    step was laid out narrower and its text wrapped at a different word;
//  * every click target carried a transparent 1.5 px border for its hover
//    outline, so all wrapped text was 3 px narrower than in the app;
//  * "Vyzkoušet" never said where the pupil was when the run moved to another
//    card, went back or restarted, so the editor could not follow it.
//
// A canvas cannot be asserted from the browser suite, so it is asserted here.

const _long =
    'Dnes se naučíme, co je to fotosyntéza. Je to proces, při kterém rostliny '
    'přeměňují sluneční světlo na energii, kterou pak využívají k růstu.';

ContentBlock _card({String? firstHint, String? laterHint, String? blockHint}) =>
    ContentBlock.fromJson({
      'block_id': 'B1',
      'type': 'display',
      if (blockHint != null) 'hint': blockHint,
      'steps': [
        {'id': 's1', 'type': 'text', 'order': 1, 'content': _long, if (firstHint != null) 'hint': firstHint},
        {'id': 's2', 'type': 'text', 'order': 2, 'content': '$_long $_long', if (laterHint != null) 'hint': laterHint},
        {'id': 's3', 'type': 'text', 'order': 3, 'content': 'Krátký závěr.'},
      ],
    });

ContentBlock _display(String id, List<String> steps) => ContentBlock.fromJson({
      'block_id': id,
      'type': 'display',
      'steps': [
        for (var i = 0; i < steps.length; i++)
          {'id': 's${i + 1}', 'type': 'text', 'order': i + 1, 'content': steps[i]},
      ],
    });

Widget _sized(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 360, child: SingleChildScrollView(child: child)),
        ),
      ),
    );

/// Every paragraph on screen: its text, its size, and where its lines break — the
/// offset of the last character of each line, which moves when a word wraps.
List<String> _paragraphs(WidgetTester tester) {
  return tester.renderObjectList<RenderParagraph>(find.byType(RichText)).map((p) {
    final text = p.text.toPlainText();
    final breaks = <int>[];
    double? lastY;
    for (var i = 0; i < text.length; i++) {
      final y = p.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
      if (lastY != null && y > lastY) breaks.add(i);
      lastY = y;
    }
    return '$text|${p.size.width.toStringAsFixed(1)}x${p.size.height.toStringAsFixed(1)}|$breaks';
  }).toList();
}

void main() {
  testWidgets('focusing a step never changes how anything in the card is laid out', (tester) async {
    Future<List<String>> layoutWith(String? highlighted) async {
      await tester.pumpWidget(_sized(PreviewExpandedBlock(
        block: _card(),
        onRefTapped: (_) {},
        highlightedStepId: highlighted,
      )));
      await tester.pumpAndSettle();
      return _paragraphs(tester);
    }

    final baseline = await layoutWith(null);
    expect(baseline, isNotEmpty);
    for (final step in ['s1', 's2', 's3']) {
      expect(await layoutWith(step), baseline, reason: 'with $step focused');
    }
  });

  testWidgets('a click target lays its content out exactly as the app does', (tester) async {
    final step = _card().steps.first;
    Future<List<String>> layout({required bool preview}) async {
      final renderer = StepContentRenderer(step: step);
      await tester.pumpWidget(_sized(preview
          ? PreviewScope(
              mode: PreviewMode(enabled: true, interactive: false, blockId: 'B1', onRefTapped: (_) {}),
              child: renderer,
            )
          : renderer));
      await tester.pumpAndSettle();
      return _paragraphs(tester);
    }

    final app = await layout(preview: false);
    expect(await layout(preview: true), app);
  });

  testWidgets('the question mark is the first step\'s, on every step, as in the app', (tester) async {
    final refs = <PreviewRef>[];
    await tester.pumpWidget(_sized(PreviewExpandedBlock(
      block: _card(firstHint: 'První nápověda'),
      onRefTapped: refs.add,
    )));
    await tester.pumpAndSettle();
    // The app shows the "?" under every step of the card, and it opens step 1's hint.
    expect(find.byIcon(Icons.help_outline), findsNWidgets(3));
    await tester.ensureVisible(find.byIcon(Icons.help_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline).last);
    expect(refs.single.stepId, 's1');
    expect(refs.single.field, 'hint');

    // A hint written only on a later step is never offered to a student.
    await tester.pumpWidget(_sized(PreviewExpandedBlock(
      block: _card(laterHint: 'Tu žák neuvidí'),
      onRefTapped: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(find.textContaining('žák ji neuvidí'), findsOneWidget);
  });

  group('Vyzkoušet', () {
    Future<List<String>> run(
      WidgetTester tester, {
      required List<ContentBlock> blocks,
      GlobalKey<PreviewLessonPlayerState>? key,
      List<PreviewRef>? clicks,
    }) async {
      final positions = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PreviewLessonPlayer(
            key: key,
            blocks: blocks,
            lessonId: 'L1',
            onRefTapped: (ref) => clicks?.add(ref),
            onStepChanged: (blockId, stepId) => positions.add('$blockId/$stepId'),
            onCompleted: ({required int xp, required double scoreKoef, String? mark}) {},
            onNavState: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return positions;
    }

    Future<void> next(WidgetTester tester) async {
      await tester.tap(find.byType(BlockMainButton).last);
      await tester.pumpAndSettle();
    }

    testWidgets('reports where the pupil is on every move', (tester) async {
      final key = GlobalKey<PreviewLessonPlayerState>();
      final positions = await run(tester, key: key, blocks: [
        _display('B1', ['První', 'Druhý']),
        _display('B2', ['Třetí']),
      ]);
      expect(positions, ['B1/s1'], reason: 'the first card, on mount');

      await next(tester);
      expect(positions.last, 'B1/s2', reason: 'a move within the card');

      await next(tester);
      expect(positions.last, 'B2/s1', reason: 'the next card');

      key.currentState!.back();
      await tester.pumpAndSettle();
      expect(positions.last, 'B1/s2', reason: 'back');

      key.currentState!.restart();
      await tester.pumpAndSettle();
      expect(positions.last, 'B1/s1', reason: 'restart');

      // Nothing is repeated just because the tree rebuilt.
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], isNot(positions[i - 1]));
      }
    });

    testWidgets('a tap on the content is the pupil\'s, not click-to-edit', (tester) async {
      final clicks = <PreviewRef>[];
      await run(tester, blocks: [_display('B1', ['Klikni na mě'])], clicks: clicks);
      await tester.tap(find.textContaining('Klikni na mě'));
      await tester.pumpAndSettle();
      expect(clicks, isEmpty);
    });

    testWidgets('offers the hint the way the app does', (tester) async {
      await run(tester, blocks: [_card(firstHint: 'Zkus si to nakreslit')]);
      expect(find.byIcon(Icons.help_outline), findsWidgets);
      await tester.tap(find.byIcon(Icons.help_outline).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Zkus si to nakreslit'), findsOneWidget);
    });

    testWidgets('survives the current card losing steps mid-run', (tester) async {
      final key = GlobalKey<PreviewLessonPlayerState>();
      final positions = <String>[];
      Widget player(List<ContentBlock> blocks) => MaterialApp(
            home: Scaffold(
              body: PreviewLessonPlayer(
                key: key,
                blocks: blocks,
                lessonId: 'L1',
                onRefTapped: (_) {},
                onStepChanged: (b, s) => positions.add('$b/$s'),
                onCompleted: ({required int xp, required double scoreKoef, String? mark}) {},
                onNavState: (_) {},
              ),
            ),
          );
      await tester.pumpWidget(player([_display('B1', ['a', 'b', 'c'])]));
      await tester.pumpAndSettle();
      await next(tester);
      await next(tester);
      expect(positions.last, 'B1/s3');

      await tester.pumpWidget(player([_display('B1', ['a'])]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(positions.last, 'B1/s1');
    });
  });
}
