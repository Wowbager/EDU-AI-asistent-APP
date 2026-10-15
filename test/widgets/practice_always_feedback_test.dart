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
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/pages/quiz_page.dart';
import 'package:eduai/widgets/block_step_engine.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';

// Regression tests for BR-9ZA9TT.
//
// An exercise with `show_solution` off said nothing at all when it came back in
// practice: the answer went red, no verdict text, no model answer, "Pokračovat".
// Practice always feeds back now: the block comes in with its solution on.
//
// BR-N26ACB made the rest general. Every open answer is graded by AI — in the
// lesson too — with a comparison standing in offline, and a question with
// `ai_evaluation` off shows right/wrong and the solution: never the AI's
// words, never the expected answer.

const _solution = 'Četnost je počet výskytů hodnoty, součet je jejich úhrn.';
const _correctAnswer = 'Četnost je počet výskytů, součet je úhrn hodnot.';
const _feedbackText = 'Zatím nevidím, čeho by se odpověď týkala.';

ContentBlock _v2Block({required bool showSolution}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_PRACTICE_FEEDBACK',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': {'text': 'Jaký je rozdíl mezi četností a součtem?'},
        'question': {
          'type': 'open',
          'correct_answer': _correctAnswer,
          'solution': _solution,
          // The author graded this one by comparison, not by AI — the case the
          // report is about.
          'ai_evaluation': false,
          'show_answers': true,
          'show_solution': showSolution,
        },
      },
    ],
  });
}

ContentBlock _atomicBlock({required bool showSolution}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_PRACTICE_FEEDBACK_ATOMIC',
    'type': 'question',
    'content': 'Jaký je rozdíl mezi četností a součtem?',
    'question': {
      'type': 'open',
      'correct_answer': _correctAnswer,
      'solution': _solution,
      'show_solution': showSolution,
    },
  });
}

/// Stands in for the API: either grades, or reports the connection is gone.
class _FakeEvaluator implements AiAnswerEvaluator {
  _FakeEvaluator({this.offline = false});

  final bool offline;
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
    if (offline) {
      return const AiEvaluationOutcome.failed(AiEvaluationFailure.offline);
    }
    return const AiEvaluationOutcome.success(AiEvaluationResult(
      score: 0.2,
      isCorrect: false,
      feedbackText: _feedbackText,
      feedback: FormativeFeedback(
        strengths: _feedbackText,
        improvements: 'Odpověď neobsahuje vysvětlení pojmů četnost a součet.',
        nextStep: 'Zkus vlastními slovy popsat, co znamená slovo četnost.',
      ),
    ));
  }

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      null;
}

