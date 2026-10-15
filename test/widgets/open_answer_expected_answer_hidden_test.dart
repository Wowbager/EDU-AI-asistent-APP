import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/core/practice/practice_feedback.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/pages/lesson_detail/atomic_cards.dart';
import 'package:eduai/pages/quiz_page.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// Regression tests for BR-RBUR29.
//
// An exact-match open question (`ai_evaluation` off) printed its expected
// answer under a wrong attempt — "Správná odpověď: 1/4 nebo slovy jedna
// čtvrtina nebo čtvrtka". The editor promises authors that field is never
// shown to the student, and the report asks for a plain right/wrong status in
// its place. The authored explanation (`solution`) is still how the lesson
// teaches the answer.
//
// The author meant each of those as an accepted answer. The editor now asks
// for them one per line, and the comparison accepts any line.
//
// BR-N26ACB: every open answer goes to the AI first, and the comparison is
// the fallback when the AI cannot be reached — which is what these tests run
// on. The expected answer is never shown, practice included.

const _expected = '1/4 nebo slovy jedna čtvrtina nebo čtvrtka';
const _solution = 'Zůstal 1 ze 4 dílků, tedy 1/4.';

/// The same answers written the way the editor now asks for: one per line.
const _variants = '1/4\nčtvrtina\njedna čtvrtina\nčtvrtka';

Map<String, dynamic> _question({String expected = _expected}) => {
      'type': 'open',
      'correct_answer': expected,
      'solution': _solution,
      'ai_evaluation': false,
      'show_answers': true,
      'show_solution': true,
    };

ContentBlock _v2Block({String expected = _expected}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_EXPECTED_HIDDEN',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': {'text': 'Zapiš to zlomkem:'},
        'question': _question(expected: expected),
      },
    ],
  });
}

ContentBlock _atomicBlock({String expected = _expected}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_EXPECTED_HIDDEN_ATOMIC',
    'type': 'question',
    'content': 'Zapiš to zlomkem:',
    'question': _question(expected: expected),
  });
}

/// The AI out of reach — every answer here falls back to comparison.
class _NoEvaluator implements AiAnswerEvaluator {
  int calls = 0;

  @override
  Future<AiEvaluationOutcome> evaluate({
    required String question,
    String studentAnswer = '',
    String? photoName,
    String? help,
    String? solution,
    String? correctAnswer,
    String? criteria,
    List<QuestionCriterion> criteriaList = const [],
    String? language,
  }) async {
    calls++;
    return const AiEvaluationOutcome.failed(AiEvaluationFailure.offline);
  }

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      null;
}

