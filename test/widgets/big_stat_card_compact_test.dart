// BR-Q7FFF3: on tablet/PC the Streak and Trofeje panels were too tall. They are
// a fixed 168px, sized around a two-line encouragement ("Skvělá práce!…",
// "Sbírej trofeje…") that stops earning its keep once the learner is past the
// newcomer rung — so past `DashboardTiers.statEncouragement` the caption goes
// and the panel shrinks with it.
//
// The heights are asserted rather than the absence of a Spacer: dropping the
// text while leaving the 168px box would have left the band of empty colour the
// client actually complained about.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/widgets/big_stat_card.dart';

void main() {
  Future<Size> pump(WidgetTester tester, Widget card,
      {double width = 600}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: card),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(BigStatCard));
  }

  group('a newcomer keeps the encouragement', () {
    testWidgets('streak', (tester) async {
      final size = await pump(tester, BigStatCard.streak(days: 1, xp: 0));

      expect(find.text(AppStrings.statStreakSubtitle), findsOneWidget);
      expect(size.height, 168);
    });

    testWidgets('trophies', (tester) async {
      final size = await pump(tester, BigStatCard.trophies(count: 0, xp: 0));

      expect(find.text(AppStrings.statTrophiesSubtitle), findsOneWidget);
      expect(size.height, 168);
    });

    testWidgets('the threshold itself belongs to the lower tier',
        (tester) async {
      final size = await pump(tester, BigStatCard.streak(days: 1, xp: 30));

      expect(find.text(AppStrings.statStreakSubtitle), findsOneWidget);
      expect(size.height, 168);
    });
  });

  group('past 30 XP the caption goes and the panel shrinks', () {
    testWidgets('streak', (tester) async {
      final size = await pump(tester, BigStatCard.streak(days: 1, xp: 31));

      expect(find.text(AppStrings.statStreakSubtitle), findsNothing);
      expect(size.height, 124);
      // The number is the point of the tile and has to survive the trim.
      expect(find.text('1'), findsOneWidget);
      expect(find.text(AppStrings.statStreak), findsOneWidget);
    });

    testWidgets('trophies', (tester) async {
      final size = await pump(tester, BigStatCard.trophies(count: 3, xp: 31));

      expect(find.text(AppStrings.statTrophiesSubtitle), findsNothing);
      expect(size.height, 124);
      expect(find.text('3'), findsOneWidget);
      expect(find.text(AppStrings.statTrophies), findsOneWidget);
    });
  });

  // The shop replaces the trophy tile above 100 XP — always in the compact
  // regime, always beside the streak tile. It cannot drop its caption (a title
  // and an icon would say nothing), so it has to shrink some other way or the
  // two halves of the row disagree on a height.
  testWidgets('the shop tile keeps its caption but matches the streak height',
      (tester) async {
    final shop = await pump(tester, BigStatCard.shop(xp: 116));
    expect(find.text(AppStrings.statShopSubtitle), findsOneWidget);

    final streak = await pump(tester, BigStatCard.streak(days: 4, xp: 116));

    expect(shop.height, streak.height);
    expect(shop.height, 124);
  });

  testWidgets('a narrow tile ellipses the shop caption rather than overflowing',
      (tester) async {
    // The panel is a fixed height, so a caption that wraps to a third line on a
    // small tablet would spill out of the coloured box.
    final size = await pump(tester, BigStatCard.shop(xp: 116), width: 260);

    expect(tester.takeException(), isNull);
    expect(size.height, 124);
  });
}
