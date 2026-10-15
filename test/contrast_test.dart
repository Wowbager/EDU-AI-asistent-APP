// Colour contrast helpers (BR-YXSVVC).
//
// The shop printed its labels in the rarity pastels, which measured 1.0–1.7:1
// against the surfaces they sat on. These pin the helper that stops that: the
// ratio maths against known WCAG values, and the guarantee `readableOn` makes
// — whatever comes out clears the threshold, keeps the hue, and leaves an
// already-passing colour alone.
//
//   flutter test test/contrast_test.dart
import 'package:eduai/core/util/contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette values the shop was printing as text, on the default theme.
const _cardBlue = Color(0xFFA7D9FF); // common
const _hintIconColor = Color(0xFFFFB800); // rare
const _gradientPurple = Color(0xFF7F68C1); // epic

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);
const _appBackground = Color(0xFFF6F2FF);

/// Darkest point of the shop panel's wash on the default theme.
const _panelEnd = Color(0xFFE8E5F2);

void main() {
  group('contrastRatio', () {
    test('spans the WCAG range', () {
      expect(contrastRatio(_black, _white), closeTo(21.0, 0.01));
      expect(contrastRatio(_white, _white), closeTo(1.0, 0.01));
    });

    test('is symmetric', () {
      expect(
        contrastRatio(_cardBlue, _white),
        closeTo(contrastRatio(_white, _cardBlue), 0.0001),
      );
    });

    test('measures the reported failures', () {
      // What the reporter was looking at: the numbers behind "skoro
      // nečitelné".
      expect(contrastRatio(_cardBlue, _white), lessThan(2.0));
      expect(contrastRatio(_hintIconColor, _white), lessThan(2.0));
      expect(contrastRatio(_gradientPurple, _appBackground), lessThan(4.5));
    });
  });

  group('readableOn', () {
    test('leaves a colour that already passes untouched', () {
      // A palette chosen with contrast in mind keeps its exact value — the
      // helper is a floor, not an opinion.
      expect(readableOn(_black, _white), _black);
      expect(readableOn(const Color(0xFF3C315B), _white), const Color(0xFF3C315B));
    });

    for (final (name, color) in [
      ('common', _cardBlue),
      ('rare', _hintIconColor),
      ('epic', _gradientPurple),
    ]) {
      for (final (surface, background) in [
        ('white', _white),
        ('app background', _appBackground),
        ('panel wash', _panelEnd),
      ]) {
        test('$name clears AA on the $surface', () {
          final result = readableOn(color, background);
          expect(
            contrastRatio(result, background),
            greaterThanOrEqualTo(kContrastAA),
            reason: '$name printed as text on the $surface must be readable',
          );
        });
      }
    }

    test('keeps the hue so the rarity is still recognisable', () {
      // Measured on the panel wash, where all three genuinely fail — epic
      // already clears AA on plain white and would come back untouched.
      for (final color in [_cardBlue, _hintIconColor, _gradientPurple]) {
        final before = HSLColor.fromColor(color);
        final after = HSLColor.fromColor(readableOn(color, _panelEnd));

        expect(after.hue, closeTo(before.hue, 1.0));
        expect(after.saturation, closeTo(before.saturation, 0.01));
        expect(
          after.lightness,
          lessThan(before.lightness),
          reason: 'on a light backdrop the fix is to go darker',
        );
      }
    });

    test('lightens instead of darkening on a dark backdrop', () {
      // No shipped theme is dark, but nothing stops a user-authored one from
      // being — and then darkening would make it worse, not better.
      final result = readableOn(const Color(0xFF2A2340), _black);

      expect(contrastRatio(result, _black), greaterThanOrEqualTo(kContrastAA));
      expect(
        HSLColor.fromColor(result).lightness,
        greaterThan(HSLColor.fromColor(const Color(0xFF2A2340)).lightness),
      );
    });

    test('falls back to black or white when the hue runs out of room', () {
      // Pure yellow cannot reach 7:1 on white at any lightness without
      // giving up its hue; the contract is the ratio, so it gives it up.
      final result = readableOn(
        const Color(0xFFFFFF00),
        _white,
        minRatio: 7.0,
      );

      expect(contrastRatio(result, _white), greaterThanOrEqualTo(7.0));
    });

    test('honours a custom threshold', () {
      final aa = readableOn(_cardBlue, _white);
      final aaa = readableOn(_cardBlue, _white, minRatio: 7.0);

      expect(contrastRatio(aaa, _white), greaterThanOrEqualTo(7.0));
      expect(
        HSLColor.fromColor(aaa).lightness,
        lessThan(HSLColor.fromColor(aa).lightness),
      );
    });
  });
}
