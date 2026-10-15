// BR-3V2P22: joining a class by student code from an existing account.
//
// The service is a thin typed wrapper over three endpoints; what matters is
// that the wire shape is right (code uppercased, correct paths) and that the
// server's refusal message + status reach the caller untouched, because the
// UI shows that message verbatim and branches on 404 ("not a class").
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/services/classroom_join_service.dart';

/// Answers each path with a canned (status, body) and records the requests.
class _ScriptedAdapter implements HttpClientAdapter {
  final Map<String, (int, Object)> script;
  final List<RequestOptions> requests = [];

  _ScriptedAdapter(this.script);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient api;

  Future<ClassroomJoinService> service(Map<String, (int, Object)> script) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = ApiClient(AuthTokenStorage(prefs: prefs));
    api.dio.httpClientAdapter = _ScriptedAdapter(script);
    return ClassroomJoinService(api);
  }

  _ScriptedAdapter adapter() => api.dio.httpClientAdapter as _ScriptedAdapter;

  test('lookup sends the code uppercased and parses the class', () async {
    final svc = await service({
      '/api/user/classrooms/lookup': (
        200,
        {
          'data': {
            'classroom': {'id': 7, 'name': '5.A'},
            'student_name': 'Jana N.',
          },
        },
      ),
    });

    final result = await svc.lookup(' abc123 ');

    expect(result.isSuccess, isTrue);
    expect(result.data!.classroom.id, 7);
    expect(result.data!.classroom.name, '5.A');
    expect(result.data!.studentName, 'Jana N.');

    final sent = adapter().requests.single;
    expect(sent.method, 'POST');
    expect(sent.data, {'code': 'ABC123'});
  });

  test('a code that is no class surfaces as a 404 failure', () async {
    final svc = await service({
      '/api/user/classrooms/lookup': (404, {'message': 'Kód třídy nebyl nalezen.'}),
    });

    final result = await svc.lookup('ZZZ999');

    expect(result.isFailure, isTrue);
    expect(result.statusCode, 404);
    expect(result.error, 'Kód třídy nebyl nalezen.');
  });

  test('join returns the joined class and the full membership list', () async {
    final svc = await service({
      '/api/user/classrooms/join': (
        200,
        {
          'data': {
            'classroom': {'id': 9, 'name': 'Fyzika 7'},
            'classrooms': [
              {'id': 7, 'name': '5.A'},
              {'id': 9, 'name': 'Fyzika 7'},
            ],
          },
        },
      ),
    });

    final result = await svc.join('bbb222');

    expect(result.isSuccess, isTrue);
    expect(result.data!.classroom.name, 'Fyzika 7');
    expect(result.data!.classrooms.map((c) => c.id), [7, 9]);
    expect(adapter().requests.single.data, {'code': 'BBB222'});
  });

  test('a refused join keeps the server message and status', () async {
    final svc = await service({
      '/api/user/classrooms/join': (409, {'message': 'Už jsi ve třídě 5.A.'}),
    });

    final result = await svc.join('ABC123');

    expect(result.isFailure, isTrue);
    expect(result.statusCode, 409);
    expect(result.error, 'Už jsi ve třídě 5.A.');
  });

  test('myClassrooms lists the current membership', () async {
    final svc = await service({
      '/api/user/classrooms': (
        200,
        {
          'data': [
            {'id': 7, 'name': '5.A'},
          ],
        },
      ),
    });

    final result = await svc.myClassrooms();

    expect(result.isSuccess, isTrue);
    expect(result.data!.single.name, '5.A');
    expect(adapter().requests.single.method, 'GET');
  });
}
