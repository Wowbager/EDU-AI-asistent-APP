import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/theme/app_text_styles.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

/// BR-PM7XQ3 — a student who answered correctly was still being told what to do
/// next and offered another attempt, which reads as "that wasn't good enough".
/// A correct answer closes the question: no next step, no retry. The authored
/// explanation stays, but as the model answer it is, in the card's own type.
void main() {
  const solutionMarkdown = 'Hodnota **a** se vyskytuje mezi daty ctyrikrat.';

  const feedback = FormativeFeedback(
    strengths: 'Chapes, na co se ptame.',
    improvements: 'Cetnost je konkretni cislo.',
    nextStep: 'Projdi radu a zaznamenej vyskyty.',
  );

  BlockStep step({String? solutionText = solutionMarkdown}) => BlockStep(
        stepId: 's1',
        type: StepType.question,
        evaluationConfig: EvaluationConfig(
          type: 'open',
          question: 'Jakou cetnost ma v datech hodnota a?',
          solution: solutionText,
          showSolution: true,
          aiEvaluation: true,
        ),
      );

  StepAnswerState answered({required bool isCorrect}) => StepAnswerState(
        textAnswer: 'ctyri',
        isAnswered: true,
        isCorrect: isCorrect,
        evaluatedByAi: true,
        feedback: feedback,
      );

  Future<void> pump(
    WidgetTester tester, {
    required bool isCorrect,
    BlockStep? target,
    bool canReanswer = true,
    VoidCallback? onReworkAnswer,
  }) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StepContentRenderer(
              step: target ?? step(),
              answerState: answered(isCorrect: isCorrect),
              showSolution: true,
              canReanswer: canReanswer,
              onReworkAnswer: onReworkAnswer ?? () {},
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('a correct answer drops the next-step section', (tester) async {
    await pump(tester, isCorrect: true);

    expect(find.text(AppStrings.openFeedbackNextStep), findsNothing);
    expect(find.text(feedback.nextStep), findsNothing);

    // What the student did well, and how to say it better, still stand.
    expect(find.text(AppStrings.openFeedbackStrengths), findsOneWidget);
    expect(find.text(AppStrings.openFeedbackImprovements), findsOneWidget);
  });

  testWidgets('a correct answer drops the try again button', (tester) async {
    await pump(tester, isCorrect: true);

    expect(find.text(AppStrings.engineTryAgain), findsNothing);
  });

  testWidgets('an incorrect answer keeps the retry', (tester) async {
    var reopened = 0;
    // Without an explanation: the model answer on screen closes the question
    // whatever the verdict (BR-XWBT8W).
    await pump(
      tester,
      isCorrect: false,
      target: step(solutionText: null),
      onReworkAnswer: () => reopened++,
    );

    await tester.tap(find.text(AppStrings.engineTryAgain));
    expect(reopened, 1);
  });

  testWidgets('an incorrect answer drops the next step too, once the model '
      'answer is on screen to replace it (BR-Y3A5M8)', (tester) async {
    await pump(tester, isCorrect: false);

    expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
    expect(find.text(AppStrings.openFeedbackNextStep), findsNothing);
    expect(find.text(feedback.nextStep), findsNothing);
  });

  testWidgets('the explanation is labelled as the model answer', (tester) async {
    await pump(tester, isCorrect: true);

    expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
    expect(find.text(AppStrings.stepExplanation), findsNothing);
  });

  testWidgets('the model answer is set in the same type as the rest of the card',
      (tester) async {
    await pump(tester, isCorrect: true);

    final body = tester.widget<MarkdownBody>(
      find.descendant(
        of: find.byType(OpenAnswerFeedbackCard),
        matching: find.byType(MarkdownBody),
      ),
    );
    expect(body.styleSheet!.p!.fontSize, AppTextStyles.meta().fontSize,
        reason: 'the AI sections are meta-sized; the explanation must match');
  });

  testWidgets('a plain-text explanation is unaffected by the markdown path',
      (tester) async {
    await pump(
      tester,
      isCorrect: true,
      target: step(solutionText: 'Hodnota a se vyskytuje ctyrikrat.'),
    );

    final text = tester.widget<Text>(
      find.text('Hodnota a se vyskytuje ctyrikrat.'),
    );
    expect(text.style!.fontSize, AppTextStyles.meta().fontSize);
  });
}
