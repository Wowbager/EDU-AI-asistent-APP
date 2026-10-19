import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/preview/preview_expanded_block.dart';
import 'package:eduai/preview/preview_ref.dart';
import 'package:eduai/widgets/block_action_buttons.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// The editor's "Náhled" draws the card's own buttons, and every one of them must
// only ever report where a thing is authored. This is the cheap local mirror of the
// browser test that asserts the same contract over the message channel — that one
// needs a full Flutter web build to run, this one does not.

ContentBlock _block({
  String? stepHint,
  String? stepHelp,
  String? blockHint,
  String? blockHelp,
}) {
  return ContentBlock.fromJson({
    'block_id': 'B1',
    'type': 'question',
    if (blockHint != null) 'hint': blockHint,
    if (blockHelp != null) 'help': blockHelp,
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': 'Kolik je 3/4 z 12?',
        if (stepHint != null) 'hint': stepHint,
        if (stepHelp != null) 'help': stepHelp,
        'question': {
          'type': 'multiple_choice',
          'options': [
            {'id': 'o1', 'text': 'Devět', 'is_correct': true, 'feedback': 'Ano'},
            {'id': 'o2', 'text': 'Osm', 'is_correct': false, 'feedback': 'Skoro'},
          ],
        },
      },
    ],
  });
}

Widget _wrap(
  ContentBlock block, {
  required void Function(PreviewRef) onRefTapped,
  ExportMode exportMode = ExportMode.courseV2,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PreviewExpandedBlock(
          block: block,
          exportMode: exportMode,
          onRefTapped: onRefTapped,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the question mark appears only where there is something behind it',
      (tester) async {
    await tester.pumpWidget(_wrap(_block(), onRefTapped: (_) {}));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.help_outline), findsNothing);

    await tester.pumpWidget(
      _wrap(_block(stepHint: 'Zkus si to nakreslit'), onRefTapped: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  testWidgets('a step hint is reported as the step\'s, a card hint as the card\'s',
      (tester) async {
    final refs = <PreviewRef>[];

    await tester.pumpWidget(
      _wrap(_block(stepHint: 'Nakresli si to'), onRefTapped: refs.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline));
    expect(refs.single.stepId, 's1');
    expect(refs.single.field, 'hint');

    refs.clear();
    // A card-wide hint lives on the block. Sending a stepId with it would make the
    // editor write the card's hint onto a step that never had one.
    await tester.pumpWidget(
      _wrap(_block(blockHint: 'Platí pro celou kartu'), onRefTapped: refs.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline));
    expect(refs.single.stepId, isNull);
    expect(refs.single.blockId, 'B1');
    expect(refs.single.field, 'hint');
  });

  testWidgets('a quiz card shows the question mark and nothing else', (tester) async {
    await tester.pumpWidget(_wrap(
      _block(stepHint: 'Nakresli si to'),
      exportMode: ExportMode.quizV2,
      onRefTapped: (_) {},
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
  });

  testWidgets('every step carries the completed row', (tester) async {
    await tester.pumpWidget(_wrap(_block(), onRefTapped: (_) {}));
    await tester.pumpAndSettle();

    // The content is rendered as though answered — feedback and solution showing —
    // so the row that belongs under it is the finished one, not a greyed check.
    expect(find.byType(BlockMainButton), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('nothing in it can advance or complete anything', (tester) async {
    final refs = <PreviewRef>[];
    await tester.pumpWidget(
      _wrap(_block(stepHint: 'Nakresli si to'), onRefTapped: refs.add),
    );
    await tester.pumpAndSettle();

    // Inertness is structural: the engine is what emits stepChanged and completed,
    // and it is not in the tree. There is nothing here to turn off.
    expect(find.byType(BlockStepEngine), findsNothing);

    for (final button in find.byType(BlockActionButton).evaluate().toList()) {
      await tester.tap(find.byWidget(button.widget));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(BlockMainButton));
    await tester.pumpAndSettle();

    // Every one of them produced a ref and nothing else.
    expect(refs, isNotEmpty);
    expect(refs.every((ref) => ref.blockId == 'B1'), isTrue);
  });
}
