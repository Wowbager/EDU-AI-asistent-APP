import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/evaluation/expected_answer.dart';

// BR-RBUR29 — an exact-match open question accepts every variant its author
// lists, one per line: "1/4", "čtvrtina", "čtvrtka".

void main() {
  group('matchesExpectedAnswer', () {
    const variants = '1/4\nčtvrtina\njedna čtvrtina\nčtvrtka';

    test('any listed variant is right', () {
      expect(matchesExpectedAnswer('1/4', variants), isTrue);
      expect(matchesExpectedAnswer('čtvrtina', variants), isTrue);
      expect(matchesExpectedAnswer('jedna čtvrtina', variants), isTrue);
      expect(matchesExpectedAnswer('čtvrtka', variants), isTrue);
    });

    test('ignores case and surrounding whitespace, as before', () {
      expect(matchesExpectedAnswer('  Čtvrtina ', variants), isTrue);
      expect(matchesExpectedAnswer('JEDNA ČTVRTINA', variants), isTrue);
    });

    test('a variant must match whole, not as part of a line', () {
      expect(matchesExpectedAnswer('jedna', variants), isFalse);
      expect(matchesExpectedAnswer('1/4 čtvrtina', variants), isFalse);
    });

    test('a single-line expected answer behaves exactly as it always did', () {
      expect(matchesExpectedAnswer('Praha', 'Praha'), isTrue);
      expect(matchesExpectedAnswer('praha', ' Praha '), isTrue);
      // The reported question: prose on one line is still one variant.
      expect(
        matchesExpectedAnswer(
            'čtvrtina', '1/4 nebo slovy jedna čtvrtina nebo čtvrtka'),
        isFalse,
      );
    });

    test('blank lines and Windows line endings are not variants', () {
      expect(matchesExpectedAnswer('', '1/4\n\nčtvrtka'), isFalse);
      expect(matchesExpectedAnswer('čtvrtka', '1/4\r\nčtvrtka\r\n'), isTrue);
    });

    test('nothing to compare against is never a match', () {
      expect(matchesExpectedAnswer('cokoli', null), isFalse);
      expect(matchesExpectedAnswer('', null), isFalse);
      expect(matchesExpectedAnswer('', '   '), isFalse);
    });
  });
}
