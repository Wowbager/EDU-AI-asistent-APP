import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

/// BR-KYBZ7H — a question whose only markdown is a blockquote used to fall
/// through to a plain Text widget, so readers saw the literal `>` character.
void main() {
  Future<void> pump(WidgetTester tester, BlockStep step) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: StepContentRenderer(step: step)),
      ),
    ));
  }

  testWidgets('question text with a blockquote renders as markdown, not raw text',
      (tester) async {
    const step = BlockStep(
      stepId: 's1',
      type: StepType.question,
      evaluationConfig: EvaluationConfig(
        type: 'single_select',
        question: 'Jakému pojmu odpovídá tato definice?\n\n'
            '> „Text napsaný v přirozených větách a odstavcích.“',
      ),
    );

    await pump(tester, step);

    expect(find.byType(MarkdownBody), findsWidgets);
    expect(
      find.textContaining('>', findRichText: true),
      findsNothing,
      reason: 'the blockquote marker must be consumed by the markdown parser',
    );
  });

  testWidgets('text step with a blockquote renders as markdown', (tester) async {
    const step = BlockStep(
      stepId: 's1',
      type: StepType.text,
      content: StepContent(text: '> Citace na začátku odstavce.'),
    );

    await pump(tester, step);

    expect(find.byType(MarkdownBody), findsWidgets);
  });

  testWidgets('prose with a greater-than sign stays a plain Text widget',
      (tester) async {
    const step = BlockStep(
      stepId: 's1',
      type: StepType.text,
      content: StepContent(text: 'Teplota > 30 °C je vysoká.'),
    );

    await pump(tester, step);

    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('Teplota > 30 °C je vysoká.'), findsOneWidget);
  });

  testWidgets('real HTML still goes to the HTML renderer', (tester) async {
    const step = BlockStep(
      stepId: 's1',
      type: StepType.text,
      content: StepContent(text: '<p>Odstavec — s pomlčkou</p>'),
    );

    await pump(tester, step);

    expect(find.byType(MarkdownBody), findsNothing);
  });
}
