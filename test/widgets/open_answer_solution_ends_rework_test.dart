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

// BR-XWBT8W — an open question with the AI guide switched off and the model
// answer switched on. The feedback and the model answer arrived fine, but a
// "Zkusit znovu" button sat underneath them.
//
// With the guide off the model answer is on screen from the very first grading,
// and an attempt made after reading it measures nothing — the reason guided
// solving closes the field once it hands the explanation over (BR-K8TDU4). With
// the model answer hidden the feedback is all the student has, and the
// open-ended rework BR-P745Q8 built stays.

const _solution = 'Jablko nepadá daleko od stromu.';

ContentBlock _block({required String type, required bool showSolution}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_SOLUTION_ENDS_REWORK',
    'type': type,
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': {'text': 'Co znamená přísloví o jablku a stromu?'},
        'question': {
          'type': 'open',
          'correct_answer': _solution,
          'solution': _solution,
          'ai_evaluation': true,
          'ai_guided': false,
          'show_answers': true,
          'show_solution': showSolution,
        },
      },
    ],
  });
}

const _feedback = FormativeFeedback(
  strengths: 'Díky za odpověď, je vidět, že jsi nad otázkou přemýšlel.',
  improvements: 'V odpovědi ještě něco chybí.',
  nextStep: 'Zkus se k otázce vrátit a projít si, na co všechno se ptá.',
);

/// Grades every answer as not there yet — the state the report was taken in.
class _NotYetEvaluator implements AiAnswerEvaluator {
  const _NotYetEvaluator();

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
    return AiEvaluationOutcome.success(AiEvaluationResult(
      score: 0.2,
      isCorrect: false,
      feedbackText: _feedback.improvements,
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

Future<void> _answer(WidgetTester tester, ContentBlock block) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider.overrideWithValue(const _NotYetEvaluator()),
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
            }) {},
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'jablko je u stromu');
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.engineCheck));
  await tester.pumpAndSettle();
}

void main() {
  // A question block renders every step in one card; any other block renders
  // the step being answered as its own card. Both wire the button.
  for (final type in ['question', 'display']) {
    group('$type block, AI guide off', () {
      testWidgets('no try again under the model answer', (tester) async {
        await _answer(tester, _block(type: type, showSolution: true));

        // Graded and shown, as reported.
        expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
        expect(find.text(_feedback.improvements), findsOneWidget);

        expect(find.text(AppStrings.engineTryAgain), findsNothing);
      });

      testWidgets('try again stays while the model answer is hidden',
          (tester) async {
        await _answer(tester, _block(type: type, showSolution: false));

        expect(find.text(AppStrings.openFeedbackSolution), findsNothing);
        expect(find.text(AppStrings.engineTryAgain), findsOneWidget);
      });
    });
  }
}
