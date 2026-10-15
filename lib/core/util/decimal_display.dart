/// Locale-aware rendering of numbers for the UI.
///
/// Dart's `double.toString()` and `toStringAsFixed()` are locale-neutral and
/// always emit a dot, so `1.6` reached Czech students as "1.6" — in Czech and
/// Slovak maths content a decimal dot reads as a mistake in the notation
/// (BR-5DZ6JD). Every user-visible number goes through [formatDecimal] so the
/// separator follows the active locale instead of the Dart runtime.
///
/// Input is the mirror image of this: [DecimalNumberFormatter] in
/// `numeric_formatter.dart` accepts both separators, and grading normalises
/// the comma back to a dot before parsing.
library;

import '../strings/locale_manager.dart';

/// Formats [value] with the decimal separator of the active locale — a comma
/// in Czech and Slovak, a dot in English.
///
/// By default the fraction is only as long as it needs to be: whole values
/// lose it entirely (`4.0` → "4") and trailing zeros are trimmed
/// (`1.60` → "1,6"). Pass [fractionDigits] to force an exact number of
/// decimals instead, for values where a stable width matters more than a
/// short string (skill levels, compact counters).
///
/// [maxFractionDigits] caps the automatic mode and keeps binary floating-point
/// noise out of the UI: without it `0.1 + 0.2` would render as
/// "0,30000000000000004".
///
/// Above 1e21 Dart falls back to exponent notation whatever we ask for. Course
/// content never reaches that, so it is left alone rather than hand-expanded.
String formatDecimal(
  num value, {
  int? fractionDigits,
  int maxFractionDigits = 6,
}) {
  final d = value.toDouble();
  if (!d.isFinite) return d.toString();

  final String text;
  if (fractionDigits != null) {
    text = d.toStringAsFixed(fractionDigits);
  } else if (d == d.roundToDouble()) {
    // toStringAsFixed(0) rather than toInt(): it also spells out values past
    // the int range instead of overflowing.
    text = d.toStringAsFixed(0);
  } else {
    text = d
        .toStringAsFixed(maxFractionDigits)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  return _separator == '.' ? text : text.replaceAll('.', _separator);
}

/// Groups thousands the way the active locale does — a non-breaking space in
/// Czech and Slovak ("1 234"), a comma in English ("1,234").
///
/// The two must not be mixed up: a Czech reader parses "1,234" as one and a
/// bit, not as a thousand and change.
String formatGrouped(int value) {
  final digits = value.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+$)'),
    (m) => '${m[1]}$_groupSeparator',
  );
  return value < 0 ? '-$grouped' : grouped;
}

/// The decimal separator of the active locale.
String get _separator =>
    LocaleManager.current == AppLocale.en ? '.' : ',';

/// The thousands separator of the active locale. U+00A0 keeps "1 234" from
/// being broken across two lines.
String get _groupSeparator =>
    LocaleManager.current == AppLocale.en ? ',' : '\u00A0';
