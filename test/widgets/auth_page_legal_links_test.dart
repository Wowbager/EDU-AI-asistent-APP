import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/pages/auth_page.dart';
import 'package:eduai/pages/privacy_page.dart';
import 'package:eduai/pages/terms_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The terms / privacy links on the auth screen must open the in-app legal
// pages. They used to be dead (empty onTap / RichText without a recognizer).
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _pumpAuthPage(
  WidgetTester tester, {
  required bool startInLoginMode,
}) async {
  // Tall viewport so the links at the bottom of the scroll view are on
  // screen and the test font metrics don't overflow the social buttons.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  // The test-only Ahem font is much wider than the real font, so the social
  // button labels overflow their 400px cap. Cosmetic and test-only — ignore.
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: AuthPage(
          onEmailSubmit: (_) {},
          startInLoginMode: startInLoginMode,
        ),
      ),
    ),
  );
  // Let the mode animation finish without waiting on network futures.
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('welcome screen terms link opens TermsPage', (tester) async {
    await _pumpAuthPage(tester, startInLoginMode: false);

    await tester.ensureVisible(find.text(AppStrings.authTerms));
    await tester.tap(find.text(AppStrings.authTerms));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TermsPage), findsOneWidget);
  });

  testWidgets('welcome screen privacy link opens PrivacyPage', (tester) async {
    await _pumpAuthPage(tester, startInLoginMode: false);

    await tester.ensureVisible(find.text(AppStrings.authPrivacy));
    await tester.tap(find.text(AppStrings.authPrivacy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PrivacyPage), findsOneWidget);
  });

  testWidgets('sign-up screen terms span opens TermsPage', (tester) async {
    await _pumpAuthPage(tester, startInLoginMode: true);

    await tester.tapOnText(
      find.textRange.ofSubstring(AppStrings.authTermsLink),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TermsPage), findsOneWidget);
  });

  testWidgets('sign-up screen privacy span opens PrivacyPage', (tester) async {
    await _pumpAuthPage(tester, startInLoginMode: true);

    await tester.tapOnText(
      find.textRange.ofSubstring(AppStrings.authPrivacyLink),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PrivacyPage), findsOneWidget);
  });
}
