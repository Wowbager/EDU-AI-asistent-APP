// BR-USWXWV — on a portrait tablet the "Začněte s návodem" card could not be
// used: the card had a fixed 226px height and clipped its overflow, and next
// to a hard 300px illustration panel the copy column got narrow enough that
// the subtitle wrapped past that height, taking the start button with it.
//
// The panel now scales with the card and 226 is only a minimum, so the button
// stays inside the card at every width the dashboard is drawn at.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/practice_providers.dart';
import 'package:eduai/core/services/practice_filter_store.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/user_course_repository.dart';
import 'package:eduai/pages/prehled_page.dart';
import 'package:eduai/pages/quiz_page.dart' show QuizProgress;

/// The test-only Ahem font is far wider than the real one, so labels overflow
/// their rows. Cosmetic and test-only — same suppression the other dashboard
/// tests use.
void _ignoreOverflow() {
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

Future<void> _pumpDashboard(WidgetTester tester, double width) async {
  _ignoreOverflow();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // The dashboard reads the course table directly (the JPZ banner asks whether
  // that course has arrived), so it needs a database.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
        userCoursesStreamProvider
            .overrideWith((ref) => Stream.value(const <UserCourse>[])),
        dueCardsCountProvider.overrideWith((ref) async => 0),
        practiceFilterProvider
            .overrideWith((ref) => PracticeFilterNotifier(PracticeFilterStore(
                  prefs,
                ))),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: PrehledPage(quizProgressCache: <String, QuizProgress>{}),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The card clips, so anything painted outside it is gone — and a start button
/// that is gone is a guide that cannot be opened.
void _expectButtonInsideCard(WidgetTester tester) {
  final card = tester.getRect(find.byKey(guideCardKey));
  final button = tester.getRect(find.text(AppStrings.guideButton));

  expect(button.bottom, lessThanOrEqualTo(card.bottom),
      reason: 'the start button is clipped off the bottom of the guide card');
  expect(button.top, greaterThanOrEqualTo(card.top));
  expect(button.right, lessThanOrEqualTo(card.right));
  expect(button.left, greaterThanOrEqualTo(card.left));
}

void main() {
  testWidgets('portrait tablet: the start button stays inside the card',
      (tester) async {
    await _pumpDashboard(tester, 810);

    _expectButtonInsideCard(tester);
  });

  testWidgets('desktop: the start button stays inside the card',
      (tester) async {
    await _pumpDashboard(tester, 1440);

    _expectButtonInsideCard(tester);
  });

  testWidgets('the mascot never spills out of its panel', (tester) async {
    await _pumpDashboard(tester, 810);

    final card = tester.getRect(find.byKey(guideCardKey));
    // The same mascot sits on other dashboard cards, so scope the lookup.
    final mascot = tester.getRect(find.descendant(
      of: find.byKey(guideCardKey),
      matching: find.image(const AssetImage('assets/images/skins_bg.png')),
    ));

    expect(mascot.right, lessThanOrEqualTo(card.right));
    expect(mascot.width, lessThanOrEqualTo(card.width * 0.32));
  });
}
