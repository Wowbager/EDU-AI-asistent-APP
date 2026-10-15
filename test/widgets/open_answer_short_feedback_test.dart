import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

/// BR-Y3A5M8 — the short form of the feedback card.
///
/// "Co dál" is an instruction for the next attempt. With the AI guide switched
/// off the model answer appears with the very first grading, so the section
/// stood underneath an answer the student could already read in full — telling
/// them to go and work out what was printed two lines below.
///
/// The rule is not "guide off" but the reason behind it: the section stays
/// exactly while the student is coming back for another go with nothing else to
/// work from.
///
/// The card's fourth section, "Zamysli se", is gone entirely (BR-XTCYD2) — the
/// fixture still carries a `hintQuestion`, because older stored feedback does,
/// and no arrangement of this widget may render it.
void main() {
  const solution = 'Vyska v_c je kolma na stranu AB.';

  const feedback = FormativeFeedback(
    strengths: 'Je videt, ze jsi nad otazkou premyslel.',
    improvements: 'Chybi vztah mezi vyskou a stranou.',
    nextStep: 'Napis vlastnimi slovy alespon jednu myslenku.',
    hintQuestion: 'Jak je vyska natocena vuci strane AB?',
  );

  BlockStep step({
    bool aiGuided = false,
    int attempts = 3,
    bool showSolution = true,
  }) =>
      BlockStep(
        stepId: 's1',
        type: StepType.question,
        evaluationConfig: EvaluationConfig(
          type: 'open',
          question: 'Jaky je vztah vysky v_c a strany AB?',
          solution: solution,
          showSolution: showSolution,
          aiEvaluation: true,
          aiGuided: aiGuided,
          aiGuidedAttempts: attempts,
        ),
      );

  StepAnswerState graded({int attemptCount = 1, bool isCorrect = false}) =>
      StepAnswerState(
        textAnswer: 'nevim',
        isAnswered: true,
        isCorrect: isCorrect,
        evaluatedByAi: true,
        feedback: feedback,
        attemptCount: attemptCount,
      );

  Future<void> pump(
    WidgetTester tester, {
    required BlockStep target,
    required StepAnswerState answerState,
    bool canReanswer = true,
    bool live = true,
  }) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StepContentRenderer(
              step: target,
              answerState: answerState,
              showSolution: true,
              canReanswer: canReanswer,
              // A live input plus a rework callback is what marks this as the
              // question being worked on; a read-only rendering gets neither.
              onTextAnswerChanged: live ? (_) {} : null,
              onReworkAnswer: live ? () {} : null,
            ),
          ),
        ),
      ),
    ));
  }

  void expectPointers(bool shown) {
    final matcher = shown ? findsOneWidget : findsNothing;
    expect(find.text(AppStrings.openFeedbackNextStep), matcher);
    expect(find.text(feedback.nextStep), matcher);
    // Never shown, in either state — BR-XTCYD2.
    expect(find.text(feedback.hintQuestion!), findsNothing);
  }

  group('with the AI guide switched off', () {
    testWidgets('the card drops the next step', (tester) async {
      await pump(tester, target: step(), answerState: graded());

      expect(find.byType(OpenAnswerFeedbackCard), findsOneWidget);
      expectPointers(false);
    });

    testWidgets('what went well, what to improve and the model answer stay',
        (tester) async {
      await pump(tester, target: step(), answerState: graded());

      expect(find.text(AppStrings.openFeedbackStrengths), findsOneWidget);
      expect(find.text(feedback.strengths), findsOneWidget);
      expect(find.text(AppStrings.openFeedbackImprovements), findsOneWidget);
      expect(find.text(feedback.improvements), findsOneWidget);
      expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
      expect(find.text(solution), findsOneWidget);
    });

    testWidgets('no other attempt is offered under the model answer '
        '(BR-XWBT8W)', (tester) async {
      await pump(tester, target: step(), answerState: graded());

      // An attempt made after reading the model answer measures nothing, so
      // the "try again" button goes with the section.
      expect(find.text(AppStrings.engineTryAgain), findsNothing);
    });

    testWidgets('another attempt is offered while the explanation is hidden',
        (tester) async {
      await pump(
        tester,
        target: step(showSolution: false),
        answerState: graded(),
      );

      expect(find.text(AppStrings.engineTryAgain), findsOneWidget);
    });

    testWidgets(
        'it stays when the author hid the explanation, because nothing else '
        'tells the student where to go', (tester) async {
      await pump(
        tester,
        target: step(showSolution: false),
        answerState: graded(),
      );

      expect(find.text(AppStrings.openFeedbackSolution), findsNothing);
      expectPointers(true);
    });

    testWidgets('a read-only rendering drops it: there is no next attempt',
        (tester) async {
      await pump(
        tester,
        target: step(showSolution: false),
        answerState: graded(),
        canReanswer: false,
        live: false,
      );

      expectPointers(false);
    });
  });

  group('with the AI guide switched on', () {
    testWidgets('it stays while attempts remain (BR-V9TQA7)', (tester) async {
      await pump(
        tester,
        target: step(aiGuided: true),
        answerState: graded(attemptCount: 1),
      );

      // The explanation is being withheld, so the feedback is all the student
      // has — this is the case the section was written for.
      expect(find.text(AppStrings.openFeedbackSolution), findsNothing);
      expectPointers(true);
    });

    testWidgets('it goes once the last attempt is spent and the explanation '
        'is on screen', (tester) async {
      await pump(
        tester,
        target: step(aiGuided: true, attempts: 3),
        answerState: graded(attemptCount: 3),
      );

      expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
      expectPointers(false);
    });
  });

  testWidgets('a correct answer drops it even with the explanation hidden '
      '(BR-PM7XQ3)', (tester) async {
    await pump(
      tester,
      target: step(showSolution: false),
      answerState: graded(isCorrect: true),
    );

    expectPointers(false);
  });

  testWidgets('the hint question never reaches the card, not even where the '
      'next step stays (BR-XTCYD2)', (tester) async {
    // The state that used to render it: the guide is on, attempts remain, the
    // model answer is withheld. Feedback that says the same thing three times
    // is what the client asked us to stop sending.
    await pump(
      tester,
      target: step(aiGuided: true),
      answerState: graded(attemptCount: 1),
    );

    expect(find.text(AppStrings.openFeedbackNextStep), findsOneWidget);
    expect(find.text(feedback.hintQuestion!), findsNothing);
  });
}
