// AI comment for the end-of-quiz feedback popup ("Quiz Feedback v1").
//
// After a block of questions the popup shows, besides the outcome counts and
// the domain ELO deltas, a short AI-written comment on how the student worked
// (hint usage, guessing, what to practise next). The comment is online-only
// and strictly best-effort: any failure — offline, timeout, server error —
// returns null and the popup simply hides the section. The popup must never
// wait on this to render.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_service.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../providers/core_providers.dart';

/// One question of the finished block, as the AI comment endpoint wants it.
class QuizFeedbackTask {
  /// Task statement, already sanitized and truncated by the caller.
  final String assignment;

  /// `correct_no_hint | correct_with_hint | wrong | unanswered | gamed` —
  /// mirrors [QuizQuestionOutcome].
  final String outcome;

  final bool hintUsed;
  final bool helpUsed;

  /// Milliseconds from first reveal to answer, when both ends were captured.
  final int? durationMs;

  const QuizFeedbackTask({
    required this.assignment,
    required this.outcome,
    this.hintUsed = false,
    this.helpUsed = false,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'assignment': assignment,
        'outcome': outcome,
        'hint_used': hintUsed,
        'help_used': helpUsed,
        if (durationMs != null) 'duration_ms': durationMs,
      };
}

/// Fetches the AI comment for a finished quiz block.
class QuizFeedbackCommentService {
  final ApiClient _api;
  final ConnectivityService _connectivity;

  /// Slightly above the server's own LLM timeout, same reasoning as
  /// [AiAnswerEvaluator].
  static const Duration _timeout = Duration(seconds: 30);

  QuizFeedbackCommentService(this._api, this._connectivity);

  /// The comment, or null when it cannot be had — offline, error, timeout.
  ///
  /// [domainDeltas] maps domain code → average ELO delta over the block.
  Future<String?> fetchComment({
    required List<QuizFeedbackTask> tasks,
    Map<String, double> domainDeltas = const {},
    String? language,
  }) async {
    if (tasks.isEmpty) return null;
    if (!await _connectivity.isOnline) return null;

    try {
      final result = await _api
          .post<Map<String, dynamic>>(
            ApiEndpoints.quizFeedback,
            data: {
              'tasks': tasks.map((t) => t.toJson()).toList(),
              if (domainDeltas.isNotEmpty) 'domain_deltas': domainDeltas,
              if (language != null && language.trim().isNotEmpty)
                'language': language,
            },
            fromJson: (raw) =>
                raw is Map<String, dynamic> ? raw : <String, dynamic>{},
          )
          .timeout(_timeout);

      if (result.isFailure) return null;
      final payload = result.data?['data'];
      if (payload is! Map<String, dynamic>) return null;
      final comment = payload['comment'];
      if (comment is! String || comment.trim().isEmpty) return null;
      return comment.trim();
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

final quizFeedbackCommentProvider = Provider<QuizFeedbackCommentService>((ref) {
  return QuizFeedbackCommentService(
    ref.watch(apiClientProvider),
    ref.watch(connectivityServiceProvider),
  );
});
