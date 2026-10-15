// BR-TF9ZKD — only a wrong *exercise* auto-lands in Procvičování.
//
// Answering wrong used to auto-bookmark (and seed an FSRS card for) any
// interactive block. That swept up `question` blocks too — in-lesson checks and
// surveys such as "Dělal jsi přijímačky z matematiky?", where the reported
// block had default_practice off and no meaningful right answer at all. Those
// then came back in the daily queue.
//
// The gate now sits on the block type, in one place
// ([BlockTypeExtension.seedsPracticeOnWrong]), read by every auto-bookmark
// caller: lesson_detail_page (atomic answers + BlockStepEngine.onWrongAnswer)
// and quiz_page.
//
// Deliberately *not* gated: a manual bookmark tap and an admin-configured
// default_practice block. Both are opt-ins, so they keep seeding a card for a
// question block — covered by the last two tests here.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/data/repositories/practice_repository.dart';
import 'package:eduai/models/block_model.dart';

/// Blocks of the bundled onboarding course, which carries both `question` and
/// `exercise` blocks as authored by the admin editor.
List<ContentBlock> _bundledBlocks() {
  final data = jsonDecode(
    File('assets/courses/EDU_ONBOARDING_APP.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final b in (data['blocks'] as List))
      ContentBlock.fromJson(b as Map<String, dynamic>),
  ];
}

ContentBlock _firstOfType(List<ContentBlock> blocks, BlockType type) =>
    blocks.firstWhere((b) => b.type == type);

void main() {
  group('seedsPracticeOnWrong', () {
    test('is true for exercise blocks only', () {
      expect(BlockType.exercise.seedsPracticeOnWrong, isTrue);

      for (final type in BlockType.values.where((t) => t != BlockType.exercise)) {
        expect(type.seedsPracticeOnWrong, isFalse, reason: '$type must not seed');
      }
    });

    test('an admin-authored `exercise` block still seeds', () {
      // Real course JSON, so the assertion covers the parse too: the admin
      // editor writes type "exercise" for a step block carrying a question,
      // and that must survive into BlockType.exercise.
      final block = _firstOfType(_bundledBlocks(), BlockType.exercise);

      expect(block.hasV2Steps, isTrue);
      expect(block.type.seedsPracticeOnWrong, isTrue);
    });

    test('the reported survey shape — a `question` block with steps — does not',
        () {
      // Shape of the block in BR-TF9ZKD: type "question", steps, an open
      // answer nobody can get "right", default_practice off.
      final block = ContentBlock.fromJson(const {
        'block_id': 'B-PRIJIMACKY',
        'type': 'question',
        'steps': [
          {'id': 's1', 'type': 'text', 'order': 1, 'content': 'Vítáme tě'},
          {
            'id': 's2',
            'type': 'question',
            'order': 2,
            'question': {'type': 'open', 'correct_answer': 'jakýkoliv počet bodů'},
          },
        ],
      });

      expect(block.type, BlockType.question);
      expect(block.type.seedsPracticeOnWrong, isFalse);
    });

    test('stays false for a question block even when default_practice is on',
        () {
      final block = ContentBlock.fromJson(const {
        'block_id': 'B-SURVEY',
        'type': 'question',
        'default_practice': true,
      });

      expect(block.defaultPractice, isTrue);
      expect(block.type.seedsPracticeOnWrong, isFalse,
          reason: 'the flag drives the lesson-completion seed, not this gate');
    });
  });

  group('the deck itself is not gated', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a manual bookmark still seeds a card for a question block', () async {
      const userId = 'user-1';
      await db.upsertCourse(CoursesTableCompanion(
        id: const Value('c-1'),
        courseId: const Value('COURSE_1'),
        name: const Value('Course'),
        data: Value(jsonEncode({'course_id': 'COURSE_1'})),
      ));

      final block = ContentBlock.fromJson(const {
        'block_id': 'B-PRIJIMACKY',
        'type': 'question',
      });
      final card = await PracticeRepository(db: db).createCardFromBlock(
        userId: userId,
        courseId: 'c-1',
        lessonId: 'L1',
        block: block,
        sourceType: 'bookmark',
      );

      expect(card?.blockId, block.blockId);
      expect((await db.getActivePracticeCards(userId)).length, 1);
    });

    test('createCardsFromLesson still seeds default_practice question blocks',
        () async {
      const userId = 'user-1';
      await db.upsertCourse(CoursesTableCompanion(
        id: const Value('c-1'),
        courseId: const Value('COURSE_1'),
        name: const Value('Course'),
        data: Value(jsonEncode({'course_id': 'COURSE_1'})),
      ));

      final created = await PracticeRepository(db: db).createCardsFromLesson(
        userId: userId,
        courseId: 'c-1',
        lessonId: 'L1',
        blocks: [
          ContentBlock.fromJson(const {
            'block_id': 'B-OPT-IN',
            'type': 'question',
            'default_practice': true,
          }),
          ContentBlock.fromJson(const {
            'block_id': 'B-PLAIN',
            'type': 'question',
          }),
        ],
      );

      expect(created, 1);
      expect(
        (await db.getActivePracticeCards(userId)).map((c) => c.blockId),
        ['B-OPT-IN'],
      );
    });
  });
}
