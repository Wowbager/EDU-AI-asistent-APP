import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/answer_photo_picker.dart';
import 'package:eduai/widgets/block_step_engine.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';

// Regression tests for BR-5FWNTK: "the AI writes 'Promýšlím tvou odpověď',
// but after a while it goes back to the state before 'Zkontrolovat' was
// pressed, with no check and no feedback — and the quiz cannot go on".
//
// A failed evaluation leaves the step unanswered on purpose, so the student can
// send it again. The notice saying so was drawn only for answered questions,
// though, so in a step block it never appeared: the spinner stopped and the
// question looked untouched. Since BR-N26ACB a typed answer falls back to the
// comparison instead of failing, which leaves a photographed answer as the one
// that still lands here.

ContentBlock _photoBlock({bool aiEvaluation = true}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_EVAL_FAILURE',
    'type': 'exercise',
    'steps': [
      {
        'id': 's1',
        'type': 'text',
        'order': 1,
        'content': 'Zjednoduš výraz a vyfoť postup.',
      },
      {
        'id': 's2',
        'type': 'question',
        'order': 2,
        'question': {
          'type': 'open',
          'question': 'Zjednoduš výraz 2a + 3a.',
          'correct_answer': '5a',
          'allow_photo': true,
          'ai_evaluation': aiEvaluation,
          'show_answers': true,
        },
      },
    ],
  });
}

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Fails every evaluation until [recover] is called, counting the attempts.
class _FlakyEvaluator implements AiAnswerEvaluator {
  _FlakyEvaluator({this.failure = AiEvaluationFailure.unavailable});

  final AiEvaluationFailure failure;
  bool _recovered = false;
  int calls = 0;

  void recover() => _recovered = true;

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      UploadedPhoto(name: filename, mimeType: 'image/png', size: bytes.length);

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
    if (!_recovered) return AiEvaluationOutcome.failed(failure);
    return const AiEvaluationOutcome.success(
        AiEvaluationResult(score: 1.0, isCorrect: true, feedbackText: ''));
  }
}

/// Bottom-bar stand-in mirroring QuizPage: a controller drives the engine and
/// the confirm button lives outside it.
class _QuizHarness extends StatefulWidget {
  const _QuizHarness({required this.block, this.hideEvaluation = false});
  final ContentBlock block;
  final bool hideEvaluation;

  @override
  State<_QuizHarness> createState() => _QuizHarnessState();
}

class _QuizHarnessState extends State<_QuizHarness> {
  final BlockStepEngineController _controller = BlockStepEngineController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              BlockStepEngine(
                block: widget.block,
                exportMode: ExportMode.quizV2,
                hideEvaluation: widget.hideEvaluation,
                showAnswerStatus: !widget.hideEvaluation,
                controller: _controller,
                onBlockCompleted: (
                        {int earnedXp = 0,
                        double scoreKoef = 1.0,
                        String? mark}) {},
              ),
              if (_controller.isShowingSolution)
                TextButton(
                  onPressed: _controller.continueAfterSolution,
                  child: const Text('Pokracovat'),
                )
              else
                TextButton(
                  onPressed:
                      _controller.hasPendingAnswer ? _controller.confirm : null,
                  child: const Text('Zkontrolovat'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _lessonHarness(ContentBlock block) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockStepEngine(
            block: block,
            exportMode: ExportMode.courseV2,
            onBlockCompleted: (
                    {int earnedXp = 0,
                    double scoreKoef = 1.0,
                    String? mark}) {},
          ),
        ),
      ),
    );

Widget _scoped(AiAnswerEvaluator evaluator, Widget child) => ProviderScope(
      overrides: [aiAnswerEvaluatorProvider.overrideWithValue(evaluator)],
      child: child,
    );

