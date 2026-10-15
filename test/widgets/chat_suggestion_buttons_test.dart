import 'dart:convert';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/chat_models.dart';
import 'package:eduai/widgets/chat/chat_message_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// BR-UE8KK4 — a RAG answer's "Mohlo by tě zajímat" questions are buttons, not
/// markdown bullets: tapping one asks it as a new question. The API keeps
/// writing the bullets into the answer text for older app builds, so the
/// bubble has to take that copy back out before rendering.

/// The answer text exactly as RagSearchService::formatAnswer() assembles it.
const _answerWithBakedSuggestions =
    '[ZAKLADNI SKOLA] Absenci omlouvá zákonný zástupce do tří dnů.\n'
    '\n'
    '**Mohlo by tě zajímat:**\n'
    '- Jak se omlouvá absence?\n'
    '- Jak funguje odhlašování obědů?\n'
    '\n'
    '**Zdroje:**\n'
    '- [Školní řád ZŠ a SŠ](https://example.test/rad)';

ChatMessagesTableData _message({
  required String content,
  String metadata = '{}',
  String role = 'assistant',
}) =>
    ChatMessagesTableData(
      id: 'm1',
      sessionId: 's1',
      role: role,
      content: content,
      messageType: 'text',
      metadata: metadata,
      syncStatus: 'synced',
      createdAt: DateTime(2026, 8, 31, 10, 15),
    );

String _metadataWith(List<String> questions) => jsonEncode({
      'source': 'rag',
      'suggestions': [
        for (final q in questions) {'entry_id': 'e-$q', 'question': q},
      ],
    });

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('ChatMessageHelpers', () {
    test('reads the follow-up questions out of metadata', () {
      final message = _message(
        content: _answerWithBakedSuggestions,
        metadata: _metadataWith(
            ['Jak se omlouvá absence?', 'Jak funguje odhlašování obědů?']),
      );

      expect(
        message.suggestions.map((s) => s.question),
        ['Jak se omlouvá absence?', 'Jak funguje odhlašování obědů?'],
      );
      expect(message.suggestions.first.entryId, 'e-Jak se omlouvá absence?');
    });

    test('drops the markdown copy so the questions show up once', () {
      final message = _message(
        content: _answerWithBakedSuggestions,
        metadata: _metadataWith(
            ['Jak se omlouvá absence?', 'Jak funguje odhlašování obědů?']),
      );

      expect(message.displayContent, isNot(contains('Mohlo by tě zajímat')));
      expect(message.displayContent, isNot(contains('- Jak se omlouvá')));
      // The answer and its sources are untouched.
      expect(message.displayContent, contains('Absenci omlouvá'));
      expect(message.displayContent, contains('**Zdroje:**'));
      expect(message.displayContent, contains('Školní řád ZŠ a SŠ'));
    });

    test('leaves the text alone when there is nothing to replace it with', () {
      final message = _message(content: _answerWithBakedSuggestions);

      expect(message.suggestions, isEmpty);
      expect(message.displayContent, _answerWithBakedSuggestions);
    });

    test('survives metadata that is empty or not an object', () {
      expect(_message(content: 'a', metadata: '').suggestions, isEmpty);
      expect(_message(content: 'a', metadata: 'not json').suggestions, isEmpty);
      expect(_message(content: 'a', metadata: '[]').suggestions, isEmpty);
      expect(
        _message(content: 'a', metadata: '{"suggestions":[{"question":"  "}]}')
            .suggestions,
        isEmpty,
      );
      expect(_message(content: 'a', metadata: 'not json').displayContent, 'a');
    });
  });

  group('ChatBubble suggestions', () {
    testWidgets('renders one button per question and reports the tap',
        (tester) async {
      final asked = <String>[];

      await tester.pumpWidget(_host(ChatBubble(
        content: 'Absenci omlouvá zákonný zástupce.',
        isUser: false,
        suggestions: const [
          'Jak se omlouvá absence?',
          'Jak funguje odhlašování obědů?',
        ],
        onSuggestionTap: asked.add,
      )));

      expect(find.text(AppStrings.chatSuggestionsTitle), findsOneWidget);
      expect(find.byType(ChatSuggestionButton), findsNWidgets(2));

      await tester.tap(find.text('Jak funguje odhlašování obědů?'));
      await tester.pumpAndSettle();

      expect(asked, ['Jak funguje odhlašování obědů?']);
    });

    testWidgets('shows nothing extra when the answer has no follow-ups',
        (tester) async {
      await tester.pumpWidget(_host(const ChatBubble(
        content: 'Absenci omlouvá zákonný zástupce.',
        isUser: false,
      )));

      expect(find.byType(ChatSuggestionButton), findsNothing);
      expect(find.text(AppStrings.chatSuggestionsTitle), findsNothing);
    });

    testWidgets('a button without a handler cannot be tapped', (tester) async {
      await tester.pumpWidget(_host(const ChatBubble(
        content: 'Absenci omlouvá zákonný zástupce.',
        isUser: false,
        suggestions: ['Jak se omlouvá absence?'],
      )));

      final button = tester.widget<ChatSuggestionButton>(
          find.byType(ChatSuggestionButton));
      expect(button.onTap, isNull);
      expect(
        tester.widget<Semantics>(find.ancestor(
          of: find.byType(InkWell),
          matching: find.byType(Semantics),
        ).first).properties.enabled,
        isFalse,
      );
    });
  });

  group('ChatMessageBubble', () {
    testWidgets('turns a stored RAG answer into buttons', (tester) async {
      final asked = <String>[];

      await tester.pumpWidget(_host(ChatMessageBubble(
        message: _message(
          content: _answerWithBakedSuggestions,
          metadata: _metadataWith(
              ['Jak se omlouvá absence?', 'Jak funguje odhlašování obědů?']),
        ),
        avatarEmoji: '🔑',
        onSuggestionTap: asked.add,
      )));

      // Each question shows up once — as a button, not also as the markdown
      // bullet the API still writes into the answer for older builds.
      expect(find.byType(ChatSuggestionButton), findsNWidgets(2));
      expect(find.text('Jak se omlouvá absence?'), findsOneWidget);
      expect(find.text('Jak funguje odhlašování obědů?'), findsOneWidget);
      expect(find.text(AppStrings.chatSuggestionsTitle), findsOneWidget);

      await tester.tap(find.text('Jak se omlouvá absence?'));
      await tester.pumpAndSettle();

      expect(asked, ['Jak se omlouvá absence?']);
    });

    testWidgets('a student message never offers follow-ups', (tester) async {
      await tester.pumpWidget(_host(ChatMessageBubble(
        message: _message(
          content: 'Jak se omlouvá absence?',
          metadata: _metadataWith(['Jak funguje odhlašování obědů?']),
          role: 'user',
        ),
        avatarEmoji: '🔑',
        onSuggestionTap: (_) {},
      )));

      expect(find.byType(ChatSuggestionButton), findsNothing);
    });
  });
}
