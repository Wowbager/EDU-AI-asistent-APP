// Open All Lessons (BR-K47WYE).
//
// Courses flagged `open_all_lessons` drop the sequential gate: every lesson is
// reachable from the start, in any order. The gate is a runtime derivation, not
// stored state, so the flag applies retroactively to students who already
// worked through part of the course.
//
// The trap this guards: `completedLessons` is a *count* of completed lessons,
// not an index. Under sequential progress the two coincide, so the fallback
// "i < completedLessons → completed" is right. Under free order it is not — a
// student who jumps to lesson 5 and finishes it has count == 1, which would
// light up lesson 1 as completed.
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/course_model.dart';

Map<String, dynamic> _courseJson({bool? openAll, int lessonCount = 5}) {
  return {
    'course_id': 'C1',
    'name': 'Test course',
    'language': 'cs',
    if (openAll != null) 'open_all_lessons': openAll,
    'lessons': List.generate(
      lessonCount,
      (i) => {
        'lesson_id': 'L${i + 1}',
        'name': 'Lesson ${i + 1}',
        'order': i + 1,
        'blocks': <Map<String, dynamic>>[],
      },
    ),
    'blocks': <Map<String, dynamic>>[],
  };
}

Course _course({
  bool? openAll,
  int completedLessons = 0,
  Map<String, dynamic>? lessonsProgress,
}) {
  return Course.fromJsonData(
    id: 'local-1',
    data: _courseJson(openAll: openAll),
    completedLessons: completedLessons,
    lessonsProgress: lessonsProgress,
  );
}

void main() {
  group('open_all_lessons parsing', () {
    test('defaults to false when the key is absent', () {
      expect(_course().openAllLessons, isFalse);
    });

    test('reads the flag off the course JSON', () {
      expect(_course(openAll: true).openAllLessons, isTrue);
    });
  });

  group('sequential courses (default) keep the gate', () {
    test('lessons past the current one stay locked', () {
      final course = _course(completedLessons: 2);

      expect(course.lessons[0].status, LessonStatus.completed);
      expect(course.lessons[1].status, LessonStatus.completed);
      expect(course.lessons[2].status, LessonStatus.inProgress);
      expect(course.lessons[3].status, LessonStatus.locked);
      expect(course.lessons[4].status, LessonStatus.locked);
    });
  });

  group('open_all_lessons courses', () {
    test('no lesson is locked, even with zero progress', () {
      final course = _course(openAll: true);

      expect(
        course.lessons.map((l) => l.status),
        everyElement(isNot(LessonStatus.locked)),
      );
    });

    test('completing a later lesson does not mark earlier ones completed', () {
      // Student jumped straight to lesson 5. completedLessons == 1 is a count,
      // and must not be read as "the first lesson is done".
      final course = _course(
        openAll: true,
        completedLessons: 1,
        lessonsProgress: {
          'L5': {'is_completed': true},
        },
      );

      expect(course.lessons[4].status, LessonStatus.completed);
      for (final i in [0, 1, 2, 3]) {
        expect(
          course.lessons[i].status,
          LessonStatus.inProgress,
          reason: 'lesson ${i + 1} was never opened — must not read as completed',
        );
      }
    });

    test('the same data on a sequential course still trips the old fallback', () {
      // Documents why the open-all branch has to bypass the fallback rather
      // than reuse it: this is the sequential behaviour, deliberately kept.
      final course = _course(
        completedLessons: 1,
        lessonsProgress: {
          'L5': {'is_completed': true},
        },
      );

      expect(course.lessons[0].status, LessonStatus.completed);
    });

    test('per-lesson completion is honoured', () {
      final course = _course(
        openAll: true,
        completedLessons: 2,
        lessonsProgress: {
          'L2': {'is_completed': true},
          'L4': {'is_completed': true},
        },
      );

      expect(course.lessons[1].status, LessonStatus.completed);
      expect(course.lessons[3].status, LessonStatus.completed);
      expect(course.lessons[0].status, LessonStatus.inProgress);
      expect(course.lessons[2].status, LessonStatus.inProgress);
      expect(course.lessons[4].status, LessonStatus.inProgress);
    });

    test('a finished course still reports every lesson completed', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(openAll: true),
        completedLessons: 5,
        isCompleted: true,
      );

      expect(
        course.lessons.map((l) => l.status),
        everyElement(LessonStatus.completed),
      );
    });
  });
}
