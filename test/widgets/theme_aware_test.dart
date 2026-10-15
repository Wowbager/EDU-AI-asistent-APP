import 'package:eduai/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for BR-W3XQ5K: switching the color profile from the menu
/// left the screen underneath (dashboard, profile) painted in the old palette
/// until the user navigated elsewhere.
///
/// Route content is cached by Flutter (`_ModalScopeState._page`), so a screen
/// parked in the navigator stack is not rebuilt when the root rebuilds — it has
/// to listen to [ThemeManager] itself, which is what [ThemeAwareState] does.
void main() {
  const magenta = Color(0xFFFF00FF);

  final altTheme = ThemeConfig.fromJson({
    'name': 'Test',
    'colors': {'background': '#FF00FF'},
  });

  tearDown(() => ThemeManager.apply(ThemeConfig.defaultTheme));

  Color backgroundOf(WidgetTester tester) =>
      tester.widget<ColoredBox>(find.byKey(const Key('probe-surface'))).color;

  testWidgets('theme-aware screen repaints when the theme changes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ProbeScreen()));
    expect(backgroundOf(tester), ThemeConfig.defaultTheme.colors.background);

    ThemeManager.apply(altTheme);
    await tester.pump();

    expect(backgroundOf(tester), magenta);
  });

  testWidgets('repaints even while covered by a pushed route', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ProbeScreen()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // Stand-in for the menu → theme selector stack the bug was reported from.
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('menu'))),
    );
    await tester.pumpAndSettle();

    ThemeManager.apply(altTheme);
    await tester.pumpAndSettle();

    navigator.pop();
    await tester.pumpAndSettle();

    expect(backgroundOf(tester), magenta);
  });
}

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen();

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> with ThemeAwareState {
  @override
  Widget build(BuildContext context) {
    // Reads the static getter during build, exactly like the real screens.
    return ColoredBox(
      key: const Key('probe-surface'),
      color: AppColors.background,
      child: const SizedBox.expand(),
    );
  }
}
