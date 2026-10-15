import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../../models/course_model.dart' as models;

/// Why an enroll-by-code attempt failed. The UI maps these to localized copy.
enum EnrollErrorKind {
  codeShort,
  notFound,

  /// The session is gone (no active user). [enrollCourseByCode] has already
  /// triggered the forced logout, so the app is on its way back to the login
  /// screen — the caller must not show interactive UI on top of that.
  loginRequired,

  /// The course is marked `logged_only` and the current user is a guest.
  /// Nothing was torn down and the guest keeps their data, so the caller should
  /// offer an upgrade path (see `showLoginRequiredForCourseDialog`) rather than
  /// a dead-end message.
  loginRequiredForCourse,

  alreadyCompleted,
  loadError,
  generic,
}

/// Result of [enrollCourseByCode]. On success [course] is non-null; otherwise
/// [error] describes why. [code] echoes the input (for "not found" messages);
/// [message] carries the raw error text for [EnrollErrorKind.generic].
class EnrollOutcome {
  final models.Course? course;
  final String? userCourseId;
  final int? downloadedVersion;
  final EnrollErrorKind? error;
  final String code;
  final String? message;

  const EnrollOutcome._({
    required this.code,
    this.course,
    this.userCourseId,
    this.downloadedVersion,
    this.error,
    this.message,
  });

  bool get isSuccess => course != null;

  factory EnrollOutcome.success({
    required String code,
    required models.Course course,
    String? userCourseId,
    int? downloadedVersion,
  }) =>
      EnrollOutcome._(
        code: code,
        course: course,
        userCourseId: userCourseId,
        downloadedVersion: downloadedVersion,
      );

  factory EnrollOutcome.failure(
    String code,
    EnrollErrorKind error, {
    String? message,
  }) =>
      EnrollOutcome._(code: code, error: error, message: message);
}

/// Resolve a course by its join code/PIN, enroll the active user, download the
/// full course JSON and return the navigable course model.
///
/// This is the single source of truth for the "enter a code → open the course"
/// flow, shared by the Knihovna code input and the /course|/pin deep links so
/// both behave identically (incl. the only-once completed guard). It performs
/// no navigation and no UI — the caller renders errors and pushes the page.
Future<EnrollOutcome> enrollCourseByCode(WidgetRef ref, String code) async {
  if (code.length < 6) {
    return EnrollOutcome.failure(code, EnrollErrorKind.codeShort);
  }

  try {
    final courseRepo = ref.read(courseRepositoryProvider);
    final userCourseRepo = ref.read(userCourseRepositoryProvider);
    final db = ref.read(appDatabaseProvider);

    // Step 1: Find course by code
    final course = await courseRepo.findCourseByCode(code);
    if (course == null) {
      return EnrollOutcome.failure(code, EnrollErrorKind.notFound);
    }

    // Step 1.5: Block guests from logged_only courses.
    // Allow only real accounts: a user with an email OR a server-authenticated
    // student PIN login (flagged locally via isEmailValidated). Guests hold a
    // Sanctum token too, so token presence must NOT count as logged in
    // (BR-N2ENN4).
    if (course.data['logged_only'] == true) {
      final activeUser = await db.getActiveUser();
      if (activeUser == null ||
          (activeUser.email.isEmpty && !activeUser.isEmailValidated)) {
        return EnrollOutcome.failure(
          code,
          EnrollErrorKind.loginRequiredForCourse,
        );
      }
    }

    // Step 2: Require an active user. A null user means the session was wiped
    // (logged out) — send the user back to login rather than silently failing.
    final user = await db.getActiveUser();
    if (user == null) {
      ref.read(logoutCoordinatorProvider).forceLogoutToLogin();
      return EnrollOutcome.failure(code, EnrollErrorKind.loginRequired);
    }

    // Step 3: Add course to the user's library
    await userCourseRepo.startCourse(userId: user.id, courseId: course.id);

    // Step 4: Download full course JSON from R2
    await courseRepo.downloadFullCourseJson(course.id);

    // Step 4.5: Sync downloadedVersion with actual courses.version
    final courseRow = await db.getCourseById(course.id);
    final userCourse = await db.getUserCourseByUserAndCourse(user.id, course.id);
    if (userCourse != null && courseRow != null) {
      await db.updateUserCourseDownloadedVersion(
        id: userCourse.id,
        downloadedVersion: courseRow.version,
      );
    }

    // Step 4.6: Kick off a sync now that the course content is local — it
    // seeds practice cards for every default_practice block and pushes them
    // to the server, so the student's practice set is complete immediately
    // after enrollment instead of waiting for the next periodic sync.
    ref.read(syncServiceProvider).sync();

    // Step 5: Load full course data for navigation
    final fullCourse = await courseRepo.getCourseById(course.id);
    if (fullCourse == null) {
      return EnrollOutcome.failure(code, EnrollErrorKind.loadError);
    }

    // Step 6.5: Block re-entry for only_once completed courses
    if (fullCourse.data['only_once'] == true &&
        userCourse != null &&
        userCourse.status == 'completed') {
      return EnrollOutcome.failure(code, EnrollErrorKind.alreadyCompleted);
    }

    final courseModel = models.Course.fromJsonData(
      id: fullCourse.id,
      data: fullCourse.data,
      completedLessons: userCourse?.completedLessons ?? 0,
      isCompleted: userCourse?.status == 'completed',
    );

    return EnrollOutcome.success(
      code: code,
      course: courseModel,
      userCourseId: userCourse?.id,
      downloadedVersion: courseRow?.version ?? course.version,
    );
  } catch (e) {
    return EnrollOutcome.failure(code, EnrollErrorKind.generic, message: '$e');
  }
}
