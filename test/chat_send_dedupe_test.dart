// Regression test: the mentor sheet fires a full sync (via the block's
// "question" content feedback) right before it POSTs the message, so the
// sync's chat pull can land while that POST is still in flight and insert the
// server rows first. sendMessage() must then reuse them instead of inserting a
// second copy of the same server_id — the student's question showed up twice
// in the sheet (BR-M7EQY8).
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
import 'package:eduai/models/chat_models.dart';

class _FakeRemote implements ChatRemoteDataSource {
  /// Messages the sync pull sees on the server.
  List<dynamic> allMessages = const [];

  int sendCalls = 0;

  @override
  Future<ApiResult<List<dynamic>>> fetchSessions({String? since}) async =>
      ApiResult.success(const []);

  @override
  Future<ApiResult<List<dynamic>>> fetchAllMessages({String? since}) async =>
      ApiResult.success(allMessages);

  @override
  Future<ApiResult<Map<String, dynamic>>> sendMessage(
      int sessionId, String content,
      {String? context}) async {
    sendCalls++;
    return ApiResult.success({
      'data': {
        'user_message': {'id': 100, 'role': 'user', 'content': content},
        'assistant_message': {'id': 101, 'role': 'assistant', 'content': ''},
      },
    });
  }

  @override
  Stream<ChatStreamEvent> streamResponse(
          int sessionId, int assistantMessageId) =>
      Stream.fromIterable(
          [ChatStreamToken('Ahoj'), ChatStreamToken(' světe')]);

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
  late _FakeRemote remote;
  late ChatRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _FakeRemote();
    repo = ChatRepository(
      localDataSource: ChatLocalDataSource(db),
      remoteDataSource: remote,
      connectivity: _OnlineConn(),
      syncQueue: _NoQueue(),
    );

    await db.into(db.chatSessionsTable).insert(const ChatSessionsTableCompanion(
          id: Value('local-session'),
          userId: Value('user-1'),
          serverId: Value(7),
          title: Value(''),
          persona: Value('math_mentor'),
        ));
  });

  tearDown(() => db.close());

  Future<List<ChatMessagesTableData>> messages() =>
      (db.select(db.chatMessagesTable)
            ..orderBy([(m) => OrderingTerm.asc(m.serverId)]))
          .get();

  test('sendMessage reuses rows a concurrent pull already inserted', () async {
    // The sync pull won the race: both server rows are already local, the
    // assistant one still empty because the stream had not started.
    remote.allMessages = [
      {
        'id': 100,
        'chat_session_id': 7,
        'role': 'user',
        'content': 'nějak furt nevím co to ta statistika je',
        'message_type': 'text',
      },
      {
        'id': 101,
        'chat_session_id': 7,
        'role': 'assistant',
        'content': '',
        'message_type': 'text',
      },
    ];
    await repo.pullHistory('user-1');
    expect(await messages(), hasLength(2));

    final events = await repo
        .sendMessage('local-session', 'nějak furt nevím co to ta statistika je')
        .toList();

    final rows = await messages();
    expect(rows, hasLength(2),
        reason: 'the pulled rows must be reused, not duplicated');
    expect(rows.where((m) => m.role == 'user'), hasLength(1));
    expect(rows.last.content, 'Ahoj světe',
        reason: 'the stream must fill the assistant row that already exists');
    expect(events.last, isA<ChatStreamDone>());
  });

  test('sendMessage inserts both rows when no pull ran', () async {
    await repo.sendMessage('local-session', 'ahoj').toList();

    final rows = await messages();
    expect(rows, hasLength(2));
    expect(rows.first.serverId, 100);
    expect(rows.last.content, 'Ahoj světe');
  });

  test('the v19 cleanup keeps the filled row of a duplicated pair', () async {
    // What a device that already hit the race carries: the user question
    // twice, and two assistant rows of which only one got the stream.
    for (final row in [
      ('a', 100, 'user', 'nějak furt nevím co to ta statistika je'),
      ('b', 100, 'user', 'nějak furt nevím co to ta statistika je'),
      ('c', 101, 'assistant', ''),
      ('d', 101, 'assistant', 'Statistika je věda, která...'),
    ]) {
      await db.into(db.chatMessagesTable).insert(ChatMessagesTableCompanion(
            id: Value(row.$1),
            sessionId: const Value('local-session'),
            serverId: Value(row.$2),
            role: Value(row.$3),
            content: Value(row.$4),
          ));
    }

    await db.dedupeChatMessagesByServerId();

    final rows = await messages();
    expect(rows, hasLength(2));
    expect(rows.first.role, 'user');
    expect(rows.last.content, 'Statistika je věda, která...',
        reason: 'the streamed answer must survive, not the empty placeholder');
  });

  test('a later pull does not duplicate what sendMessage inserted', () async {
    await repo.sendMessage('local-session', 'ahoj').toList();

    remote.allMessages = [
      {
        'id': 100,
        'chat_session_id': 7,
        'role': 'user',
        'content': 'ahoj',
        'message_type': 'text',
      },
      {
        'id': 101,
        'chat_session_id': 7,
        'role': 'assistant',
        'content': 'Ahoj světe',
        'message_type': 'text',
      },
    ];
    await repo.pullHistory('user-1');

    expect(await messages(), hasLength(2));
  });
}
