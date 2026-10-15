import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/widgets/auth_hero_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-UDENF8. The logo is one single-fill mark recoloured by a `srcIn` filter,
// and in-app that filter follows the active skin on purpose — a custom theme
// carries the logo with it.
//
// The auth journey is the exception. A skin outlives the session that chose
// it: `_restoreSavedTheme` reapplies the saved palette at boot before anything
// knows whether the user is still signed in, and `resetToDefault()` only runs
// on a clean logout. So an expired session lands on a login screen wearing the
// previous user's colours. These pin the auth wordmark to the brand purple no
// matter what is applied.
// ─────────────────────────────────────────────────────────────────────────────

/// A skin whose `progressFill` is nothing like the brand purple — the blue the
/// report screenshot was taken in.
final _blueSkin = ThemeConfig(
  name: 'Ocean',
  version: 1,
  colors: ThemeColors.fromJson(const {'progressFill': '#64B5F6'}),
  typography: ThemeTypography.defaults,
  radii: ThemeRadii.defaults,
);

Future<ColorFilter?> _pumpWordmarkFilter(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(home: Center(child: buildAuthWordmark(width: 276))),
  );
  return tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter;
}

void main() {
  setUp(() => ThemeManager.apply(ThemeConfig.defaultTheme));
  tearDown(() => ThemeManager.apply(ThemeConfig.defaultTheme));

  test('the pinned colour is the default palette, not a stray literal', () {
    expect(kAuthWordmarkColour, ThemeColors.defaults.progressFill);
  });

  testWidgets('the auth wordmark keeps the brand purple under a skin',
      (tester) async {
    ThemeManager.apply(_blueSkin);
    expect(AppColors.progressFill, _blueSkin.colors.progressFill);

    expect(
      await _pumpWordmarkFilter(tester),
      ColorFilter.mode(kAuthWordmarkColour, BlendMode.srcIn),
    );
  });

  testWidgets('and renders identically on the default theme', (tester) async {
    expect(
      await _pumpWordmarkFilter(tester),
      ColorFilter.mode(kAuthWordmarkColour, BlendMode.srcIn),
    );
  });
}
