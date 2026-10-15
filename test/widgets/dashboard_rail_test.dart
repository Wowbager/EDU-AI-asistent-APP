import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/widgets/continue_lesson_card.dart';
import 'package:eduai/widgets/progress_ring_card.dart';
import 'package:eduai/widgets/recent_activity_card.dart';

// Regression tests for BR-NTB3JW. The dashboard's desktop rail carried three
// cards that all read as half-finished: the ring said "3 z 0 lekcí" under a
// 0 % circle, "Pokračuj v lekci" claimed nothing had been started while the
// activity card right below it listed two touched courses, and every activity
// row was captioned "Historii aktivity teprve připravujeme — zatím vidíš
// ukázku".

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

ActivityEntry _entry(String subject) => ActivityEntry(
      icon: Icons.menu_book_rounded,
      iconColor: Colors.indigo,
      action: 'Pokračovat',
      subject: subject,
      timeLabel: 'Právě teď',
    );

void main() {
  group('ProgressRingCard', () {
    testWidgets('an unknown total never prints more done than total',
        (tester) async {
      // The dashboard sums enrolled courses; a course whose payload has not
      // been downloaded knows its finished lessons but not its total.
      await _pump(
        tester,
        const ProgressRingCard(lessonsDone: 3, lessonsTotal: 0),
      );

      expect(find.text('3 z 0 lekcí'), findsNothing);
      expect(find.text('0 z 0 lekcí'), findsOneWidget);
      // The ring already read 0 % in that state — the caption now matches it.
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('real counts are printed untouched', (tester) async {
      await _pump(
        tester,
        const ProgressRingCard(lessonsDone: 3, lessonsTotal: 4),
      );

      expect(find.text('3 z 4 lekcí'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });
  });

  group('ContinueLessonCard', () {
    testWidgets('the course variant offers the course, not "nothing started"',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ContinueLessonCard.course(
          courseTitle: '(Ne)rovnice ZŠ',
          lessonLabel: 'Všechny lekce máš hotové.',
          buttonLabel: 'Otevřít kurz',
          onContinue: () => taps++,
        ),
      );

      expect(find.text('Zatím jsi nezačal žádnou lekci.'), findsNothing);
      expect(find.text('(Ne)rovnice ZŠ'), findsOneWidget);

      await tester.tap(find.text('Otevřít kurz'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('no step bar without steps', (tester) async {
      await _pump(
        tester,
        const ContinueLessonCard.course(
          courseTitle: '(Ne)rovnice ZŠ',
          lessonLabel: 'Všechny lekce máš hotové.',
          buttonLabel: 'Otevřít kurz',
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('0 z 0 kroků'), findsNothing);
    });

    testWidgets('a lesson still shows its step bar', (tester) async {
      await _pump(
        tester,
        const ContinueLessonCard(
          courseTitle: '(Ne)rovnice ZŠ',
          lessonLabel: 'Lekce 1: Úvod',
          stepsDone: 2,
          stepsTotal: 5,
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('2 z 5 kroků'), findsOneWidget);
    });

    testWidgets('the empty variant still says nothing has been started',
        (tester) async {
      await _pump(tester, const ContinueLessonCard.empty());

      expect(find.text('Zatím jsi nezačal žádnou lekci.'), findsOneWidget);
    });
  });

  group('RecentActivityCard', () {
    testWidgets('real rows carry no "still being built" footnote',
        (tester) async {
      await _pump(tester, RecentActivityCard(entries: [_entry('Výrazy ZŠ')]));

      expect(find.text('Výrazy ZŠ'), findsOneWidget);
      expect(
        find.textContaining('připravujeme'),
        findsNothing,
        reason: 'the rows are real activity, not a preview',
      );
    });

    testWidgets('an empty list says data is still being collected',
        (tester) async {
      await _pump(tester, const RecentActivityCard(entries: []));

      expect(find.text('Zatím sbíráme data o tvé aktivitě.'), findsOneWidget);
    });
  });
}
