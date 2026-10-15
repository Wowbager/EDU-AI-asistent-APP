// BR-NAH3TR — asking the AI from a block (the robot button in a test, "go_to:
// CHAT" in a lesson) opened the chat by sending the whole assembled task
// context as the student's own message: a wall of text down to the
// "[Obrázek: funkce36.png]" placeholders the sanitizer leaves behind, and the
// same blob showed up again whenever a sync pull raced the POST.
//
// The chat page now uses the channel the mentor sheet already had: the context
// goes to the server as the hidden `message_type: context` message and the
// visible opening message is the student's question.
//
//   flutter test test/widgets/chat_block_context_hidden_test.dart
import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/chat_repository.dart';
import 'package:eduai/models/chat_models.dart';
import 'package:eduai/pages/chat_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _taskContext = 'Potřebuji pomoct s úlohou z kurzu "Funkce a grafy ZŠ", '
    'lekce "Soustava souřadnic a lineární funkce".\n'
    'Obsah úlohy: y: [Obrázek: funkce36.png]';

class _SentMessage {
  final String content;
  final String? context;

  _SentMessage(this.content, this.context);
}

class _FakeChatRepo implements ChatRepository {
  final sent = <_SentMessage>[];
  int createSessionCalls = 0;

  @override
  Future<ChatSessionsTableData> createSession(
      String userId, String personaSlug) async {
    createSessionCalls++;
    final now = DateTime(2026, 8, 31, 11, 19);
    return ChatSessionsTableData(
      id: 's1',
      userId: userId,
      serverId: 42,
      title: '',
      persona: personaSlug,
      lastMessageAt: now,
      syncStatus: 'synced',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Stream<ChatStreamEvent> sendMessage(String sessionId, String content,
      {String? context}) {
    sent.add(_SentMessage(content, context));
    // Only a token: ChatStreamDone would kick off a real sync service.
    return Stream.value(ChatStreamToken('Jasně'));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

UsersTableData _user() {
  final now = DateTime(2026, 1, 1);
  return UsersTableData(
    id: 'u1',
    email: 'student@example.com',
    name: 'Student',
    avatarIndex: 0,
    selectedSubjects: '[0]',
    isEmailValidated: true,
    isActive: true,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Future<_FakeChatRepo> _pumpChat(
  WidgetTester tester, {
  String? initialQuestion,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final repo = _FakeChatRepo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        activeUserProvider.overrideWith((ref) async => _user()),
        connectivityStateProvider
            .overrideWith((ref) => Stream.value(ConnectivityState.wifi)),
        chatMessagesStreamProvider.overrideWith(
          (ref, sessionId) => Stream.value(const <ChatMessagesTableData>[]),
        ),
      ],
      child: MaterialApp(
        home: ChatDetailPage(
          sessionId: '',
          sessionTitle: 'Soustava souřadnic a lineární funkce',
          persona: ChatPersona.mathMentor,
          initialContext: _taskContext,
          initialQuestion: initialQuestion,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return repo;
}

void main() {
  testWidgets('the task context is sent hidden, not as the visible message',
      (tester) async {
    final repo = await _pumpChat(tester);

    expect(repo.createSessionCalls, 1);
    expect(repo.sent.length, 1);
    expect(repo.sent.single.context, _taskContext);

    // The blob — image placeholders included — stays out of the transcript.
    expect(repo.sent.single.content, AppStrings.chatContextOpeningQuestion);
    expect(repo.sent.single.content, isNot(contains('Obsah úlohy')));
    expect(repo.sent.single.content, isNot(contains('[Obrázek:')));
  });

  testWidgets("the student's own question opens the transcript when there is one",
      (tester) async {
    final repo = await _pumpChat(tester, initialQuestion: '  pořád nevím  ');

    expect(repo.sent.single.content, 'pořád nevím');
    expect(repo.sent.single.context, _taskContext);
  });
}
