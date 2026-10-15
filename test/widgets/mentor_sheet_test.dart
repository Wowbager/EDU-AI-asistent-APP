import 'dart:async';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/data/repositories/chat_repository.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/chat_models.dart';
import 'package:eduai/pages/lesson_detail/mentor_sheet.dart';
import 'package:eduai/widgets/chat/chat_message_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// BR-C7TYTT — the hint/help panel is now a conversation with the course
/// mentor: hint as the first bubble, three quick replies under it, and
/// "Nerozumím tomu" pulling the block's help text into the same transcript
/// before the AI input field appears.
///
/// BR-FEQ97Q / BR-E495XK live on in here too: "Přidat k procvičování" must not
/// be offered where tapping it would do nothing.
ContentBlock _block({String? help}) => ContentBlock(
      blockId: 'b1',
      type: BlockType.question,
      atomicHint: 'Zkus dosadit za x.',
      atomicHelp: help,
    );

/// BR-JHDNB3 — a step-based block whose second step brings its own hint/help.
ContentBlock _steppedBlock({String? stepHelp}) => ContentBlock.fromJson({
      'block_id': 'b2',
      'type': 'display',
      'hint': 'Zkus dosadit za x.',
      'help': 'Rozepiš si obě strany rovnice.',
      'steps': [
        {'id': 's1', 'type': 'text', 'order': 1, 'content': 'Úvod'},
        {
          'id': 's2',
          'type': 'text',
          'order': 2,
          'content': 'Video',
          'hint': 'Sleduj, co se stane s pravou stranou.',
          if (stepHelp != null) 'help': stepHelp,
        },
      ],
    });