/// Hand the picked photo to the engine the way AnswerPhotoPicker does — the
/// real button opens the platform picker, which a widget test cannot answer.
Future<void> _attachPhoto(WidgetTester tester) async {
  final picker =
      tester.widget<AnswerPhotoPicker>(find.byType(AnswerPhotoPicker).first);
  picker.onPicked!(
      PickedAnswerPhoto(bytes: _pngBytes, filename: 'postup.png'));
  await tester.pumpAndSettle();
}

Future<void> _submitInQuiz(WidgetTester tester) async {
  await _attachPhoto(tester);
  await tester.tap(find.widgetWithText(TextButton, 'Zkontrolovat'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a quiz question whose evaluation failed says so',
      (tester) async {
    final evaluator = _FlakyEvaluator();
    await tester.pumpWidget(
        _scoped(evaluator, _QuizHarness(block: _photoBlock())));
    await tester.pumpAndSettle();

    await _submitInQuiz(tester);

    expect(evaluator.calls, 1);
    // The bug: nothing on screen but the untouched question.
    expect(find.byType(OpenAnswerRetryNotice), findsOneWidget);
    expect(find.text(AppStrings.openFeedbackFailed), findsOneWidget);
    expect(find.text(AppStrings.openFeedbackRetry), findsOneWidget);
  });

  testWidgets('the notice does not depend on the ai_evaluation switch',
      (tester) async {
    // Every open answer goes to the AI (BR-N26ACB); the switch only picks
    // whether its feedback is shown. A failure is not feedback.
    final evaluator = _FlakyEvaluator();
    await tester.pumpWidget(_scoped(
        evaluator, _QuizHarness(block: _photoBlock(aiEvaluation: false))));
    await tester.pumpAndSettle();

    await _submitInQuiz(tester);

    expect(find.byType(OpenAnswerRetryNotice), findsOneWidget);
  });

  testWidgets('nor on a quiz that hides its evaluation', (tester) async {
    // Hiding right/wrong is no reason to hide that nothing was evaluated —
    // the quiz's atomic card shows the notice there too.
    final evaluator = _FlakyEvaluator();
    await tester.pumpWidget(_scoped(
        evaluator, _QuizHarness(block: _photoBlock(), hideEvaluation: true)));
    await tester.pumpAndSettle();

    await _submitInQuiz(tester);

    expect(find.byType(OpenAnswerRetryNotice), findsOneWidget);
  });

  testWidgets('retrying from the notice evaluates again and moves on',
      (tester) async {
    final evaluator = _FlakyEvaluator();
    await tester.pumpWidget(
        _scoped(evaluator, _QuizHarness(block: _photoBlock())));
    await tester.pumpAndSettle();

    await _submitInQuiz(tester);
    expect(find.text('Pokracovat'), findsNothing);

    evaluator.recover();
    await tester.tap(find.text(AppStrings.openFeedbackRetry));
    await tester.pumpAndSettle();

    expect(evaluator.calls, 2);
    expect(find.byType(OpenAnswerRetryNotice), findsNothing);
    expect(find.text('Pokracovat'), findsOneWidget,
        reason: 'once graded, the quiz can continue to the next question');
  });

  testWidgets('a rejection that cannot be retried still explains itself',
      (tester) async {
    final evaluator =
        _FlakyEvaluator(failure: AiEvaluationFailure.notEvaluable);
    await tester.pumpWidget(
        _scoped(evaluator, _QuizHarness(block: _photoBlock())));
    await tester.pumpAndSettle();

    await _submitInQuiz(tester);

    expect(find.text(AppStrings.openFeedbackNotEvaluable), findsOneWidget);
    expect(find.text(AppStrings.openFeedbackRetry), findsNothing);
  });

  testWidgets('the lesson path shows it as well', (tester) async {
    final evaluator = _FlakyEvaluator();
    await tester.pumpWidget(_scoped(evaluator, _lessonHarness(_photoBlock())));
    await tester.pumpAndSettle();

    await _attachPhoto(tester);
    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();

    expect(evaluator.calls, 1);
    expect(find.byType(OpenAnswerRetryNotice), findsOneWidget);
  });
}
