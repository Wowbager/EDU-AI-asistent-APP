import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/strings/locale_manager.dart';
import 'package:eduai/pages/auth_page.dart';
import 'package:eduai/widgets/language_switcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-U75N5Y: the auth screen must offer a language switcher, because the only
// other picker lives in the profile — unreachable before login. The choice has
// to persist (SharedPreferences) so it survives logging in and restarting.
// ─────────────────────────────────────────────────────────────────────────────

/// Mirrors the app shell (`MyApp` in lib/app.dart): it listens to
/// [LocaleManager] and keys `MaterialApp` by the locale, which throws away the
/// element tree so the static `AppStrings.x` getters are re-read. Without this
/// the switcher would flip the locale but leave the visible strings stale.
class _LocaleShell extends StatefulWidget {
  const _LocaleShell({required this.child});

  final Widget child;

  @override
  State<_LocaleShell> createState() => _LocaleShellState();
}

class _LocaleShellState extends State<_LocaleShell> {
  @override
  void initState() {
    super.initState();
    LocaleManager.notifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleManager.notifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final locale = LocaleManager.current;
    return MaterialApp(
      key: ValueKey('app-locale-${locale.code}'),
      locale: locale.toFlutterLocale(),
      home: widget.child,
    );
  }
}

Future<SharedPreferences> _pumpAuthPage(WidgetTester tester) async {
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
      child: _LocaleShell(
        child: AuthPage(onEmailSubmit: (_) {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return prefs;
}

void main() {
  setUp(() {
    // Each test starts from the app default so ordering cannot leak state.
    LocaleManager.notifier.value = AppLocale.cs;
  });

  tearDown(() {
    LocaleManager.notifier.value = AppLocale.cs;
  });

  testWidgets('auth screen shows a switcher for every supported locale',
      (tester) async {
    await _pumpAuthPage(tester);

    expect(find.byType(LanguageSwitcher), findsOneWidget);
    for (final locale in AppLocale.values) {
      expect(find.text(locale.code.toUpperCase()), findsOneWidget);
    }
    // Czech is the default selection.
    expect(LocaleManager.current, AppLocale.cs);
  });

  testWidgets('tapping EN switches the locale and translates the screen',
      (tester) async {
    await _pumpAuthPage(tester);

    // The sign-in form has its own headline (authFormHeadline); authHeadline
    // is the marketing line on welcome_page / login_page — see BR-UWJD4M.
    final czechHeadline = AppStrings.authFormHeadline;
    expect(find.text(czechHeadline), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(LocaleManager.current, AppLocale.en);
    // AppStrings resolves against the active locale, so the headline changed.
    expect(AppStrings.authFormHeadline, isNot(czechHeadline));
    expect(find.text(AppStrings.authFormHeadline), findsOneWidget);
  });

  testWidgets('the picked locale is persisted and restored on next launch',
      (tester) async {
    final prefs = await _pumpAuthPage(tester);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(prefs.getString('app_locale'), 'en');

    // Simulate a fresh launch: main() calls LocaleManager.restore() before
    // runApp, which must bring the choice back — this is what makes the
    // language stick after logging in.
    LocaleManager.notifier.value = AppLocale.cs;
    await LocaleManager.restore();
    expect(LocaleManager.current, AppLocale.en);
  });
}
