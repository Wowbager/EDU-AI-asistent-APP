// BR-PJUUZZ — true/false buttons read "True (Ano)" / "False (Ne)".
//
// That text is not the author's: the admin editor seeds it when a question is
// switched to true/false and offers no field to change it. The app printed it
// verbatim, so every student saw the same half-English label whatever their
// language. Those two seeded options now get a label in the app's locale;
// anything an author actually wrote is still shown as written.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/strings/locale_manager.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

void main() {
  BlockStep trueFalseStep(String trueText, String falseText) => BlockStep(
        stepId: 's1',
        type: StepType.question,
        evaluationConfig: EvaluationConfig(
          type: 'true_false',
          question: 'Dívčí tým C bude mít méně bodů než tým A.',
          options: [
            EvaluationOption(id: 'true', text: trueText, isCorrect: true),
            EvaluationOption(id: 'false', text: falseText),
          ],
        ),
      );

  // The exact pair the admin's QuestionStepEditor writes.
  final adminSeeded = trueFalseStep('True (Ano)', 'False (Ne)');

  Future<void> pump(WidgetTester tester, BlockStep step) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: StepContentRenderer(step: step)),
      ),
    ));
  }

  tearDown(() => LocaleManager.notifier.value = AppLocale.cs);

  testWidgets('admin-seeded options show Czech labels', (tester) async {
    LocaleManager.notifier.value = AppLocale.cs;
    await pump(tester, adminSeeded);

    expect(find.textContaining('Ano'), findsOneWidget);
    expect(find.textContaining('Ne'), findsOneWidget);
    expect(find.textContaining('True'), findsNothing);
    expect(find.textContaining('False'), findsNothing);
  });

  testWidgets('admin-seeded options follow the app locale', (tester) async {
    LocaleManager.notifier.value = AppLocale.en;
    await pump(tester, adminSeeded);

    expect(find.textContaining('True'), findsOneWidget);
    expect(find.textContaining('False'), findsOneWidget);
    expect(find.textContaining('Ano'), findsNothing);
  });

  testWidgets('options with no text get a label too', (tester) async {
    LocaleManager.notifier.value = AppLocale.sk;
    await pump(tester, trueFalseStep('', ' '));

    expect(find.textContaining('Áno'), findsOneWidget);
    expect(find.textContaining('Nie'), findsOneWidget);
  });

  testWidgets('labels an author wrote are left alone', (tester) async {
    LocaleManager.notifier.value = AppLocale.en;
    await pump(tester, trueFalseStep('Ano, je to pravda', 'Ne, není to pravda'));

    expect(find.textContaining('Ano, je to pravda'), findsOneWidget);
    expect(find.textContaining('Ne, není to pravda'), findsOneWidget);
  });

  test('the label is resolved on read, not frozen at parse time', () {
    LocaleManager.notifier.value = AppLocale.cs;
    final option = EvaluationOption.fromJson(
        {'id': 'true', 'text': 'True (Ano)', 'is_correct': true});

    expect(option.label, 'Ano');
    LocaleManager.notifier.value = AppLocale.en;
    expect(option.label, 'True');
    // The stored text is untouched — it is what older app builds still show.
    expect(option.text, 'True (Ano)');
  });
}
