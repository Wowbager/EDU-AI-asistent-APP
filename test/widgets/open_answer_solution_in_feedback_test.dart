import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

/// BR-BC3SYR — on an AI-evaluated open question the authored explanation used
/// to render as a second panel under the feedback card, and the answer field
/// stayed live after grading. The explanation now belongs to the card, and a
/// finished attempt is locked until the student asks for another one.
void main() {
  const solution = 'Hodnota a se vyskytuje mezi daty ctyrikrat.';

  const feedback = FormativeFeedback(
    strengths: 'Chapes, na co se ptame.',
    improvements: 'Cetnost je konkretni cislo.',
    nextStep: 'Projdi radu a zaznamenej vyskyty.',
  );

  BlockStep step({
    bool showSolution = true,
    bool aiEvaluation = true,
    String? solutionText = solution,
  }) =>
      BlockStep(
        stepId: 's1',
        type: StepType.question,
        evaluationConfig: EvaluationConfig(
          type: 'open',
          question: 'Jakou cetnost ma v datech hodnota a?',
          solution: solutionText,
          showSolution: showSolution,
          aiEvaluation: aiEvaluation,
        ),
      );

  const answered = StepAnswerState(
    textAnswer: 'velkou',
    isAnswered: true,
    isCorrect: false,
    evaluatedByAi: true,
    feedback: feedback,
  );

  Future<void> pump(
    WidgetTester tester, {
    required BlockStep target,
    StepAnswerState? answerState = answered,
    bool showSolutionState = true,
    bool canReanswer = false,
    VoidCallback? onReworkAnswer,
  }) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StepContentRenderer(
              step: target,
              answerState: answerState,
              showSolution: showSolutionState,
              canReanswer: canReanswer,
              onReworkAnswer: onReworkAnswer,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('explanation renders inside the feedback card, once', (tester) async {
    await pump(tester, target: step());

    final card = tester.widget<OpenAnswerFeedbackCard>(
      find.byType(OpenAnswerFeedbackCard),
    );
    expect(card.solution, solution);

    // Once — the standalone panel that used to sit under the card is gone.
    expect(find.text(solution), findsOneWidget);
    // Labelled as the model answer since BR-PM7XQ3 — inside this card the
    // authored text is what the student was aiming for, not a side note.
    expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OpenAnswerFeedbackCard),
        matching: find.text(solution),
      ),
      findsOneWidget,
    );
  });

  testWidgets('show_solution off keeps the explanation hidden', (tester) async {
    await pump(tester, target: step(showSolution: false));

    expect(find.byType(OpenAnswerFeedbackCard), findsOneWidget);
    expect(find.text(solution), findsNothing);
  });

  testWidgets('an exact-match open question keeps its own solution panel',
      (tester) async {
    await pump(tester, target: step(aiEvaluation: false));

    expect(find.byType(OpenAnswerFeedbackCard), findsNothing);
    expect(find.text(solution), findsOneWidget);
  });

  testWidgets('the answer field locks once the answer is graded', (tester) async {
    await pump(tester, target: step(), canReanswer: true);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });

  testWidgets('the field stays live before the answer is submitted',
      (tester) async {
    await pump(
      tester,
      target: step(),
      answerState: const StepAnswerState(textAnswer: 'velkou'),
      showSolutionState: false,
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);
  });

  testWidgets('a failed evaluation leaves the field editable', (tester) async {
    await pump(
      tester,
      target: step(),
      answerState: const StepAnswerState(
        textAnswer: 'velkou',
        evaluationFailed: true,
      ),
      showSolutionState: false,
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);
    expect(find.text(AppStrings.engineTryAgain), findsNothing,
        reason: 'the retry notice carries its own button');
  });

  testWidgets('try again is offered when the attempt can be reopened',
      (tester) async {
    var reopened = 0;
    await pump(
      tester,
      target: step(showSolution: false),
      canReanswer: true,
      onReworkAnswer: () => reopened++,
    );

    await tester.tap(find.text(AppStrings.engineTryAgain));
    expect(reopened, 1);
  });

  testWidgets('but not once the explanation is in the card (BR-XWBT8W)',
      (tester) async {
    await pump(
      tester,
      target: step(),
      canReanswer: true,
      onReworkAnswer: () {},
    );

    expect(find.text(solution), findsOneWidget);
    expect(find.text(AppStrings.engineTryAgain), findsNothing);
  });

  testWidgets('no try again button in a quiz, where one attempt is all there is',
      (tester) async {
    await pump(tester, target: step(), onReworkAnswer: () {});

    expect(find.text(AppStrings.engineTryAgain), findsNothing);
  });

  testWidgets('the card carries the explanation even without three-part feedback',
      (tester) async {
    await pump(
      tester,
      target: step(),
      answerState: const StepAnswerState(
        textAnswer: 'velkou',
        isAnswered: true,
        evaluatedByAi: true,
        aiFeedback: 'Zkus to spocitat presne.',
      ),
    );

    expect(find.text(solution), findsOneWidget);
    expect(find.text('Zkus to spocitat presne.'), findsOneWidget);
  });
}
