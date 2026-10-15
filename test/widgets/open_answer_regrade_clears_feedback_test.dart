import 'dart:async';
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

// BR-K8TDU4 — two ends of the same rule: feedback describes one attempt.
//
// 1. Submitting a reworked answer clears the card the previous attempt left.
//    Guided solving keeps that card up while the student types (BR-V9TQA7) —
//    it is the instruction they are working from — but once the text it
//    described has been replaced and sent, it is advice about an answer that no
//    longer exists, and it sat there through the whole grading call.
//
// 2. Once the guided loop is over, the question is closed. BR-EDB2MB closed it
//    on a correct answer; spending the last attempt is the same ending seen
//    from the other side — it is the moment the worked solution is handed over,
//    and an attempt made after reading it measures nothing (and under
//    `open_answer_score: last` would overwrite the score actually earned).

ContentBlock _block({int attempts = 3, bool aiGuided = true}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_REGRADE',
    'type': 'display',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': {'text': 'Jak sestrojíš přímku obsahující stranu AB?'},
        'question': {
          'type': 'open',
          'correct_answer': 'Kolmicí k přímce p bodem B.',
          'solution': 'Kolmice k p procházející bodem B.',
          'ai_evaluation': true,
          'ai_guided': aiGuided,
          'ai_guided_attempts': attempts,
          'show_answers': true,
          'show_solution': true,
        },
      },
    ],
  });
}

const _first = FormativeFeedback(
  strengths: 'Vsimls si vztahu mezi vyskou a stranou.',
  improvements: 'Chybi ti spojeni s primkou p.',
  nextStep: 'Zkus popsat konkretni konstrukcni krok.',
);

const _second = FormativeFeedback(
  strengths: 'Ted uz popisujes konstrukci.',
  improvements: 'Jeste dopln, ktery bod pouzijes.',
  nextStep: 'Pojmenuj bod, kterym kolmice prochazi.',
);

/// Hands out a queued outcome per call, and can hold the call open so the test
/// can look at the screen while grading is in flight.
class _ScriptedEvaluator implements AiAnswerEvaluator {
  final List<AiEvaluationOutcome> outcomes;
  final bool hold;

  /// Completed by the test to release a held call.
  final Completer<void> gate = Completer<void>();

  int calls = 0;

  _ScriptedEvaluator(this.outcomes, {this.hold = false});

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
    final outcome = outcomes[calls.clamp(0, outcomes.length - 1)];
    calls++;
    // Only the second call waits — the first has to land so there is feedback
    // on screen to clear.
    if (hold && calls > 1) await gate.future;
    return outcome;
  }

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      null;
}

AiEvaluationOutcome _graded(FormativeFeedback? feedback, {String text = ''}) {
  return AiEvaluationOutcome.success(AiEvaluationResult(
    score: 0.2,
    isCorrect: false,
    feedbackText: feedback?.improvements ?? text,
    feedback: feedback,
  ));
}

Widget _harness(ContentBlock block, AiAnswerEvaluator evaluator) {
  return ProviderScope(
    overrides: [aiAnswerEvaluatorProvider.overrideWithValue(evaluator)],
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
  );
}

Future<void> _answer(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.engineCheck));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('submitting a reworked answer takes the old feedback off screen',
      (tester) async {
    final evaluator = _ScriptedEvaluator(
      [_graded(_first), _graded(_second)],
      hold: true,
    );

    await tester.pumpWidget(_harness(_block(), evaluator));
    await _answer(tester, 'Sestrojit na c vysku AB.');
    expect(find.text(_first.improvements), findsOneWidget);

    // The guided loop leaves the field open, so the student reworks in place —
    // and the feedback stays up while they type.
    await tester.enterText(find.byType(TextField), 'Sestrojim kolmici k p.');
    await tester.pumpAndSettle();
    expect(
      find.text(_first.improvements),
      findsOneWidget,
      reason: 'BR-V9TQA7: the instruction stays while the answer is rewritten',
    );

    // Submitted. The second evaluation is still out, so this is exactly the
    // window the report is about.
    await tester.tap(find.text(AppStrings.engineCheck));
    await tester.pump();
    expect(find.text(_first.improvements), findsNothing);

    evaluator.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(_second.improvements), findsOneWidget);
    expect(find.text(_first.improvements), findsNothing);
  });

  testWidgets('a regrade that returns no feedback does not resurrect the old card',
      (tester) async {
    // A server response the client cannot parse into parts is graded but
    // wordless. `copyWith` used to keep the previous value, so the first
    // attempt's card came back dressed as the verdict on the second.
    final evaluator = _ScriptedEvaluator([_graded(_first), _graded(null)]);

    await tester.pumpWidget(_harness(_block(), evaluator));
    await _answer(tester, 'Sestrojit na c vysku AB.');
    expect(find.text(_first.improvements), findsOneWidget);

    await _answer(tester, 'Sestrojim kolmici k p.');

    expect(evaluator.calls, 2);
    expect(find.text(_first.improvements), findsNothing);
  });

  testWidgets('spending the last guided attempt closes the question',
      (tester) async {
    final evaluator = _ScriptedEvaluator([_graded(_first)]);

    await tester.pumpWidget(_harness(_block(attempts: 1), evaluator));
    await _answer(tester, 'Nevim.');

    // The worked solution is handed over…
    expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
    // …and with it there is no way back into the field.
    expect(find.text(AppStrings.engineTryAgain), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isFalse,
    );
  });

  testWidgets('a guided question with attempts left still reopens',
      (tester) async {
    final evaluator = _ScriptedEvaluator([_graded(_first)]);

    await tester.pumpWidget(_harness(_block(attempts: 3), evaluator));
    await _answer(tester, 'Nevim.');

    // Mid-loop: the solution is still held back and the field stays live.
    expect(find.text(AppStrings.openFeedbackSolution), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isTrue,
    );
  });

  testWidgets('an unguided formative question offers no try again under the '
      'solution either (BR-XWBT8W)', (tester) async {
    // Without guided solving the solution arrives with the first grading, and
    // an attempt made after reading it measures nothing just the same.
    final evaluator = _ScriptedEvaluator([_graded(_first)]);

    await tester.pumpWidget(_harness(_block(aiGuided: false), evaluator));
    await _answer(tester, 'Nevim.');

    expect(find.text(AppStrings.openFeedbackSolution), findsOneWidget);
    expect(find.text(AppStrings.engineTryAgain), findsNothing);
  });
}
