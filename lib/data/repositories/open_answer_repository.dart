import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/core_providers.dart';
import '../../core/sync/sync_queue.dart';
import '../../models/block_model.dart';
import 'package:eduai/core/util/silent_log.dart';

/// Records free-text and photographed answers given outside quiz mode.
///
/// Quiz answers ride along inside the quiz-attempt payload; answers in lessons
/// and exercises have no such carrier, so they go through here.
///
/// BR-FFVVYR posted them directly and swallowed failures with a silent log.
/// That quietly lost every answer given offline — the one case an offline-first
/// app is supposed to handle — so BR-P745Q8 moved them onto the sync queue.
/// Nothing here blocks the student: the queue drains in the background, and the
/// feedback they were shown came from the evaluation call, not from this.
class OpenAnswerRepository {
  final SyncQueue _queue;
  static const _uuid = Uuid();

  OpenAnswerRepository(this._queue);

  /// Mint the idempotency key for an attempt.
  ///
  /// Called where the answer is *given*, not where it is sent, so a replay of
  /// the queue updates one row instead of creating a second — and so a retry,
  /// which mints a fresh key, is stored as its own attempt rather than
  /// overwriting the one it followed.
  static String newAttemptId() => _uuid.v4();

  /// Queue one evaluated attempt.
  ///
  /// [attemptId] should come from [newAttemptId] at answer time. Passing null
  /// mints one here, which is fine for a caller that has no earlier moment to
  /// hang it on but gives up idempotency across app restarts.
  Future<void> record({
    required String courseId,
    required String blockId,
    required String answerText,
    required bool isCorrect,
    String? attemptId,
    String? lessonId,
    String? stepId,
    String? photoName,
    double? aiScore,
    String? aiFeedback,
    FormativeFeedbackPayload? feedback,
    List<Map<String, dynamic>> criteriaScores = const [],
    Map<String, dynamic>? gradingBasis,
    bool evaluatedByAi = false,
    bool failed = false,
    String? aiModel,
    String? promptVersion,
    DateTime? answeredAt,
  }) async {
    if (answerText.trim().isEmpty && (photoName == null || photoName.isEmpty)) {
      return;
    }

    final clientUuid = attemptId ?? newAttemptId();

    try {
      await _queue.enqueue(
        tableName: 'open_answers',
        recordId: clientUuid,
        operation: SyncOperation.create,
        payload: {
          'client_uuid': clientUuid,
          'course_id': courseId,
          if (lessonId != null && lessonId.isNotEmpty) 'lesson_id': lessonId,
          'block_id': blockId,
          if (stepId != null && stepId.isNotEmpty) 'step_id': stepId,
          'answer_text': answerText,
          if (photoName != null && photoName.isNotEmpty) 'photo_name': photoName,
          'is_correct': isCorrect,
          'evaluated_by_ai': evaluatedByAi,
          // A failed evaluation is an outcome worth keeping: it is why the
          // student saw a retry rather than feedback.
          'attempt_status': failed ? 'failed' : 'evaluated',
          if (aiScore != null) 'ai_score': aiScore,
          if (aiFeedback != null && aiFeedback.isNotEmpty) 'ai_feedback': aiFeedback,
          if (feedback != null) 'feedback_parts': feedback,
          if (criteriaScores.isNotEmpty) 'criteria_scores': criteriaScores,
          // What this attempt was judged against, as it stood right now. The
          // teacher can still read the attempt after the question is edited.
          if (gradingBasis != null) 'grading_basis': gradingBasis,
          if (aiModel != null) 'ai_model': aiModel,
          if (promptVersion != null) 'prompt_version': promptVersion,
          'answered_at': (answeredAt ?? DateTime.now()).toUtc().toIso8601String(),
        },
        // Above ordinary background sync: a teacher looking at a class right
        // now wants today's answers, and the payload is small.
        priority: 1,
      );
    } catch (e, stack) {
      silentLog('OpenAnswerRepository.record', e, stack);
    }
  }

  /// Snapshot of the material an attempt was evaluated against.
  ///
  /// Built at answer time from the block the student is looking at, so it
  /// records the question as *they* saw it — not as it reads after the teacher
  /// rewrites it next term.
  static Map<String, dynamic> gradingBasisFor({
    required String question,
    String? expectedAnswer,
    String? solution,
    List<QuestionCriterion> criteria = const [],
  }) {
    return {
      'question': question,
      if (expectedAnswer != null && expectedAnswer.trim().isNotEmpty)
        'expected_answer': expectedAnswer,
      if (solution != null && solution.trim().isNotEmpty) 'solution': solution,
      if (criteria.isNotEmpty)
        'criteria': criteria.map((c) => c.toJson()).toList(),
    };
  }
}

/// The `feedback_parts` object as it goes over the wire.
typedef FormativeFeedbackPayload = Map<String, dynamic>;

final openAnswerRepositoryProvider = Provider<OpenAnswerRepository>((ref) {
  return OpenAnswerRepository(ref.watch(syncQueueProvider));
});
