// BR-35W2HV: the wire contract behind the guest-upgrade merge. CodeController
// folds the calling guest into the student account when `merge_guest` is true,
// whatever `shared_device` says — so the parameter name and both values have
// to reach the server exactly as it reads them.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/services/guest_auth_service.dart';

/// Captures the /api/resolve-code body and answers "not found".
class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    body = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({'message': 'Code not found'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs});

  @override
  String? get token => 'guest-token';
  @override
  bool get isAuthenticated => true;
  @override
  Future<void> load() async {}
  @override
  Future<void> setToken(String token) async {}
  @override
  Future<void> clearToken() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(GuestAuthService, _CapturingAdapter)> service() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(_FakeAuthTokenStorage(prefs: prefs));
    final adapter = _CapturingAdapter();
    api.dio.httpClientAdapter = adapter;
    return (GuestAuthService(apiClient: api, prefs: prefs), adapter);
  }

  test('a guest-upgrade login sends merge_guest alongside shared_device',
      () async {
    final (svc, adapter) = await service();

    await svc.resolveCode('ab12cd', sharedDevice: true, mergeGuest: true);

    expect(adapter.body, {
      'code': 'AB12CD',
      'shared_device': true,
      'merge_guest': true,
    });
  });

  test('merge_guest is off unless the caller asks for it', () async {
    final (svc, adapter) = await service();

    await svc.resolveCode('ab12cd', sharedDevice: true);

    expect(adapter.body!['merge_guest'], isFalse);
  });
}
