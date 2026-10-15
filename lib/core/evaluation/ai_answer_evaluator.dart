import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/block_model.dart';
import '../../models/open_answer_feedback.dart';
import '../connectivity/connectivity_service.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../providers/core_providers.dart';

/// Outcome of an AI-evaluated open answer (BR-FFVVYR, reshaped by BR-P745Q8).
class AiEvaluationResult {
  /// 0.0–1.0 partial credit.
  ///
  /// Internal. It feeds `scoreKoef`, so ELO and FSRS see partial credit — but
  /// nothing student-facing may render it, and neither may [isCorrect]. The
  /// brief is explicit: feedback teaches, it does not classify.
  final double score;

  /// Whether the score cleared the server-side pass threshold. Internal, for
  /// the same reason as [score]; drives progress and the teacher view only.
  final bool isCorrect;

  /// What the student actually sees. Null only on responses from a server
  /// that predates BR-P745Q8, where [feedbackText] is all there is.
  final FormativeFeedback? feedback;

  /// Flat feedback string. Kept for the pre-BR-P745Q8 fallback path.
  final String feedbackText;

  /// Situations that need the UI to behave differently — an unreadable photo
  /// should stay attached so the student can replace it, not silently vanish.
  final List<AnswerFlag> flags;

  /// Model that produced the feedback, recorded so a teacher can tell which
  /// model judged an answer if the configured model changes later.
  final String? model;

  /// Prompt contract the feedback was produced under. Stored with the attempt
  /// so a later prompt rewrite stays auditable.
  final String? promptVersion;

  /// Per-criterion scores, when the question defines criteria. Teacher-facing.
  final List<Map<String, dynamic>> criteriaScores;

  const AiEvaluationResult({
    required this.score,
    required this.isCorrect,
    required this.feedbackText,
    this.feedback,
    this.flags = const [],
    this.model,
    this.promptVersion,
    this.criteriaScores = const [],
  });

  bool get hasFlag => flags.isNotEmpty;

  bool get photoUnreadable => flags.contains(AnswerFlag.unreadablePhoto);

