import 'package:eduai/core/util/markdown_table_column_width.dart';
import 'package:eduai/widgets/markdown_latex_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// BR-9AHW8R: wide markdown tables must scroll sideways, not reflow into the
/// viewport. flutter_markdown only adds the horizontal scroll view when
/// `tableColumnWidth is IntrinsicColumnWidth || is FixedColumnWidth`, so these
/// tests guard both the wiring and the column-width cap that keeps a
/// prose-heavy cell from stretching the table without limit.

const double _viewportWidth = 320;

const _wideTable = '''
| Rok | Předmět | Vyučující | Hodnocení | Poznámka | Kredity |
| --- | --- | --- | --- | --- | --- |
| 2024 | Matematika | Novotná | Výborně | Postup do dalšího ročníku | 12 |
| 2025 | Fyzika | Dvořák | Velmi dobře | Doporučeno opakování | 8 |
''';

Widget _host(String markdown) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: _viewportWidth,
            child: SingleChildScrollView(
              child: MarkdownLatexWidget(content: markdown),
            ),
          ),
        ),
      ),
    );

Finder _horizontalScrollOf(Finder descendant) => find.ancestor(
      of: descendant,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
    );

void main() {
  testWidgets('wide table is wrapped in a horizontal scroll view',
      (tester) async {
    await tester.pumpWidget(_host(_wideTable));
    await tester.pumpAndSettle();

    expect(find.byType(Table), findsOneWidget);
    expect(_horizontalScrollOf(find.byType(Table)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide table keeps its natural width instead of reflowing',
      (tester) async {
    await tester.pumpWidget(_host(_wideTable));
    await tester.pumpAndSettle();

    // The whole point of the fix: the table overflows the viewport (and is
    // therefore scrollable) rather than being squeezed to fit it.
    expect(tester.getSize(find.byType(Table)).width,
        greaterThan(_viewportWidth));
  });

  testWidgets('table uses the capped intrinsic column width', (tester) async {
    await tester.pumpWidget(_host(_wideTable));
    await tester.pumpAndSettle();

    final table = tester.widget<Table>(find.byType(Table));
    expect(table.defaultColumnWidth, isA<CappedIntrinsicColumnWidth>());
    // Guards the flutter_markdown type check that enables the scroll view.
    expect(table.defaultColumnWidth, isA<IntrinsicColumnWidth>());
  });

  testWidgets('a prose-heavy cell is capped rather than stretched forever',
      (tester) async {
    const prose = 'Toto je velmi dlouhá věta v jedné buňce tabulky, která by '
        'bez omezení šířky sloupce roztáhla celou tabulku na několik tisíc '
        'pixelů a ostatní sloupce by zmizely mimo obrazovku.';

    await tester.pumpWidget(_host('''
| Pojem | Vysvětlení |
| --- | --- |
| Kapacita | $prose |
'''));
    await tester.pumpAndSettle();

    final width = tester.getSize(find.byType(Table)).width;
    // Still wider than the viewport, i.e. still scrolling rather than reflowing.
    expect(width, greaterThan(_viewportWidth));
    // But two capped columns plus cell padding and borders — nowhere near the
    // several thousand pixels an uncapped intrinsic width would produce.
    expect(width, lessThan(2 * kMaxMarkdownTableColumnWidth + 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow table does not overflow or need scrolling',
      (tester) async {
    await tester.pumpWidget(_host('''
| A | B |
| --- | --- |
| 1 | 2 |
'''));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Table)).width,
        lessThanOrEqualTo(_viewportWidth));
    expect(tester.takeException(), isNull);
  });
}
