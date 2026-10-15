// Spec test for the practice picker (BR-K4KHJZ): the subject → area tree and
// the selection transforms behind its checkboxes.
//
// Pure functions — no database, no widgets:
//   flutter test test/practice_scope_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/practice/practice_filter.dart';
import 'package:eduai/core/practice/practice_scope.dart';

PracticeCardsTableData card({
  required String id,
  String courseId = 'course-A',
  String lessonId = 'L1',
  int state = 0,
  DateTime? dueDate,
  DateTime? lastReview,
  bool isActive = true,
}) {
  final now = DateTime.now();
  return PracticeCardsTableData(
    id: id,
    serverId: null,
    userId: 'u1',
    courseId: courseId,
    lessonId: lessonId,
    blockId: 'block-$id',
    sourceType: 'lesson',
    state: state,
    dueDate: dueDate ?? now.subtract(const Duration(minutes: 1)),
    stability: 0,
    difficulty: 0,
    reps: 0,
    lapses: 0,
    scheduledDays: 0,
    elapsedDays: 0,
    lastReview: lastReview,
    weight: 5.0,
    avgTimeSec: 20,
    skipCondition: null,
    isActive: isActive,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

const _courseA = PracticeCourseInfo(
  id: 'row-A',
  title: 'Rovnice',
  lessonTitles: {'L1': 'Lineární rovnice', 'L2': 'Soustavy'},
);
const _courseB = PracticeCourseInfo(
  id: 'row-B',
  title: 'Zlomky',
  lessonTitles: {'L1': 'Krácení'},
);

void main() {
  final now = DateTime.now();

  group('buildPracticeScope', () {
    test('groups cards into subjects and areas, in course order', () {
      final scope = buildPracticeScope(
        cards: [
          card(id: 'a2', courseId: 'A', lessonId: 'L2'),
          card(id: 'a1', courseId: 'A', lessonId: 'L1'),
          card(id: 'b1', courseId: 'B', lessonId: 'L1'),
        ],
        courses: {'A': _courseA, 'B': _courseB},
        now: now,
      );

      expect(scope.map((s) => s.title), ['Rovnice', 'Zlomky']);
      expect(
        scope.first.areas.map((a) => a.title),
        ['Lineární rovnice', 'Soustavy'],
        reason: 'areas follow the order of lessons in the course',
      );
      expect(scope.first.areas.first.keys, {'A|L1'});
    });

    test('cards with no lesson become a trailing "other" area', () {
      final scope = buildPracticeScope(
        cards: [
          card(id: 'loose', courseId: 'A', lessonId: ''),
          card(id: 'a1', courseId: 'A', lessonId: 'L1'),
        ],
        courses: {'A': _courseA},
        now: now,
      );

      final areas = scope.single.areas;
      expect(areas.last.isUnassigned, isTrue);
      expect(areas.last.keys, {'A|'});
      expect(areas.first.lessonId, 'L1');
    });

    test('both id spellings of one course collapse into a single subject', () {
      // A card's courseId is either the local row id or the course_id field.
      final scope = buildPracticeScope(
        cards: [
          card(id: 'x', courseId: 'row-A', lessonId: 'L1'),
          card(id: 'y', courseId: 'A2-Rovnice_c1', lessonId: 'L1'),
        ],
        courses: {'row-A': _courseA, 'A2-Rovnice_c1': _courseA},
        now: now,
      );

      expect(scope, hasLength(1));
      expect(scope.single.courseIds, {'row-A', 'A2-Rovnice_c1'});
      expect(scope.single.areas.single.keys, {'row-A|L1', 'A2-Rovnice_c1|L1'});
    });

    test('cards of an unresolvable course are dropped', () {
      final scope = buildPracticeScope(
        cards: [card(id: 'ghost', courseId: 'gone')],
        courses: const {},
        now: now,
      );
      expect(scope, isEmpty);
    });

    test('due counts match the queue\'s notion of eligible today', () {
      final scope = buildPracticeScope(
        cards: [
          card(id: 'due', courseId: 'A', lessonId: 'L1'),
          card(
            id: 'not-due',
            courseId: 'A',
            lessonId: 'L1',
            state: 2,
            dueDate: now.add(const Duration(days: 3)),
          ),
          card(
            id: 'done-today',
            courseId: 'A',
            lessonId: 'L1',
            state: 2,
            lastReview: now,
          ),
        ],
        courses: {'A': _courseA},
        now: now,
      );

      final area = scope.single.areas.first;
      expect(area.totalCount, 3);
      expect(area.dueCount, 1);
    });
  });

  group('PracticeSelection', () {
    late List<PracticeSubject> scope;

    setUp(() {
      scope = buildPracticeScope(
        cards: [
          card(id: 'a1', courseId: 'A', lessonId: 'L1'),
          card(id: 'a2', courseId: 'A', lessonId: 'L2'),
          card(id: 'b1', courseId: 'B', lessonId: 'L1'),
        ],
        courses: {'A': _courseA, 'B': _courseB},
        now: now,
      );
    });

    PracticeSubject subject(String title) =>
        scope.firstWhere((s) => s.title == title);

    test('an empty filter shows every area as selected', () {
      for (final s in scope) {
        for (final a in s.areas) {
          expect(PracticeSelection.isAreaSelected(PracticeFilter.all, a), isTrue);
        }
      }
    });

    test('unticking one area expands "everything" into an explicit selection',
        () {
      final rovnice = subject('Rovnice');
      final filter = PracticeSelection.setArea(
        filter: PracticeFilter.all,
        scope: scope,
        area: rovnice.areas.first, // A|L1
        selected: false,
      );

      expect(filter.isAll, isFalse);
      expect(filter.allowsArea('A', 'L1'), isFalse);
      expect(filter.allowsArea('A', 'L2'), isTrue);
      expect(filter.allowsArea('B', 'L1'), isTrue,
          reason: 'the untouched subject stays in scope');
    });

    test('a fully selected subject is stored as the course, not its areas', () {
      // So a lesson added to that course later stays inside the selection
      // instead of quietly dropping out of it.
      final filter = PracticeSelection.setSubject(
        filter: PracticeFilter.all,
        scope: scope,
        subject: subject('Zlomky'),
        selected: false,
      );

      expect(filter.courseIds, {'A'});
      expect(filter.lessonKeys, isEmpty);
      expect(filter.allowsArea('A', 'L3-added-later'), isTrue);
    });

    test('deselecting the last area falls back to practising everything', () {
      var filter = PracticeFilter.all;
      for (final s in scope) {
        filter = PracticeSelection.setSubject(
          filter: filter,
          scope: scope,
          subject: s,
          selected: false,
        );
      }
      expect(filter.isAll, isTrue);
    });

    test('re-selecting everything collapses back to the unrestricted filter',
        () {
      final narrowed = PracticeSelection.setSubject(
        filter: PracticeFilter.all,
        scope: scope,
        subject: subject('Zlomky'),
        selected: false,
      );
      expect(narrowed.isAll, isFalse);

      final widened = PracticeSelection.setSubject(
        filter: narrowed,
        scope: scope,
        subject: subject('Zlomky'),
        selected: true,
      );
      expect(widened.isAll, isTrue);
    });

    test('selecting a subject keeps a partial selection in another one', () {
      final rovnice = subject('Rovnice');
      var filter = PracticeSelection.setArea(
        filter: PracticeFilter.all,
        scope: scope,
        area: rovnice.areas.first,
        selected: false,
      );
      filter = PracticeSelection.setSubject(
        filter: filter,
        scope: scope,
        subject: subject('Zlomky'),
        selected: false,
      );

      expect(filter.allowsArea('A', 'L1'), isFalse);
      expect(filter.allowsArea('A', 'L2'), isTrue);
      expect(filter.allowsArea('B', 'L1'), isFalse);
      expect(PracticeSelection.selectedAreaCount(filter, subject('Rovnice')), 1);
    });
  });

  group('PracticeFilter persistence', () {
    test('survives an encode/decode round trip', () {
      const filter = PracticeFilter(
        courseIds: {'A'},
        lessonKeys: {'B|L1', 'B|'},
      );
      expect(PracticeFilter.decode(filter.encode()), filter);
    });

    test('a corrupt or missing payload degrades to practising everything', () {
      expect(PracticeFilter.decode(null).isAll, isTrue);
      expect(PracticeFilter.decode('').isAll, isTrue);
      expect(PracticeFilter.decode('not json').isAll, isTrue);
      expect(PracticeFilter.decode('[1,2]').isAll, isTrue);
    });
  });
}
