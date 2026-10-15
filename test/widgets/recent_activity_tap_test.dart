import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/widgets/recent_activity_card.dart';

// Regression tests for BR-9NDW6D. The dashboard's "Nedávná aktivita" rows read
// "Pokračovat · <název kurzu>" but carried no tap handler at all, so clicking
// one on the web did nothing — no navigation, no error, nothing in the console.

Future<void> _pump(WidgetTester tester, List<ActivityEntry> entries) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecentActivityCard(entries: entries),
        ),
      ),
    ),
  );
}

ActivityEntry _entry(String subject, {VoidCallback? onTap}) => ActivityEntry(
      icon: Icons.menu_book_rounded,
      iconColor: Colors.indigo,
      action: 'Pokračovat',
      subject: subject,
      timeLabel: 'Právě teď',
      onTap: onTap,
    );

void main() {
  testWidgets('a row with onTap fires it when tapped', (tester) async {
    var taps = 0;
    await _pump(tester, [_entry('Funkce a grafy ZŠ', onTap: () => taps++)]);

    await tester.tap(find.text('Funkce a grafy ZŠ'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('the whole row is the target, not just the text', (tester) async {
    var taps = 0;
    await _pump(tester, [_entry('Funkce a grafy ZŠ', onTap: () => taps++)]);

    // The gap between the title and the timestamp used to be dead space; the
    // opaque hit-test behaviour makes it part of the target.
    final row = find.byType(RecentActivityCard);
    final box = tester.getRect(row);
    await tester.tapAt(Offset(box.right - 24, box.center.dy));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('each row fires its own handler', (tester) async {
    final tapped = <String>[];
    await _pump(tester, [
      _entry('První kurz', onTap: () => tapped.add('první')),
      _entry('Druhý kurz', onTap: () => tapped.add('druhý')),
    ]);

    await tester.tap(find.text('Druhý kurz'));
    await tester.pump();

    expect(tapped, ['druhý']);
  });

  testWidgets('a row without onTap stays inert and does not throw',
      (tester) async {
    await _pump(tester, [_entry('Kurz bez obsahu')]);

    await tester.tap(find.text('Kurz bez obsahu'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
