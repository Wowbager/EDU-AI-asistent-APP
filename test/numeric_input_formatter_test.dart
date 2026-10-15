// Numeric question input filtering (BR-WAEZE3).
//
// A `type: numeric` question is graded with
// `double.tryParse(text.replaceAll(',', '.'))`, so anything the field lets
// through that is not a number scores as wrong without telling the student why.
// `keyboardType` does not help on web/desktop, where a physical keyboard writes
// into the field directly — the formatter is the only filter that runs there.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/util/numeric_formatter.dart';

void main() {
  final formatter = DecimalNumberFormatter();

  /// Runs the formatter over a whole string as if it were pasted in one go.
  String paste(String text) => formatter
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      )
      .text;

  /// Runs the formatter character by character, the way typing hits it.
  String type(String text) {
    var value = TextEditingValue.empty;
    for (final char in text.split('')) {
      final next = value.text + char;
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        ),
      );
    }
    return value.text;
  }

  group('DecimalNumberFormatter — accepts numbers', () {
    test('keeps plain digits', () {
      expect(type('42'), '42');
      expect(paste('42'), '42');
    });

    test('keeps a decimal point and a Czech decimal comma', () {
      expect(type('2.5'), '2.5');
      expect(type('2,5'), '2,5');
    });

    test('keeps a leading minus', () {
      expect(type('-3'), '-3');
      expect(type('-0,75'), '-0,75');
    });

    test('allows the intermediate states typing a decimal goes through', () {
      expect(type('-'), '-');
      expect(type('12,'), '12,');
      expect(type(',5'), ',5');
    });

    test('leaves an empty field empty', () {
      expect(paste(''), '');
    });
  });

  group('DecimalNumberFormatter — rejects non-numbers', () {
    test('drops letters, the reported case', () {
      expect(type('ggggg'), '');
      expect(paste('ggggg'), '');
    });

    test('drops letters mixed into a number', () {
      expect(type('1a2'), '12');
      expect(paste('12 kusů'), '12');
    });

    test('keeps only the first decimal separator', () {
      expect(type('1.2.3'), '1.23');
      expect(type('1,2,3'), '1,23');
      expect(type('1.2,3'), '1.23');
    });

    test('keeps a minus only in leading position', () {
      expect(type('1-2'), '12');
      expect(paste('--5'), '-5');
    });

    test('drops whitespace and separators the grader cannot parse', () {
      expect(paste('1 000'), '1000');
      expect(paste('4 %'), '4');
    });
  });

  group('DecimalNumberFormatter — output stays gradable', () {
    // Mirrors the parse in `_applyAnswer` (block_step_engine.dart).
    double? grade(String typed) =>
        double.tryParse(typed.trim().replaceAll(',', '.'));

    test('every accepted complete answer parses as a double', () {
      for (final input in ['42', '2,5', '-3', '-0,75', '0.5', ',5']) {
        expect(grade(type(input)), isNotNull, reason: 'input: $input');
      }
    });
  });
}
