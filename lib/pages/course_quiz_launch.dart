import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/elo/elo_engine.dart';
import '../core/gamification/course_quiz.dart';
import '../core/providers/core_providers.dart';
import '../core/util/silent_log.dart';
import '../models/course_model.dart';
import 'quiz_page.dart';

/// The questions [course]'s Kvíz asks on this launch with [progress] — ten
/// matched to the student's ELO the way the global quiz picks them
/// (BR-WRMW7W), or every question where the quiz is the assessment
/// (`courseQuizIsDrawn`). Empty when the course has no questions.
///
/// QuizPage restores [progress] by question index, so while it holds answers
/// the previous draw is asked again; a new draw resets it. On a cold start the
/// draw keeps whatever an unfinished run left in the course's resume store,
/// which QuizPage then restores by block id.
Future<List<ContentBlock>> courseQuizBlocks(
  WidgetRef ref,
  Course course,
  QuizProgress progress,
) async {
  final all = course.getAllQuestionBlocks();
  if (all.isEmpty || !courseQuizIsDrawn(course)) return all;

  final previous = progress.questionBlocks;
  if (previous != null && progress.answeredFlags.isNotEmpty) return previous;

  // Same inputs as the global quiz: the student's profile (unavailable →
  // the engine's default rating per dimension) and the server's task
  // calibration where it has one (BR-697NCA).
  var studentElo = List<double?>.filled(kGpfDimensions, null);
  var calibratedTaskElo = const <String, List<double?>>{};
  var answered = const <String>{};
  try {
    final eloRepo = ref.read(eloRepositoryProvider);
    final user = ref.read(activeUserProvider).valueOrNull;
    if (user != null) {
      final profile = await eloRepo.getProfile(user.id);
      if (profile != null) studentElo = profile.profilElo;
      answered = await _unfinishedRunAnswers(ref, user.id, course.id);
    }
    calibratedTaskElo =
        await eloRepo.calibratedTaskElo(all.map((b) => b.blockId));
  } catch (e, st) {
    silentLog('course_quiz_launch', e, st);
  }

  final drawn = selectCourseQuizBlocks(
    pool: all,
    studentElo: studentElo,
    answeredBlockIds: answered,
    calibratedTaskElo: calibratedTaskElo,
  );
  progress
    ..reset()
    ..questionBlocks = drawn;
  return drawn;
}

/// Answered block ids of an unfinished run in [courseId]'s resume store —
/// the same `user_courses.progressData` QuizPage hydrates from.
Future<Set<String>> _unfinishedRunAnswers(
  WidgetRef ref,
  String userId,
  String courseId,
) async {
  final db = ref.read(appDatabaseProvider);
  final localCourse = await db.getCourseByFieldCourseId(courseId);
  if (localCourse == null) return const {};
  final userCourse =
      await db.getUserCourseByUserAndCourse(userId, localCourse.id);
  if (userCourse == null) return const {};
  final fresh =
      await ref.read(userCourseRepositoryProvider).getUserCourseById(userCourse.id);
  return unfinishedQuizAnswerIds(fresh?.progressData ?? const {});
}
