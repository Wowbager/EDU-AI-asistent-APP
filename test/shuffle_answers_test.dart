// Answer shuffling (BR-K5RF9E).
//
// Authors can turn "zamíchat odpovědi" on for a whole course
// (CourseV2.shuffle_answers) and override it per question
// (QuestionConfig.shuffle_options). The tri-state lives only in the JSON:
// parsing resolves it into a plain bool so every consumer downstream sees a
// single answer, and the shuffle itself runs in the view layer — parsing is
// re-run on rebuild-heavy paths, so shuffling here would reorder options
// mid-question.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/course_model.dart';

Map<String, dynamic> _option(String id, {bool correct = false}) => {
      'id': id,
      'text': 'Option $id',
      'is_correct': correct,
    };

/// A course JSON with one question block, wired through the real
/// `Course.fromJsonData` → `getAllBlocks()` path so the course-level default
/// actually has to survive the plumbing.
Map<String, dynamic> _courseJson({
  bool? courseShuffle,
  bool? questionShuffle,
  String type = 'multiple_choice',
}) {
  return {
    'course_id': 'C1',
    'name': 'Test course',
    'language': 'cs',
    if (courseShuffle != null) 'shuffle_answers': courseShuffle,
    'lessons': [
      {
        'lesson_id': 'L1',
        'name': 'Lesson 1',
        'order': 1,
        'blocks': [
          {'block_id': 'B1', 'order': 1},
        ],
      },
    ],
    'blocks': [
      {
        'block_id': 'B1',
        'type': 'question',
        'duration': '1 min',
        'question': {
          'type': type,
          if (questionShuffle != null) 'shuffle_options': questionShuffle,
          'options': type == 'true_false'
              ? _trueFalseOptions
              : [
                  _option('a'),
                  _option('b', correct: true),
                  _option('c'),
                  _option('d'),
                ],
        },
      },
    ],
  };
}

/// The Ano/Ne pair as the admin writes it for a true_false question.
final _trueFalseOptions = [
  {'id': 'true', 'text': 'Ano', 'is_correct': true},
  {'id': 'false', 'text': 'Ne', 'is_correct': false},
];

AtomicQuestion _parseQuestion({
  bool? courseShuffle,
  bool? questionShuffle,
  String type = 'multiple_choice',
}) {
  final course = Course.fromJsonData(
    id: 'C1',
    data: _courseJson(
      courseShuffle: courseShuffle,
      questionShuffle: questionShuffle,
      type: type,
    ),
  );
  final block = course.getAllBlocks().firstWhere((b) => b.blockId == 'B1');
  return block.atomicQuestion!;
}

