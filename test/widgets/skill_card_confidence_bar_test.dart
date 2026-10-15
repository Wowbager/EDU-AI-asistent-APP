import 'package:eduai/widgets/skill_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for BR-PXZUB3: the cells at the edges of the confidence
/// interval were painted with the faintest shade in the palette (alpha 0.06)
/// and were effectively invisible. The old fade normalised the distance by the
/// interval width, so a narrow interval (5-7) pushed both its edges straight to
/// the bottom of the range.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required double level,
    required int low,
    required int high,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SkillCard(
            title: 'Číslo a operace',
            subtitle: 'Matematika',
            emoji: '🧮',
            level: level,
            confidenceLow: low,
            confidenceHigh: high,
          ),
        ),
      ),
    );
  }

  /// Opacity of the purple fill behind the cell labelled [n].
  double cellAlpha(WidgetTester tester, int n) {
    final cell = tester.widget<Container>(
      find
          .ancestor(of: find.text('$n'), matching: find.byType(Container))
          .first,
    );
    return ((cell.decoration! as BoxDecoration).color ?? Colors.transparent).a;
  }

  testWidgets('narrow interval keeps its edges clearly visible',
      (tester) async {
    // Level 5.8 → dot on cell 6, interval 5-7 (the reported case).
    await pumpCard(tester, level: 5.8, low: 5, high: 7);

    expect(cellAlpha(tester, 5), closeTo(0.42, 0.001));
    expect(cellAlpha(tester, 7), closeTo(0.42, 0.001));
    // Outside the interval: no fill at all.
    expect(cellAlpha(tester, 4), 0.0);
    expect(cellAlpha(tester, 8), 0.0);
  });

  testWidgets('wide interval still steps down towards its edges',
      (tester) async {
    await pumpCard(tester, level: 7.0, low: 4, high: 10);

    expect(cellAlpha(tester, 6), greaterThan(cellAlpha(tester, 5)));
    expect(cellAlpha(tester, 5), greaterThan(cellAlpha(tester, 4)));
    expect(cellAlpha(tester, 8), closeTo(cellAlpha(tester, 6), 0.001));
    // Even the outermost cells stay above the legibility floor.
    expect(cellAlpha(tester, 4), greaterThanOrEqualTo(0.18));
    expect(cellAlpha(tester, 10), greaterThanOrEqualTo(0.18));
  });

  testWidgets('single-cell interval leaves the neighbours empty',
      (tester) async {
    // Level 5.6 → dot on cell 6, interval 6-6 (second card in the report).
    await pumpCard(tester, level: 5.6, low: 6, high: 6);

    expect(cellAlpha(tester, 5), 0.0);
    expect(cellAlpha(tester, 7), 0.0);
  });
}