Widget _host({
  ContentBlock? block,
  String? stepId,
  VoidCallback? onSavePractice,
  bool allowAi = true,
  void Function(String question, {required bool isFirst})? onAskMentor,
  VoidCallback? onEscalateToHelp,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showMentorSheet(
              context: context,
              block: block ?? _block(help: 'Rozepiš si obě strany rovnice.'),
              stepId: stepId,
              buildAiContext: () => 'context',
              allowAi: allowAi,
              onShown: () {},
              onEscalateToHelp: onEscalateToHelp ?? () {},
              onSavePractice: onSavePractice,
              onAskMentor: onAskMentor ?? (_, {required isFirst}) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// A chat repository whose round trips finish only when the test says so —
/// the window BR-3PNK46 lives in.
///
/// Given [connectivity], it refuses to go anywhere while that is offline, the
/// way [ChatRepository] does.
class _FakeChatRepo implements ChatRepository {
  final _Conn? connectivity;
  final session = Completer<ChatSessionsTableData>();
  final sent = <String>[];
  final _replies = <StreamController<ChatStreamEvent>>[];

  /// The session's stored messages, as the local database would emit them.
  final stored = StreamController<List<ChatMessagesTableData>>();

  bool get _offline => connectivity?.online == false;

  _FakeChatRepo({this.connectivity}) {
    // Not awaited: a stream nobody listened to — the session never came to
    // be — never finishes closing.
    addTearDown(() {
      stored.close();
    });
  }

  /// The answer stream of the latest question.
  StreamController<ChatStreamEvent> get replies => _replies.last;

  @override
  Future<ChatSessionsTableData> createSession(
          String userId, String personaSlug) =>
      _offline ? Future.error(Exception('Requires internet')) : session.future;

  @override
  Stream<ChatStreamEvent> sendMessage(String sessionId, String content,
      {String? context}) {
    if (_offline) return Stream.value(ChatStreamError('Requires internet'));
    sent.add(content);
    final replies = StreamController<ChatStreamEvent>();
    addTearDown(() {
      replies.close();
    });
    _replies.add(replies);
    return replies.stream;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The device's connection, switchable mid-conversation.
class _Conn implements ConnectivityService {
  bool online;

  _Conn({this.online = true});

  @override
  Future<bool> get isOnline async => online;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// ChatStreamDone asks for a sync to pick up the session title.
class _NoSync implements SyncService {
  @override
  Future<void> sync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _createdAt = DateTime(2026, 9, 23, 14, 55);

ChatSessionsTableData _session() => ChatSessionsTableData(
      id: 's1',
      userId: 'u1',
      serverId: 42,
      title: '',
      persona: ChatPersona.mathMentor.id,
      lastMessageAt: _createdAt,
      syncStatus: 'synced',
      createdAt: _createdAt,
      updatedAt: _createdAt,
    );

ChatMessagesTableData _row(String id, String role, String content) =>
    ChatMessagesTableData(
      id: id,
      sessionId: 's1',
      serverId: null,
      role: role,
      content: content,
      messageType: 'text',
      metadata: '{}',
      syncStatus: 'synced',
      createdAt: _createdAt,
    );

UsersTableData _user() => UsersTableData(
      id: 'u1',
      email: 'student@example.com',
      name: 'Student',
      avatarIndex: 0,
      selectedSubjects: '[0]',
      isEmailValidated: true,
      isActive: true,
      syncStatus: 0,
      createdAt: _createdAt,
      updatedAt: _createdAt,
    );

/// Opens the sheet with [repo] behind it, escalates to the AI and sends
/// [question].
Future<void> _askMentor(
  WidgetTester tester, {
  required _FakeChatRepo repo,
  required String question,
  _Conn? connectivity,
  void Function(String question, {required bool isFirst})? onAskMentor,
}) async {
  // Tall enough for the whole transcript: the list builds lazily, and a bubble
  // below the fold would not be found.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(onAskMentor: onAskMentor, overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    connectivityServiceProvider.overrideWithValue(connectivity ?? _Conn()),
    activeUserProvider.overrideWith((ref) async => _user()),
    chatMessagesStreamProvider
        .overrideWith((ref, sessionId) => repo.stored.stream),
    syncServiceProvider.overrideWithValue(_NoSync()),
  ]));
  await _openSheet(tester);

  await tester.tap(find.text(AppStrings.lessonFeedbackConfused));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), question);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump();
}

String _composerText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('opens as a mentor conversation: title, hint bubble, 3 replies',
      (tester) async {
    await tester.pumpWidget(_host(onSavePractice: () {}));
    await _openSheet(tester);

    expect(find.text(AppStrings.personaMathMentorName), findsOneWidget);
    expect(find.textContaining('Zkus dosadit za x.'), findsOneWidget);
    expect(find.text(AppStrings.lessonFeedbackClear), findsOneWidget);
    expect(find.text(AppStrings.lessonFeedbackPractice), findsOneWidget);
    expect(find.text(AppStrings.lessonFeedbackConfused), findsOneWidget);

    // The input field only shows up once the student escalates.
    expect(find.text(AppStrings.mentorSheetInputHint), findsNothing);
  });

  testWidgets('hides "Přidat k procvičování" when the caller offers no handler',
      (tester) async {
    await tester.pumpWidget(_host(onSavePractice: null));
    await _openSheet(tester);

    expect(find.text(AppStrings.lessonFeedbackPractice), findsNothing);
    expect(find.text(AppStrings.lessonFeedbackClear), findsOneWidget);
    expect(find.text(AppStrings.lessonFeedbackConfused), findsOneWidget);
  });

  testWidgets('"Přidat k procvičování" saves, confirms and keeps the sheet open',
      (tester) async {
    var saved = 0;
    await tester.pumpWidget(_host(onSavePractice: () => saved++));
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.lessonFeedbackPractice));
    await tester.pumpAndSettle();

    expect(saved, 1);
    // Confirmed in the transcript, and the option cannot be tapped twice.
    expect(find.textContaining(AppStrings.lessonFeedbackPracticeAdded),
        findsOneWidget);
    expect(find.text(AppStrings.lessonFeedbackPractice), findsNothing);
    // Still a conversation — the other replies remain.
    expect(find.text(AppStrings.lessonFeedbackConfused), findsOneWidget);
  });

  testWidgets('"Už je to jasné" closes the sheet', (tester) async {
    await tester.pumpWidget(_host());
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.lessonFeedbackClear));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.lessonFeedbackConfused), findsNothing);
  });

  testWidgets(
      '"Nerozumím tomu" echoes the reply, shows help and opens the input',
      (tester) async {
    var escalated = 0;
    await tester.pumpWidget(
      _host(onSavePractice: () {}, onEscalateToHelp: () => escalated++),
    );
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.lessonFeedbackConfused));
    await tester.pumpAndSettle();

    expect(escalated, 1);
    // The tapped label becomes the student's message …
    expect(find.textContaining(AppStrings.lessonFeedbackConfused),
        findsOneWidget);
    // … answered by the block's own help text.
    expect(find.textContaining('Rozepiš si obě strany rovnice.'),
        findsOneWidget);
    // Quick replies give way to the AI input field.
    expect(find.text(AppStrings.lessonFeedbackClear), findsNothing);
    expect(find.text(AppStrings.lessonFeedbackPractice), findsNothing);
    expect(find.text(AppStrings.mentorSheetInputHint), findsOneWidget);
  });

  testWidgets('a block without help asks the student to describe the problem',
      (tester) async {
    await tester.pumpWidget(_host(block: _block()));
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.lessonFeedbackConfused));
    await tester.pumpAndSettle();

    expect(find.textContaining(AppStrings.mentorSheetNoHelp), findsOneWidget);
    // The hint is not repeated as if it were new information.
    expect(find.textContaining('Zkus dosadit za x.'), findsOneWidget);
  });

  testWidgets('opens with the step\'s own hint, not the block\'s shared one',
      (tester) async {
    // BR-JHDNB3: the sheet is scoped to the step whose "?" was tapped.
    await tester.pumpWidget(_host(block: _steppedBlock(), stepId: 's2'));
    await _openSheet(tester);

    expect(find.textContaining('Sleduj, co se stane s pravou stranou.'),
        findsOneWidget);
    expect(find.textContaining('Zkus dosadit za x.'), findsNothing);
  });

  testWidgets('a step without its own hint still gets the block\'s',
      (tester) async {
    await tester.pumpWidget(_host(block: _steppedBlock(), stepId: 's1'));
    await _openSheet(tester);

    expect(find.textContaining('Zkus dosadit za x.'), findsOneWidget);
  });

  testWidgets('a step that overrides only the hint keeps the block\'s help',
      (tester) async {
    // hint and help fall back independently, so "Nerozumím tomu" still reveals
    // the block's shared explanation.
    await tester.pumpWidget(_host(block: _steppedBlock(), stepId: 's2'));
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.lessonFeedbackConfused));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rozepiš si obě strany rovnice.'),
        findsOneWidget);
  });

  testWidgets('a step with its own help replaces the block\'s',
      (tester) async {
    await tester.pumpWidget(_host(
      block: _steppedBlock(stepHelp: 'Krok po kroku: nejdřív zlomek.'),
      stepId: 's2',
    ));
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.lessonFeedbackConfused));
    await tester.pumpAndSettle();

    expect(find.textContaining('Krok po kroku: nejdřív zlomek.'),
        findsOneWidget);
    expect(find.textContaining('Rozepiš si obě strany rovnice.'), findsNothing);
  });

  testWidgets('allowAi: false keeps the AI input out of a graded test',
      (tester) async {
    await tester.pumpWidget(_host(allowAi: false));
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.lessonFeedbackConfused));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rozepiš si obě strany rovnice.'),
        findsOneWidget);
    expect(find.text(AppStrings.mentorSheetInputHint), findsNothing);
  });

  group('BR-3PNK46 — the sent question shows up at once', () {
    // The repository stores the question only after the server has created the
    // session and acknowledged the POST, so the transcript used to show nothing
    // but the typing dots until the answer began to stream.
    const question = 'Proč se to dělí pěti?';

    testWidgets('while the session is still being created', (tester) async {
      final repo = _FakeChatRepo();

      await _askMentor(tester, repo: repo, question: question);

      expect(find.textContaining(question), findsOneWidget);
      expect(find.byType(ChatTypingIndicator), findsOneWidget);
      expect(_composerText(tester), isEmpty);
    });

    testWidgets('and stays a single bubble once the stored row arrives',
        (tester) async {
      final repo = _FakeChatRepo();

      await _askMentor(tester, repo: repo, question: question);
      repo.session.complete(_session());
      await tester.pump();
      expect(repo.sent, [question]);
      expect(find.textContaining(question), findsOneWidget);

      // The POST came back: the question and the empty answer row are stored.
      repo.stored.add([
        _row('m1', 'user', question),
        _row('m2', 'assistant', ''),
      ]);
      await tester.pump();
      expect(find.textContaining(question), findsOneWidget);

      // The answer streams into the stored row.
      repo.stored.add([
        _row('m1', 'user', question),
        _row('m2', 'assistant', 'Protože dní bylo pět.'),
      ]);
      repo.replies.add(ChatStreamToken('Protože dní bylo pět.'));
      await tester.pump();
      expect(find.textContaining(question), findsOneWidget);
      expect(find.textContaining('Protože dní bylo pět.'), findsOneWidget);
    });

    testWidgets('a follow-up repeating an earlier question still shows',
        (tester) async {
      final repo = _FakeChatRepo();

      await _askMentor(tester, repo: repo, question: question);
      repo.session.complete(_session());
      await tester.pump();
      repo.stored.add([
        _row('m1', 'user', question),
        _row('m2', 'assistant', 'Protože dní bylo pět.'),
      ]);
      repo.replies.add(ChatStreamDone('Protože dní bylo pět.', 2));
      await tester.pumpAndSettle();

      // The same question again: the stored copy from the first round must not
      // be taken for this one and hide it.
      await tester.enterText(find.byType(TextField), question);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(repo.sent, [question, question]);
      expect(find.textContaining(question), findsNWidgets(2));
    });

    testWidgets('a failed send takes the bubble back and returns the text',
        (tester) async {
      final repo = _FakeChatRepo();

      await _askMentor(tester, repo: repo, question: question);
      // Online, but the server turned the session down.
      repo.session.completeError(Exception('Server error'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.chatStreamError), findsOneWidget);
      expect(repo.sent, isEmpty);
      // Nothing claims the question went out; it waits in the field for a
      // retry instead of being lost.
      expect(find.byType(ChatTypingIndicator), findsNothing);
      expect(_composerText(tester), question);
      expect(find.textContaining(question), findsOneWidget); // the field only
    });
  });

  group('BR-BMH4HF — offline, the sheet says so', () {
    // The repository will not reach for the server without a connection, and
    // the sheet worded that as "Chyba při generování odpovědi" — as if the
    // mentor had broken — where the Chaty tab says the chat needs internet.
    const question = 'Proč se to dělí pěti?';

    testWidgets('on the opening question', (tester) async {
      final conn = _Conn(online: false);
      final repo = _FakeChatRepo(connectivity: conn);
      final asked = <String>[];

      await _askMentor(
        tester,
        repo: repo,
        question: question,
        connectivity: conn,
        onAskMentor: (q, {required isFirst}) => asked.add(q),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.chatRequiresInternet), findsOneWidget);
      expect(find.text(AppStrings.chatStreamError), findsNothing);
      // Nothing went out, so nothing is counted; the question waits in the
      // field for when the connection is back.
      expect(asked, isEmpty);
      expect(find.byType(ChatTypingIndicator), findsNothing);
      expect(_composerText(tester), question);
    });

    testWidgets('on a follow-up after the connection drops', (tester) async {
      final conn = _Conn();
      final repo = _FakeChatRepo(connectivity: conn);

      await _askMentor(
        tester,
        repo: repo,
        question: question,
        connectivity: conn,
      );
      repo.session.complete(_session());
      await tester.pump();
      repo.stored.add([
        _row('m1', 'user', question),
        _row('m2', 'assistant', 'Protože dní bylo pět.'),
      ]);
      repo.replies.add(ChatStreamDone('Protože dní bylo pět.', 2));
      await tester.pumpAndSettle();

      conn.online = false;
      const followUp = 'A proč ne šesti?';
      await tester.enterText(find.byType(TextField), followUp);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.chatRequiresInternet), findsOneWidget);
      expect(find.text(AppStrings.chatStreamError), findsNothing);
      expect(repo.sent, [question]);
      expect(_composerText(tester), followUp);
    });
  });
}
