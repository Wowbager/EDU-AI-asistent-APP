// BR-C7TYTT — the lesson mentor sheet sends the task context as a hidden
// `message_type: context` message so the model keeps the task while the
// transcript opens with the student's own question. Filtering lives in
// watchMessages, so a context row pulled down by sync on another device stays
// hidden there too.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/data/datasources/local/chat_local_datasource.dart';

void main() {
  late AppDatabase db;
  late ChatLocalDataSource local;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = ChatLocalDataSource(db);
  });
  tearDown(() => db.close());

  Future<void> insert(String id, String content, {String type = 'text'}) {
    return local.insertMessage(ChatMessagesTableCompanion(
      id: Value(id),
      sessionId: const Value('s1'),
      role: const Value('user'),
      content: Value(content),
      messageType: Value(type),
    ));
  }

  test('watchMessages hides context messages but keeps the rest', () async {
    await insert('m1', 'Obsah úlohy: …', type: 'context');
    await insert('m2', 'Proč se to dělí dvěma?');

    final messages = await local.watchMessages('s1').first;

    expect(messages.map((m) => m.id), ['m2']);
  });

  test('an unknown message type still renders', () async {
    await insert('m1', 'Něco nového', type: 'image');

    final messages = await local.watchMessages('s1').first;

    expect(messages.map((m) => m.id), ['m1']);
  });

  test('getMessagesBySessionId keeps context rows for sync bookkeeping',
      () async {
    await insert('m1', 'Obsah úlohy: …', type: 'context');
    await insert('m2', 'Proč se to dělí dvěma?');

    final all = await local.getMessagesBySessionId('s1');

    expect(all.length, 2);
  });
}
