import 'package:flutter/services.dart';

/// Formatter that keeps a text field to a single decimal number.
///
/// Allows digits, one leading `-`, and one `.` or `,` decimal separator —
/// matching the grading path, which parses the answer with
/// `double.tryParse(text.replaceAll(',', '.'))`.
///
/// This is needed on top of `keyboardType: numberWithOptions`: that only hints
/// which soft keyboard to show, so on web and desktop a physical keyboard can
/// still type letters into a numeric question (BR-WAEZE3).
///
/// The output side is `formatDecimal` in `decimal_display.dart`, which renders
/// numbers back with the separator of the active locale.
class DecimalNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = _filter(newValue.text);
    if (filtered == newValue.text) return newValue;
    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
      composing: TextRange.empty,
    );
  }

  /// Drops every character that cannot appear in a decimal number, keeping the
  /// first `-` (only in leading position) and the first decimal separator.
  static String _filter(String input) {
    final buffer = StringBuffer();
    var hasSeparator = false;

    for (final char in input.split('')) {
      if (_isDigit(char)) {
        buffer.write(char);
      } else if (char == '-') {
        if (buffer.isEmpty) buffer.write(char);
      } else if (char == '.' || char == ',') {
        if (hasSeparator) continue;
        hasSeparator = true;
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}
