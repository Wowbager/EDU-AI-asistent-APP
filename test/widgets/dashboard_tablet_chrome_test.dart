// BR-H98WYB — on a portrait tablet the shell already draws the sidebar rail
// (logo, Doplňky, the profile), but the dashboard kept rendering its own
// header on top of it: a second logo, the XP pill and the same two actions.
// The header only checked `isDesktop`, and the rail sits in the width class
// below that.
//
// The header is phone-only now, and because the rail was the one place that
// showed no XP number, the account block at its foot carries it.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/practice_providers.dart';
import 'package:eduai/core/services/practice_filter_store.dart';
import 'package:eduai/data/repositories/user_course_repository.dart';
import 'package:eduai/pages/prehled_page.dart';
import 'package:eduai/pages/quiz_page.dart' show QuizProgress;
import 'package:eduai/widgets/adaptive_shell.dart';
import 'package:eduai/widgets/themed_svg.dart';
import 'package:eduai/widgets/welcome_card.dart';

/// The test-only Ahem font is far wider than the real one, so labels overflow
/// their rows. Cosmetic and test-only — same suppression the other shell tests
/// use.
void _ignoreOverflow() {
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

/// The personalisation face only ever appears in the dashboard header, so it
/// stands in for the whole header row.
final _headerActions = find.byWidgetPredicate(
  (w) => w is ThemedSvg && w.asset == 'assets/icons/personalisation.svg',
);

/// A signed-out student has no stats row, so the XP reads zero everywhere.
final _xp = find.text('0 XP');

Future<List<Override>> _overrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // The dashboard reads the course table directly (the JPZ banner asks whether
  // that course has arrived), so it needs a database — the real one opens a
  // file and leaves a timer pending in the test.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDatabaseProvider.overrideWithValue(db),
    activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
    userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
    userCoursesStreamProvider
        .overrideWith((ref) => Stream.value(const <UserCourse>[])),
    dueCardsCountProvider.overrideWith((ref) async => 0),
    // Skipping the real provider keeps the account lookup it watches out of
    // the test; the stored scope is "everything" either way.
    practiceFilterProvider
        .overrideWith((ref) => PracticeFilterNotifier(PracticeFilterStore(
              prefs,
            ))),
  ];
}

Future<void> _pumpDashboard(WidgetTester tester, double width) async {
  _ignoreOverflow();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: await _overrides(),
      child: const MaterialApp(
        home: Scaffold(
          body: PrehledPage(quizProgressCache: <String, QuizProgress>{}),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpShell(WidgetTester tester, double width) async {
  _ignoreOverflow();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: await _overrides(),
      child: MaterialApp(
        home: AdaptiveShell(
          selectedIndex: 0,
          onItemTapped: (_) {},
          title: 'Přehled',
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the phone keeps its inline header', (tester) async {
    await _pumpDashboard(tester, 390);

    expect(_headerActions, findsOneWidget);
    expect(_xp, findsOneWidget);
  });

  testWidgets('the tablet drops it — the rail carries the same things',
      (tester) async {
    await _pumpDashboard(tester, 700);

    expect(_headerActions, findsNothing);
    expect(_xp, findsNothing);
  });

  testWidgets('the greeting is content, so it survives the tablet',
      (tester) async {
    await _pumpDashboard(tester, 700);

    expect(find.byType(WelcomeCard), findsOneWidget);
  });

  testWidgets('the rail shows the XP the header used to', (tester) async {
    await _pumpShell(tester, 700);

    expect(_xp, findsOneWidget);
  });
}
