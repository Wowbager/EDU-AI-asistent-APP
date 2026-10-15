// BR-VC5HPV — the RAG mentor is reached through /chat/skolnik, and that link
// always called createSession(): closing the browser and reopening the same URL
// handed the student a brand-new empty chat while their transcript stayed under
// the previous session id ("chat přes RAG se neuloží").
//
// resumeOrCreateSession() reopens the last conversation with that mentor, and
// pulls the history first when this device has never seen it.
//
//   flutter test test/chat_mentor_resume_session_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/data/datasources/local/chat_local_datasource.dart';
import 'package:eduai/data/datasources/remote/chat_remote_datasource.dart';
import 'package:eduai/data/repositories/chat_repository.dart';

class _FakeRemote implements ChatRemoteDataSource {
  _FakeRemote({this.sessions = const [], this.messages = const []});

  final List<dynamic> sessions;
  final List<dynamic> messages;
  int createCalls = 0;

  @override
  Future<ApiResult<List<dynamic>>> fetchSessions({String? since}) async =>
      ApiResult.success(sessions);

  @override
  Future<ApiResult<List<dynamic>>> fetchAllMessages({String? since}) async =>
      ApiResult.success(messages);

  @override
  Future<ApiResult<Map<String, dynamic>>> createSession({
    required String persona,
    String title = '',
  }) async {
    createCalls++;
    return ApiResult.success({
      'data': {'id': 99, 'title': ''},
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _OnlineConn implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoQueue implements SyncQueue {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ChatRepository repoWith(_FakeRemote remote) => ChatRepository(
        localDataSource: ChatLocalDataSource(db),
        remoteDataSource: remote,
        connectivity: _OnlineConn(),
        syncQueue: _NoQueue(),
      );

  test('reopens the last local conversation with that mentor', () async {
    await db.into(db.chatSessionsTable).insert(ChatSessionsTableCompanion(
          id: const Value('old'),
          userId: const Value('u1'),
          serverId: const Value(41),
          persona: const Value('skolnik'),
          lastMessageAt: Value(DateTime(2026, 9, 1)),
        ));
    await db.into(db.chatSessionsTable).insert(ChatSessionsTableCompanion(
          id: const Value('recent'),
          userId: const Value('u1'),
          serverId: const Value(42),
          persona: const Value('skolnik'),
          lastMessageAt: Value(DateTime(2026, 9, 3)),
        ));

    final remote = _FakeRemote();
    final session = await repoWith(remote).resumeOrCreateSession('u1', 'skolnik');

    expect(session.id, 'recent');
    expect(remote.createCalls, 0, reason: 'the link must not mint a session');
  });

  test('pulls the history when this device has no local session yet',
      () async {
    // Web reload with the local store gone: the server still has the chat.
    final remote = _FakeRemote(sessions: [
      {
        'id': 42,
        'title': 'Školní řád',
        'persona': 'skolnik',
        'last_message_at': DateTime(2026, 9, 3).toIso8601String(),
      },
    ], messages: [
      {
        'id': 7,
        'chat_session_id': 42,
        'role': 'user',
        'content': 'Jak omluvit absenci?',
        'message_type': 'text',
      },
    ]);

    final session = await repoWith(remote).resumeOrCreateSession('u1', 'skolnik');

    expect(session.serverId, 42);
    expect(remote.createCalls, 0);
    final messages = await ChatLocalDataSource(db).getMessagesBySessionId(session.id);
    expect(messages.single.content, 'Jak omluvit absenci?');
  });

  test('starts a chat when the student has never talked to this mentor',
      () async {
    await db.into(db.chatSessionsTable).insert(const ChatSessionsTableCompanion(
          id: Value('other-mentor'),
          userId: Value('u1'),
          persona: Value('ai_teacher'),
        ));

    final remote = _FakeRemote();
    final session = await repoWith(remote).resumeOrCreateSession('u1', 'skolnik');

    expect(remote.createCalls, 1);
    expect(session.persona, 'skolnik');
  });

  test('ignores another user\'s conversation with the same mentor', () async {
    await db.into(db.chatSessionsTable).insert(const ChatSessionsTableCompanion(
          id: Value('someone-else'),
          userId: Value('u2'),
          serverId: Value(41),
          persona: Value('skolnik'),
        ));

    final remote = _FakeRemote();
    final session = await repoWith(remote).resumeOrCreateSession('u1', 'skolnik');

    expect(remote.createCalls, 1);
    expect(session.id, isNot('someone-else'));
  });
}
