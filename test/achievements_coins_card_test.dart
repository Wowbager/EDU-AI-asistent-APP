// The "Mince EDUX" card on the Achievements screen (BR-HK9828).
//
// The client asked for the coin total beside the rest of the stats, laid out as
// Level + Streak over Trophies + Mince EDUX. These pin that the number is shown
// and that the grid survives the narrowest phone the app supports — the cards
// went from full width to half, which is where overflow would show up.
//
//   flutter test test/achievements_coins_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/pages/achievements_page.dart';

Widget _wrap(Widget child, {Size size = const Size(360, 780)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('the coin total is shown on its own card', (tester) async {
    await tester.pumpWidget(_wrap(const AchievementsPage(
      level: 3,
      currentXp: 250,
      streakDays: 4,
      trophiesCount: 6,
      coinsEarned: 128,
    )));
    await tester.pump();

    expect(find.text(AppStrings.achievementsCoins), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('a student with no coins yet sees zero, not an empty card',
      (tester) async {
    await tester.pumpWidget(_wrap(const AchievementsPage(trophiesCount: 2)));
    await tester.pump();

    expect(find.text(AppStrings.achievementsCoins), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('all four stat cards are on screen', (tester) async {
    await tester.pumpWidget(_wrap(const AchievementsPage(
      level: 1,
      currentXp: 274,
      xpForNextLevel: 500,
      streakDays: 2,
      trophiesCount: 6,
      coinsEarned: 40,
    )));
    await tester.pump();

    expect(find.text(AppStrings.achievementsLvl(1)), findsOneWidget);
    expect(find.text(AppStrings.profileStatStreak), findsOneWidget);
    expect(find.text(AppStrings.achievementsTrophies), findsOneWidget);
    expect(find.text(AppStrings.achievementsCoins), findsOneWidget);
  });

  testWidgets('the half-width cards do not overflow a narrow phone',
      (tester) async {
    // 320dp is the narrowest the app is expected to render on, and the longest
    // string in the grid — the XP fraction at four digits — lives in the Lvl
    // card that just lost half its width.
    await tester.pumpWidget(_wrap(
      const AchievementsPage(
        level: 9,
        currentXp: 4750,
        xpForNextLevel: 5000,
        streakDays: 365,
        trophiesCount: 12,
        coinsEarned: 9999,
      ),
      size: const Size(320, 700),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
