// BR-PHJQDK — a course the student had finished showed every lesson ticked off
// after its author added lessons.
//
// The student finished both lessons of a two-lesson course, which completed it.
// The author then published a four-lesson version of it: the first two lessons
// kept their ids, two new ones followed. The stored completed status never
// downgrades, and the course-level override marked every lesson completed off
// it — so the course page read "4 z 4 lekcí", 100 % and DOKONČENO for a student
// who had never opened lessons 3 and 4.
//
// Pure functions — no database, no widgets:
//   flutter test test/course_gained_lessons_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/sync/sync_status.dart';
import 'package:eduai/data/repositories/user_course_repository.dart';
import 'package:eduai/models/course_card_view.dart';
import 'package:eduai/models/course_model.dart';
import 'package:eduai/widgets/kurzy_course_card.dart' show CourseStatus;

Map<String, dynamic> _courseJson({
  int lessonCount = 4,
  bool openAll = false,
  bool onlyOnce = false,
}) {
  return {
    'course_id': 'S1',
    'name': 'Základy statistiky',
    'language': 'cs',
    if (openAll) 'open_all_lessons': true,
    if (onlyOnce) 'only_once': true,
    'lessons': List.generate(
      lessonCount,
      (i) => {
        'lesson_id': 'L${i + 1}',
        'name': 'Lekce ${i + 1}',
        'order': i + 1,
        'blocks': <Map<String, dynamic>>[],
      },
    ),
    'blocks': <Map<String, dynamic>>[],
  };
}

/// The reporter's student: lessons 1 and 2 done back when there were only two.
const _firstTwoDone = {
  'L1': {'is_completed': true},
  'L2': {'is_completed': true},
};

List<LessonStatus> _statuses(Course c) =>
    c.lessons.map((l) => l.status).toList();

void main() {
  group('a completed course that gained lessons', () {
    test('open_all_lessons: the new lessons are open, not done', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(openAll: true),
        completedLessons: 2,
        isCompleted: true,
        lessonsProgress: _firstTwoDone,
      );

      expect(_statuses(course), [
        LessonStatus.completed,
        LessonStatus.completed,
        LessonStatus.inProgress,
        LessonStatus.inProgress,
      ]);
      expect(course.isCompleted, isFalse,
          reason: 'two of four lessons is not a finished course');
    });

    test('sequential: the first new lesson is next, the rest stay locked', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(),
        completedLessons: 2,
        isCompleted: true,
        lessonsProgress: _firstTwoDone,
      );

      expect(_statuses(course), [
        LessonStatus.completed,
        LessonStatus.completed,
        LessonStatus.inProgress,
        LessonStatus.locked,
      ]);
      expect(course.isCompleted, isFalse);
    });

    test('callers without per-lesson progress go by the count', () {
      // Dashboard and Kurzy build the course without lessonsProgress.
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(),
        completedLessons: 2,
        isCompleted: true,
      );

      expect(_statuses(course), [
        LessonStatus.completed,
        LessonStatus.completed,
        LessonStatus.inProgress,
        LessonStatus.locked,
      ]);
    });

    test('the lesson page re-derives it the same way', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(openAll: true),
      );

      final after = course.withLessonProgress(
        lessonsProgress: {
          ..._firstTwoDone,
          'L3': {'is_completed': true},
        },
        completedLessons: 3,
        isCompleted: true,
      );

      expect(_statuses(after).last, LessonStatus.inProgress);
      expect(after.isCompleted, isFalse);
    });

    test('finishing the new lessons completes it again', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(openAll: true),
        completedLessons: 4,
        isCompleted: true,
        lessonsProgress: {
          ..._firstTwoDone,
          'L3': {'is_completed': true},
          'L4': {'is_completed': true},
        },
      );

      expect(_statuses(course), everyElement(LessonStatus.completed));
      expect(course.isCompleted, isTrue);
    });
  });

  group('completed courses the override still covers', () {
    test('a zero count marks every lesson done (legacy data)', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(),
        completedLessons: 0,
        isCompleted: true,
      );

      expect(_statuses(course), everyElement(LessonStatus.completed));
      expect(course.isCompleted, isTrue);
    });

    test('an only_once course finished by its quiz stays finished', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(onlyOnce: true),
        completedLessons: 1,
        isCompleted: true,
      );

      expect(_statuses(course), everyElement(LessonStatus.completed));
      expect(course.isCompleted, isTrue);
    });

    test('lessons removed since completion do not reopen it', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseJson(lessonCount: 3),
        completedLessons: 4,
        isCompleted: true,
      );

      expect(course.isCompleted, isTrue);
    });
  });

  group('course card', () {
    UserCourse userCourse({required int completedLessons}) {
      final now = DateTime(2026, 10, 1);
      return UserCourse(
        id: 'uc-1',
        userId: 'u-1',
        courseId: 'c-1',
        status: UserCourseStatus.completed,
        progressPercent: 100,
        completedLessons: completedLessons,
        totalLessons: 0,
        currentLessonIndex: 0,
        timeSpentSeconds: 0,
        progressData: const {'lessons': _firstTwoDone},
        downloadedVersion: 1,
        syncStatus: SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
        courseData: _courseJson(openAll: true),
      );
    }

    test('shows a course that gained lessons as in progress', () {
      expect(CourseCardView.of(userCourse(completedLessons: 2)).status,
          CourseStatus.inProgress);
    });

    test('still shows a fully finished course as completed', () {
      expect(CourseCardView.of(userCourse(completedLessons: 4)).status,
          CourseStatus.completed);
    });
  });
}
