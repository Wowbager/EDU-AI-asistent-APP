// The AI grader as the preview has it: never available.
//
// Every open answer goes to the API first (BR-N26ACB), and the engine reads the
// grader from `aiAnswerEvaluatorProvider`. A preview has no pupil, no session and
// must not send a teacher's draft to the API, so the page overrides the provider
// with this. The engine then does what the app does offline: a typed answer is
// compared with `correct_answer` (one accepted answer per line), and a photo-only
// answer keeps its retry.

import 'dart:typed_data';


import '../core/evaluation/ai_answer_evaluator.dart';
import '../models/block_model.dart';

class PreviewAnswerEvaluator implements AiAnswerEvaluator {
  const PreviewAnswerEvaluator();

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      null;

  @override
  Future<AiEvaluationOutcome> evaluate({
    required String question,
    String studentAnswer = '',
    String? photoName,
    String? help,
    String? solution,
    String? correctAnswer,
    String? criteria,
    List<QuestionCriterion> criteriaList = const [],
    String? language,
  }) async =>
      const AiEvaluationOutcome.failed(AiEvaluationFailure.unavailable);
}

/// The overrides every preview subtree runs under, in the whole-app build (the
/// `/preview` route) and in the editor's own entry point alike.
final previewProviderOverrides = [
  aiAnswerEvaluatorProvider.overrideWithValue(const PreviewAnswerEvaluator()),
];
