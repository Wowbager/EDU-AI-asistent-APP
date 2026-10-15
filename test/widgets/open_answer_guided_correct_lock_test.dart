import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// BR-EDB2MB — a guided question the student got right is finished: the short
// feedback and the solution appear, and there is no way back into the field.
//
// BR-PM7XQ3 already hid the retry button inside the answered card. The rework
// button a *finished* block draws underneath it (BR-P745Q8) had no such rule,
// so a student who had already got there was still invited to answer again —
// and under `open_answer_score: last` that second, worse attempt would replace
// the one that counted.
//
// Only guided questions are affected: an unguided formative question is the
// open-ended rework loop BR-P745Q8 built, and it keeps inviting another go.

ContentBlock _block({required bool aiGuided}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_GUIDED_LOCK',
    'type': 'display',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': {'text': 'Co znamená přísloví o jablku a stromu?'},
        'question': {
          'type': 'open',
          'correct_answer': 'Děti se podobají rodičům.',
          'solution': 'Jablko nepadá daleko od stromu.',
          'ai_evaluation': true,
          'ai_guided': aiGuided,
          'ai_guided_attempts': 3,
          'show_answers': true,
          'show_solution': true,
        },
      },
    ],
  });
}

const _feedback = FormativeFeedback(
  strengths: 'Vystihl jsi to.',
  improvements: 'Mohl bys to říct ještě stručněji.',
  nextStep: 'Zkus to shrnout jednou větou.',
);

class _FixedEvaluator implements AiAnswerEvaluator {
  final bool isCorrect;

  const _FixedEvaluator({required this.isCorrect});

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
      score: isCorrect ? 0.95 : 0.2,
      isCorrect: isCorrect,
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

/// The block, with `isCompleted` under the test's control — that is what turns
/// every step into read-only history and brings out the rework button.
Widget _harness(
  ContentBlock block, {
  required bool isCorrect,
  required ValueListenable<bool> completed,
}) {
  return ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider
          .overrideWithValue(_FixedEvaluator(isCorrect: isCorrect)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ValueListenableBuilder<bool>(
            valueListenable: completed,
            builder: (context, isCompleted, _) => BlockStepEngine(
              block: block,
              exportMode: ExportMode.courseV2,
              isCompleted: isCompleted,
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
    ),
  );
}

/// Answer the question, let the evaluation land, then finish the block so the
/// history rendering — and its rework button — is what is on screen.
Future<void> _answerAndFinish(
  WidgetTester tester,
  ValueNotifier<bool> completed,
  String text,
) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.engineCheck));
  await tester.pumpAndSettle();

  completed.value = true;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a finished guided question answered right offers no way back in',
      (tester) async {
    final completed = ValueNotifier(false);
    addTearDown(completed.dispose);

    await tester.pumpWidget(_harness(
      _block(aiGuided: true),
      isCorrect: true,
      completed: completed,
    ));
    await _answerAndFinish(tester, completed, 'Deti se podobaji rodicum.');

    expect(find.text(AppStrings.openFeedbackRework), findsNothing);
    // Closed, not blank: the model answer is what the student is left with.
    expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
  });

  testWidgets('a guided question answered wrong can still be reworked',
      (tester) async {
    final completed = ValueNotifier(false);
    addTearDown(completed.dispose);

    await tester.pumpWidget(_harness(
      _block(aiGuided: true),
      isCorrect: false,
      completed: completed,
    ));
    await _answerAndFinish(tester, completed, 'Nevim.');

    expect(find.text(AppStrings.openFeedbackRework), findsOneWidget);
  });

  testWidgets('an unguided formative question keeps its open-ended rework',
      (tester) async {
    final completed = ValueNotifier(false);
    addTearDown(completed.dispose);

    await tester.pumpWidget(_harness(
      _block(aiGuided: false),
      isCorrect: true,
      completed: completed,
    ));
    await _answerAndFinish(tester, completed, 'Deti se podobaji rodicum.');

    expect(
      find.text(AppStrings.openFeedbackRework),
      findsOneWidget,
      reason: 'BR-P745Q8 rework is unchanged outside guided solving',
    );
  });
}
