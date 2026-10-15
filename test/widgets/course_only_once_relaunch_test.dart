// BR-Y4WMCU — a test course ("Only Quiz" + "Only Once", PIN 676767) could be
// taken again after the student had finished it. The code-entry path refuses a
// finished only-once course, but the course page itself still offered "Začít
// kvíz": the quiz action was picked before the completed state was looked at.
// Any other way back to the page — the published course in Knihovna, in the
// stage logs — relaunched the quiz from card 1 and recorded a second attempt.
//
// The course page now treats a finished only-once course as closed, whichever
// door the student came through.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/main.dart' show routeObserver;
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/course_detail_page.dart' show CourseDetailPage;

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

Course _course({
  required bool completed,
  bool onlyOnce = true,
  bool onlyQuiz = true,
}) =>
    Course.fromJsonData(
      id: 'GPF-vstupni-test-v3_c1',
      completedLessons: completed ? 1 : 0,
      isCompleted: completed,
      data: {
        'name': 'Matematika ZŠ',
        'only_once': onlyOnce,
        'only_quiz': onlyQuiz,
        // The admin forces "Starts with Quiz" on together with "Only Quiz".
        'starts_with_quiz': onlyQuiz,
        'blocks': [
          {
            'block_id': 'b-1',
            'type': 'exercise',
            'steps': [
              {
                'id': 's-1',
                'type': 'question',
                'text': 'Jak daleko od sebe leží na číselné ose čísla -6 a -123?',
                'question': {
                  'type': 'multiple_choice',
                  'options': [
                    {'id': 'a', 'text': '-129', 'is_correct': false},
                    {'id': 'b', 'text': '129', 'is_correct': false},
                    {'id': 'c', 'text': '117', 'is_correct': true},
                    {'id': 'd', 'text': '-117', 'is_correct': false},
                  ],
                },
              },
            ],
          },
        ],
        'lessons': [
          {
            'lesson_id': 'l-1',
            'name': 'Vstupní test',
            'blocks': [
              {'block_id': 'b-1', 'order': 0},
            ],
          },
        ],
      },
    );

Future<void> _pumpCourse(
  WidgetTester tester,
  Course course, {
  double width = 400,
}) async {
  _ignoreOverflow();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 1400);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        navigatorObservers: [routeObserver],
        home: CourseDetailPage(course: course),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final startQuiz = find.text(AppStrings.courseStartQuiz);
  final quizButton = find.text(AppStrings.courseQuiz);
  final alreadyCompleted = find.text(AppStrings.libraryCourseAlreadyCompleted);

  group('finished only-once course', () {
    testWidgets('offers no way back into the quiz on a phone', (tester) async {
      await _pumpCourse(tester, _course(completed: true));

      expect(startQuiz, findsNothing,
          reason: 'the test was taken — "Začít kvíz" would run it again');
      expect(alreadyCompleted, findsOneWidget,
          reason: 'the student is told why there is nothing to start');
    });

    testWidgets('offers no way back into the quiz on a desktop',
        (tester) async {
      await _pumpCourse(tester, _course(completed: true), width: 1440);

      expect(startQuiz, findsNothing);
      expect(alreadyCompleted, findsOneWidget);
    });

    testWidgets('with lessons hides the secondary quiz button too',
        (tester) async {
      // Without "Only Quiz" a finished course gets the completed action row,
      // whose "Kvíz" button reaches the same quiz.
      await _pumpCourse(tester, _course(completed: true, onlyQuiz: false));

      expect(quizButton, findsNothing);
      expect(startQuiz, findsNothing);
      expect(alreadyCompleted, findsOneWidget);
    });
  });

  group('unaffected courses', () {
    testWidgets('an unfinished only-once quiz can still be started',
        (tester) async {
      await _pumpCourse(tester, _course(completed: false));

      expect(startQuiz, findsOneWidget);
      expect(alreadyCompleted, findsNothing);
    });

    testWidgets('a finished ordinary quiz course can be retaken',
        (tester) async {
      await _pumpCourse(tester, _course(completed: true, onlyOnce: false));

      expect(startQuiz, findsOneWidget);
      expect(alreadyCompleted, findsNothing);
    });
  });
}
