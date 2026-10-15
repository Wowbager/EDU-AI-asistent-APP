import 'dart:math';

import '../../models/course_model.dart';
import '../strings/app_strings.dart';

/// The dashboard's "Dej si kvíz" challenge — a mixed quiz drawn from every
/// course the learner has (BR-ERUJBY).
///
/// Deliberately client-side: the questions are already in the local Drift copy
/// of each course, so the challenge works offline and needs no endpoint of its
/// own. What it must NOT do is pretend to belong to one of those courses —
/// writing a multi-course session into a single course's resume store is what
/// broke practice in BR-CNSK2C. Hence [globalQuizCourseId]: a sentinel that
/// matches no local course row, so every course-keyed write in QuizPage
/// early-returns, while quiz attempts still land server-side under a stable id.
const String globalQuizCourseId = 'GLOBAL_QUIZ';

/// How many questions one global quiz asks.
const int globalQuizLength = 10;

/// Whether a course's raw JSON holds anything worth asking.
///
/// Cheap on purpose — it runs for every course on every dashboard build, while
/// the full block extraction happens only when the card is tapped.
bool courseDataHasQuestions(Map<String, dynamic>? data) {
  final blocks = data?['blocks'] as List<dynamic>?;
  if (blocks == null || blocks.isEmpty) return false;
  return blocks.any((b) {
    final type = (b as Map<String, dynamic>)['type'] as String?;
    return type == 'exercise' || type == 'question' || type == 'quiz';
  });
}

/// Seed for [buildGlobalQuizPool], stable within a calendar day.
///
/// A fresh shuffle on every rebuild would reorder the quiz under the learner
/// mid-session; a fixed seed would serve the same ten questions forever. Days
/// since the epoch is the middle ground.
int globalQuizSeed(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;

/// Every answerable block across [courses], deduplicated, in course order.
///
/// Blocks with no question (plain text/display blocks) are dropped: the card
/// promises a quiz, and QuizPage would count them out of the score anyway.
/// Duplicate block ids — the same block reachable from two courses — are kept
/// once, otherwise a short pool can repeat itself inside one session.
///
/// This is the raw candidate pool for the entry dialog + ELO selection
/// (`global_quiz_selection.dart`); [buildGlobalQuizPool] remains as the
/// selection-free draw.
List<ContentBlock> buildGlobalQuizCandidates(List<Course> courses) {
  final seen = <String>{};
  final pool = <ContentBlock>[];

  for (final course in courses) {
    for (final block in course.getAllQuestionBlocks()) {
      if (block.atomicQuestion == null && !block.hasV2Steps) continue;
      if (!seen.add(block.blockId)) continue;
      pool.add(block);
    }
  }

  return pool;
}

/// One selectable course/lesson row of the global-quiz entry dialog
/// (BR-RB8WRW), carrying the question blocks behind it.
class GlobalQuizLessonGroup {
  final String courseId;
  final String courseTitle;

  /// Empty for question blocks the course keeps outside any lesson.
  final String lessonId;

  /// The lesson title; the unassigned group borrows the course title.
  final String title;

  final List<ContentBlock> blocks;

  const GlobalQuizLessonGroup({
    required this.courseId,
    required this.courseTitle,
    required this.lessonId,
    required this.title,
    required this.blocks,
  });

  /// Stable checkbox identity for the entry dialog — lesson ids are only
  /// unique within their course.
  String get key => '$courseId::$lessonId';
}

/// [buildGlobalQuizCandidates], grouped per lesson for the entry dialog.
///
/// Groups follow course order, lessons in course order, with each course's
/// unassigned question blocks in a trailing group. The same deduplication
/// applies: a block reachable from two courses stays with the first.
List<GlobalQuizLessonGroup> buildGlobalQuizLessonGroups(List<Course> courses) {
  final seen = <String>{};
  final groups = <GlobalQuizLessonGroup>[];

  for (final course in courses) {
    final byLesson = <String, List<ContentBlock>>{};
    final unassigned = <ContentBlock>[];
    final lessonTitles = <String, String>{};

    for (final block in course.getAllQuestionBlocks()) {
      if (block.atomicQuestion == null && !block.hasV2Steps) continue;
      if (!seen.add(block.blockId)) continue;
      final home = course.findLessonForBlock(block.blockId);
      if (home == null) {
        unassigned.add(block);
        continue;
      }
      byLesson.putIfAbsent(home.lessonId, () => []).add(block);
      lessonTitles.putIfAbsent(
        home.lessonId,
        () => home.lessonIndex < course.lessons.length &&
                course.lessons[home.lessonIndex].title.isNotEmpty
            ? course.lessons[home.lessonIndex].title
            : AppStrings.lessonFallbackName(home.lessonIndex + 1),
      );
    }

    for (final entry in byLesson.entries) {
      groups.add(GlobalQuizLessonGroup(
        courseId: course.id,
        courseTitle: course.title,
        lessonId: entry.key,
        title: lessonTitles[entry.key] ?? entry.key,
        blocks: entry.value,
      ));
    }
    if (unassigned.isNotEmpty) {
      groups.add(GlobalQuizLessonGroup(
        courseId: course.id,
        courseTitle: course.title,
        lessonId: '',
        title: course.title,
        blocks: unassigned,
      ));
    }
  }

  return groups;
}

/// Pick up to [limit] answerable blocks from across [courses].
List<ContentBlock> buildGlobalQuizPool(
  List<Course> courses, {
  required int seed,
  int limit = globalQuizLength,
}) {
  final pool = buildGlobalQuizCandidates(courses);
  pool.shuffle(Random(seed));
  return pool.length <= limit ? pool : pool.sublist(0, limit);
}
