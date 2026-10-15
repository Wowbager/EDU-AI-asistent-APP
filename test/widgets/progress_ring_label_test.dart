import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/strings/locale_manager.dart';
import 'package:eduai/widgets/progress_ring_card.dart';

// BR-H4ZWEK — the caption under the percentage in "Tvůj postup" ran into the
// ring. "Dokončeno" is ~71 px wide in Poppins 12, and it sits below the
// centre, where the 74 px hole is narrower than its diameter: the label's
// corners landed ~41 px from the centre, inside the 9 px stroke. The client
// asked for "Hotovo" instead; the label is now also boxed into the hole, so a
// translation that is still too long shrinks rather than overlapping.

/// Stroke width of the ring, as painted by `_RingPainter`.
const _ringStroke = 9.0;

Future<void> _pump(WidgetTester tester, {int done = 0, int total = 2}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: ProgressRingCard(lessonsDone: done, lessonsTotal: total),
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => LocaleManager.notifier.value = AppLocale.cs);

  testWidgets('the Czech caption reads "Hotovo"', (tester) async {
    await _pump(tester);

    expect(find.text('Hotovo'), findsOneWidget);
    expect(find.text('Dokončeno'), findsNothing);
  });

  for (final locale in AppLocale.values) {
    for (final (done, total) in [(0, 2), (2, 2)]) {
      testWidgets(
          '${locale.code}: caption and percentage stay inside the ring '
          '($done/$total)', (tester) async {
        LocaleManager.notifier.value = locale;
        await _pump(tester, done: done, total: total);

        final percent = find.text('${(done / total * 100).round()}%');
        final ring = tester.getRect(find
            .ancestor(of: percent, matching: find.byType(CustomPaint))
            .first);
        final hole = ring.width / 2 - _ringStroke;

        // The test font draws every glyph a full em wide, so these labels are
        // wider here than in Poppins — the worst case for the hole.
        for (final label in [
          tester.getRect(percent),
          tester.getRect(find.text(AppStrings.progressCardCompleted)),
        ]) {
          final farthest = [
            label.topLeft,
            label.topRight,
            label.bottomLeft,
            label.bottomRight,
          ].map((p) => (p - ring.center).distance).reduce(math.max);

          expect(farthest, lessThanOrEqualTo(hole),
              reason: '$label reaches past the ring hole (r = $hole)');
        }
      });
    }
  }
}
