// BR-HCF5AS — https://app-stage.edu-ai.eu/chat/skolnik answered with the
// router's "Stránka nenalezena" page: `/chat` was a route, `/chat/:mentor` was
// not, so the link named a mentor nobody was listening for.
//
// The route now parks the slug the way `/course/:code` parks a join code, and
// ChatyPage — the page the chat tab shows — turns it into a conversation with
// that mentor. tab_routes_test.dart covers the routing half; this covers what
// the page does with the slug once it has it.
//
//   flutter test test/widgets/chat_mentor_deep_link_test.dart
import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/chat_repository.dart';
import 'package:eduai/models/chat_models.dart';
import 'package:eduai/pages/chat_detail_page.dart';
import 'package:eduai/pages/chaty_page.dart';
import 'package:eduai/routing/deep_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mentors as the server sends them: `skolnik` is public, and `dejepisec`
/// stands for one an admin added after this build shipped.
final _mentors = [
  const ChatMentor(
    slug: 'skolnik',
    name: 'Školník',
    description: 'Odpovídá z dokumentů školy.',
    emoji: '🔑',
    engine: 'rag',
  ),
  const ChatMentor(
    slug: 'dejepisec',
    name: 'Dějepisec',
    description: 'Mentor přidaný v adminu.',
    emoji: '🏛️',
  ),
];

class _FakeChatRepo implements ChatRepository {
  _FakeChatRepo({this.existing});

  /// The session already on this device, the way a student who chatted before
  /// closing the app has one (BR-VC5HPV). Null means a first visit.
  final ChatSessionsTableData? existing;

  final createdFor = <String>[];
  final resumedFor = <String>[];

  ChatSessionsTableData _session(String userId, String personaSlug,
      {String id = 's1'}) {
    final now = DateTime(2026, 9, 1, 12, 0);
    return ChatSessionsTableData(
      id: id,
      userId: userId,
      serverId: 7,
      title: '',
      persona: personaSlug,
      lastMessageAt: now,
      syncStatus: 'synced',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ChatSessionsTableData> createSession(
      String userId, String personaSlug) async {
    createdFor.add(personaSlug);
    return _session(userId, personaSlug);
  }

  @override
  Future<ChatSessionsTableData> resumeOrCreateSession(
      String userId, String personaSlug) async {
    resumedFor.add(personaSlug);
    return existing ?? await createSession(userId, personaSlug);
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

/// The test-only Ahem font is far wider than the real one, so the header row
/// overflows. Cosmetic and test-only — same suppression the other chat tests
/// use.
void _ignoreOverflow() {
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

/// Pumps the chat tab with [slug] already parked, the way `ShellEntry` leaves
/// it after a `/chat/:mentor` link.
Future<(_FakeChatRepo, ProviderContainer)> _pumpWithPendingSlug(
  WidgetTester tester,
  String? slug, {
  List<ChatMentor>? mentors,
  ChatSessionsTableData? existingSession,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  _ignoreOverflow();

  final repo = _FakeChatRepo(existing: existingSession);
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      activeUserProvider.overrideWith((ref) async => _user()),
      chatMentorsProvider.overrideWith((ref) async => mentors ?? _mentors),
      chatSessionsStreamProvider.overrideWith(
        (ref) => Stream.value(const <ChatSessionsTableData>[]),
      ),
      chatMessagesStreamProvider.overrideWith(
        (ref, sessionId) => Stream.value(const <ChatMessagesTableData>[]),
      ),
      connectivityStateProvider
          .overrideWith((ref) => Stream.value(ConnectivityState.wifi)),
    ],
  );
  addTearDown(container.dispose);

  if (slug != null) {
    container.read(pendingChatMentorSlugProvider.notifier).state = slug;
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatyPage()),
    ),
  );
  await tester.pumpAndSettle();

  return (repo, container);
}

void main() {
  testWidgets('a parked slug opens a chat with that mentor', (tester) async {
    final (repo, container) = await _pumpWithPendingSlug(tester, 'skolnik');

    expect(repo.resumedFor, ['skolnik']);
    expect(repo.createdFor, ['skolnik'],
        reason: 'nothing to resume on a first visit');
    expect(find.byType(ChatDetailPage), findsOneWidget);
    expect(
      tester.widget<ChatDetailPage>(find.byType(ChatDetailPage)).persona,
      ChatPersona.skolnik,
    );
    // Consumed, so a rebuild does not start the conversation a second time.
    expect(container.read(pendingChatMentorSlugProvider), isNull);
  });

  testWidgets('resolves a mentor this build does not know about',
      (tester) async {
    // The point of the server-driven list: an admin can add a mentor and link
    // to it without an app release.
    final (repo, _) = await _pumpWithPendingSlug(tester, 'dejepisec');

    expect(repo.resumedFor, ['dejepisec']);
  });

  testWidgets('falls back to the built-ins when the server list is empty',
      (tester) async {
    // Offline, or the request failed: `skolnik` ships with the app, so the
    // link still has to work.
    final (repo, _) =
        await _pumpWithPendingSlug(tester, 'skolnik', mentors: const []);

    expect(repo.resumedFor, ['skolnik']);
  });

  testWidgets('says so instead of opening the wrong chat for a bad slug',
      (tester) async {
    // ChatPersona.fromId answers aiTeacher for anything it does not recognise,
    // which would silently open a conversation with a different mentor.
    final (repo, _) = await _pumpWithPendingSlug(tester, 'neexistuje');

    expect(repo.resumedFor, isEmpty);
    expect(repo.createdFor, isEmpty);
    expect(find.byType(ChatDetailPage), findsNothing);
    expect(
      find.text(AppStrings.chatMentorNotFound('neexistuje')),
      findsOneWidget,
    );
  });

  testWidgets('does nothing when no link parked a slug', (tester) async {
    final (repo, _) = await _pumpWithPendingSlug(tester, null);

    expect(repo.resumedFor, isEmpty);
    expect(find.byType(ChatDetailPage), findsNothing);
  });

  testWidgets('acts on a link that arrives while the tab is already open',
      (tester) async {
    // The shell route is reused across URLs, so ChatyPage is not remounted:
    // only the provider changes under it.
    final (repo, container) = await _pumpWithPendingSlug(tester, null);
    expect(repo.resumedFor, isEmpty);

    container.read(pendingChatMentorSlugProvider.notifier).state = 'skolnik';
    await tester.pumpAndSettle();

    expect(repo.resumedFor, ['skolnik']);
  });

  testWidgets('reopens the conversation the student already had (BR-VC5HPV)',
      (tester) async {
    // The link is how the RAG mentor is reached on the web build, so opening
    // it again after closing the browser must land in the same chat instead of
    // starting an empty one.
    final now = DateTime(2026, 9, 3, 9, 0);
    final (repo, _) = await _pumpWithPendingSlug(
      tester,
      'skolnik',
      existingSession: ChatSessionsTableData(
        id: 'existing',
        userId: 'u1',
        serverId: 7,
        title: 'Školní řád',
        persona: 'skolnik',
        lastMessageAt: now,
        syncStatus: 'synced',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(repo.createdFor, isEmpty);
    expect(
      tester.widget<ChatDetailPage>(find.byType(ChatDetailPage)).sessionId,
      'existing',
    );
  });
}
