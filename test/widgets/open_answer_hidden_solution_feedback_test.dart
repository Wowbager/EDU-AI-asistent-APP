import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/block_step_engine.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';

// Regression tests for BR-TFX6BJ.
//
// `show_solution` says "do not reveal the reference answer". The engine read it
// as "there is nothing worth pausing for" and advanced the moment the answer
// was recorded — so an AI-graded open question with the solution hidden threw
// its feedback away before the student could read it. The renderer had the rule
// right all along (the feedback card renders, the authored solution inside it
// does not); only the engine's skip decision was wrong.

const _solution = 'Četnost je počet výskytů hodnoty, součet je jejich úhrn.';

ContentBlock _block({
  required bool aiEvaluation,
  required bool showSolution,
}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_HIDDEN_SOLUTION',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': {'text': 'Jaký je rozdíl mezi četností a součtem?'},
        'question': {
          'type': 'open',
          'correct_answer': 'Četnost je počet výskytů, součet je úhrn hodnot.',
          'solution': _solution,
          'ai_evaluation': aiEvaluation,
          'show_answers': true,
          'show_solution': showSolution,
        },
      },
    ],
  });
}

const _feedback = FormativeFeedback(
  strengths: 'Zatím nevidím, čeho by se odpověď týkala.',
  improvements: 'Odpověď neobsahuje vysvětlení pojmů četnost a součet.',
  nextStep: 'Zkus vlastními slovy popsat, co znamená slovo četnost.',
);

/// Stands in for the API. The engine only ever calls [evaluate] here — the
/// question has no photo — so the rest is never exercised.
class _FakeEvaluator implements AiAnswerEvaluator {
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
    return const AiEvaluationOutcome.success(AiEvaluationResult(
      score: 0.2,
      isCorrect: false,
      feedbackText: 'Zatím nevidím, čeho by se odpověď týkala.',
      feedback: _feedback,
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

/// The in-lesson path: no controller, so the engine renders its own button and
/// drives its own state — the same wiring LessonDetailPage uses.
Widget _harness(ContentBlock block, {required VoidCallback onCompleted}) {
  return ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider.overrideWithValue(_FakeEvaluator()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockStepEngine(
            block: block,
            exportMode: ExportMode.courseV2,
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

void main() {
  testWidgets('hidden solution still pauses on the AI feedback',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(_harness(
      _block(aiEvaluation: true, showSolution: false),
      onCompleted: () => completed = true,
    ));
    await tester.pumpAndSettle();

    await _answer(tester, 'velký');

    // The block must wait on the feedback screen. Before the fix show_solution
    // vetoed the pause: the block completed on the spot and the lesson moved
    // to the next block with the feedback never shown.
    expect(completed, isFalse);
    expect(find.byType(OpenAnswerFeedbackCard), findsOneWidget);
  });

  testWidgets('hidden solution keeps the authored solution out of the card',
      (tester) async {
    await tester.pumpWidget(_harness(
      _block(aiEvaluation: true, showSolution: false),
      onCompleted: () {},
    ));
    await tester.pumpAndSettle();

    await _answer(tester, 'velký');

    // Pausing must not turn into revealing: show_solution still does its job.
    expect(find.text(_solution), findsNothing);
    final card = tester.widget<OpenAnswerFeedbackCard>(
      find.byType(OpenAnswerFeedbackCard),
    );
    expect(card.solution, isNull);
  });

  testWidgets('a shown solution reaches the card as before', (tester) async {
    await tester.pumpWidget(_harness(
      _block(aiEvaluation: true, showSolution: true),
      onCompleted: () {},
    ));
    await tester.pumpAndSettle();

    await _answer(tester, 'velký');

    final card = tester.widget<OpenAnswerFeedbackCard>(
      find.byType(OpenAnswerFeedbackCard),
    );
    expect(card.solution, _solution);
  });

  testWidgets('an exact-match question with a hidden solution still skips',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(_harness(
      _block(aiEvaluation: false, showSolution: false),
      onCompleted: () => completed = true,
    ));
    await tester.pumpAndSettle();

    await _answer(tester, 'velký');

    // No AI feedback exists for this question, and show_solution forbids the
    // only other content there was. Nothing to stop for — unchanged behaviour.
    expect(completed, isTrue);
    expect(find.byType(OpenAnswerFeedbackCard), findsNothing);
  });
}
