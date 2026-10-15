import 'package:eduai/core/strings/locale_manager.dart';
import 'package:eduai/widgets/global_quiz_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dashboard quiz opens this dialog under the heading "Co chceš
/// procvičovat?", which reads as the FSRS Procvičování picker rather than a
/// quiz. It now asks "Z čeho si dáš kvíz?" (BR-XPHKV2). The literal is pinned
/// on purpose: the bug is the copy itself, so comparing against the getter
/// would pass whatever it said.
void main() {
  tearDown(() => LocaleManager.notifier.value = AppLocale.cs);

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: GlobalQuizEntryDialog(
          domains: [],
          domainNames: {},
          courses: [],
        ),
      ),
    ));
  }

  testWidgets('asks what the quiz should come from', (tester) async {
    await pump(tester);

    expect(find.text('Z čeho si dáš kvíz?'), findsOneWidget);
    expect(find.text('Co chceš procvičovat?'), findsNothing);
  });

  testWidgets('says the same in Slovak', (tester) async {
    LocaleManager.notifier.value = AppLocale.sk;
    await pump(tester);

    expect(find.text('Z čoho si dáš kvíz?'), findsOneWidget);
  });

  testWidgets('says the same in English', (tester) async {
    LocaleManager.notifier.value = AppLocale.en;
    await pump(tester);

    expect(find.text('What should your quiz cover?'), findsOneWidget);
  });
}