void main() {
  group('shuffle flag resolution', () {
    test('question with no shuffle_options inherits the course default', () {
      expect(_parseQuestion(courseShuffle: true).shuffleOptions, isTrue);
      expect(_parseQuestion(courseShuffle: false).shuffleOptions, isFalse);
    });

    test('legacy question in a course with no flag at all stays off', () {
      expect(_parseQuestion().shuffleOptions, isFalse);
    });

    test('shuffle_options: false overrides a course default of true', () {
      final q = _parseQuestion(courseShuffle: true, questionShuffle: false);
      expect(q.shuffleOptions, isFalse);
    });

    test('shuffle_options: true overrides a course default of false', () {
      final q = _parseQuestion(courseShuffle: false, questionShuffle: true);
      expect(q.shuffleOptions, isTrue);
    });
  });

  // BR-K3D8MP: the Ano/Ne buttons keep their authored position — shuffling is
  // for MCQ alternatives, not for a fixed binary pair.
  group('true/false questions never shuffle', () {
    test('ignore a course default of true', () {
      final q = _parseQuestion(courseShuffle: true, type: 'true_false');
      expect(q.shuffleOptions, isFalse);
    });

    test('ignore shuffle_options: true on the question itself', () {
      final q = _parseQuestion(
        courseShuffle: true,
        questionShuffle: true,
        type: 'true_false',
      );
      expect(q.shuffleOptions, isFalse);
    });

    test('keep Ano before Ne for every seed', () {
      final q = _parseQuestion(courseShuffle: true, type: 'true_false');
      for (var seed = 0; seed < 20; seed++) {
        expect(
          q.shuffledOptions(Random(seed)).map((o) => o.id),
          ['true', 'false'],
        );
      }
    });

    test('multiple choice in the same course still shuffles', () {
      expect(_parseQuestion(courseShuffle: true).shuffleOptions, isTrue);
    });
  });

  group('shuffledOptions()', () {
    test('preserves the option set, ids and is_correct mapping', () {
      final q = _parseQuestion(courseShuffle: true);
      final shuffled = q.shuffledOptions(Random(7));

      expect(shuffled.length, q.options.length);
      expect(
        shuffled.map((o) => o.id).toSet(),
        q.options.map((o) => o.id).toSet(),
      );
      // The correct flag travels with the option — evaluation keys on id, so a
      // reorder must never move correctness onto a different answer.
      for (final option in shuffled) {
        final original = q.options.firstWhere((o) => o.id == option.id);
        expect(option.isCorrect, original.isCorrect);
        expect(option.text, original.text);
      }
      expect(shuffled.where((o) => o.isCorrect).map((o) => o.id), ['b']);
    });

    test('actually reorders for at least one seed', () {
      final q = _parseQuestion(courseShuffle: true);
      final orders = List.generate(
        20,
        (i) => q.shuffledOptions(Random(i)).map((o) => o.id).join(),
      ).toSet();
      expect(orders.length, greaterThan(1));
    });

    test('returns the original order when shuffling is off', () {
      final q = _parseQuestion(courseShuffle: false);
      expect(
        q.shuffledOptions(Random(7)).map((o) => o.id),
        q.options.map((o) => o.id),
      );
    });

    test('a single option is left alone', () {
      const q = AtomicQuestion(
        type: 'multiple_choice',
        shuffleOptions: true,
        options: [EvaluationOption(id: 'a', text: 'A', isCorrect: true)],
      );
      expect(q.shuffledOptions(Random(1)).single.id, 'a');
    });
  });

  group('question steps (V2 step format)', () {
    Map<String, dynamic> stepBlockJson({
      bool? questionShuffle,
      String type = 'multiple_choice',
    }) =>
        {
          'block_id': 'B2',
          'type': 'question',
          'duration': '1 min',
          'steps': [
            {
              'id': 's1',
              'type': 'question',
              'text': 'Kolik je 2+2?',
              'question': {
                'type': type,
                if (questionShuffle != null)
                  'shuffle_options': questionShuffle,
                'options': type == 'true_false'
                    ? _trueFalseOptions
                    : [
                        _option('a'),
                        _option('b', correct: true),
                        _option('c'),
                      ],
              },
            },
          ],
        };

    test('step questions inherit the course default', () {
      final block = ContentBlock.fromJson(
        stepBlockJson(),
        courseShuffleDefault: true,
      );
      expect(block.steps.single.evaluationConfig!.shuffleOptions, isTrue);
    });

    test('step questions can override the course default', () {
      final block = ContentBlock.fromJson(
        stepBlockJson(questionShuffle: false),
        courseShuffleDefault: true,
      );
      expect(block.steps.single.evaluationConfig!.shuffleOptions, isFalse);
    });

    test('true/false steps stay unshuffled whatever the course or question says', () {
      final block = ContentBlock.fromJson(
        stepBlockJson(type: 'true_false', questionShuffle: true),
        courseShuffleDefault: true,
      );
      final config = block.steps.single.evaluationConfig!;
      expect(config.shuffleOptions, isFalse);
      expect(config.shuffledOptions(Random(1)).map((o) => o.id), ['true', 'false']);
    });

    test('EvaluationConfig.shuffledOptions keeps ids and correctness', () {
      final block = ContentBlock.fromJson(
        stepBlockJson(),
        courseShuffleDefault: true,
      );
      final config = block.steps.single.evaluationConfig!;
      final shuffled = config.shuffledOptions(Random(3));

      expect(
        shuffled.map((o) => o.id).toSet(),
        config.options.map((o) => o.id).toSet(),
      );
      expect(shuffled.where((o) => o.isCorrect).map((o) => o.id), ['b']);
    });

    test('copyWith carries the shuffled order onto the step', () {
      final block = ContentBlock.fromJson(
        stepBlockJson(),
        courseShuffleDefault: true,
      );
      final step = block.steps.single;
      final config = step.evaluationConfig!;
      final reordered = config.options.reversed.toList();

      final viewStep = step.copyWith(
        evaluationConfig: config.copyWith(options: reordered),
      );

      expect(viewStep.stepId, step.stepId);
      expect(viewStep.type, step.type);
      expect(viewStep.content?.text, step.content?.text);
      expect(
        viewStep.evaluationConfig!.options.map((o) => o.id),
        ['c', 'b', 'a'],
      );
      // Everything else on the config survives the copy.
      expect(viewStep.evaluationConfig!.shuffleOptions, isTrue);
      expect(viewStep.evaluationConfig!.type, config.type);
    });
  });
}
