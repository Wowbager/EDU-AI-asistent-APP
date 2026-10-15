import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/lesson_detail/atomic_cards.dart';

/// BR-KYBZ7H — the atomic (v2) cards carried their own copy of the markdown
/// sniffing, so a blockquote-only block printed the literal `>` there too.
void main() {
  Future<void> pump(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ));
  }

  testWidgets('display card renders a blockquote as markdown', (tester) async {
    final block = ContentBlock(
      blockId: 'b1',
      type: BlockType.display,
      content: 'Definice:\n\n> „Text napsaný v přirozených větách.“',
    );

    await pump(
      tester,
      LessonAtomicDisplayCard(block: block, actionRow: const SizedBox.shrink()),
    );

    expect(find.byType(MarkdownBody), findsWidgets);
  });

  testWidgets('display card leaves a greater-than in prose alone',
      (tester) async {
    final block = ContentBlock(
      blockId: 'b1',
      type: BlockType.display,
      content: 'Teplota > 30 °C je vysoká.',
    );

    await pump(
      tester,
      LessonAtomicDisplayCard(block: block, actionRow: const SizedBox.shrink()),
    );

    expect(find.byType(MarkdownBody), findsNothing);
  });
}
