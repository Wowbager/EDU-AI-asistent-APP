import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/lesson_detail_page.dart';

/// BR-J43MA4 — the AI-help ("Zeptat se AI") context for an open question leaked
/// the options/text of an *earlier* MCQ step in the same block, because the
/// context was built by scanning every step for the first one with options
/// while the block's own `currentStepIndex` stayed frozen at 0.
///
/// These tests drive [buildLessonChatContext] directly with the live step index
/// the engine reports, proving the context is scoped to the step the student is
/// actually on.
void main() {
  // A block that bundles an answered MCQ step (s1) and the current open
  // question step (s2) — the exact "Statistika / přísloví" shape from the bug.
  ContentBlock proverbBlock() => ContentBlock(
        blockId: 'b1',
        type: BlockType.question,
        steps: [
          const BlockStep(
            stepId: 's1',
            type: StepType.evaluation,
            content: StepContent(text: 'Kolik jablek je na obrázku?'),
            evaluationConfig: EvaluationConfig(
              type: 'multiple_choice',
              question: 'Kolik jablek je na obrázku?',
              options: [
                EvaluationOption(id: 'a', text: '4'),
                EvaluationOption(id: 'b', text: '3'),
                EvaluationOption(id: 'c', text: '2'),
                EvaluationOption(id: 'd', text: '9'),
              ],
            ),
          ),
          const BlockStep(
            stepId: 's2',
            type: StepType.evaluation,
            content: StepContent(text: 'Jaké přísloví se sem hodí?'),
            hint: 'Strom, jablka, rodina...',
            help: 'Když jsou děti podobné rodičům, říká se...',
            evaluationConfig: EvaluationConfig(type: 'open'),
          ),
        ],
      );

  test('open question (step 2) does not leak the earlier MCQ options', () {
    final context = buildLessonChatContext(
      block: proverbBlock(),
      courseName: 'Statistika',
      lessonName: 'Data a základní pojmy',
      liveStepIndex: 1,
    );

    // The current (open) question, hint and help are present …
    expect(context, contains('Jaké přísloví se sem hodí?'));
    expect(context, contains('Strom, jablka, rodina...'));
    expect(context, contains('Když jsou děti podobné rodičům'));

    // … and none of the earlier MCQ bleeds through.
    expect(context, isNot(contains('Otázka s možnostmi')));
    expect(context, isNot(contains('- 4')));
    expect(context, isNot(contains('- 9')));
    expect(context, isNot(contains('Kolik jablek')));
  });

  test('MCQ question (step 1) still gets its own options', () {
    final context = buildLessonChatContext(
      block: proverbBlock(),
      courseName: 'Statistika',
      lessonName: 'Data a základní pojmy',
      liveStepIndex: 0,
    );

    expect(context, contains('Otázka s možnostmi'));
    expect(context, contains('- 4'));
    expect(context, contains('- 9'));
    expect(context, contains('Kolik jablek je na obrázku?'));

    // The later open step's hint/help must not appear while on the MCQ.
    expect(context, isNot(contains('Strom, jablka, rodina')));
  });

  test('a clamped-out-of-range live index falls back to the last step', () {
    final context = buildLessonChatContext(
      block: proverbBlock(),
      courseName: 'Statistika',
      lessonName: 'Data a základní pojmy',
      liveStepIndex: 99,
    );

    // Clamped to step 2 (open) — behaves like the open-question case.
    expect(context, contains('Jaké přísloví se sem hodí?'));
    expect(context, isNot(contains('- 4')));
  });

  test('the student message is threaded into the context', () {
    final context = buildLessonChatContext(
      block: proverbBlock(),
      courseName: 'Statistika',
      lessonName: 'Data a základní pojmy',
      liveStepIndex: 1,
      studentMessage: 'pořád nevím',
    );

    expect(context, contains('pořád nevím'));
  });
}
