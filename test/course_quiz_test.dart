// BR-WRMW7W: a course's "Kvíz" (course page, the lesson page once the course
// is done, the dashboard's "Rychlé kvízy") is drawn by the global quiz's
// rule — ten questions matched to the student's ELO — instead of handing
// over every question block the course holds. Courses whose quiz is the
// assessment itself keep every question, and an unfinished run keeps the
// blocks it already answered so the resume store still lines up.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/elo/elo_engine.dart';
import 'package:eduai/core/gamification/course_quiz.dart';
import 'package:eduai/core/gamification/global_quiz.dart';
import 'package:eduai/models/course_model.dart';

Map<String, dynamic>? _template;

/// One exercise block cloned from the bundled fixture under [id], with GPF
/// vectors that make it rankable when [elo] is given.
ContentBlock _block(String id, {double? elo}) {
  _template ??= (jsonDecode(
    File('assets/courses/EDU_ONBOARDING_APP.json').readAsStringSync(),
  ) as Map<String, dynamic>)['blocks']
      .cast<Map<String, dynamic>>()
      .firstWhere((b) => b['type'] == 'exercise') as Map<String, dynamic>;

  final json = Map<String, dynamic>.from(_template!);
  json['block_id'] = id;
  if (elo == null) {
    json.remove('gpf');
  } else {
    json['gpf'] = {
      'relation_vector':
          List<double>.generate(kGpfDimensions, (i) => i == 0 ? 2.0 : 0.0),
      'elo_vector':
          List<double?>.generate(kGpfDimensions, (i) => i == 0 ? elo : null),
    };
  }
  return ContentBlock.fromJson(json);
}

/// The 48-question course from the report's screenshot ("Karta 1 z 48").
List<ContentBlock> _coursePool() => [
      for (var i = 0; i < 48; i++) _block('b$i', elo: (i % 10).toDouble()),
    ];

final _student = List<double?>.generate(kGpfDimensions, (i) => i == 0 ? 5.0 : null);

Course _course(Map<String, dynamic> flags) =>
    Course.fromJsonData(id: 'C1', data: {'title': 'Kurz', ...flags});

void main() {
  group('courseQuizIsDrawn', () {
    test('a regular course draws its quiz', () {
      expect(courseQuizIsDrawn(_course(const {})), isTrue);
    });

    test('a quiz that is the assessment keeps every question', () {
      expect(courseQuizIsDrawn(_course(const {'only_once': true})), isFalse);
      expect(courseQuizIsDrawn(_course(const {'starts_with_quiz': true})),
          isFalse);
      expect(courseQuizIsDrawn(_course(const {'only_quiz': true})), isFalse);
    });
  });

  group('selectCourseQuizBlocks', () {
    test('a 48-question course yields ten distinct questions, not all 48', () {
      final picked = selectCourseQuizBlocks(
        pool: _coursePool(),
        studentElo: _student,
        random: Random(1),
      );
      expect(picked, hasLength(globalQuizLength));
      expect(picked.map((b) => b.blockId).toSet(), hasLength(globalQuizLength));
    });

    test('the draw is ELO-matched like the global quiz', () {
      final pool = [
        for (var i = 0; i < 20; i++) _block('near$i', elo: 5.0),
        for (var i = 0; i < 20; i++) _block('far$i', elo: 0.0),
      ];
      final picked = selectCourseQuizBlocks(
        pool: pool,
        studentElo: _student,
        random: Random(2),
      );
      expect(picked.map((b) => b.blockId), everyElement(startsWith('near')));
    });

    test('a course with fewer questions than one quiz asks them all', () {
      final pool = [for (var i = 0; i < 6; i++) _block('b$i', elo: 5.0)];
      final picked = selectCourseQuizBlocks(
        pool: pool,
        studentElo: _student,
        random: Random(3),
      );
      expect(picked.map((b) => b.blockId).toSet(),
          pool.map((b) => b.blockId).toSet());
    });

    test('an unfinished run keeps its answered blocks, first, and tops up', () {
      final picked = selectCourseQuizBlocks(
        pool: _coursePool(),
        studentElo: _student,
        answeredBlockIds: const {'b40', 'b7', 'gone'},
        random: Random(4),
      );
      expect(picked, hasLength(globalQuizLength));
      expect(picked.take(2).map((b) => b.blockId), ['b7', 'b40'],
          reason: 'answered blocks lead, in course order, so the resume '
              'lands on the first unanswered question');
      expect(picked.map((b) => b.blockId).toSet(), hasLength(globalQuizLength));
    });

    test('a block listed by two lessons is asked once', () {
      // Seven questions, each listed twice: fourteen entries, seven questions.
      final pool = [
        for (var lesson = 0; lesson < 2; lesson++)
          for (var i = 0; i < 7; i++) _block('b$i', elo: 5.0),
      ];
      final picked = selectCourseQuizBlocks(
        pool: pool,
        studentElo: _student,
        random: Random(5),
      );
      expect(picked, hasLength(7));
      expect(picked.map((b) => b.blockId).toSet(), hasLength(7));
    });
  });

  group('unfinishedQuizAnswerIds', () {
    test('reads the answered blocks of a run still in progress', () {
      expect(
        unfinishedQuizAnswerIds({
          'quiz_in_progress': true,
          'quiz_answers': {
            'b1': {'is_answered': true, 'is_correct': false},
            'b2': {'is_answered': false},
            'b3': {'is_answered': true, 'is_correct': true},
          },
        }),
        {'b1', 'b3'},
      );
    });

    test('a finished or never-started quiz has nothing to resume', () {
      expect(
        unfinishedQuizAnswerIds({
          'quiz_in_progress': false,
          'quiz_answers': {
            'b1': {'is_answered': true},
          },
        }),
        isEmpty,
      );
      expect(unfinishedQuizAnswerIds(const {}), isEmpty);
      expect(
        unfinishedQuizAnswerIds({'quiz_in_progress': true, 'quiz_answers': 3}),
        isEmpty,
      );
    });
  });
}
