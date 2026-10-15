import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/widgets/answer_photo_picker.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// Regression tests for BR-HF7F2H: an open question with allow_photo may be
// answered with text, with a photo, or with both. Attaching only a photo used
// to leave the student stuck — the engine's confirm button stayed disabled in
// the lesson path, and in the controller-driven (quiz/practice) path the button
// lit up but _confirmAnswer bailed on the missing StepAnswerState, so the tap
// did nothing at all. The API has always accepted a photo-only attempt.
//
// Every open answer is graded by AI (BR-N26ACB), so submitting goes through a
// stand-in evaluator that takes the photo and grades it off the network — the
// gating being tested sits in front of it either way.

ContentBlock _photoBlock() {
  return ContentBlock.fromJson({
    'block_id': 'TEST_PHOTO_ONLY',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'question': {
          'type': 'open',
          'question': 'Spočítej příklad a vyfoť řešení',
          'correct_answer': '42',
          'allow_photo': true,
          'ai_evaluation': false,
          'show_answers': true,
        },
      },
    ],
  });
}

/// A real 1x1 PNG — the picker renders a thumbnail with Image.memory, which
/// throws on anything that is not decodable.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

PickedAnswerPhoto _photo() => PickedAnswerPhoto(
      bytes: _pngBytes,
      filename: 'reseni.png',
    );

/// Takes the upload and grades whatever it is sent, off the network.
class _PhotoEvaluator implements AiAnswerEvaluator {
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
  }) async =>
      const AiEvaluationOutcome.success(
          AiEvaluationResult(score: 1.0, isCorrect: true, feedbackText: ''));
}

Widget _scoped(Widget child) => ProviderScope(
      overrides: [
        aiAnswerEvaluatorProvider.overrideWithValue(_PhotoEvaluator()),
      ],
      child: child,
    );

/// Hand the picked photo to the engine the way AnswerPhotoPicker does. Tapping
/// the real button would open the platform image picker, which a widget test
/// has no way to answer.
Future<void> attachPhoto(WidgetTester tester) async {
  final picker = tester.widget<AnswerPhotoPicker>(
    find.byType(AnswerPhotoPicker).first,
  );
  expect(
    picker.onPicked,
    isNotNull,
    reason: 'the picker must be interactive on an unanswered question',
  );
  picker.onPicked!(_photo());
  await tester.pumpAndSettle();
}

/// Bottom-bar stand-in mirroring QuizPage: the engine's own button is hidden
/// when a controller drives it, so the button lives out here.
class _ControllerHarness extends StatefulWidget {
  const _ControllerHarness({required this.block});
  final ContentBlock block;

  @override
  State<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends State<_ControllerHarness> {
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

/// The in-lesson path: no controller, so the engine renders its own button.
/// It only grows a "Zkontrolovat" label once there is something to submit —
/// otherwise it stays a bare checkmark that just nags for an answer.
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

void main() {
  testWidgets('photo alone enables the in-lesson confirm button',
      (tester) async {
    await tester.pumpWidget(_scoped(_lessonHarness(_photoBlock())));
    await tester.pumpAndSettle();

    // Nothing submitted yet, so no labelled button.
    expect(find.text('Zkontrolovat'), findsNothing);

    await attachPhoto(tester);

    // This is the case the bug report describes: the photo IS the answer, but
    // the button stayed dead because only text and option picks were counted.
    expect(find.text('Zkontrolovat'), findsOneWidget);
  });

  testWidgets('photo alone enables the controller-driven confirm button',
      (tester) async {
    await tester.pumpWidget(_scoped(_ControllerHarness(block: _photoBlock())));
    await tester.pumpAndSettle();

    // Nothing entered yet — nothing to submit.
    final button = find.widgetWithText(TextButton, 'Zkontrolovat');
    expect(tester.widget<TextButton>(button).onPressed, isNull);

    await attachPhoto(tester);

    // The photo is the answer: the bar must offer to submit it.
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
  });

  testWidgets('confirming a photo-only answer actually submits it',
      (tester) async {
    await tester.pumpWidget(_scoped(_ControllerHarness(block: _photoBlock())));
    await tester.pumpAndSettle();

    await attachPhoto(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Zkontrolovat'));
    await tester.pumpAndSettle();

    // The answer was applied and the engine moved on to its solution state.
    // Before the fix the tap was a silent no-op: _confirmAnswer bailed on the
    // missing StepAnswerState and the bar still read "Zkontrolovat".
    expect(find.text('Pokracovat'), findsOneWidget);
    expect(find.text('Zkontrolovat'), findsNothing);
  });

  testWidgets('removing the photo disables the button again', (tester) async {
    await tester.pumpWidget(_scoped(_ControllerHarness(block: _photoBlock())));
    await tester.pumpAndSettle();

    await attachPhoto(tester);
    final button = find.widgetWithText(TextButton, 'Zkontrolovat');
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);

    final picker = tester.widget<AnswerPhotoPicker>(
      find.byType(AnswerPhotoPicker).first,
    );
    picker.onRemoved!();
    await tester.pumpAndSettle();

    // Back to an empty answer — an enabled button here would be a dead tap.
    expect(tester.widget<TextButton>(button).onPressed, isNull);
  });

  testWidgets('the attach-photo affordance is a full-width filled button',
      (tester) async {
    await tester.pumpWidget(_scoped(_ControllerHarness(block: _photoBlock())));
    await tester.pumpAndSettle();

    // BR-HF7F2H asked for prominence: students answering on paper never found
    // the old left-aligned TextButton.
    expect(
      find.descendant(
        of: find.byType(AnswerPhotoPicker),
        matching: find.byType(ElevatedButton),
      ),
      findsOneWidget,
    );
  });
}
