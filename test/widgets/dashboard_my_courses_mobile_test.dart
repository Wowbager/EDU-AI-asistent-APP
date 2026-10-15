// BR-WYA3RQ — on a phone the dashboard drew every started course twice: once
// in the "Pokračovat" carousel and once again in the "Moje kurzy" list
// directly below it.
//
// "Moje kurzy" is now phone-hidden, but only while the carousel has something
// to show. It filters on hasStarted, so hiding the list unconditionally would
// hand a just-enrolled student the empty dashboard of BR-H42B3V — the case the
// second test pins.
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
import 'package:eduai/core/sync/sync_status.dart';
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

UserCourse _course({required bool started}) {
  final now = DateTime(2026, 1, 1);
  return UserCourse(
    id: 'uc',
    userId: 'user',
    courseId: 'course',
    status: started ? UserCourseStatus.inProgress : UserCourseStatus.downloaded,
    progressPercent: started ? 20 : 0,
    completedLessons: started ? 1 : 0,
    totalLessons: 2,
    currentLessonIndex: 0,
    timeSpentSeconds: 0,
    progressData: const {},
    downloadedVersion: 1,
    syncStatus: SyncStatus.synced,
    createdAt: now,
    updatedAt: now,
    courseName: 'Funkce a grafy ZŠ',
    courseData: const {
      'title': 'Funkce a grafy ZŠ',
      'description': 'Procvičíme si práci se souřadnicemi.',
      'emoji': '📖',
    },
  );
}

Future<List<Override>> _overrides(List<UserCourse> courses) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // The dashboard reads the course table directly (the JPZ banner asks whether
  // that course has arrived), so it needs a database.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDatabaseProvider.overrideWithValue(db),
    activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
    userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
    userCoursesStreamProvider.overrideWith((ref) => Stream.value(courses)),
    dueCardsCountProvider.overrideWith((ref) async => 0),
    practiceFilterProvider
        .overrideWith((ref) => PracticeFilterNotifier(PracticeFilterStore(
              prefs,
            ))),
  ];
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  double width,
  List<UserCourse> courses,
) async {
  _ignoreOverflow();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: await _overrides(courses),
      child: const MaterialApp(
        home: Scaffold(
          body: PrehledPage(quizProgressCache: <String, QuizProgress>{}),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _myCourses = find.text(AppStrings.sectionMyCourses);
final _continue = find.text(AppStrings.sectionContinue);

void main() {
  testWidgets('a phone showing "Pokračovat" drops the duplicate "Moje kurzy"',
      (tester) async {
    await _pumpDashboard(tester, 390, [_course(started: true)]);

    expect(_continue, findsOneWidget);
    expect(_myCourses, findsNothing);
  });

  testWidgets('a phone with nothing started still gets "Moje kurzy"',
      (tester) async {
    await _pumpDashboard(tester, 390, [_course(started: false)]);

    expect(_continue, findsNothing);
    expect(_myCourses, findsOneWidget);
  });

  testWidgets('wider layouts keep both sections', (tester) async {
    await _pumpDashboard(tester, 900, [_course(started: true)]);

    expect(_myCourses, findsOneWidget);
  });
}
