// Question selection for a course's "Kvíz" — the quiz the course page, the
// lesson page once the course is done, and the dashboard's "Rychlé kvízy"
// open over the course's question blocks.
//
// It follows the global quiz's rule (BR-WRMW7W): ten questions matched to the
// student's ELO profile by [selectGlobalQuizBlocks], with its random fill-up
// when too few can be matched — not every question the course holds.
//
// Two things the global quiz does not have to care about:
//   - Some courses' quiz IS the assessment ([courseQuizIsDrawn]): those keep
//     every question.
//   - The course quiz resumes. QuizPage keeps an unfinished run's answers by
//     block id in `user_courses.progressData`, so a fresh draw keeps the
//     blocks that run already answered and only tops up the rest.
//
// Pure Dart, no Flutter — unit-tested directly.
library;

import 'dart:math';

import '../../models/course_model.dart';
import 'global_quiz.dart';
import 'global_quiz_selection.dart';

/// Whether [course]'s Kvíz is drawn rather than asking every question.
///
/// Not when the quiz is the assessment itself: an `only_once` test, the entry
/// quiz of a `starts_with_quiz` course, or an `only_quiz` course whose
/// completion is that quiz.
bool courseQuizIsDrawn(Course course) =>
    !course.onlyOnce && !course.startsWithQuiz && !course.onlyQuiz;

/// Block ids an unfinished course-quiz run has answered, read from the resume
/// store QuizPage writes into `user_courses.progressData`. Empty once the run
/// was submitted (`quiz_in_progress` false) or when nothing was answered.
Set<String> unfinishedQuizAnswerIds(Map<String, dynamic> progressData) {
  if (progressData['quiz_in_progress'] != true) return const {};
  final answers = progressData['quiz_answers'];
  if (answers is! Map) return const {};
  return {
    for (final entry in answers.entries)
      if (entry.key is String &&
          entry.value is Map &&
          (entry.value as Map)['is_answered'] == true)
        entry.key as String,
  };
}

/// Select up to [limit] of the course's question blocks in [pool] for the
/// student's [studentElo] profile.
///
/// Blocks in [answeredBlockIds] (an unfinished run, see
/// [unfinishedQuizAnswerIds]) stay in and lead, in course order, so QuizPage's
/// resume lands on the first question still open; the rest is a fresh
/// ELO-matched draw, shuffled the way the global quiz shuffles its ten.
List<ContentBlock> selectCourseQuizBlocks({
  required List<ContentBlock> pool,
  required List<double?> studentElo,
  Set<String> answeredBlockIds = const {},
  Map<String, List<double?>> calibratedTaskElo = const {},
  Random? random,
  int limit = globalQuizLength,
}) {
  final rng = random ?? Random();

  // A block two lessons list is one question.
  final seen = <String>{};
  final unique = [
    for (final block in pool)
      if (seen.add(block.blockId)) block,
  ];

  final kept = unique
      .where((b) => answeredBlockIds.contains(b.blockId))
      .take(limit)
      .toList();
  final keptIds = kept.map((b) => b.blockId).toSet();

  final drawn = selectGlobalQuizBlocks(
    pool: [
      for (final block in unique)
        if (!keptIds.contains(block.blockId)) block,
    ],
    studentElo: studentElo,
    calibratedTaskElo: calibratedTaskElo,
    random: rng,
    limit: limit - kept.length,
  )..shuffle(rng);

  return [...kept, ...drawn];
}
