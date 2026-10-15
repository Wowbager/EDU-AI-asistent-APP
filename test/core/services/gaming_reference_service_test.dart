// BR-H3TCRE — the quiz fetches each task's previous valid reaction times so
// GamingGuard.classify can switch from the fixed 2 s floor to the robust
// median/MAD threshold. Anything that goes wrong must leave the quiz on the
// floor, never block or crash an answer.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/network/api_endpoints.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/services/gaming_reference_service.dart';

late SharedPreferences _prefs;

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient(this.respond) : super(AuthTokenStorage(prefs: _prefs));

  final ApiResult<dynamic> Function() respond;
  final calls = <(String, Map<String, dynamic>?)>[];

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    calls.add((path, queryParameters));
    final result = respond();
    return result.isSuccess
        ? ApiResult.success(result.data as T)
        : ApiResult.failure(result.error!);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  group('GamingReferenceService.fetch', () {
    test('asks for every distinct, non-empty block id in one request', () async {
      final api = _RecordingApiClient(
        () => ApiResult.success(<String, dynamic>{'data': <String, dynamic>{}}),
      );

      await GamingReferenceService(api).fetch(['blk_a', '', 'blk_b', 'blk_a']);

      expect(api.calls, hasLength(1));
      expect(api.calls.single.$1, ApiEndpoints.eloGamingReference);
      expect(api.calls.single.$2, {'block_ids': 'blk_a,blk_b'});
    });

    test('returns the reference times per block as doubles', () async {
      final api = _RecordingApiClient(() => ApiResult.success(<String, dynamic>{
            'data': {
              'blk_a': [4.25, 7, 12.001],
              'blk_b': <dynamic>[],
            },
          }));

      final reference =
          await GamingReferenceService(api).fetch(['blk_a', 'blk_b']);

      expect(reference, {
        'blk_a': [4.25, 7.0, 12.001],
        'blk_b': <double>[],
      });
    });

    test('no block ids, no request', () async {
      final api = _RecordingApiClient(
        () => ApiResult.success(<String, dynamic>{'data': <String, dynamic>{}}),
      );

      expect(await GamingReferenceService(api).fetch(['', '']), isEmpty);
      expect(api.calls, isEmpty);
    });

    test('offline or a server error leaves the fixed floor (empty)', () async {
      final api = _RecordingApiClient(() => ApiResult.failure('offline'));

      expect(await GamingReferenceService(api).fetch(['blk_a']), isEmpty);
    });

    test('a malformed body is ignored entry by entry, never thrown', () async {
      final api = _RecordingApiClient(() => ApiResult.success(<String, dynamic>{
            'data': {
              'blk_a': [5.5, 'x', null, 6],
              'blk_b': 'nope',
            },
          }));

      expect(
        await GamingReferenceService(api).fetch(['blk_a', 'blk_b']),
        {
          'blk_a': [5.5, 6.0],
        },
      );

      final listBody = _RecordingApiClient(
        () => ApiResult.success(<String, dynamic>{'data': <dynamic>[]}),
      );
      expect(await GamingReferenceService(listBody).fetch(['blk_a']), isEmpty);
    });
  });
}
