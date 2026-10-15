import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/lesson_detail/atomic_cards.dart';
import 'package:eduai/widgets/markdown_latex_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-NE3HEF — the solution shown after a multiple-choice question was the last
// content field still hardcoded to a plain Text, so a citation in it rendered
// as a literal ">". The open-answer card already routed the same field through
// the markdown widget.
// ─────────────────────────────────────────────────────────────────────────────

ContentBlock _block(String solution) => ContentBlock(
      blockId: 'B1',
      type: BlockType.question,
      atomicQuestion: AtomicQuestion(
        type: 'multiple_choice',
        solution: solution,
        options: const [
          EvaluationOption(id: 'a', text: 'Ano', isCorrect: true),
          EvaluationOption(id: 'b', text: 'Ne'),
        ],
      ),
    );

Future<void> _pump(WidgetTester tester, String solution) async {
  final block = _block(solution);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LessonAtomicQuestionCard(
              block: block,
              question: block.atomicQuestion,
              isAnswered: true,
              evaluate: true,
              openInput: null,
              actionRow: const SizedBox.shrink(),
              onOptionSelected: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a citation in the solution renders as markdown', (tester) async {
    await _pump(tester, '> Jmenovatel se nezměnil.');

    // findsWidgets, not findsOneWidget: a quote body is re-rendered through a
    // nested MarkdownLatexWidget so its white text reaches bold and maths too
    // (BR-PV5B35).
    expect(find.byType(MarkdownLatexWidget), findsWidgets);
    expect(find.textContaining('Jmenovatel se nezměnil.', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('>', findRichText: true), findsNothing);
  });

  testWidgets('a plain solution stays a plain Text', (tester) async {
    await _pump(tester, 'Protože obsah je součin stran.');

    expect(find.byType(MarkdownLatexWidget), findsNothing);
    expect(find.text('Protože obsah je součin stran.'), findsOneWidget);
  });
}
