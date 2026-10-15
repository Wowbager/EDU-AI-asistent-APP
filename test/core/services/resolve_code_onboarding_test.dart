// BR-YXVMKY: the "Vyber si svůj vibe" onboarding must run on a student's very
// first entry into the app and never again.
//
// A student enters by typing their login code, and the account behind that
// code was created by their teacher — it has a name, a class and a history
// before the student has ever opened the app. Nothing on the client can tell
// that first entry from the hundredth, so `/api/resolve-code` now answers it
// with `profile_setup_required`, read from the account's own `onboarded_at`.
// This pins the wire contract: the field has to survive the parse, and its
// absence has to mean "don't onboard" (an older API, a course PIN).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/services/guest_auth_service.dart';

/// Answers /api/resolve-code with a canned (status, body).
class _ScriptedAdapter implements HttpClientAdapter {
  final Map<String, (int, Object)> script;

  _ScriptedAdapter(this.script);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final entry = script[options.path] ?? (500, {'message': 'unscripted'});
    return ResponseBody.fromString(
      jsonEncode(entry.$2),
      entry.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// In-memory token store: a successful code login writes the issued token,
/// and FlutterSecureStorage has no implementation under `flutter test`.
class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs});

  String? _token;

  @override
  String? get token => _token;
  @override
  bool get isAuthenticated => _token != null;
  @override
  Future<void> load() async {}
  @override
  Future<void> setToken(String token) async => _token = token;
  @override
  Future<void> clearToken() async => _token = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GuestAuthService> service(Object body) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(_FakeAuthTokenStorage(prefs: prefs));
    api.dio.httpClientAdapter = _ScriptedAdapter({
      '/api/resolve-code': (200, body),
    });
    return GuestAuthService(apiClient: api, prefs: prefs);
  }

  Map<String, dynamic> studentBody({bool? profileSetupRequired}) => {
        'type': 'user',
        'token': 'tok-123',
        'minor': false,
        if (profileSetupRequired != null)
          'profile_setup_required': profileSetupRequired,
        'user': {'id': 7, 'name': 'Jana Nováková', 'email': 'jana@example.com'},
      };

  test('a student who has never opened the app is sent to the onboarding',
      () async {
    final svc = await service(studentBody(profileSetupRequired: true));

    final resolved = await svc.resolveCode('abc123');

    expect(resolved!.isUser, isTrue);
    expect(resolved.profileSetupRequired, isTrue);
  });

  test('a student who has onboarded signs straight in', () async {
    final svc = await service(studentBody(profileSetupRequired: false));

    final resolved = await svc.resolveCode('abc123');

    expect(resolved!.profileSetupRequired, isFalse);
  });

  test('an API that never sends the field means no onboarding', () async {
    // Fail closed on the side of not interrupting a student who is trying to
    // get into a lesson — the same direction the course-PIN path takes.
    final svc = await service(studentBody());

    final resolved = await svc.resolveCode('abc123');

    expect(resolved!.profileSetupRequired, isFalse);
  });

  test('a course PIN never carries an onboarding verdict', () async {
    final svc = await service({
      'type': 'course',
      'course': {'id': 1, 'course_id': 'c1', 'name': 'Fyzika'},
    });

    final resolved = await svc.resolveCode('pin123');

    expect(resolved!.isCourse, isTrue);
    expect(resolved.profileSetupRequired, isFalse);
  });
}