/// True when any Text on screen carries the expected answer, in whatever
/// sentence it has been wrapped.
bool _expectedAnswerOnScreen(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .any((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').contains(_expected));
}

/// A lesson by default; practice runs the engine the way QuizPage does.
Widget _engineHarness(
  ContentBlock block,
  _NoEvaluator evaluator, {
  bool practice = false,
}) {
  return ProviderScope(
    overrides: [aiAnswerEvaluatorProvider.overrideWithValue(evaluator)],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockStepEngine(
            block: block,
            exportMode: practice ? ExportMode.quizV2 : ExportMode.courseV2,
            showAnswerStatus: practice,
            onBlockCompleted: ({
              int earnedXp = 0,
              double scoreKoef = 1.0,
              String? mark,
              DateTime? tsBubbleOpen,
              DateTime? tsAnswerClick,
              DateTime? tsAnswerSubmit,
              int attemptCount = 0,
            }) {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _answerInEngine(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.engineCheck));
  await tester.pumpAndSettle();
}

Widget _atomicHarness({
  required AtomicQuestion question,
  required String answer,
  required bool isCorrect,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LessonAtomicOpenQuestionInput(
          controller: TextEditingController(text: answer),
          question: question,
          userAnswer: answer,
          isAnswered: true,
          isCorrect: isCorrect,
          showEvaluation: true,
          onChanged: () {},
          onCheckAnswer: () {},
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lesson step (V2 engine)', () {
    testWidgets('a wrong answer shows a status, not the expected answer',
        (tester) async {
      final evaluator = _NoEvaluator();
      await tester.pumpWidget(_engineHarness(_v2Block(), evaluator));
      await tester.pumpAndSettle();

      // The reported answer: right in substance, wrong to a string comparison.
      await _answerInEngine(tester, 'čtvrtina');

      expect(evaluator.calls, 1, reason: 'the AI is always asked first');
      expect(_expectedAnswerOnScreen(tester), isFalse);
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      // The author's explanation is still what teaches the answer.
      expect(find.text(_solution), findsOneWidget);
    });

    testWidgets('a matching answer says so in words', (tester) async {
      final evaluator = _NoEvaluator();
      await tester.pumpWidget(_engineHarness(_v2Block(), evaluator));
      await tester.pumpAndSettle();

      await _answerInEngine(tester, _expected);

      expect(find.text(AppStrings.lessonCorrect), findsOneWidget);
      expect(find.text(AppStrings.lessonIncorrect), findsNothing);
    });

    testWidgets('any variant on its own line is accepted', (tester) async {
      final evaluator = _NoEvaluator();
      await tester.pumpWidget(
          _engineHarness(_v2Block(expected: _variants), evaluator));
      await tester.pumpAndSettle();

      await _answerInEngine(tester, 'čtvrtina');

      expect(evaluator.calls, 1);
      expect(find.text(AppStrings.lessonCorrect), findsOneWidget);
      expect(find.text(AppStrings.lessonIncorrect), findsNothing);
    });
  });

  group('practice, offline', () {
    testWidgets('reveals no variant, only the status and the solution',
        (tester) async {
      final evaluator = _NoEvaluator();
      await tester.pumpWidget(_engineHarness(
        withPracticeFeedback(_v2Block(expected: _variants)),
        evaluator,
        practice: true,
      ));
      await tester.pumpAndSettle();

      await _answerInEngine(tester, 'půlka');

      // BR-9ZA9TT printed "Správná odpověď: 1/4" here; BR-N26ACB: never. (The
      // solution itself says 1/4, so the variants after it are what to look
      // for.)
      expect(evaluator.calls, 1);
      expect(find.textContaining('Správná odpověď'), findsNothing);
      expect(find.textContaining('čtvrtina'), findsNothing);
      expect(find.textContaining('čtvrtka'), findsNothing);
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
    });

    testWidgets('a variant still counts as right', (tester) async {
      final evaluator = _NoEvaluator();
      await tester.pumpWidget(_engineHarness(
        withPracticeFeedback(_v2Block(expected: _variants)),
        evaluator,
        practice: true,
      ));
      await tester.pumpAndSettle();

      await _answerInEngine(tester, 'čtvrtka');

      expect(find.text(AppStrings.lessonCorrect), findsOneWidget);
    });
  });

  group('lesson atomic card', () {
    testWidgets('a wrong answer shows a status, not the expected answer',
        (tester) async {
      final question = _atomicBlock().atomicQuestion!;
      expect(question.showSolution, isTrue);

      await tester.pumpWidget(_atomicHarness(
        question: question,
        answer: 'čtvrtina',
        isCorrect: false,
      ));
      await tester.pumpAndSettle();

      expect(_expectedAnswerOnScreen(tester), isFalse);
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
    });
  });

  group('course quiz', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    testWidgets('a wrong answer does not reveal the expected answer',
        (tester) async {
      final evaluator = _NoEvaluator();
      await tester.pumpWidget(_quizHarness(_atomicBlock(), evaluator, db));
      await tester.pumpAndSettle();

      await _answerInQuiz(tester, 'čtvrtina');

      expect(evaluator.calls, 1, reason: 'the AI is always asked first');
      expect(_expectedAnswerOnScreen(tester), isFalse);
      // The verdict is still there: red field and a cancel icon.
      expect(_fieldIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('any variant on its own line is accepted', (tester) async {
      final evaluator = _NoEvaluator();
      await tester.pumpWidget(
          _quizHarness(_atomicBlock(expected: _variants), evaluator, db));
      await tester.pumpAndSettle();

      await _answerInQuiz(tester, 'čtvrtina');

      expect(evaluator.calls, 1);
      expect(_fieldIcon(Icons.check_circle), findsOneWidget);
      expect(_fieldIcon(Icons.cancel), findsNothing);
    });
  });
}

Widget _quizHarness(ContentBlock block, _NoEvaluator evaluator, AppDatabase db) {
  return ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider.overrideWithValue(evaluator),
      appDatabaseProvider.overrideWithValue(db),
      workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
    ],
    child: MaterialApp(
      home: QuizPage(
        questionBlocks: [block],
        courseTitle: 'Zlomky',
        courseId: 'course-1',
        evaluate: true,
      ),
    ),
  );
}

Future<void> _answerInQuiz(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.quizCheck));
  await tester.pumpAndSettle();
}

/// The verdict icon inside the quiz's answer field.
Finder _fieldIcon(IconData icon) => find.descendant(
      of: find.byType(TextField).first,
      matching: find.byIcon(icon),
    );
