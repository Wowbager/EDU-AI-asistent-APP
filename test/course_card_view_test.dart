// Spec test for the shared course-card derivation (BR-NS3UBD): the Kurzy tab
// and the dashboard render the same course, so they must read the same numbers
// out of it. Before this model each page derived its own and they disagreed.
//
// Pure functions — no database, no widgets:
//   flutter test test/course_card_view_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/sync/sync_status.dart';
import 'package:eduai/data/repositories/user_course_repository.dart';
import 'package:eduai/models/course_card_view.dart';
import 'package:eduai/widgets/kurzy_course_card.dart' show CourseStatus;

UserCourse _course({
  UserCourseStatus status = UserCourseStatus.downloaded,
  Map<String, dynamic> progressData = const {},
  Map<String, dynamic>? courseData,
  String? courseName,
  int totalLessons = 0,
  int completedLessons = 0,
}) {
  final now = DateTime(2026, 1, 1);
  return UserCourse(
    id: 'uc-1',
    userId: 'u-1',
    courseId: 'c-1',
    status: status,
    progressPercent: 0,
    completedLessons: completedLessons,
    totalLessons: totalLessons,
    currentLessonIndex: 0,
    timeSpentSeconds: 0,
    progressData: progressData,
    downloadedVersion: 1,
    syncStatus: SyncStatus.synced,
    createdAt: now,
    updatedAt: now,
    courseName: courseName,
    courseData: courseData,
  );
}

void main() {
  group('CourseCardView.of', () {
    test('sums blocks across lessons for progress', () {
      final view = CourseCardView.of(_course(
        status: UserCourseStatus.inProgress,
        courseData: {
          'name': 'Výrazy',
          'emoji': '🧮',
          'lessons': [
            {'blocks': List.filled(4, {})},
            {'blocks': List.filled(6, {})},
          ],
        },
        progressData: {
          'lessons': {
            '0': {'completed_blocks': [0, 1, 2]},
            '1': {'completed_blocks': [0]},
          },
        },
      ));

      expect(view.title, 'Výrazy');
      expect(view.emoji, '🧮');
      expect(view.lessonCount, 2);
      expect(view.currentProgress, 4);
      expect(view.totalProgress, 10);
      expect(view.status, CourseStatus.inProgress);
      expect(view.needsHydration, isFalse);
    });

    // The dashboard used to miss this and showed 0 % for a quiz the Kurzy tab
    // already reported as finished.
    test('reports a finished only_quiz course as complete at 1/1', () {
      final view = CourseCardView.of(_course(
        courseData: {'name': 'Rychlý kvíz', 'only_quiz': true, 'lessons': []},
        progressData: {'quiz_completed': true},
      ));

      expect(view.status, CourseStatus.completed);
      expect(view.currentProgress, 1);
      expect(view.totalProgress, 1);
    });

    test('an unfinished only_quiz course sits at 0/1', () {
      final view = CourseCardView.of(_course(
        courseData: {'name': 'Rychlý kvíz', 'only_quiz': true, 'lessons': []},
      ));

      expect(view.status, CourseStatus.notStarted);
      expect(view.currentProgress, 0);
      expect(view.totalProgress, 1);
    });

    test('asks for hydration and falls back when the payload is missing', () {
      final view = CourseCardView.of(_course(totalLessons: 7));

      expect(view.needsHydration, isTrue);
      expect(view.lessonCount, 7);
      expect(view.emoji, '📖');
    });
  });

  group('resolveKnownCourseTitle', () {
    test('prefers the payload name over the local one', () {
      expect(
        resolveKnownCourseTitle(_course(
          courseName: 'Kurz',
          courseData: {'name': 'Zlomky'},
        )),
        'Zlomky',
      );
    });

    test('rejects placeholders left by sync', () {
      expect(resolveKnownCourseTitle(_course(courseName: 'Kurz')), isNull);
      expect(resolveKnownCourseTitle(_course(courseName: 'Course')), isNull);
      expect(resolveKnownCourseTitle(_course(courseName: '  ')), isNull);
      expect(resolveKnownCourseTitle(_course(courseName: 'c-1')), isNull);
    });

    test('accepts a real local name', () {
      expect(resolveKnownCourseTitle(_course(courseName: 'Zlomky')), 'Zlomky');
    });
  });
}
