import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// Regression test for BR-E6MWSB: feedback renders below the question, so on a
// step with tall content (the report: a full-width image) the graded answer
// landed off-screen and the student had to scroll to find out how they did.
// Evaluating an answer must bring the feedback into view.

const _tallPrompt = 'Zadani ktere zabere celou obrazovku.\n';

ContentBlock _questionBlock({required bool withFeedback}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_SCROLL',
    'type': 'question',
    'steps': [
      {'id': 's1', 'type': 'text', 'order': 1, 'content': _tallPrompt * 40},
      {
        'id': 's2',
        'type': 'question',
        'order': 2,
        'question': {
          'type': 'multiple_choice',
          'options': [
            {
              'id': 'opt_1',
              'text': 'Dva',
              'is_correct': true,
              if (withFeedback) 'feedback': 'Vyborne, presne tak',
            },
            {
              'id': 'opt_2',
              'text': 'Tri',
              'is_correct': false,
              if (withFeedback) 'feedback': 'Pozor na zavazi',
            },
          ],
          'show_answers': true,
        },
      },
    ],
  });
}

/// An exercise card that renders three questions side by side and grades them
/// in one tap. Numeric, because a block holding an open question is graded by
/// AI one question at a time instead (BR-N26ACB).
ContentBlock _multiQuestionBlock() {
  Map<String, dynamic> question(String id) => {
        'id': id,
        'type': 'question',
        'order': 1,
        'question': {
          'type': 'numeric',
          'question': 'Otazka $id',
          'correct_number': 4,
          'solution': 'Reseni $id',
        },
      };

  return ContentBlock.fromJson({
    'block_id': 'TEST_SCROLL_MULTI',
    'type': 'exercise',
    'steps': [
      {'id': 's0', 'type': 'text', 'order': 1, 'content': _tallPrompt * 40},
      question('s1'),
      question('s2'),
      question('s3'),
    ],
  });
}

Widget _wrap(
  ContentBlock block,
  ScrollController controller, {
  BlockStepEngineController? engineController,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 300,
        child: SingleChildScrollView(
          controller: controller,
          child: BlockStepEngine(
            block: block,
            controller: engineController,
            onBlockCompleted: ({int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {},
          ),
        ),
      ),
    ),
  );
}

/// Whether [finder]'s widget sits inside the 300px viewport of [_wrap].
bool _isOnScreen(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  return rect.top >= 0 && rect.bottom <= 300;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('evaluating an answer scrolls its feedback into view',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    // The reported screen is a quiz: the confirm button lives in the page's
    // bottom bar, so the answer can be graded while the student is looking at
    // the question — the image, in the report — and not at the options.
    final engineController = BlockStepEngineController();
    addTearDown(engineController.dispose);

    await tester.pumpWidget(_wrap(
      _questionBlock(withFeedback: true),
      controller,
      engineController: engineController,
    ));
    await tester.pumpAndSettle();

    // The options sit below the tall prompt, so answering means scrolling
    // there — and then scrolling back up to re-read the question.
    await _scrollTo(tester, find.text('Tri'));
    await tester.tap(find.text('Tri'));
    await tester.pumpAndSettle();

    controller.jumpTo(0);
    await tester.pumpAndSettle();

    engineController.confirm();
    await tester.pumpAndSettle();

    // The feedback is on screen, not somewhere below the fold.
    expect(find.text('Pozor na zavazi'), findsOneWidget);
    expect(_isOnScreen(tester, find.text('Pozor na zavazi')), isTrue,
        reason: 'feedback must be scrolled into view after evaluation');
    expect(controller.offset, greaterThan(0.0),
        reason: 'the view moved down to the feedback');
  });

  testWidgets('a multi-question block anchors only the question being answered',
      (tester) async {
    // The anchor is a GlobalKey, so a card that renders several questions at
    // once must hand it to exactly one of them — two would throw on build.
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(_multiQuestionBlock(), controller));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.enterText(find.byType(TextField).at(i), '3');
      await tester.pumpAndSettle();
    }

    await _scrollTo(tester, find.text('Zkontrolovat'));
    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The batch lands on the last question, so its solution is what the
    // student is scrolled to.
    expect(_isOnScreen(tester, find.text('Reseni s3')), isTrue);
  });
}
