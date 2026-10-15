// Prefilling the course-code dialog from the catalogue search (BR-P84ZAA).
//
// The library search box and the "Zadat kód kurzu" dialog are separate fields.
// When the user typed the code into search first, opening the dialog should
// carry it over instead of showing an empty field. `courseCodeFromQuery`
// decides what carries over: exactly 6 alphanumerics (uppercased, same rule as
// the code input), otherwise nothing.
//
//   flutter test test/library_code_from_query_test.dart
import 'package:eduai/pages/knihovna_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('courseCodeFromQuery', () {
    test('a 6-digit search prefills the code', () {
      expect(courseCodeFromQuery('654321'), '654321');
    });

    test('letters are uppercased to match the code field', () {
      expect(courseCodeFromQuery('abc123'), 'ABC123');
    });

    test('separators and spaces are stripped before counting to 6', () {
      expect(courseCodeFromQuery(' abc-123 '), 'ABC123');
      expect(courseCodeFromQuery('AB 12 34'), 'AB1234');
    });

    test('fewer than 6 usable chars does not prefill', () {
      expect(courseCodeFromQuery('abc12'), isNull);
      expect(courseCodeFromQuery('---'), isNull);
    });

    test('more than 6 usable chars does not prefill', () {
      expect(courseCodeFromQuery('abc1234'), isNull);
      expect(courseCodeFromQuery('a course name'), isNull);
    });

    test('empty search does not prefill', () {
      expect(courseCodeFromQuery(''), isNull);
    });
  });
}
