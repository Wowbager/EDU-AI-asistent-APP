import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/data/repositories/consent_repository.dart';
import 'package:eduai/pages/consent/consent_request_page.dart';

/// [ConsentRequestPage.onSubmit] returns a [ConsentActionResult], not a bare
/// bool — see the Task 11 "Watch out for" note in the plan. That is what lets
/// this screen tell "the request never reached the server" (offline, DNS,
/// timeout) apart from "the server said no", and therefore avoid ever
/// claiming "we emailed your parent" when nothing was actually sent.
void main() {
  Future<void> pump(WidgetTester tester, ConsentRequestPage page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  testWidgets('rejects an obviously invalid email without calling the API', (tester) async {
    var called = false;

    await pump(tester, ConsentRequestPage(
      country: 'CZ',
      onSubmit: (_) async {
        called = true;
        return const ConsentActionResult.success();
      },
      onEnterCode: () {},
      onBack: () {},
    ));

    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('Odeslat rodiči'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.textContaining('Zkontroluj e-mail'), findsOneWidget);
  });

  testWidgets('submits a valid email and shows the waiting screen on success', (tester) async {
    String? submitted;

    await pump(tester, ConsentRequestPage(
      country: 'CZ',
      onSubmit: (email) async {
        submitted = email;
        return const ConsentActionResult.success();
      },
      onEnterCode: () {},
      onBack: () {},
    ));

    await tester.enterText(find.byType(TextField), 'rodic@example.com');
    await tester.tap(find.text('Odeslat rodiči'));
    await tester.pumpAndSettle();

    expect(submitted, 'rodic@example.com');
    expect(find.textContaining('Poslali jsme rodiči e-mail'), findsOneWidget);
  });

  testWidgets('offers the code entry after the waiting delay', (tester) async {
    await pump(tester, ConsentRequestPage(
      country: 'CZ',
      waitingDuration: const Duration(milliseconds: 50),
      onSubmit: (_) async => const ConsentActionResult.success(),
      onEnterCode: () {},
      onBack: () {},
    ));

    await tester.enterText(find.byType(TextField), 'rodic@example.com');
    await tester.tap(find.text('Odeslat rodiči'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.text('Zadat kód'), findsOneWidget);
  });

  testWidgets('does not offer the code entry before the waiting delay elapses', (tester) async {
    await pump(tester, ConsentRequestPage(
      country: 'CZ',
      waitingDuration: const Duration(seconds: 10),
      onSubmit: (_) async => const ConsentActionResult.success(),
      onEnterCode: () {},
      onBack: () {},
    ));

    await tester.enterText(find.byType(TextField), 'rodic@example.com');
    await tester.tap(find.text('Odeslat rodiči'));
    await tester.pumpAndSettle();

    expect(find.text('Zadat kód'), findsNothing);
  });

  testWidgets(
      'a network failure (request never reached the server) stays on the form '
      'and never claims the parent was emailed', (tester) async {
    await pump(tester, ConsentRequestPage(
      country: 'CZ',
      onSubmit: (_) async => const ConsentActionResult.failure(ConsentFailure.network),
      onEnterCode: () {},
      onBack: () {},
    ));

    await tester.enterText(find.byType(TextField), 'rodic@example.com');
    await tester.tap(find.text('Odeslat rodiči'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Poslali jsme rodiči e-mail'), findsNothing);
    // Still on the form, offline-specific copy — distinct from the generic
    // "the server rejected it" message.
    expect(find.text('Odeslat rodiči'), findsOneWidget);
    expect(find.textContaining('zkontroluj připojení k internetu'), findsOneWidget);
    expect(find.textContaining('Něco se nepovedlo'), findsNothing);
  });

  testWidgets(
      'a rejected request (server responded, said no) shows the generic error, '
      'not the network one', (tester) async {
    await pump(tester, ConsentRequestPage(
      country: 'CZ',
      onSubmit: (_) async => const ConsentActionResult.failure(ConsentFailure.rejected),
      onEnterCode: () {},
      onBack: () {},
    ));

    await tester.enterText(find.byType(TextField), 'rodic@example.com');
    await tester.tap(find.text('Odeslat rodiči'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Poslali jsme rodiči e-mail'), findsNothing);
    expect(find.textContaining('Něco se nepovedlo'), findsOneWidget);
    expect(find.textContaining('zkontroluj připojení k internetu'), findsNothing);
  });

  testWidgets('the child can go back while waiting, before the code option appears', (tester) async {
    var wentBack = false;

    await pump(tester, ConsentRequestPage(
      country: 'CZ',
      waitingDuration: const Duration(seconds: 10),
      onSubmit: (_) async => const ConsentActionResult.success(),
      onEnterCode: () {},
      onBack: () => wentBack = true,
    ));

    await tester.enterText(find.byType(TextField), 'rodic@example.com');
    await tester.tap(find.text('Odeslat rodiči'));
    await tester.pumpAndSettle();

    // Well before the 10s delay elapses — going back must still work.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(wentBack, isTrue);
  });
}
