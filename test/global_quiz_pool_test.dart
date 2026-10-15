// BR-ERUJBY: the dashboard's "Dej si kvíz" challenge mixes questions from every
// course the learner has. The pool builder is the whole feature — get it wrong
// and the card either opens empty or asks the same question twice.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/gamification/global_quiz.dart';
import 'package:eduai/models/course_model.dart';

/// A course whose blocks are [count] copies of the bundled fixture's first
/// exercise, re-identified so they are distinct questions.
Map<String, dynamic> _syntheticCourse(String prefix, int count) {
  final fixture = jsonDecode(
    File('assets/courses/EDU_ONBOARDING_APP.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final template = (fixture['blocks'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((b) => b['type'] == 'exercise');

  final blocks = <Map<String, dynamic>>[];
  final refs = <Map<String, dynamic>>[];
  for (var i = 0; i < count; i++) {
    final block = Map<String, dynamic>.from(template);
    block['block_id'] = '$prefix-$i';
    blocks.add(block);
    refs.add({'block_id': '$prefix-$i', 'order': i});
  }

  return {
    'blocks': blocks,
    'lessons': [
      {'lesson_id': '$prefix-l1', 'title': 'L1', 'blocks': refs},
    ],
  };
}

void main() {
  group('courseDataHasQuestions', () {
    test('true for a course carrying exercise blocks', () {
      expect(courseDataHasQuestions(_syntheticCourse('a', 2)), isTrue);
    });

    test('false for a metadata-only or block-less course', () {
      expect(courseDataHasQuestions(null), isFalse);
      expect(courseDataHasQuestions(const {}), isFalse);
      expect(courseDataHasQuestions(const {'blocks': []}), isFalse);
      expect(
        courseDataHasQuestions(const {
          'blocks': [
            {'block_id': 'x', 'type': 'text'}
          ]
        }),
        isFalse,
      );
    });
  });

  group('buildGlobalQuizPool', () {
    Course course(String prefix, int count) => Course.fromJsonData(
          id: prefix,
          data: _syntheticCourse(prefix, count),
        );

    test('draws from every course, capped at the quiz length', () {
      final pool = buildGlobalQuizPool(
        [course('a', 8), course('b', 8)],
        seed: 1,
      );

      expect(pool, hasLength(globalQuizLength));
      final prefixes = pool.map((b) => b.blockId.split('-').first).toSet();
      expect(prefixes, containsAll(<String>['a', 'b']),
          reason: 'a "global" quiz that only ever asks one course is not global');
    });

    test('never repeats a block inside one session', () {
      final pool = buildGlobalQuizPool([course('a', 20)], seed: 7);
      expect(pool.map((b) => b.blockId).toSet(), hasLength(pool.length));
    });

    test('a short pool is served whole rather than padded', () {
      final pool = buildGlobalQuizPool([course('a', 3)], seed: 7);
      expect(pool, hasLength(3));
    });

    test('no courses means no quiz — the card hides rather than opening empty',
        () {
      expect(buildGlobalQuizPool(const [], seed: 7), isEmpty);
    });

    test('the same seed picks the same questions, a new seed re-shuffles', () {
      final courses = [course('a', 30)];
      final first = buildGlobalQuizPool(courses, seed: 1);
      final again = buildGlobalQuizPool(courses, seed: 1);
      final other = buildGlobalQuizPool(courses, seed: 2);

      expect(first.map((b) => b.blockId), again.map((b) => b.blockId),
          reason: 'a rebuild must not reorder the quiz under the learner');
      expect(first.map((b) => b.blockId).toList(),
          isNot(other.map((b) => b.blockId).toList()));
    });
  });

  group('globalQuizSeed', () {
    test('is stable within a day and moves with the date', () {
      final morning = DateTime.utc(2026, 8, 31, 6);
      final evening = DateTime.utc(2026, 8, 31, 23, 59);
      final tomorrow = DateTime.utc(2026, 9, 1, 6);

      expect(globalQuizSeed(morning), globalQuizSeed(evening));
      expect(globalQuizSeed(tomorrow), isNot(globalQuizSeed(morning)));
    });
  });

  group('buildGlobalQuizLessonGroups (BR-RB8WRW)', () {
    /// Two lessons of 2 and 3 questions plus one question outside any lesson.
    Course lessonedCourse(String prefix) {
      final data = _syntheticCourse(prefix, 6);
      final refs = ((data['lessons'] as List).first
          as Map<String, dynamic>)['blocks'] as List<Map<String, dynamic>>;
      data['lessons'] = [
        {'lesson_id': '$prefix-l1', 'name': 'První lekce', 'blocks': refs.sublist(0, 2)},
        {'lesson_id': '$prefix-l2', 'name': 'Druhá lekce', 'blocks': refs.sublist(2, 5)},
        // refs[5] belongs to no lesson on purpose.
      ];
      return Course.fromJsonData(id: prefix, data: data);
    }

    test('splits a course into its lessons plus an unassigned tail', () {
      final groups = buildGlobalQuizLessonGroups([lessonedCourse('a')]);

      expect(groups.map((g) => g.lessonId), ['a-l1', 'a-l2', '']);
      expect(groups.map((g) => g.blocks.length), [2, 3, 1]);
      expect(groups[0].title, 'První lekce');
      expect(groups.map((g) => g.key).toSet(), hasLength(3),
          reason: 'keys must be unique — they are the checkbox identity');
    });

    test('covers exactly the candidate pool, with no block twice', () {
      final courses = [lessonedCourse('a'), lessonedCourse('b')];
      final groups = buildGlobalQuizLessonGroups(courses);

      final grouped = [for (final g in groups) ...g.blocks].map((b) => b.blockId);
      final flat = buildGlobalQuizCandidates(courses).map((b) => b.blockId);
      expect(grouped.toSet(), flat.toSet());
      expect(grouped.toList(), hasLength(grouped.toSet().length));
    });
  });
}
