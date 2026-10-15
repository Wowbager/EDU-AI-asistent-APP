import '../../models/block_model.dart';

/// Practice always feeds back (BR-9ZA9TT).
///
/// `show_solution` is an authoring switch about the *lesson*: it lets an author
/// keep the worked solution off the screen while the class is still working on
/// the exercise. Practice is the opposite situation — the card comes back days
/// later, out of its lesson, with nobody to ask — so a silent red border is all
/// the student gets, which teaches nothing (the report's screenshot is exactly
/// that: a wrong answer, no verdict text, no model answer, "Pokračovat").
///
/// The flag is read in ~8 places across the atomic quiz card, the step engine
/// and the step renderer, so it is overridden once here, on the copy that goes
/// into the session, rather than at each of them. The stored course JSON is
/// untouched: the lesson keeps the behaviour its author chose.
ContentBlock withPracticeFeedback(ContentBlock block) {
  final question = block.atomicQuestion;
  final needsAtomic = question != null && !question.showSolution;
  final needsSteps = block.steps.any(
    (s) => s.evaluationConfig?.showSolution == false,
  );
  if (!needsAtomic && !needsSteps) return block;

  return block.copyWith(
    atomicQuestion: needsAtomic ? question.copyWith(showSolution: true) : null,
    steps: needsSteps
        ? [
            for (final step in block.steps)
              step.evaluationConfig?.showSolution == false
                  ? step.copyWith(
                      evaluationConfig:
                          step.evaluationConfig!.copyWith(showSolution: true),
                    )
                  : step,
          ]
        : null,
  );
}
