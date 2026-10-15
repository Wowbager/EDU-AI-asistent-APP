import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/widgets/markdown_latex_widget.dart';

/// BR-KYBZ7H — once blockquotes reach the markdown renderer they also need to
/// *look* like quotes, not just italic prose.
///
/// BR-PV5B35 — and that look has to be the app palette: a solid [
/// AppColors.primary] fill with white text, like a selected button. The fill
/// is why every one of these assertions is about the *nested* MarkdownBody:
/// flutter_markdown lets the `p` style override `blockquote`'s colour, so the
/// quote body is re-rendered through its own MarkdownLatexWidget instead.
void main() {
  Future<void> pumpQuote(WidgetTester tester, String markdown) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MarkdownLatexWidget(content: markdown)),
    ));
  }

  /// The MarkdownBody rendering the quote body, i.e. the inner one.
  MarkdownStyleSheet quoteStyleSheet(WidgetTester tester) {
    final bodies = tester.widgetList<MarkdownBody>(find.byType(MarkdownBody));
    expect(bodies.length, 2,
        reason: 'the quote body renders through a nested MarkdownBody');
    return bodies.last.styleSheet!;
  }

  Container quoteCard(WidgetTester tester) {
    return tester.widgetList<Container>(find.byType(Container)).firstWhere(
          (c) => (c.decoration as BoxDecoration?)?.color == AppColors.primary,
          orElse: () => throw TestFailure(
              'no quote card painted in the primary colour'),
        );
  }

  testWidgets('blockquote is a filled card in the active palette',
      (tester) async {
    await pumpQuote(tester, '> Citace v lekci.');

    final decoration = quoteCard(tester).decoration! as BoxDecoration;
    expect(decoration.color, AppColors.primary);
    expect(decoration.borderRadius, isNotNull,
        reason: 'the card matches the rounded chip/button shape');

    expect(find.textContaining('Citace v lekci.', findRichText: true),
        findsOneWidget);
  });

  testWidgets('quote text, bold and links are all white', (tester) async {
    await pumpQuote(tester, '> Citace s [odkazem](https://edu-ai.eu) a **důrazem**.');

    final styleSheet = quoteStyleSheet(tester);
    expect(styleSheet.p!.color, Colors.white,
        reason: 'plain quote text must read on the primary fill');
    expect(styleSheet.strong!.color, Colors.white,
        reason: 'bold carries its own colour and would stay dark otherwise');
    expect(styleSheet.a!.color, Colors.white,
        reason: 'the usual purple link colour is invisible on purple');
  });

  testWidgets('text outside a quote keeps the normal colours', (tester) async {
    await pumpQuote(tester, 'Běžný odstavec bez citace.');

    final styleSheet =
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet!;
    expect(styleSheet.p!.color, AppColors.primaryDark88);
    expect(styleSheet.a!.color, AppColors.quizPurple);
  });

  testWidgets('multi-line quote keeps all of its lines', (tester) async {
    await pumpQuote(tester, '> První řádek\n> Druhý řádek');

    expect(find.textContaining('První řádek', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Druhý řádek', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('>', findRichText: true), findsNothing,
        reason: 'the quote markers must be consumed, not printed');
  });

  testWidgets('the blockquote fallback style stays readable', (tester) async {
    // _AppQuoteSyntax claims every `> quote`, so flutter_markdown's own
    // blockquote path should never run — but if some other syntax ever emits
    // one, its dark text must not land on the solid primary fill.
    await pumpQuote(tester, '> Citace v lekci.');

    final styleSheet = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody).first)
        .styleSheet!;
    final fallback = styleSheet.blockquoteDecoration as BoxDecoration?;
    expect(fallback, isNotNull);
    expect(fallback!.color, isNot(AppColors.primary));
  });
}
