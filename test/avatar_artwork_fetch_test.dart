// Fetching avatar artwork from the public R2 bucket (BR-7JRBCN).
//
// Stage regression: the catalog and /user/avatar both returned 200, yet the
// shop still reported itself offline. Artwork downloads were going through the
// app's API client, whose AuthInterceptor attaches our Sanctum bearer token to
// every request unconditionally. R2 is S3-compatible and tries to parse
// `Authorization` as a signature, so it rejected all 40 downloads — and a 401
// from a bucket would have been read as an expired session and logged the user
// out.
//
//   flutter test test/avatar_artwork_fetch_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/data/datasources/remote/avatar_remote_datasource.dart';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="0 0 270.93 270.93"><rect width="270" height="270"/></svg>';

const _r2Url =
    'https://pub-4e0c94219f454e70a63b7f41b436f85f.r2.dev/avatar/head/x.svg';

/// Records what actually reached the bucket.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final String body;
  final int statusCode;

  _RecordingAdapter({this.body = _svg, this.statusCode = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(body, statusCode);
  }

  @override
  void close({bool force = false}) {}
}

/// A real [ApiClient] holding a real token, so a regression that routes the
/// download back through it would actually leak something observable.
Future<AvatarRemoteDataSource> _dataSource(_RecordingAdapter adapter) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'secret-session'});

  final tokens = AuthTokenStorage(prefs: await SharedPreferences.getInstance());
  await tokens.load();

  return AvatarRemoteDataSource(
    ApiClient(tokens),
    storageClient: Dio()..httpClientAdapter = adapter,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bucket never sees our session token', () async {
    final adapter = _RecordingAdapter();

    final result = await (await _dataSource(adapter)).downloadSvg(_r2Url);

    expect(result.isSuccess, isTrue);
    expect(adapter.requests, hasLength(1));
    expect(
      adapter.requests.single.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
      reason: 'R2 is a third party; the token must not leave our API',
    );
  });

  test('the artwork request goes to the absolute bucket URL', () async {
    final adapter = _RecordingAdapter();

    await (await _dataSource(adapter)).downloadSvg(_r2Url);

    expect(adapter.requests.single.uri.toString(), _r2Url);
  });

  test('a rejected download fails softly instead of throwing', () async {
    // One unreachable item must not take the whole refresh down with it.
    final adapter = _RecordingAdapter(body: 'Forbidden', statusCode: 403);

    final result = await (await _dataSource(adapter)).downloadSvg(_r2Url);

    expect(result.isFailure, isTrue);
  });

  test('a response that is not an SVG is rejected', () async {
    // A captive-portal or error page must never be cached as artwork.
    final adapter = _RecordingAdapter(body: '<html>nope</html>');

    final result = await (await _dataSource(adapter)).downloadSvg(_r2Url);

    expect(result.isFailure, isTrue);
  });
}
