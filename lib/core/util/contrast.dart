import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour contrast helpers (BR-YXSVVC).
///
/// The palette is authored for *fills* — card backgrounds, badges, borders —
/// and themes are user-editable, so a pastel that happens to read on the
/// default background can be invisible on the next one. Anything that paints
/// palette colour onto text runs it through here first.

/// WCAG 2.1 minimum for body text (< 18.66 px bold / < 24 px regular).
const double kContrastAA = 4.5;

/// WCAG 2.1 minimum for large text and for non-text UI shapes.
const double kContrastAALarge = 3.0;

/// WCAG 2.1 contrast ratio between two opaque colours: 1.0 (identical) to
/// 21.0 (black on white).
///
/// Both colours must be opaque — an alpha channel is ignored, not composited,
/// so blend against the backdrop before calling.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [color] shifted along its own hue until it clears [minRatio] against
/// [background].
///
/// Returns [color] untouched when it already passes, so a palette that was
/// chosen with contrast in mind keeps its exact value. Otherwise lightness
/// walks away from the background — darker on a light backdrop, lighter on a
/// dark one — which keeps the hue recognisable: a "rare" gold stays gold, it
/// just stops being a pastel.
Color readableOn(
  Color color,
  Color background, {
  double minRatio = kContrastAA,
}) {
  if (contrastRatio(color, background) >= minRatio) return color;

  final darken = background.computeLuminance() > 0.5;
  final hsl = HSLColor.fromColor(color);

  // 2 % steps over the full lightness range: fine enough that the result is
  // not visibly darker than it has to be, coarse enough to stay cheap in a
  // build method.
  for (var step = 1; step <= 50; step++) {
    final lightness =
        (hsl.lightness + (darken ? -0.02 : 0.02) * step).clamp(0.0, 1.0);
    final candidate = hsl.withLightness(lightness).toColor();

    if (contrastRatio(candidate, background) >= minRatio) return candidate;
  }

  // Fully saturated hues can run out of lightness before they clear the
  // threshold. Black or white always does.
  return darken ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
}
