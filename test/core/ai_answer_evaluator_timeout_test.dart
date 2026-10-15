import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/core/network/api_client.dart';

// Regression tests for BR-5FWNTK. The server may take two model rounds on one
// open answer — the second when the first feedback gives the expected answer
// away — and each round may use its full 20s. The app gave up after 25s, and
// Dio after 30s, so an evaluation the server was about to deliver came back as
// a failure; at temperature 0 the same question needed the second round every
// time, and the student could never get past it.
//
// testWidgets rather than test: its clock is fake, so a server that takes most
// of a minute costs no real time.

class _Conn implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Answers `POST /api/answers/evaluate` after [delay] — never, when null —
/// recording the receive timeout the caller asked Dio for.
class _SlowApi implements ApiClient {
  _SlowApi(this.delay);

  final Duration? delay;
  Duration? receiveTimeout;

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Duration? receiveTimeout,
  }) async {
    this.receiveTimeout = receiveTimeout;
    final delay = this.delay;
    // A completer rather than a long timer: a timer would outlive the test.
    await (delay == null
        ? Completer<void>().future
        : Future<void>.delayed(delay));
    final body = <String, dynamic>{
      'data': {
        'score': 1.0,
        'is_correct': true,
        'feedback': 'Správně.',
        'model': 'test',
      },
    };
    return ApiResult.success(
      fromJson != null ? fromJson(body) : body as T,
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// What the server allows itself per round (`AI_EVAL_TIMEOUT`,
/// `AI_EVAL_VISION_TIMEOUT` defaults in eduai-api/config/chat.php).
const _textRound = Duration(seconds: 20);
const _photoRound = Duration(seconds: 45);

Future<AiEvaluationOutcome> _evaluate(
  WidgetTester tester,
  _SlowApi api, {
  String? photoName,
}) async {
  AiEvaluationOutcome? outcome;
  unawaited(AiAnswerEvaluator(api, _Conn())
      .evaluate(
        question: 'Zjednoduš výraz 2a + 3a.',
        studentAnswer: 'pět a',
        photoName: photoName,
        correctAnswer: '5a',
      )
      .then((o) => outcome = o));

  // Well past anything either budget allows, in fake time.
  await tester.pump(const Duration(minutes: 5));
  expect(outcome, isNotNull, reason: 'the evaluation must settle');
  return outcome!;
}

void main() {
  testWidgets('an answer the server grades in its second round lands',
      (tester) async {
    // Two rounds, both slow but inside the server's own limit.
    final api = _SlowApi(_textRound * 2 - const Duration(seconds: 2));

    final outcome = await _evaluate(tester, api);

    expect(outcome.isSuccess, isTrue,
        reason: 'the client gave up while the server was still grading');
    expect(outcome.result!.isCorrect, isTrue);
  });

  testWidgets('Dio is told to wait as long as the evaluator does',
      (tester) async {
    final api = _SlowApi(const Duration(seconds: 1));

    await _evaluate(tester, api);

    // Left at Dio's client-wide 30s, the receive timeout ends the call before
    // the evaluator's own budget is ever reached.
    expect(api.receiveTimeout, isNotNull);
    expect(api.receiveTimeout! > _textRound * 2, isTrue);
  });

  testWidgets('a photographed answer gets two vision rounds too',
      (tester) async {
    final api = _SlowApi(_photoRound * 2 - const Duration(seconds: 2));

    final outcome = await _evaluate(tester, api, photoName: 'postup.png');

    expect(outcome.isSuccess, isTrue);
    expect(api.receiveTimeout! > _photoRound * 2, isTrue);
  });

  testWidgets('a server that never answers still ends in a failure',
      (tester) async {
    // The budget is longer, not gone: the student must not wait forever.
    final api = _SlowApi(null);

    final outcome = await _evaluate(tester, api);

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure, AiEvaluationFailure.unavailable);
  });
}
