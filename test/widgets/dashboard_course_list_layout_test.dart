// BR-NS3UBD: the dashboard's "Moje kurzy" section used the wide-grid tile on
// phones. At one column the tile stretched to the full width but kept the
// grid's fixed 320px height, so a gap opened above a hairline progress bar.
//
// The phone path now stacks [KurzyCourseCard] in a plain Column inside the
// dashboard's vertical scroll view — no fixed height, so the card is as tall
// as its content. This pins that shape: full width, self-sized, no overflow.
//
//   flutter test test/widgets/dashboard_course_list_layout_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/widgets/kurzy_course_card.dart';

Widget _card(String title) => KurzyCourseCard(
      iconWidget: const Text('📖'),
      title: title,
      description: 'Popis kurzu',
      lessonCount: 7,
      durationHours: 3,
      currentProgress: 3,
      totalProgress: 20,
      status: CourseStatus.inProgress,
      onTap: () {},
    );

void main() {
  testWidgets('phone course list fills the width and sizes to its content',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _card('Co umí EDU AI asistent'),
                    const SizedBox(height: 12),
                    _card('Výrazy'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);

    final cards = find.byType(KurzyCourseCard);
    expect(cards, findsNWidgets(2));

    // 390 minus the section's 16px gutters.
    expect(tester.getSize(cards.first).width, 358);

    // The grid tile was locked to 320; a self-sized card is well under that,
    // which is exactly the empty space the report complained about.
    expect(tester.getSize(cards.first).height, lessThan(320));
  });
}
