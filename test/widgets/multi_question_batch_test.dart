import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// Regression test for BR-E4H835: an exercise block with several questions
// renders all of them at once, so all of them must be answerable — and the
// "Zkontrolovat" button must stay inactive until every question is filled.
// Before the fix only the first question was wired up: text typed into the
// others was silently discarded and the button lit up after one answer.
//
// The questions are numeric: a block holding an open question is graded by AI
// one question at a time (BR-N26ACB), so only locally graded questions batch.

ContentBlock _threeQuestionBlock({bool withSolutions = true}) {
  Map<String, dynamic> question(String id, String prompt, num correct) => {
        'id': id,
        'type': 'question',
        'order': 1,
        'question': {
          'type': 'numeric',
          'question': prompt,
          'correct_number': correct,
          if (withSolutions) 'solution': 'Reseni $id',
        },
      };

  return ContentBlock.fromJson({
    'block_id': 'TEST_MULTI',
    'type': 'exercise',
    'steps': [
      {'id': 's0', 'type': 'text', 'order': 1, 'content': 'Zkus se zamyslet'},
      question('s1', 'Kolik je zaku', 24),
      question('s2', 'Kolik je trid', 3),
      question('s3', 'Kolik je skol', 1),
    ],
  });
}

/// The AI out of reach, so an open answer falls back to comparison
/// (BR-N26ACB) — which is what a test off the network can check.
class _OfflineEvaluator implements AiAnswerEvaluator {
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
  }) async =>
      const AiEvaluationOutcome.failed(AiEvaluationFailure.offline);

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      null;
}

class _Completion {
  bool done = false;
  double? scoreKoef;
}

Widget _wrap(
  ContentBlock block,
  _Completion completion, {
  StepProgressData? savedProgress,
}) {
  return ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider.overrideWithValue(_OfflineEvaluator()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockStepEngine(
            block: block,
            savedProgress: savedProgress,
            onBlockCompleted: (
                {int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {
              completion.done = true;
              completion.scoreKoef = scoreKoef;
            },
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('all questions in the block are answerable, not just the first',
      (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_threeQuestionBlock(), completion));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));

    // Text typed into the 2nd and 3rd question must survive a rebuild — the
    // old engine dropped it because those fields had no onChanged handler, so
    // their content was never recorded in _stepAnswers. It looked fine until
    // any setState rebuilt the card from state and wiped the fields.
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '7');
    await tester.pumpAndSettle();

    // Typing into the first question forces a rebuild of the whole card.
    await tester.enterText(find.byType(TextField).at(0), '24');
    await tester.pumpAndSettle();

    expect(find.text('24'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('"Zkontrolovat" stays inactive until every question is filled',
      (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_threeQuestionBlock(), completion));
    await tester.pumpAndSettle();

    // Nothing filled — no active check button.
    expect(find.text('Zkontrolovat'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '24');
    await tester.pumpAndSettle();
    expect(find.text('Zkontrolovat'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.pumpAndSettle();
    expect(find.text('Zkontrolovat'), findsNothing);

    // Last one filled — now it activates.
    await tester.enterText(find.byType(TextField).at(2), '7');
    await tester.pumpAndSettle();
    expect(find.text('Zkontrolovat'), findsOneWidget);
  });

  testWidgets('one tap evaluates every question and scores the average',
      (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_threeQuestionBlock(), completion));
    await tester.pumpAndSettle();

    // Two correct, one wrong → 2/3.
    await tester.enterText(find.byType(TextField).at(0), '24');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '7');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();

    // Every question got evaluated: all three solutions are on screen.
    expect(find.text('Reseni s1'), findsOneWidget);
    expect(find.text('Reseni s2'), findsOneWidget);
    expect(find.text('Reseni s3'), findsOneWidget);

    // Solutions are shown first; the block completes on the follow-up tap.
    expect(completion.done, isFalse);
    final continueButton = find.byIcon(Icons.check).last;
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(completion.done, isTrue);
    expect(completion.scoreKoef, closeTo(2 / 3, 0.001));
  });

  testWidgets('progress from the old one-at-a-time flow finishes the rest',
      (tester) async {
    final completion = _Completion();
    // Saved by the pre-fix engine: question 1 evaluated, 2 and 3 never asked.
    final saved = StepProgressData(
      blockId: 'TEST_MULTI',
      currentStepIndex: 1,
      stepAnswers: {
        's1': const StepAnswerState(
          textAnswer: '24',
          isAnswered: true,
          isCorrect: true,
          scoreKoef: 1.0,
        ),
      },
    );
    await tester.pumpWidget(
        _wrap(_threeQuestionBlock(), completion, savedProgress: saved));
    await tester.pumpAndSettle();

    // The block is not treated as finished — the two other questions are live.
    // The answered one still renders, but locked.
    expect(completion.done, isFalse);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(tester.widget<TextField>(find.byType(TextField).at(0)).enabled,
        isFalse);
    expect(find.text('Zkontrolovat'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '1');
    await tester.pumpAndSettle();
    expect(find.text('Zkontrolovat'), findsOneWidget);

    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();

    final continueButton = find.byIcon(Icons.check).last;
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    // All three end up correct.
    expect(completion.done, isTrue);
    expect(completion.scoreKoef, closeTo(1.0, 0.001));
  });

  testWidgets('open-question block is not batched but still gates on all questions',
      (tester) async {
    final completion = _Completion();
    Map<String, dynamic> aiQuestion(String id, String prompt) => {
          'id': id,
          'type': 'question',
          'order': 1,
          'question': {
            'type': 'open',
            'question': prompt,
            'correct_answer': 'cokoli',
            'ai_evaluation': true,
          },
        };
    final block = ContentBlock.fromJson({
      'block_id': 'TEST_AI',
      'type': 'exercise',
      'steps': [aiQuestion('s1', 'Prvni'), aiQuestion('s2', 'Druha')],
    });

    await tester.pumpWidget(_wrap(block, completion));
    await tester.pumpAndSettle();

    // Both questions accept input even though evaluation stays sequential.
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(0), 'prvni odpoved');
    await tester.pumpAndSettle();
    expect(find.text('Zkontrolovat'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), 'druha odpoved');
    await tester.pumpAndSettle();
    expect(find.text('Zkontrolovat'), findsOneWidget);
  });

  testWidgets('single-question block keeps the old immediate flow',
      (tester) async {
    final completion = _Completion();
    final block = ContentBlock.fromJson({
      'block_id': 'TEST_SINGLE',
      'type': 'exercise',
      'steps': [
        {'id': 's0', 'type': 'text', 'order': 1, 'content': 'Zamysli se'},
        {
          'id': 's1',
          'type': 'question',
          'order': 2,
          'question': {
            'type': 'open',
            'question': 'Jaky byl statisticky soubor',
            'correct_answer': 'zaci',
            'solution': 'Reseni s1',
          },
        },
      ],
    });
    await tester.pumpWidget(_wrap(block, completion));
    await tester.pumpAndSettle();

    expect(find.text('Zkontrolovat'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'zaci');
    await tester.pumpAndSettle();
    expect(find.text('Zkontrolovat'), findsOneWidget);

    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();
    expect(find.text('Reseni s1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check).last);
    await tester.pumpAndSettle();
    expect(completion.done, isTrue);
    expect(completion.scoreKoef, closeTo(1.0, 0.001));
  });
}
