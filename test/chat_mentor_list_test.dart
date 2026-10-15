// BR-EER4ME — a mentor switched off in the admin kept being offered by the
// app. The new-chat list is server-driven, but every fallback path answered
// with ChatMentor.builtIns: a compile-time snapshot of the six mentors that
// predate the `mentors` table, which no admin edit can ever reach. These cover
// what the repository falls back to, and that an empty server list is taken at
// face value instead of being replaced by the built-ins.
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/data/datasources/local/chat_local_datasource.dart';
import 'package:eduai/data/datasources/remote/chat_remote_datasource.dart';
import 'package:eduai/data/repositories/chat_repository.dart';

/// Answers `fetchMentors` from a scripted queue, one entry per call.
class _FakeRemote implements ChatRemoteDataSource {
  final List<ApiResult<List<dynamic>>> replies;
  int calls = 0;

  _FakeRemote(this.replies);

  @override
  Future<ApiResult<List<dynamic>>> fetchMentors({int? courseId}) async =>
      replies[calls++];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Conn implements ConnectivityService {
  bool online;
  _Conn({this.online = true});

  @override
  Future<bool> get isOnline async => online;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoLocal implements ChatLocalDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoQueue implements SyncQueue {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, dynamic> _mentor(String slug) => {
      'slug': slug,
      'name': slug,
      'engine': 'llm',
      'visibility': 'public',
    };

ChatRepository _repo(
  List<ApiResult<List<dynamic>>> replies, {
  _Conn? conn,
}) =>
    ChatRepository(
      localDataSource: _NoLocal(),
      remoteDataSource: _FakeRemote(replies),
      connectivity: conn ?? _Conn(),
      syncQueue: _NoQueue(),
    );

void main() {
  test('a failed refresh keeps the last server list, not the built-ins',
      () async {
    // ai_teacher was switched off in the admin, so the server stopped sending
    // it. The next request fails — the retired mentor must not come back.
    final repo = _repo([
      ApiResult.success([_mentor('math_mentor')]),
      ApiResult.failure('Network error'),
    ]);

    expect((await repo.fetchMentors()).map((m) => m.slug), ['math_mentor']);
    expect(
      (await repo.fetchMentors()).map((m) => m.slug),
      ['math_mentor'],
      reason: 'the built-in six would put ai_teacher back in the picker',
    );
  });

  test('an empty server list means no mentor is on offer', () async {
    // Every mentor deactivated: the picker has nothing to show, and showing
    // the built-ins instead would offer six mentors the server refuses.
    final repo = _repo([ApiResult.success(const [])]);

    expect(await repo.fetchMentors(), isEmpty);
  });

  test('the built-ins stand in only until the server has been heard from',
      () async {
    // Fresh install, offline: the picker must still offer something.
    final offline = _repo(const [], conn: _Conn(online: false));

    expect(await offline.fetchMentors(), isNotEmpty);
    expect(offline.lastServerMentors, isNull);
  });

  test('going offline after a successful fetch keeps the server list',
      () async {
    final conn = _Conn();
    final repo = _repo([
      ApiResult.success([_mentor('study_coach')]),
    ], conn: conn);

    await repo.fetchMentors();
    conn.online = false;

    expect((await repo.fetchMentors()).map((m) => m.slug), ['study_coach']);
  });

  test('a course list never falls back — a failure hides the course button',
      () async {
    final repo = _repo([
      ApiResult.success([_mentor('math_mentor')]),
      ApiResult.failure('Network error'),
    ]);

    await repo.fetchMentors();

    expect(await repo.fetchMentors(courseId: 7), isEmpty);
  });
}
