// Regression test for BR-NT8CEC: the retry interceptor must NOT resend
// non-idempotent requests. Retrying a POST that timed out client-side (while
// the server already processed it) duplicated chat messages — the AI-help
// block context showed up twice. GET/HEAD carry no side effects and stay
// retryable so sync/read traffic keeps its resilience.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/network/api_interceptors.dart';

/// Adapter that returns 503 for the first [failTimes] calls, then 200.
class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;
  final int failTimes;
  _CountingAdapter({this.failTimes = 1 << 30});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final status = calls <= failTimes ? 503 : 200;
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_CountingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(RetryInterceptor(dio));
  return dio;
}

void main() {
  test('GET is retried once on a 5xx and succeeds', () async {
    final adapter = _CountingAdapter(failTimes: 1); // fail first, succeed on retry
    final dio = _dioWith(adapter);

    final res = await dio.get('/sync');

    expect(res.statusCode, 200);
    expect(adapter.calls, 2, reason: 'GET should be resent exactly once');
  });

  test('POST is NOT retried on a 5xx (non-idempotent)', () async {
    final adapter = _CountingAdapter(); // always 503
    final dio = _dioWith(adapter);

    await expectLater(
      dio.post('/chat/sessions/1/messages', data: {'content': 'hi'}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1,
        reason: 'a non-idempotent POST must not be resent — it would duplicate');
  });
}
