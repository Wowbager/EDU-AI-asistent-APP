// BR-PHJQDK — the course page called a course finished after its author had
// added lessons the student never opened.
//
// The reporter's student finished both lessons of a two-lesson course. The
// author then published four lessons under the same course; the first two kept
// their ids. Opening the course showed DOKONČENO, "4 z 4 lekcí" and a tick on
// every lesson, because the page took the stored completed status at its word.
//
// Wide layout at the reporter's 1536px, where the screenshot was taken.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/main.dart' show routeObserver;
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/course_detail_page.dart' show CourseDetailPage;
import 'package:eduai/widgets/progress_ring_card.dart';

const _courseId = 'c-1';
const _userCourseId = 'uc-1';

Map<String, dynamic> _courseData() => {
      'course_id': 'S1_Statistika_c1',
      'name': 'Základy statistiky',
      'open_all_lessons': true,
      'blocks': [
        for (var i = 0; i < 4; i++)
          {
            'block_id': 'b-$i',
            'type': 'question',
            'question': '$i + 1?',
            'options': ['$i', '${i + 1}'],
            'correct_answer': 1,
          },
      ],
      'lessons': [
        for (var i = 0; i < 4; i++)
          {
            'lesson_id': 'L${i + 1}',
            'name': 'Lekce ${i + 1}',
            'blocks': [
              {'block_id': 'b-$i', 'order': 0},
            ],
          },
      ],
    };

/// No network: the page's update check stops before calling the API.
class _Offline implements ConnectivityService {
  @override
  Future<bool> get isOnline async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The test-only Ahem font is far wider than the real one, so labels overflow
/// their rows. Cosmetic and test-only.
void _ignoreOverflow() {
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

Future<void> _pumpCourse(
  WidgetTester tester, {
  required int completedLessons,
  required Map<String, dynamic> lessonsProgress,
}) async {
  _ignoreOverflow();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1536, 2400);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  final data = _courseData();
  await tester.runAsync(() async {
    await db.upsertCourse(CoursesTableCompanion(
      id: const Value(_courseId),
      courseId: const Value('S1_Statistika_c1'),
      name: const Value('Základy statistiky'),
      data: Value(jsonEncode(data)),
    ));
    await db.upsertUserCourse(UserCoursesTableCompanion(
      id: const Value(_userCourseId),
      userId: const Value('u-1'),
      courseId: const Value(_courseId),
      status: const Value('completed'),
      progressPercent: const Value(100),
      completedLessons: Value(completedLessons),
      progressDataJson: Value(jsonEncode({'lessons': lessonsProgress})),
    ));
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        authTokenStorageProvider
            .overrideWithValue(AuthTokenStorage(prefs: prefs)),
        connectivityServiceProvider.overrideWithValue(_Offline()),
        activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        navigatorObservers: [routeObserver],
        home: CourseDetailPage(
          course: Course.fromJsonData(id: _courseId, data: data),
          userCourseId: _userCourseId,
        ),
      ),
    ),
  );
  // The page reads progress out of the database after its first frame.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

int _lessonsDone(WidgetTester tester) =>
    tester.widget<ProgressRingCard>(find.byType(ProgressRingCard)).lessonsDone;

void main() {
  testWidgets('a finished course that gained lessons is not reported done',
      (tester) async {
    await _pumpCourse(
      tester,
      completedLessons: 2,
      lessonsProgress: {
        'L1': {'is_completed': true},
        'L2': {'is_completed': true},
      },
    );

    expect(find.text(AppStrings.courseCompleted), findsNothing,
        reason: 'lessons 3 and 4 were never opened');
    expect(_lessonsDone(tester), 2, reason: '"2 z 4 lekcí", not "4 z 4"');
    expect(find.byIcon(Icons.check), findsNWidgets(2),
        reason: 'only the two lessons the student finished are ticked');
  });

  testWidgets('a course finished in full still reads as done', (tester) async {
    await _pumpCourse(
      tester,
      completedLessons: 4,
      lessonsProgress: {
        for (var i = 1; i <= 4; i++) 'L$i': {'is_completed': true},
      },
    );

    expect(find.text(AppStrings.courseCompleted), findsWidgets);
    expect(_lessonsDone(tester), 4);
  });
}
