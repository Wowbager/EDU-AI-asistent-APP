import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:eduai/pages/legal/legal_page.dart';
import 'package:eduai/routing/app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-QVMBDN: tapping a document in the legal footer changed the URL but left
// the previously rendered document ("Podmínky") on screen.
//
// The footer picked its navigation strategy from `kIsWeb` instead of from
// `inAppMode`, so the two modes were crossed:
//   • public web route  → took the imperative branch, URL never followed;
//   • in-app pushed page → called context.go, which swapped the router stack
//     *underneath* the imperatively pushed route (the reported symptom).
//
// These tests pin the strategy to `inAppMode` from both sides. Note kIsWeb is
// false under `flutter test`, so the first group is what fails on the old code.
// ─────────────────────────────────────────────────────────────────────────────

const _termsHeading = 'Podmínky užívání aplikace EDU AI asistent';
const _cookiesHeading = 'Prohlášení o cookies a obdobných technologiích';
const _accessibilityHeading = 'Prohlášení o přístupnosti';
const _cookiesHeadingEn = 'Cookie and Similar Technologies Statement';
const _termsHeadingEn = 'Terms of Use of the EDU AI assistant application';

/// Wide/tall viewport so the markdown heading and the footer are both laid out
/// without the test-only Ahem font overflowing.
void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

/// Waits until the markdown asset is rendered. `pumpAndSettle` is unusable
/// here: while the asset is in flight [LegalPage] shows a
/// [CircularProgressIndicator], which never stops scheduling frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      // Lay out the freshly built markdown and let the route transition end —
      // until it does, the outgoing document is still mounted.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  fail('legal document did not finish loading');
}

/// Boots the real router straight onto a legal route. Starting at `/` would
/// build [AuthWrapper], which needs a ProviderScope, a database and network —
/// none of which this test is about.
Future<(GoRouter, GlobalKey<NavigatorState>)> _pumpRouterAt(
  WidgetTester tester,
  String location,
) async {
  _useLargeViewport(tester);

  final navigatorKey = GlobalKey<NavigatorState>();
  final router =
      buildAppRouter(navigatorKey: navigatorKey, initialLocation: location);
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _settle(tester);

  return (router, navigatorKey);
}

void main() {
  // `rootBundle` is a process-global CachingAssetBundle that caches the *Future*
  // of each asset. Every `testWidgets` runs in its own fake-async zone, so a
  // future cached by one test can never deliver its value to the next one and
  // LegalPage would spin forever. Drop the cache between tests.
  setUp(rootBundle.clear);

  group('public web legal page navigates through the router', () {
    testWidgets('footer link updates the URL and the document', (tester) async {
      final (router, _) = await _pumpRouterAt(tester, '/terms');
      expect(find.text(_termsHeading), findsOneWidget);

      await tester.tap(find.text('Cookies'));
      await _settle(tester);

      expect(router.state.uri.path, '/cookies');
      expect(find.text(_cookiesHeading), findsOneWidget);
      expect(find.text(_termsHeading), findsNothing);
    });

    testWidgets('footer link keeps the locale on the /en routes',
        (tester) async {
      final (router, _) = await _pumpRouterAt(tester, '/terms/en');

      await tester.tap(find.text('Cookies'));
      await _settle(tester);

      expect(router.state.uri.path, '/cookies/en');
      expect(find.text(_cookiesHeadingEn), findsOneWidget);
    });
  });

  group('legal routes render the document they point at', () {
    testWidgets('go() from /terms to /cookies swaps the rendered document',
        (tester) async {
      final (router, _) = await _pumpRouterAt(tester, '/terms');
      expect(find.text(_termsHeading), findsOneWidget);

      router.go('/cookies');
      await _settle(tester);

      expect(find.text(_cookiesHeading), findsOneWidget);
      expect(find.text(_termsHeading), findsNothing);
    });

    testWidgets('go() to a second document keeps swapping (terms → accessibility)',
        (tester) async {
      final (router, _) = await _pumpRouterAt(tester, '/terms');

      router.go('/accessibility');
      await _settle(tester);

      expect(find.text(_accessibilityHeading), findsOneWidget);
      expect(find.text(_termsHeading), findsNothing);
    });

    testWidgets('go() to the /en variant renders the English document',
        (tester) async {
      final (router, _) = await _pumpRouterAt(tester, '/cookies');

      router.go('/cookies/en');
      await _settle(tester);

      expect(find.text(_cookiesHeadingEn), findsOneWidget);
      expect(find.text(_cookiesHeading), findsNothing);
    });
  });

  group('in-app legal page', () {
    testWidgets('footer link swaps the document and keeps the back button',
        (tester) async {
      _useLargeViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: LegalPage(slug: 'terms', locale: 'cs', inAppMode: true),
        ),
      );
      await _settle(tester);

      expect(find.text(_termsHeading), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.text('Cookies'));
      await _settle(tester);

      expect(find.text(_cookiesHeading), findsOneWidget);
      expect(find.text(_termsHeading), findsNothing);
      // Still in-app: back button, not the public-web "home" affordance.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.home), findsNothing);
    });

    testWidgets('language pill switches locale without leaving the stack',
        (tester) async {
      _useLargeViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: LegalPage(slug: 'terms', locale: 'cs', inAppMode: true),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('→ EN'));
      await _settle(tester);

      expect(find.text(_termsHeadingEn), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('public web header', () {
    testWidgets('language pill moves to the /en route', (tester) async {
      final (router, _) = await _pumpRouterAt(tester, '/terms');

      await tester.tap(find.text('→ EN'));
      await _settle(tester);

      expect(router.state.uri.path, '/terms/en');
      expect(find.text(_termsHeadingEn), findsOneWidget);
      // Public web shows "home", never a back button.
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}