  factory AiEvaluationResult.fromJson(Map<String, dynamic> json) {
    return AiEvaluationResult(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      isCorrect: json['is_correct'] as bool? ?? false,
      feedbackText: json['feedback'] as String? ?? '',
      feedback: FormativeFeedback.fromJson(json['feedback_parts']),
      flags: AnswerFlag.parseList(json['flags']),
      model: json['model'] as String?,
      promptVersion: json['prompt_version'] as String?,
      criteriaScores: (json['criteria_scores'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

/// Why an evaluation did not produce feedback.
///
/// BR-FFVVYR collapsed every failure into `null`, and callers answered it by
/// falling back to `answer == expected` string comparison. That was defensible
/// while a wrong verdict was the worst case. It is not defensible now: against
/// a paragraph-long expected answer the comparison always fails, so the
/// fallback reliably told a correct student they were wrong. Callers now
/// distinguish the cases and offer a retry instead.
enum AiEvaluationFailure {
  /// No connection. The answer is kept; evaluation is retried later.
  offline,

  /// Timed out, 5xx, or an unparseable response.
  unavailable,

  /// Throttled. Same handling as [unavailable], separated for logging.
  rateLimited,

  /// Nothing to send — no text and no photo.
  emptyAnswer,

  /// The server rejected the request outright (422): the question carries no
  /// statement, no expected answer and no criteria, so there is nothing to
  /// judge against.
  ///
  /// Separate from [unavailable] because retrying cannot fix it. Offering a
  /// retry button here produced an endless loop that burned the student's rate
  /// limit and never returned feedback — this is a content bug, and the student
  /// should be able to move on.
  notEvaluable,
}

/// Either feedback or a reason there is none.
class AiEvaluationOutcome {
  final AiEvaluationResult? result;
  final AiEvaluationFailure? failure;

  const AiEvaluationOutcome.success(AiEvaluationResult this.result)
    : failure = null;

  const AiEvaluationOutcome.failed(AiEvaluationFailure this.failure)
    : result = null;

  bool get isSuccess => result != null;
}

/// Handle of an uploaded photo, as issued by the API.
class UploadedPhoto {
  final String name;
  final String mimeType;
  final int size;

  const UploadedPhoto({
    required this.name,
    required this.mimeType,
    required this.size,
  });
}

/// Evaluates free-text and photographed answers via the API.
///
/// The app deliberately does no evaluation of its own for AI questions. Doing
/// it locally would mean either shipping the expected answer into a comparison
/// that cannot handle rephrasing, or showing the student a verdict the brief
/// forbids — so when the API cannot answer, the student is asked to try again.
class AiAnswerEvaluator {
  final ApiClient _api;
  final ConnectivityService _connectivity;

  /// Above the longest the server may legitimately take, so a slow-but-
  /// successful evaluation still lands instead of being cut off client-side.
  ///
  /// That is two model rounds, not one: when the first feedback gives the
  /// expected answer away, the server asks again (BR-P745Q8), and each round
  /// may use its full `AI_EVAL_TIMEOUT` (20s). The old 25s covered a single
  /// round, so an answer that needed the second one timed out here while the
  /// server was still working — and the same question, graded at temperature
  /// 0, needed it every time (BR-5FWNTK).
  static const Duration _timeout = Duration(seconds: 2 * 20 + 10);

  /// Reading a photograph takes longer than reading a sentence; the server
  /// allows 45s per vision round (`AI_EVAL_VISION_TIMEOUT`), again up to two.
  static const Duration _photoTimeout = Duration(seconds: 2 * 45 + 10);

  AiAnswerEvaluator(this._api, this._connectivity);

  /// Upload a photographed answer, returning the handle to send with the
  /// evaluation. Null when the upload failed — the caller keeps the local file
  /// so the student can retry without re-taking the picture.
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async {
    if (!await _connectivity.isOnline) return null;

    try {
      final form = FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: filename),
        if (courseId != null) 'course_id': courseId,
      });

      final result = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.answerPhoto,
        data: form,
        fromJson: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      if (result.isFailure) return null;

      final payload = result.data?['data'];
      if (payload is! Map<String, dynamic>) return null;

      final name = payload['photo_name'] as String?;
      if (name == null || name.isEmpty) return null;

      return UploadedPhoto(
        name: name,
        mimeType: payload['mime_type'] as String? ?? 'image/jpeg',
        size: (payload['size'] as num?)?.toInt() ?? bytes.length,
      );
    } catch (_) {
      return null;
    }
  }

  /// Evaluate one open answer.
  ///
  /// Unlike BR-FFVVYR's version this does not refuse to run when the question
  /// has no reference material: the brief says a question with neither an
  /// expected answer nor criteria should still get feedback, judged on plain
  /// factual correctness against the task statement.
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
  }) async {
    final hasPhoto = photoName != null && photoName.isNotEmpty;
    if (studentAnswer.trim().isEmpty && !hasPhoto) {
      return const AiEvaluationOutcome.failed(AiEvaluationFailure.emptyAnswer);
    }

    if (!await _connectivity.isOnline) {
      return const AiEvaluationOutcome.failed(AiEvaluationFailure.offline);
    }

    final timeout = hasPhoto ? _photoTimeout : _timeout;

    try {
      final result = await _api
          .post<Map<String, dynamic>>(
            ApiEndpoints.answersEvaluate,
            data: {
              'question': question,
              if (studentAnswer.trim().isNotEmpty) 'student_answer': studentAnswer,
              if (hasPhoto) 'photo_name': photoName,
              if (help != null && help.trim().isNotEmpty) 'help': help,
              if (solution != null && solution.trim().isNotEmpty) 'solution': solution,
              if (correctAnswer != null && correctAnswer.trim().isNotEmpty)
                'correct_answer': correctAnswer,
              if (criteria != null && criteria.trim().isNotEmpty) 'criteria': criteria,
              if (criteriaList.isNotEmpty)
                'criteria_list': criteriaList.map((c) => c.toJson()).toList(),
              if (language != null && language.trim().isNotEmpty) 'language': language,
            },
            fromJson: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
            // Dio's own 30s receive timeout would otherwise end the call
            // first — the photo budget never took effect because of it.
            receiveTimeout: timeout,
          )
          .timeout(timeout);

      if (result.isFailure) {
        return AiEvaluationOutcome.failed(switch (result.statusCode) {
          429 => AiEvaluationFailure.rateLimited,
          422 => AiEvaluationFailure.notEvaluable,
          _ => AiEvaluationFailure.unavailable,
        });
      }

      final payload = result.data?['data'];
      if (payload is! Map<String, dynamic>) {
        return const AiEvaluationOutcome.failed(AiEvaluationFailure.unavailable);
      }

      return AiEvaluationOutcome.success(AiEvaluationResult.fromJson(payload));
    } on TimeoutException {
      return const AiEvaluationOutcome.failed(AiEvaluationFailure.unavailable);
    } catch (_) {
      return const AiEvaluationOutcome.failed(AiEvaluationFailure.unavailable);
    }
  }
}

final aiAnswerEvaluatorProvider = Provider<AiAnswerEvaluator>((ref) {
  return AiAnswerEvaluator(
    ref.watch(apiClientProvider),
    ref.watch(connectivityServiceProvider),
  );
});
