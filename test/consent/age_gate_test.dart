import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/consent/age_threshold.dart';
import 'package:eduai/pages/consent/age_gate_page.dart';

/// AgeGatePage has two mandatory steps, in this order:
///  1. Confirm the country (CZ/SK, shown as two large tappable options — not
///     a dropdown). [AgeThreshold.detectCountry] pre-selects a guess, but
///     the guess must be explicitly confirmed via "Pokračovat" before the
///     age question appears; it is never silently accepted.
///  2. The age question for the confirmed country's threshold.
///
/// This is a deliberate deviation from the plan's original single-step
/// snippet (dropdown next to the Yes/No buttons) per the Task 13 blockquote:
/// the country must be an unmissable, explicit step, not a detail tucked
/// next to unrelated buttons.
void main() {
  tearDown(AgeThreshold.resetForTest);

  Future<void> pump(WidgetTester tester, AgeGatePage page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  Future<void> confirmCountry(WidgetTester tester) async {
    await tester.tap(find.text('Pokračovat'));
    await tester.pumpAndSettle();
  }

  group('country step', () {
    testWidgets('shows both country options and no age question yet', (tester) async {
      await pump(tester, AgeGatePage(
        initialCountry: 'CZ',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
      ));

      expect(find.text('CZ'), findsOneWidget);
      expect(find.text('SK'), findsOneWidget);
      expect(find.textContaining('15'), findsNothing);
      expect(find.textContaining('16'), findsNothing);
    });

    testWidgets('Continue is disabled until a recognised country is selected', (tester) async {
      // 'US' is not one of the two markets this gate supports, so neither
      // chip is pre-selected — Continue must not silently carry an
      // unrecognised guess through to the age question.
      await pump(tester, AgeGatePage(
        initialCountry: 'US',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
      ));

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pokračovat'));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('CZ'));
      await tester.pumpAndSettle();

      final buttonAfter = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pokračovat'));
      expect(buttonAfter.onPressed, isNotNull);
    });

    testWidgets('selecting a different country changes the threshold shown next', (tester) async {
      await pump(tester, AgeGatePage(
        initialCountry: 'CZ',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
      ));

      await tester.tap(find.text('SK'));
      await tester.pumpAndSettle();
      await confirmCountry(tester);

      expect(find.textContaining('16'), findsOneWidget);
      expect(find.textContaining('15'), findsNothing);
    });
  });

  group('country list follows the server, not a hardcoded pair', () {
    testWidgets('a server-added market (PL) shows up as a real option', (tester) async {
      AgeThreshold.applyServerConfig(
        thresholds: {'CZ': 15, 'SK': 16, 'PL': 13},
        defaultThreshold: 14,
      );

      await pump(tester, AgeGatePage(
        initialCountry: 'PL',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
      ));

      expect(find.text('CZ'), findsOneWidget);
      expect(find.text('SK'), findsOneWidget);
      expect(find.text('PL'), findsOneWidget);

      await confirmCountry(tester);

      expect(find.textContaining('13'), findsOneWidget);
    });

    testWidgets('a long country list scrolls instead of overflowing a short screen', (tester) async {
      // Deliberately short viewport: on a normal phone height this many
      // options would not need to scroll, so shrink the surface to force
      // the case where the content genuinely does not fit.
      tester.view.physicalSize = const Size(800, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final manyCountries = {
        for (final c in [
          'CZ', 'SK', 'PL', 'DE', 'AT', 'HU', 'FR', 'IT', 'ES', 'NL', 'BE', 'PT', 'SE', 'FI', 'DK',
        ])
          c: 15,
      };
      AgeThreshold.applyServerConfig(thresholds: manyCountries, defaultThreshold: 15);

      await pump(tester, AgeGatePage(
        initialCountry: 'CZ',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
      ));

      // If the country step still used an unbounded Column with Spacer()s,
      // this many options on a 420px-tall surface would throw a RenderFlex
      // overflow and fail pumpAndSettle outright. Reaching this point at all
      // is the "does not overflow" assertion; the loop below additionally
      // confirms every option is actually reachable (mounted, just possibly
      // scrolled off-screen), not silently dropped.
      for (final country in manyCountries.keys) {
        expect(find.text(country), findsOneWidget);
      }
    });
  });

  group('age step', () {
    testWidgets('shows 15 for CZ once confirmed', (tester) async {
      await pump(tester, AgeGatePage(
        initialCountry: 'CZ',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
      ));

      await confirmCountry(tester);

      expect(find.textContaining('15'), findsOneWidget);
    });

    testWidgets('shows 16 for SK once confirmed', (tester) async {
      await pump(tester, AgeGatePage(
        initialCountry: 'SK',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
      ));

      await confirmCountry(tester);

      expect(find.textContaining('16'), findsOneWidget);
    });

    testWidgets('"yes" hands off to the normal login', (tester) async {
      var oldEnough = false;

      await pump(tester, AgeGatePage(
        initialCountry: 'CZ',
        onOldEnough: () => oldEnough = true,
        onNeedsConsent: (_) {},
      ));

      await confirmCountry(tester);
      await tester.tap(find.text('Ano'));
      await tester.pumpAndSettle();

      expect(oldEnough, isTrue);
    });

    testWidgets('"no" starts the consent flow with the confirmed country', (tester) async {
      String? country;

      await pump(tester, AgeGatePage(
        initialCountry: 'SK',
        onOldEnough: () {},
        onNeedsConsent: (c) => country = c,
      ));

      await confirmCountry(tester);
      await tester.tap(find.text('Ne'));
      await tester.pumpAndSettle();

      expect(country, 'SK');
    });

    testWidgets('going back from the age step returns to the country step, not out of the gate', (tester) async {
      var leftGateEntirely = false;

      await pump(tester, AgeGatePage(
        initialCountry: 'CZ',
        onOldEnough: () {},
        onNeedsConsent: (_) {},
        onBack: () => leftGateEntirely = true,
      ));

      await confirmCountry(tester);
      expect(find.textContaining('15'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Back on the country step — the age question is gone again.
      expect(find.textContaining('15'), findsNothing);
      expect(find.text('CZ'), findsOneWidget);
      expect(leftGateEntirely, isFalse);
    });
  });

  group('Android hardware back (PopScope)', () {
    // The software arrow (tested above) is one way to trigger the age→country
    // step-back, but Android's hardware/gesture back does not go through that
    // IconButton at all — it asks the current Route to pop directly. This
    // reproduces main_screen.dart's real setup, where AuthPage (and this gate
    // inside it) is pushed as its own MaterialPageRoute, so a bare Navigator
    // push is the right harness rather than pumping AgeGatePage as `home`.
    Future<void> pushGate(WidgetTester tester, GlobalKey<NavigatorState> key) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: Center(child: Text('behind the gate'))),
      ));

      key.currentState!.push(MaterialPageRoute(
        builder: (_) => AgeGatePage(
          initialCountry: 'CZ',
          onOldEnough: () {},
          onNeedsConsent: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('on the age step, hardware back steps to country selection instead of leaving the gate',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await pushGate(tester, navigatorKey);

      await confirmCountry(tester);
      expect(find.textContaining('15'), findsOneWidget);

      // Simulate the Android/system back button (bypasses the software arrow
      // entirely — this is exactly what PopScope intercepts).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Still inside the gate, but back on the (unconfirmed) country step.
      expect(find.byType(AgeGatePage), findsOneWidget);
      expect(find.textContaining('15'), findsNothing);
      expect(find.text('CZ'), findsOneWidget);
    });

    testWidgets('on the country step, hardware back genuinely leaves the gate', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await pushGate(tester, navigatorKey);

      // Still on the country step — nothing left inside the gate to step
      // back through, so this pop is allowed to proceed.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AgeGatePage), findsNothing);
      expect(find.text('behind the gate'), findsOneWidget);
    });

    testWidgets('two hardware backs from the age step land outside the gate, not skip a step',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await pushGate(tester, navigatorKey);

      await confirmCountry(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AgeGatePage), findsOneWidget); // first back: still in the gate

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AgeGatePage), findsNothing); // second back: now it leaves
      expect(find.text('behind the gate'), findsOneWidget);
    });
  });
}
