import 'dart:async';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/chat_models.dart';
import 'package:eduai/models/mentor_presentation.dart';
import 'package:eduai/pages/new_chat_page.dart';
import 'package:eduai/widgets/mentor_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// BR-E8ZQP2 — the new-chat picker went from a bottom sheet of emoji tiles to
/// the designed mentor list. The page draws whatever `GET /api/chat/mentors`
/// returns (BR-N7FC2B) and hands the chosen mentor back to the chat tab, so
/// these cover both halves of that contract: what a card shows for a given
/// server row, and what a tap returns.

final _mentors = [
  const ChatMentor(
    slug: 'study_coach',
    name: 'Studijní kouč',
    description: 'AI asistent specializovaný na organizaci přípravy.',
    emoji: '📚',
  ),
  const ChatMentor(
    slug: 'math_mentor',
    name: 'Mentor kurzu',
    description: 'AI asistent ti vysvětlí pojmy a postupy.',
    emoji: '📐',
    visibility: ChatMentor.visibilityHidden,
  ),
  const ChatMentor(
    slug: 'skolnik',
    name: 'Školník',
    description: 'Digitální knihovník ti odpoví na otázky ze školního řádu.',
    emoji: '🔑',
    engine: 'rag',
  ),
];

Widget _app({List<ChatMentor>? mentors, Widget? home}) {
  return ProviderScope(
    overrides: [
      chatMentorsProvider.overrideWith((ref) async => mentors ?? _mentors),
    ],
    child: MaterialApp(home: home ?? const NewChatPage()),
  );
}

void main() {
  Future<ChatMentor?> pumpAndPick(
    WidgetTester tester, {
    required String cardText,
    double width = 390,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);

    ChatMentor? picked;

    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showNewChatPicker(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(cardText));
    await tester.pumpAndSettle();

    return picked;
  }

  testWidgets('draws a card per mentor, in the order the server sent',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.newChatSubtitle), findsOneWidget);
    expect(
      tester
          .widgetList<MentorCard>(find.byType(MentorCard))
          .map((card) => card.mentor.slug),
      ['study_coach', 'math_mentor', 'skolnik'],
    );
  });

  testWidgets('offers no mentor until the server has answered',
      (tester) async {
    // BR-YSPPYA — the first open of the picker drew the compiled-in six while
    // the request was in flight, so "Asistent učitele", switched off in the
    // admin, sat on top of the list until the answer replaced it.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Never completes: the request is still in flight.
          chatMentorsProvider.overrideWith(
            (ref) => Completer<List<ChatMentor>>().future,
          ),
        ],
        child: const MaterialApp(home: NewChatPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MentorCard), findsNothing);
    expect(find.text(AppStrings.personaAiTeacherName), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('keeps the previous list on screen while it refreshes',
      (tester) async {
    // The picker refetches on every open (BR-EER4ME); a list this app run has
    // already received stays up meanwhile instead of a spinner.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        chatMentorsProvider.overrideWith((ref) {
          calls++;
          // The refresh never completes, so only the first answer can show.
          return calls == 1
              ? Future.value(_mentors)
              : Completer<List<ChatMentor>>().future;
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(chatMentorsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NewChatPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(MentorCard), findsNWidgets(_mentors.length));
  });

  testWidgets('falls back to the built-in mentors when the request fails',
      (tester) async {
    // A failed request must still leave something to pick (BR-N7FC2B).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatMentorsProvider.overrideWith(
            (ref) => Future<List<ChatMentor>>.error(Exception('offline')),
          ),
        ],
        child: const MaterialApp(home: NewChatPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(MentorCard),
      findsNWidgets(ChatMentor.builtIns.length),
    );
  });

  testWidgets('offers nothing when every mentor is switched off in the admin',
      (tester) async {
    // BR-EER4ME — the built-in six used to stand in for an empty server list,
    // so a mentor the admin retired was offered again and the tap 422'd.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(mentors: const []));
    await tester.pumpAndSettle();

    expect(find.byType(MentorCard), findsNothing);
    expect(find.text(AppStrings.newChatNoMentors), findsOneWidget);
  });

  test('labels come from the server fields, not from the slug', () {
    final byName = {for (final m in _mentors) m.slug: m};

    expect(byName['math_mentor']!.availabilityLabel,
        AppStrings.mentorAvailabilityCourseOnly);
    expect(byName['math_mentor']!.kindLabel, AppStrings.mentorKindAi);
    expect(byName['skolnik']!.kindLabel, AppStrings.mentorKindLibrary);
    expect(byName['skolnik']!.availabilityLabel,
        AppStrings.mentorAvailabilityOnline);
    expect(byName['study_coach']!.availabilityLabel,
        AppStrings.mentorAvailabilityOnline);
  });

  test('a mentor with only a subtitle still fills the second line', () {
    const mentor = ChatMentor(
      slug: 'novy',
      name: 'Nový mentor',
      subtitle: 'Vytvořený v adminu',
    );

    expect(mentor.cardDescription, 'Vytvořený v adminu');
  });

  testWidgets('the cards survive the narrowest phone', (tester) async {
    // Title, availability chip and kind tag share one row; at 320px the title
    // has to give way rather than the row overflowing.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MentorCard), findsNWidgets(_mentors.length));
  });

  testWidgets('a tap on a card returns that mentor (phone)', (tester) async {
    final picked = await pumpAndPick(tester, cardText: 'Školník');

    expect(picked?.slug, 'skolnik');
  });

  testWidgets('a tap on a card returns that mentor (desktop dialog)',
      (tester) async {
    // The wide layout shows the picker as a dialog so the conversation pane
    // stays visible; the result has to travel the same way.
    final picked = await pumpAndPick(
      tester,
      cardText: 'Studijní kouč',
      width: 1400,
    );

    expect(picked?.slug, 'study_coach');
  });
}
