// Locale-aware decimal separator in displayed numbers (BR-5DZ6JD).
//
// Dart renders `1.6` as "1.6" in every locale, so the solution to a numeric
// question reached Czech students with a decimal dot — which in Czech maths
// notation reads as an error. The input side already accepted both separators
// (see numeric_input_formatter_test.dart); this covers the output side.
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/strings/locale_manager.dart';
import 'package:eduai/core/util/decimal_display.dart';

void main() {
  tearDown(() => LocaleManager.notifier.value = AppLocale.cs);

  group('formatDecimal', () {
    test('uses a comma in Czech and Slovak, a dot in English', () {
      LocaleManager.notifier.value = AppLocale.cs;
      expect(formatDecimal(1.6), '1,6');

      LocaleManager.notifier.value = AppLocale.sk;
      expect(formatDecimal(1.6), '1,6');

      LocaleManager.notifier.value = AppLocale.en;
      expect(formatDecimal(1.6), '1.6');
    });

    test('drops the fraction from whole values', () {
      expect(formatDecimal(4), '4');
      expect(formatDecimal(4.0), '4');
      expect(formatDecimal(-12.0), '-12');
    });

    test('trims trailing zeros instead of padding to a fixed width', () {
      expect(formatDecimal(1.60), '1,6');
      expect(formatDecimal(0.50), '0,5');
      expect(formatDecimal(2.125), '2,125');
    });

    test('keeps floating-point noise out of the UI', () {
      expect(formatDecimal(0.1 + 0.2), '0,3');
    });

    // Dart switches to exponent notation only above 1e21, which no course
    // content reaches; everything below is spelled out.
    test('spells out large whole values instead of using exponent notation',
        () {
      expect(formatDecimal(1e20).contains('e'), isFalse);
      expect(formatDecimal(1000000), '1000000');
    });

    test('honours an explicit fraction width', () {
      expect(formatDecimal(2, fractionDigits: 1), '2,0');
      expect(formatDecimal(2.46, fractionDigits: 1), '2,5');

      LocaleManager.notifier.value = AppLocale.en;
      expect(formatDecimal(2, fractionDigits: 1), '2.0');
    });

    test('negative fractions keep their sign', () {
      expect(formatDecimal(-0.25), '-0,25');
    });
  });

  group('formatGrouped', () {
    test('separates thousands the way the locale does', () {
      LocaleManager.notifier.value = AppLocale.cs;
      expect(formatGrouped(1234), '1\u00A0234');
      expect(formatGrouped(1234567), '1\u00A0234\u00A0567');

      LocaleManager.notifier.value = AppLocale.en;
      expect(formatGrouped(1234), '1,234');
    });

    test('leaves values under a thousand alone', () {
      expect(formatGrouped(0), '0');
      expect(formatGrouped(999), '999');
    });

    test('groups from the right on negatives too', () {
      expect(formatGrouped(-1234), '-1\u00A0234');
    });
  });

  group('answer strings', () {
    test('the numeric solution reads with a comma in Czech', () {
      LocaleManager.notifier.value = AppLocale.cs;
      expect(AppStrings.stepCorrectNumber(1.6), 'Správná odpověď: 1,6');
      expect(AppStrings.stepTolerance(0.5), 'Tolerance: ± 0,5');
    });

    test('and with a dot in English', () {
      LocaleManager.notifier.value = AppLocale.en;
      expect(AppStrings.stepCorrectNumber(1.6), 'Correct answer: 1.6');
      expect(AppStrings.stepTolerance(0.5), 'Tolerance: ± 0.5');
    });

    test('a whole-number solution shows no decimals', () {
      LocaleManager.notifier.value = AppLocale.cs;
      expect(AppStrings.stepCorrectNumber(4), 'Správná odpověď: 4');
    });

    test('the skill level keeps one decimal in every locale', () {
      LocaleManager.notifier.value = AppLocale.cs;
      expect(AppStrings.skillLevel(2.5), 'Úroveň: 2,5');
      expect(AppStrings.skillLevel(2), 'Úroveň: 2,0');

      LocaleManager.notifier.value = AppLocale.en;
      expect(AppStrings.skillLevel(2.5), 'Level: 2.5');
    });
  });
}
