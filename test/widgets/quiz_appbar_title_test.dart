import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/gamification/global_quiz.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/quiz_page.dart';

// Regression test for BR-KEMJ4V: the global quiz showed "Cvičení" in the
// AppBar. It launches with isExercise: true on purpose — that flag keeps ELO
// updates and the completion dialog off the GLOBAL_QUIZ sentinel course — but
// the heading must not follow the behaviour flag.

ContentBlock _block() => ContentBlock.fromJson({
      'block_id': 'TEST_TITLE',
      'type': 'question',
      'content': 'Kolik je 2 + 2?',
      'question': {
        'type': 'multiple_choice',
        'options': [
          {'id': 'a', 'text': '3', 'is_correct': false},
          {'id': 'b', 'text': '4', 'is_correct': true},
        ],
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpQuiz(WidgetTester tester, QuizPage page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // QuizPage only calls setLocation/clearLocation on it, which never
          // touch the database — but the provider still has to resolve.
          workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
        ],
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder appBarTitle(String text) => find.descendant(
        of: find.byType(AppBar),
        matching: find.text(text),
      );

  testWidgets('global quiz is headed "Kvíz", not "Cvičení"', (tester) async {
    await pumpQuiz(
      tester,
      QuizPage(
        questionBlocks: [_block()],
        courseTitle: AppStrings.globalQuizTitle,
        courseId: globalQuizCourseId,
        evaluate: true,
        isExercise: true,
        appBarTitle: AppStrings.quizTitle,
      ),
    );

    expect(appBarTitle(AppStrings.quizTitle), findsOneWidget);
    expect(appBarTitle(AppStrings.quizExerciseTitle), findsNothing);
  });

  testWidgets('a real exercise keeps the "Cvičení" heading', (tester) async {
    await pumpQuiz(
      tester,
      QuizPage(
        questionBlocks: [_block()],
        courseTitle: 'Kurz',
        courseId: 'course-1',
        evaluate: true,
        isExercise: true,
      ),
    );

    expect(appBarTitle(AppStrings.quizExerciseTitle), findsOneWidget);
  });
}
