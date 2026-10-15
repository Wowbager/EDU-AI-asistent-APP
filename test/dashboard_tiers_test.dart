// BR-ERUJBY: the dashboard reshapes itself as XP grows. The thresholds are the
// contract with the product spec, so they get pinned here — a widget test would
// only tell us that *something* rendered, not that 116 XP lands on the right
// rung of every ladder.
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/gamification/dashboard_tiers.dart';
import 'package:eduai/core/strings/app_strings.dart';

void main() {
  group('thresholds are exclusive', () {
    test('practice replaces the guide above 30 XP', () {
      expect(DashboardTiers.showsPractice(30), isFalse);
      expect(DashboardTiers.showsPractice(31), isTrue);
    });

    test('the stat panels drop their encouragement above 30 XP', () {
      // BR-Q7FFF3. Shares a value with practiceInsteadOfGuide, not a meaning.
      expect(DashboardTiers.showsStatEncouragement(30), isTrue);
      expect(DashboardTiers.showsStatEncouragement(31), isFalse);
    });

    test('the Knihovna banner names the reward above 70 XP', () {
      expect(DashboardTiers.showsPromoReward(70), isFalse);
      expect(DashboardTiers.showsPromoReward(71), isTrue);
    });

    test('the shop replaces trophies above 100 XP', () {
      expect(DashboardTiers.showsShop(100), isFalse);
      expect(DashboardTiers.showsShop(101), isTrue);
    });

    test('the entrance-exam banner points at Cermatík above 100 XP', () {
      expect(DashboardTiers.showsCermatik(100), isFalse);
      expect(DashboardTiers.showsCermatik(101), isTrue);
    });
  });

  group('greeting ladder', () {
    test('each tier says something different', () {
      final welcome = DashboardTiers.greetingSubtitle(0);
      final keepGoing = DashboardTiers.greetingSubtitle(51);
      final proud = DashboardTiers.greetingSubtitle(101);
      final cheering = DashboardTiers.greetingSubtitle(201);

      expect({welcome, keepGoing, proud, cheering}, hasLength(4));
      expect(welcome, AppStrings.dashGreetingWelcome);
      expect(keepGoing, AppStrings.dashGreetingKeepGoing);
      expect(proud, AppStrings.dashGreetingProud);
      expect(cheering, AppStrings.dashGreetingCheering);
    });

    test('boundaries belong to the lower tier', () {
      expect(DashboardTiers.greetingSubtitle(50), AppStrings.dashGreetingWelcome);
      expect(
          DashboardTiers.greetingSubtitle(100), AppStrings.dashGreetingKeepGoing);
      expect(DashboardTiers.greetingSubtitle(200), AppStrings.dashGreetingProud);
    });
  });

  test('the reported account (116 XP) gets the grown-up dashboard', () {
    // The bug: 116 XP still saw the "Jak používat" intro challenge, the trophy
    // tile and the newcomer greeting.
    const xp = 116;
    expect(DashboardTiers.showsPractice(xp), isTrue);
    expect(DashboardTiers.showsPromoReward(xp), isTrue);
    expect(DashboardTiers.showsShop(xp), isTrue);
    expect(DashboardTiers.showsCermatik(xp), isTrue);
    expect(DashboardTiers.showsStatEncouragement(xp), isFalse);
    expect(DashboardTiers.greetingSubtitle(xp), AppStrings.dashGreetingProud);
  });

  test('a brand-new account still gets the onboarding dashboard', () {
    const xp = 0;
    expect(DashboardTiers.showsPractice(xp), isFalse);
    expect(DashboardTiers.showsPromoReward(xp), isFalse);
    expect(DashboardTiers.showsShop(xp), isFalse);
    expect(DashboardTiers.showsCermatik(xp), isFalse);
    expect(DashboardTiers.showsStatEncouragement(xp), isTrue);
  });
}
