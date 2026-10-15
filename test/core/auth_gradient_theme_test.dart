import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/theme/theme_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The auth background gradient has its own two theme colours so it can match
// the design exactly. Reusing gradientPurple/primaryDark would have meant
// repainting the ~260 places primaryDark drives text and buttons (BR-UWJD4M).
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  test('defaults carry the design gradient', () {
    expect(ThemeColors.defaults.authGradientTop, const Color(0xFF806DB9));
    expect(ThemeColors.defaults.authGradientBottom, const Color(0xFF4B378B));
  });

  test('an explicit gradient in a theme wins', () {
    final colors = ThemeColors.fromJson({
      'authGradientTop': '#112233',
      'authGradientBottom': '#445566',
    });

    expect(colors.authGradientTop, const Color(0xFF112233));
    expect(colors.authGradientBottom, const Color(0xFF445566));
  });

  test('a theme without the keys keeps its own hues', () {
    // Ocean's values. Before these keys existed the gradient was built from
    // gradientPurple → primaryDark, and themes that predate them must not
    // suddenly inherit the purple default.
    final colors = ThemeColors.fromJson({
      'gradientPurple': '#4A90D9',
      'primaryDark': '#1A3A5C',
    });

    expect(colors.authGradientTop, const Color(0xFF4A90D9));
    expect(colors.authGradientBottom, const Color(0xFF1A3A5C));
  });

  test('gradient colours survive a round trip through JSON', () {
    final restored = ThemeColors.fromJson(ThemeColors.defaults.toJson());

    expect(restored.authGradientTop, ThemeColors.defaults.authGradientTop);
    expect(restored.authGradientBottom, ThemeColors.defaults.authGradientBottom);
  });
}
