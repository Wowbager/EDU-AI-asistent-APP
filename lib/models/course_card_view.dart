import '../data/repositories/user_course_repository.dart';
import '../core/strings/app_strings.dart';
import '../widgets/course_cover_image.dart';
import '../widgets/kurzy_course_card.dart' show CourseStatus;
import 'course_model.dart' show Course;

/// Everything the course cards need, derived from a [UserCourse] once.
///
/// Kurzy and the dashboard both render the same course in a card, and both
/// used to derive title/emoji/block progress themselves. The two copies had
/// already drifted — the dashboard's version knew nothing about `only_quiz`
/// courses, so a finished quiz-only course showed 0 % there and 100 % on the
/// Kurzy tab. One derivation, two card shapes.
class CourseCardView {
  final String title;
  final String emoji;

  /// Course cover set in admin, shown in place of the emoji (BR-YKYXC6).
  final String? coverImageUrl;

  final String? description;
  final String? badge;
  final int lessonCount;
  final int durationHours;
  final CourseStatus status;
  final int currentProgress;
  final int totalProgress;

  /// True when the course payload has not been downloaded yet, so the caller
  /// can kick off hydration. Kept as a flag instead of doing it here: the view
  /// is pure, the download needs a ref and a frame callback.
  final bool needsHydration;

  const CourseCardView({
    required this.title,
    required this.emoji,
    this.coverImageUrl,
    required this.description,
    required this.badge,
    required this.lessonCount,
    required this.durationHours,
    required this.status,
    required this.currentProgress,
    required this.totalProgress,
    required this.needsHydration,
  });

  factory CourseCardView.of(UserCourse userCourse) {
    final courseData = userCourse.courseData ?? const {};
    final lessons = courseData['lessons'] as List<dynamic>?;
    final lessonCount = lessons?.length ?? userCourse.totalLessons;

    // Estimate duration (about 20 minutes per lesson)
    final durationHours = (lessonCount * 20 / 60).ceil();

    // Block-level progress, matching course_detail_page.
    var totalBlocks = 0;
    var completedBlocks = 0;
    for (final l in lessons ?? const []) {
      final lesson = l as Map<String, dynamic>;
      totalBlocks += (lesson['blocks'] as List<dynamic>?)?.length ?? 0;
    }
    final lessonsProgress =
        userCourse.progressData['lessons'] as Map<String, dynamic>?;
    for (final entry in lessonsProgress?.values ?? const []) {
      final lessonData = entry as Map<String, dynamic>?;
      completedBlocks +=
          (lessonData?['completed_blocks'] as List<dynamic>?)?.length ?? 0;
    }

    // Quiz-only detection and effective status/progress
    final isQuizOnly = courseData['only_quiz'] == true;
    final quizCompleted = userCourse.progressData['quiz_completed'] == true;

    final CourseStatus status;
    if (isQuizOnly && quizCompleted) {
      status = CourseStatus.completed;
    } else {
      status = switch (userCourse.status) {
        UserCourseStatus.inProgress => CourseStatus.inProgress,
        // Lessons added after the student finished reopen it (BR-PHJQDK).
        UserCourseStatus.completed => Course.gainedLessonsSinceCompletion(
                courseData,
                completedLessons: userCourse.completedLessons)
            ? CourseStatus.inProgress
            : CourseStatus.completed,
        _ => CourseStatus.notStarted,
      };
    }

    return CourseCardView(
      // Courses with an unknown name are filtered out before this runs
      // (see resolveKnownCourseTitle); the fallback here is defensive only.
      title: resolveKnownCourseTitle(userCourse) ?? AppStrings.defaultCourseName,
      emoji: courseData['emoji'] as String? ?? '📖',
      coverImageUrl: CourseCoverImage.urlFrom(courseData),
      description: courseData['description'] as String?,
      badge: courseData['badge'] as String?,
      lessonCount: lessonCount,
      durationHours: durationHours,
      status: status,
      // For quiz-only courses, show 1/1 when completed
      currentProgress: isQuizOnly ? (quizCompleted ? 1 : 0) : completedBlocks,
      totalProgress: isQuizOnly ? 1 : totalBlocks,
      // No lessons in the payload means it was never downloaded.
      needsHydration: lessons == null,
    );
  }

}

/// The course title, or null when only a placeholder is known locally.
///
/// Sync creates catalog rows before the R2 payload lands, so a course can exist
/// with its id or a legacy "Kurz" as its name. Those must not reach a card —
/// callers filter on this and hydrate instead.
String? resolveKnownCourseTitle(UserCourse userCourse) {
  final courseDataName = (userCourse.courseData?['name'] as String?)?.trim();
  if (courseDataName != null && courseDataName.isNotEmpty) {
    return courseDataName;
  }

  final localName = (userCourse.courseName ?? '').trim();
  const legacyPlaceholders = {'Kurz', 'Course'};
  if (localName.isEmpty ||
      localName == userCourse.courseId ||
      legacyPlaceholders.contains(localName)) {
    return null;
  }
  return localName;
}