/// The practice path: QuizPage runs the engine in quizV2 with evaluation on.
/// The block arrives already normalised, exactly as [playablePracticeProvider]
/// hands it over.
Widget _harness(
  ContentBlock block, {
  required _FakeEvaluator evaluator,
  required bool practice,
  required VoidCallback onCompleted,
}) {
  return ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider.overrideWithValue(evaluator),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockStepEngine(
            block: practice ? withPracticeFeedback(block) : block,
            exportMode: ExportMode.quizV2,
            showAnswerStatus: true,
            onBlockCompleted: ({
              int earnedXp = 0,
              double scoreKoef = 1.0,
              String? mark,
              DateTime? tsBubbleOpen,
              DateTime? tsAnswerClick,
              DateTime? tsAnswerSubmit,
              int attemptCount = 0,
            }) {
              onCompleted();
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _answer(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.engineCheck));
  await tester.pumpAndSettle();
}

/// The atomic card runs inside QuizPage itself, so that is what gets pumped —
/// a stand-in would only prove the test's own branch logic.
Widget _quizHarness(
  ContentBlock block, {
  required _FakeEvaluator evaluator,
  required AppDatabase db,
}) {
  return ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider.overrideWithValue(evaluator),
      // The page grades and reschedules the card after answering; both reach
      // for the database, so it gets the in-memory one rather than opening a
      // second instance of its own.
      appDatabaseProvider.overrideWithValue(db),
      workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
    ],
    child: MaterialApp(
      home: QuizPage(
        questionBlocks: [withPracticeFeedback(block)],
        courseTitle: 'Procvičování',
        courseId: 'course-1',
        evaluate: true,
        isExercise: true,
        isFsrsPractice: true,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('withPracticeFeedback', () {
    test('turns a hidden solution back on for a V2 question step', () {
      final block = _v2Block(showSolution: false);
      final practiced = withPracticeFeedback(block);

      expect(practiced.steps.single.evaluationConfig!.showSolution, isTrue);
      // The course JSON the lesson plays from must not move with it.
      expect(block.steps.single.evaluationConfig!.showSolution, isFalse);
    });

    test('turns a hidden solution back on for an atomic question', () {
      final block = _atomicBlock(showSolution: false);
      final practiced = withPracticeFeedback(block);

      expect(practiced.atomicQuestion!.showSolution, isTrue);
      expect(block.atomicQuestion!.showSolution, isFalse);
    });

    test('leaves a block that already shows its solution alone', () {
      final block = _v2Block(showSolution: true);
      expect(identical(withPracticeFeedback(block), block), isTrue);
    });

    test('keeps everything else about the question', () {
      final config =
          withPracticeFeedback(_v2Block(showSolution: false))
              .steps
              .single
              .evaluationConfig!;

      expect(config.correctAnswer, _correctAnswer);
      expect(config.solution, _solution);
      expect(config.aiEvaluation, isFalse);
      expect(config.showAnswers, isTrue);
    });
  });

  group('practice feedback in the step engine', () {
    testWidgets('online: graded by AI, answered with status and solution',
        (tester) async {
      final evaluator = _FakeEvaluator();
      var completed = false;
      await tester.pumpWidget(_harness(
        _v2Block(showSolution: false),
        evaluator: evaluator,
        practice: true,
        onCompleted: () => completed = true,
      ));
      await tester.pumpAndSettle();

      await _answer(tester, 'velký');

      expect(evaluator.calls, 1);
      // The AI's verdict, told the classic way: the question has
      // `ai_evaluation` off, so its words stay off the screen (BR-N26ACB).
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
      expect(find.text(_feedbackText), findsNothing);
      expect(find.byType(OpenAnswerFeedbackCard), findsNothing);
      expect(completed, isFalse);
    });

    testWidgets('offline: the match verdict and the solution stand in',
        (tester) async {
      final evaluator = _FakeEvaluator(offline: true);
      var completed = false;
      await tester.pumpWidget(_harness(
        _v2Block(showSolution: false),
        evaluator: evaluator,
        practice: true,
        onCompleted: () => completed = true,
      ));
      await tester.pumpAndSettle();

      await _answer(tester, 'velký');

      expect(evaluator.calls, 1);
      // Before BR-9ZA9TT a failed evaluation left the question awaiting an
      // answer behind a retry notice. It is graded by comparison instead —
      // and the expected answer stays hidden (BR-N26ACB).
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
      expect(find.textContaining(_correctAnswer), findsNothing);
      expect(find.byType(OpenAnswerRetryNotice), findsNothing);
      expect(completed, isFalse);
    });

    testWidgets('outside practice the AI grades, the hidden solution stays hidden',
        (tester) async {
      final evaluator = _FakeEvaluator();
      await tester.pumpWidget(_harness(
        _v2Block(showSolution: false),
        evaluator: evaluator,
        practice: false,
        onCompleted: () {},
      ));
      await tester.pumpAndSettle();

      await _answer(tester, 'velký');

      // The round trip happens everywhere now (BR-N26ACB); show_solution is
      // still the author's to decide outside practice.
      expect(evaluator.calls, 1);
      expect(find.text(_solution), findsNothing);
      expect(find.text(_feedbackText), findsNothing);
      expect(find.textContaining(_correctAnswer), findsNothing);
    });
  });

  group('practice feedback on an atomic question', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    testWidgets('online: graded by AI, no AI feedback card', (tester) async {
      final evaluator = _FakeEvaluator();
      await tester.pumpWidget(
        _quizHarness(_atomicBlock(showSolution: false),
            evaluator: evaluator, db: db),
      );
      await tester.pumpAndSettle();

      await _answerInQuiz(tester, 'velký');

      expect(evaluator.calls, 1);
      // `ai_evaluation` is off: the verdict shows, the AI's words do not.
      expect(_fieldIcon(Icons.cancel), findsOneWidget);
      expect(find.byType(OpenAnswerFeedbackCard), findsNothing);
      expect(find.text(_solution), findsOneWidget);
    });

    testWidgets('offline: graded by comparison, expected answer hidden',
        (tester) async {
      final evaluator = _FakeEvaluator(offline: true);
      await tester.pumpWidget(
        _quizHarness(_atomicBlock(showSolution: false),
            evaluator: evaluator, db: db),
      );
      await tester.pumpAndSettle();

      await _answerInQuiz(tester, 'velký');

      expect(evaluator.calls, 1);
      // The reported screen was a red field and nothing else. The verdict now
      // comes with the solution — never with the expected answer (BR-N26ACB).
      expect(_fieldIcon(Icons.cancel), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
      expect(find.textContaining(_correctAnswer), findsNothing);
      expect(find.byType(OpenAnswerRetryNotice), findsNothing);
    });
  });
}

/// The verdict icon inside the quiz's answer field.
Finder _fieldIcon(IconData icon) => find.descendant(
      of: find.byType(TextField).first,
      matching: find.byIcon(icon),
    );
