import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/theme/app_colors.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// Regression test for BR-J3KNJS: a multi-select question with two correct
// options, answered with only one of them, is graded wrong — but nothing on
// screen said so. The one ticked card went green, its approving feedback
// followed, and the correct option left unticked stayed neutral grey, so the
// answer read as a pass.

ContentBlock _twoCorrectBlock({
  bool showAnswers = true,
}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_MCQ_MULTI',
    'type': 'exercise',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'question': {
          'type': 'multiple_choice',
          'allow_multiple': true,
          'show_answers': showAnswers,
          'question': 'Co udelas, kdyz si nebudes jisty',
          'solution': 'Reseni s1',
          'options': [
            {
              'id': 'a',
              'text': 'Oznacim si ji k procvicovani',
              'is_correct': true,
              'feedback': 'Vyborne, to je akademicky pristup.',
            },
            {
              'id': 'b',
              'text': 'Vypnu aplikaci',
              'is_correct': false,
              'feedback': 'Ale no tak.',
            },
            {
              'id': 'c',
              'text': 'Kliknu na otaznicek',
              'is_correct': true,
              'feedback': 'Jasne, za optani nic nedas.',
            },
          ],
        },
      },
    ],
  });
}

class _Completion {
  bool done = false;
  double? scoreKoef;
}

Widget _wrap(ContentBlock block, _Completion completion) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BlockStepEngine(
          block: block,
          onBlockCompleted: (
              {int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {
            completion.done = true;
            completion.scoreKoef = scoreKoef;
          },
        ),
      ),
    ),
  );
}

/// The fill colour of the feedback banner carrying [text].
Color _bannerColorOf(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration).color!;
}

/// The border colour the option card carrying [text] was painted with.
Color _borderColorOf(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.text(text), matching: find.byType(Container))
        .first,
  );
  final decoration = container.decoration as BoxDecoration;
  return decoration.border!.top.color;
}

/// Ticks one of the two correct options and submits. With `show_answers`
/// off the engine has no feedback to pause on, so the button reads "Další"
/// and the block finishes straight into its read-only history card.
Future<void> _answerWithOneOfTwo(
  WidgetTester tester, {
  String submitLabel = 'Zkontrolovat',
}) async {
  await tester.tap(find.text('Kliknu na otaznicek'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(submitLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one of two correct options is marked wrong, not correct',
      (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_twoCorrectBlock(), completion));
    await tester.pumpAndSettle();

    await _answerWithOneOfTwo(tester);

    // The verdict is stated, and it is the one the engine actually graded.
    expect(find.text('Špatně'), findsOneWidget);
    expect(find.text('Správně'), findsNothing);

    final continueButton = find.byIcon(Icons.check).last;
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(completion.scoreKoef, 0.0);
  });

  testWidgets('the correct option left unticked is marked red',
      (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_twoCorrectBlock(), completion));
    await tester.pumpAndSettle();

    await _answerWithOneOfTwo(tester);

    // Missed correct option: red. Ticked correct option: green. The wrong
    // option nobody touched stays neutral.
    expect(_borderColorOf(tester, 'Oznacim si ji k procvicovani'),
        AppColors.error);
    expect(_borderColorOf(tester, 'Kliknu na otaznicek'), AppColors.success);
    expect(_borderColorOf(tester, 'Vypnu aplikaci'), AppColors.primaryDark16);
  });

  testWidgets('ticking both correct options passes', (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_twoCorrectBlock(), completion));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oznacim si ji k procvicovani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kliknu na otaznicek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();

    expect(find.text('Správně'), findsOneWidget);
    expect(find.text('Špatně'), findsNothing);

    final continueButton = find.byIcon(Icons.check).last;
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(completion.scoreKoef, 1.0);
  });

  // BR-6AWJS2: the verdict row above says Špatně while the ticked option's own
  // feedback sat in a green success banner under a tick — the same answer
  // called right and wrong at once.
  testWidgets('the ticked option feedback does not read as approval',
      (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_twoCorrectBlock(), completion));
    await tester.pumpAndSettle();

    await _answerWithOneOfTwo(tester);

    // The author's words stay, the success styling goes.
    expect(find.text('Jasne, za optani nic nedas.'), findsOneWidget);
    expect(_bannerColorOf(tester, 'Jasne, za optani nic nedas.'),
        AppColors.orangeBg);
    // Nothing on a wrong answer wears the tick: not the verdict (Icons.cancel),
    // not the option cards (checkboxes), and now not the feedback either.
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('a fully correct answer keeps its approving feedback',
      (tester) async {
    final completion = _Completion();
    await tester.pumpWidget(_wrap(_twoCorrectBlock(), completion));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oznacim si ji k procvicovani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kliknu na otaznicek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();

    expect(_bannerColorOf(tester, 'Jasne, za optani nic nedas.'),
        AppColors.successBg);
    expect(_bannerColorOf(tester, 'Vyborne, to je akademicky pristup.'),
        AppColors.successBg);
  });

  testWidgets('show_answers=false states the verdict without revealing the miss',
      (tester) async {
    final completion = _Completion();
    await tester
        .pumpWidget(_wrap(_twoCorrectBlock(showAnswers: false), completion));
    await tester.pumpAndSettle();

    await _answerWithOneOfTwo(tester, submitLabel: 'Další');

    // The student still learns the answer was wrong — that is a verdict, not
    // a reveal — but the option they missed is not pointed out.
    expect(find.text('Špatně'), findsOneWidget);
    expect(_borderColorOf(tester, 'Oznacim si ji k procvicovani'),
        AppColors.primaryDark16);
  });
}
