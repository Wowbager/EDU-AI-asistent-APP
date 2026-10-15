import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/block_step_engine.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

/// BR-V9TQA7 — "AI průvodce řešením".
///
/// An AI-evaluated open question with an expected answer but no criteria used
/// to hand over the authored explanation on the first submission, which is the
/// one thing that ends the thinking. Guided solving rations it: feedback and
/// another go while attempts remain, the explanation once the student gets
/// there or spends the last attempt.
void main() {
  const solution = 'Jablko nepada daleko od stromu.';

  const feedback = FormativeFeedback(
    strengths: 'Je videt, ze jsi nad otazkou premyslel.',
    improvements: 'V odpovedi jeste neco chybi.',
    nextStep: 'Precti si zadani jeste jednou.',
  );

  BlockStep step({
    bool aiGuided = true,
    int attempts = 3,
    bool showSolution = true,
  }) =>
      BlockStep(
        stepId: 's1',
        type: StepType.question,
        evaluationConfig: EvaluationConfig(
          type: 'open',
          question: 'Co znamena prislovi o jablku a stromu?',
          correctAnswer: solution,
          solution: solution,
          showSolution: showSolution,
          aiEvaluation: true,
          aiGuided: aiGuided,
          aiGuidedAttempts: attempts,
        ),
      );

  StepAnswerState graded({
    required int attemptCount,
    bool isCorrect = false,
    bool isAnswered = true,
  }) =>
      StepAnswerState(
        textAnswer: 'jablko pada blizko ke stromu',
        isAnswered: isAnswered,
        isCorrect: isCorrect,
        evaluatedByAi: true,
        feedback: feedback,
        attemptCount: attemptCount,
      );

  Future<void> pump(
    WidgetTester tester, {
    required BlockStep target,
    required StepAnswerState answerState,
    ExportMode exportMode = ExportMode.courseV2,
    bool showSolutionState = true,
    bool showAnswerStatus = false,
  }) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StepContentRenderer(
              step: target,
              answerState: answerState,
              exportMode: exportMode,
              showSolution: showSolutionState,
              showAnswerStatus: showAnswerStatus,
              canReanswer: exportMode != ExportMode.quizV2,
              // A live input is what marks this as the question being worked
              // on — read-only renderings get no callbacks and stay unguided.
              onTextAnswerChanged: (_) {},
              onReworkAnswer: () {},
            ),
          ),
        ),
      ),
    ));
  }

  group('while attempts remain', () {
    testWidgets('the explanation is withheld but the feedback is not',
        (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 1),
      );

      expect(find.byType(OpenAnswerFeedbackCard), findsOneWidget);
      expect(find.text(feedback.improvements), findsOneWidget);
      expect(find.text(solution), findsNothing);
      expect(find.text(AppStrings.openFeedbackSolution), findsNothing);
    });

    testWidgets('the answer field stays open for the next attempt',
        (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 1),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
    });

    testWidgets('the rework button is dropped — the field is already open',
        (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 1),
      );

      expect(find.text(AppStrings.engineTryAgain), findsNothing);
    });

    testWidgets('the student is told how many goes are left', (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 1),
      );

      expect(find.text(AppStrings.openFeedbackAttemptsLeft(2)), findsOneWidget);
    });

    testWidgets('status is reported even when the course hides it', (tester) async {
      // Without it the student cannot tell the last attempt missed, and the
      // loop reads as the app ignoring them.
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 1),
        showAnswerStatus: false,
      );

      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
    });

    testWidgets('feedback survives the rework the student is mid-way through',
        (tester) async {
      // Typing reopens the attempt (isAnswered goes false). The feedback is the
      // instruction for this attempt, so it has to stay on screen.
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 1, isAnswered: false),
        showSolutionState: false,
      );

      expect(find.byType(OpenAnswerFeedbackCard), findsOneWidget);
      expect(find.text(solution), findsNothing);
    });
  });

  group('once the loop ends', () {
    testWidgets('the last attempt releases the explanation', (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 3),
      );

      expect(find.text(solution), findsOneWidget);
      expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
    });

    testWidgets('the field locks again once there is nothing left to try',
        (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 3),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('a correct answer releases it early — the point was reaching it',
        (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 2, isCorrect: true),
      );

      expect(find.text(solution), findsOneWidget);
      expect(find.text(AppStrings.openFeedbackAttemptsLeft(1)), findsNothing);
    });

    testWidgets('a custom attempt count is honoured', (tester) async {
      await pump(
        tester,
        target: step(attempts: 1),
        answerState: graded(attemptCount: 1),
      );

      expect(find.text(solution), findsOneWidget);
    });

    testWidgets('show_solution off still wins — there is nothing to release',
        (tester) async {
      await pump(
        tester,
        target: step(showSolution: false),
        answerState: graded(attemptCount: 3),
      );

      expect(find.text(solution), findsNothing);
    });
  });

  group('scope', () {
    testWidgets('a read-only rendering reveals it — there is nothing to retry in',
        (tester) async {
      // Block history and the sibling questions of a multi-question card have
      // no wired input. Holding the explanation back there would be a dead end.
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StepContentRenderer(
                step: step(),
                answerState: graded(attemptCount: 1),
                showSolution: true,
              ),
            ),
          ),
        ),
      ));

      expect(find.text(solution), findsOneWidget);
    });

    testWidgets('the switch off keeps the explanation immediate', (tester) async {
      await pump(
        tester,
        target: step(aiGuided: false),
        answerState: graded(attemptCount: 1),
      );

      expect(find.text(solution), findsOneWidget);
    });

    testWidgets('a quiz is untouched — one attempt is no loop', (tester) async {
      await pump(
        tester,
        target: step(),
        answerState: graded(attemptCount: 1),
        exportMode: ExportMode.quizV2,
      );

      expect(find.text(solution), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });

  group('attempt count persistence', () {
    test('survives a StepProgressData round-trip', () {
      // A reload that reset this to zero would refund the attempts, and with
      // them the reveal the switch exists to ration.
      final progress = StepProgressData(
        blockId: 'B1',
        stepAnswers: {'s1': graded(attemptCount: 2)},
      );

      final restored = StepProgressData.fromJson(progress.toJson());

      expect(restored.stepAnswers['s1']!.attemptCount, 2);
    });

    test('reopening an attempt does not refund it', () {
      final reopened = graded(attemptCount: 2).copyWith(
        isAnswered: false,
        clearFeedback: true,
      );

      expect(reopened.attemptCount, 2);
    });

    test('an absent count reads as a fresh answer', () {
      expect(StepAnswerState.fromJson(const {}).attemptCount, 0);
    });
  });

  group('config parsing', () {
    test('reads the guided flags off authored JSON', () {
      final config = EvaluationConfig.fromJson(const {
        'type': 'open',
        'ai_evaluation': true,
        'ai_guided': true,
        'ai_guided_attempts': 5,
      });

      expect(config.aiGuided, isTrue);
      expect(config.aiGuidedAttempts, 5);
    });

    test('defaults to three attempts when the count is absent', () {
      final config = EvaluationConfig.fromJson(const {
        'type': 'open',
        'ai_guided': true,
      });

      expect(config.aiGuidedAttempts, kDefaultGuidedAttempts);
    });

    test('a zero attempt count is clamped — it would reveal before the first try',
        () {
      final config = EvaluationConfig.fromJson(const {
        'type': 'open',
        'ai_guided': true,
        'ai_guided_attempts': 0,
      });

      expect(config.aiGuidedAttempts, 1);
    });

    test('courses authored before the switch are unaffected', () {
      final config = EvaluationConfig.fromJson(const {
        'type': 'open',
        'ai_evaluation': true,
      });

      expect(config.aiGuided, isFalse);
    });
  });

  group('the block waits', () {
    ContentBlock guidedBlock() => ContentBlock.fromJson(const {
          'block_id': 'TEST_GUIDED',
          'type': 'question',
          'steps': [
            {
              'id': 's1',
              'type': 'question',
              'order': 1,
              'content': 'Co znamena prislovi o jablku a stromu?',
              'question': {
                'type': 'open',
                'correct_answer': solution,
                'solution': solution,
                'ai_evaluation': true,
                'ai_guided': true,
                'ai_guided_attempts': 3,
              },
            },
          ],
        });

    Future<void> pumpEngine(
      WidgetTester tester, {
      required int attemptCount,
      bool isCorrect = false,
    }) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlockStepEngine(
                block: guidedBlock(),
                savedProgress: StepProgressData(
                  blockId: 'TEST_GUIDED',
                  stepAnswers: {
                    's1': graded(attemptCount: attemptCount, isCorrect: isCorrect),
                  },
                ),
                onBlockCompleted: ({
                  int earnedXp = 0,
                  double scoreKoef = 1.0,
                  String? mark,
                }) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('no way past a question that still has attempts on it',
        (tester) async {
      await pumpEngine(tester, attemptCount: 1);

      // "Zkontrolovat", not "Pokracovat": the next thing to do is answer again.
      expect(find.text(AppStrings.engineContinue), findsNothing);
      expect(find.text(AppStrings.engineCheck), findsOneWidget);
    });

    testWidgets('the way out opens once the attempts are spent', (tester) async {
      await pumpEngine(tester, attemptCount: 3);

      expect(find.text(AppStrings.engineContinue), findsNothing,
          reason: 'the continue affordance is an unlabelled arrow button');
      expect(find.text(AppStrings.engineCheck), findsNothing);
      expect(find.text(solution), findsOneWidget);
    });

    testWidgets('and once the student gets there', (tester) async {
      await pumpEngine(tester, attemptCount: 2, isCorrect: true);

      expect(find.text(AppStrings.engineCheck), findsNothing);
      expect(find.text(solution), findsOneWidget);
    });
  });
}
