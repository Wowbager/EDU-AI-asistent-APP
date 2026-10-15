import 'dart:convert';

import '../core/database/app_database.dart';
import '../core/strings/app_strings.dart';

/// Predefined AI chat personas.
enum ChatPersona {
  aiTeacher('ai_teacher'),
  mathMentor('math_mentor'),
  studyCoach('study_coach'),
  languageMentor('language_mentor'),
  // RAG personas — answered by the school-document search service.
  skolnik('skolnik'),
  cermatik('cermatik');

  final String id;
  const ChatPersona(this.id);

  String get emoji {
    switch (this) {
      case ChatPersona.aiTeacher: return '🤖';
      case ChatPersona.mathMentor: return '📐';
      case ChatPersona.studyCoach: return '📚';
      case ChatPersona.languageMentor: return '🌍';
      case ChatPersona.skolnik: return '🔑';
      case ChatPersona.cermatik: return '📝';
    }
  }

  String get displayName {
    switch (this) {
      case ChatPersona.aiTeacher: return AppStrings.personaAiTeacherName;
      case ChatPersona.mathMentor: return AppStrings.personaMathMentorName;
      case ChatPersona.studyCoach: return AppStrings.personaStudyCoachName;
      case ChatPersona.languageMentor: return AppStrings.personaLanguageMentorName;
      case ChatPersona.skolnik: return AppStrings.personaSkolnikName;
      case ChatPersona.cermatik: return AppStrings.personaCermatikName;
    }
  }

  String get subtitle {
    switch (this) {
      case ChatPersona.aiTeacher: return AppStrings.personaAiTeacherSubtitle;
      case ChatPersona.mathMentor: return AppStrings.personaMathMentorSubtitle;
      case ChatPersona.studyCoach: return AppStrings.personaStudyCoachSubtitle;
      case ChatPersona.languageMentor: return AppStrings.personaLanguageMentorSubtitle;
      case ChatPersona.skolnik: return AppStrings.personaSkolnikSubtitle;
      case ChatPersona.cermatik: return AppStrings.personaCermatikSubtitle;
    }
  }

  String get description {
    switch (this) {
      case ChatPersona.aiTeacher: return AppStrings.personaAiTeacherDesc;
      case ChatPersona.mathMentor: return AppStrings.personaMathMentorDesc;
      case ChatPersona.studyCoach: return AppStrings.personaStudyCoachDesc;
      case ChatPersona.languageMentor: return AppStrings.personaLanguageMentorDesc;
      case ChatPersona.skolnik: return AppStrings.personaSkolnikDesc;
      case ChatPersona.cermatik: return AppStrings.personaCermatikDesc;
    }
  }

  static ChatPersona fromId(String id) {
    return ChatPersona.values.firstWhere(
      (p) => p.id == id,
      orElse: () => ChatPersona.aiTeacher,
    );
  }
}

/// A mentor offered by the API (GET /api/chat/mentors).
///
/// Mentors live in the server's `mentors` table and are editable from the
/// admin, so the list can hold entries this build knows nothing about. The
/// [ChatPersona] enum above stays as the offline fallback and as the source of
/// per-mentor colours and icons for the six built-ins.
class ChatMentor {
  final String slug;
  final String name;
  final String? subtitle;
  final String? description;
  final String emoji;

  /// Picture avatar, when the mentor has one. [emoji] is the fallback, so a
  /// mentor without a picture still renders.
  final String? avatarUrl;

  /// 'llm' or 'rag' — what kind of mentor this is, for the category label.
  /// Built-ins fall back to the engine the app shipped with.
  final String engine;

  /// 'public' or 'hidden'. A hidden mentor is reachable only from its course,
  /// which is what the "jen v kurzu" label on the new-chat card says.
  final String visibility;

  const ChatMentor({
    required this.slug,
    required this.name,
    this.subtitle,
    this.description,
    this.emoji = '💬',
    this.avatarUrl,
    this.engine = 'llm',
    this.visibility = visibilityPublic,
  });

  static const String visibilityPublic = 'public';
  static const String visibilityHidden = 'hidden';

  factory ChatMentor.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    final emoji = (json['emoji'] as String?)?.trim();

    final avatarUrl = (json['avatar_url'] as String?)?.trim();

    return ChatMentor(
      slug: slug,
      name: json['name'] as String? ?? slug,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      // An admin can leave the emoji empty; for a built-in mentor the app
      // already ships one, so prefer that over the generic bubble.
      emoji: (emoji != null && emoji.isNotEmpty)
          ? emoji
          : ChatPersona.fromId(slug).emoji,
      avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
      engine: json['engine'] as String? ?? 'llm',
      visibility: json['visibility'] as String? ?? visibilityPublic,
    );
  }

  /// The offline representation of a built-in persona.
  factory ChatMentor.fromPersona(ChatPersona persona) => ChatMentor(
        slug: persona.id,
        name: persona.displayName,
        subtitle: persona.subtitle,
        description: persona.description,
        emoji: persona.emoji,
        engine: (persona == ChatPersona.skolnik || persona == ChatPersona.cermatik)
            ? 'rag'
            : 'llm',
      );

  /// Built-in mentors, used until the API list arrives (or if it fails).
  static List<ChatMentor> get builtIns =>
      ChatPersona.values.map(ChatMentor.fromPersona).toList();

  ChatPersona get persona => ChatPersona.fromId(slug);
}

/// Message role constants matching server API values.
class MessageRole {
  MessageRole._();
  static const String user = 'user';
  static const String assistant = 'assistant';
  static const String system = 'system';
}

/// A follow-up question offered by a RAG answer.
///
/// The search service returns these alongside the answer; tapping one asks it
/// as a fresh question. [entryId] is the service's own document handle — it has
/// no use client-side yet (the /ask schema takes only the question text), but
/// it is kept so a future "jump straight to this entry" needs no new plumbing.
class ChatSuggestion {
  final String question;
  final String? entryId;

  const ChatSuggestion({required this.question, this.entryId});

  static List<ChatSuggestion> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ChatSuggestion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final question = (item['question'] as String?)?.trim() ?? '';
      if (question.isEmpty) continue;
      final entryId = (item['entry_id'] as String?)?.trim();
      out.add(ChatSuggestion(
        question: question,
        entryId: (entryId != null && entryId.isNotEmpty) ? entryId : null,
      ));
    }
    return out;
  }
}

/// Heading the API writes above the follow-up questions inside the answer
/// markdown (RagSearchService::formatAnswer). It stays there for app builds
/// that predate the structured `suggestions` frame, so this build has to take
/// the block back out before rendering — see [ChatMessageHelpers.displayContent].
const String _bakedSuggestionsHeading = '**Mohlo by tě zajímat:**';

/// Extension on Drift-generated ChatMessagesTableData for convenience.
extension ChatMessageHelpers on ChatMessagesTableData {
  bool get isFromUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isLiked => feedbackType == 'like';
  bool get isDisliked => feedbackType == 'dislike';

  /// Decoded `metadata` column. Anything unparseable reads as empty rather
  /// than breaking the whole conversation.
  Map<String, dynamic> get metadataMap {
    if (metadata.isEmpty) return const {};
    try {
      final decoded = jsonDecode(metadata);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Follow-up questions from a RAG answer, rendered as buttons (BR-UE8KK4).
  List<ChatSuggestion> get suggestions =>
      ChatSuggestion.listFromJson(metadataMap['suggestions']);

  /// [content] with the server's markdown copy of the follow-up questions
  /// removed, so they show up once — as buttons — and not twice.
  ///
  /// The block is rebuilt exactly as the API assembles it instead of being
  /// matched by pattern, so a heading the app does not know about is left
  /// alone rather than half-stripped.
  String get displayContent {
    final questions = suggestions;
    if (questions.isEmpty) return content;

    final block = '$_bakedSuggestionsHeading\n'
        '${questions.map((s) => '- ${s.question}').join('\n')}';
    if (content.contains('\n\n$block')) {
      return content.replaceFirst('\n\n$block', '');
    }
    return content.replaceFirst(block, '').trimRight();
  }
}

/// Extension on ChatSessionsTableData for persona access.
extension ChatSessionHelpers on ChatSessionsTableData {
  ChatPersona get chatPersona => ChatPersona.fromId(persona);
}

/// Events emitted during chat SSE streaming.
sealed class ChatStreamEvent {}

class ChatStreamToken extends ChatStreamEvent {
  final String token;
  ChatStreamToken(this.token);
}

/// Follow-up questions that arrived after the answer text (BR-UE8KK4).
class ChatStreamSuggestions extends ChatStreamEvent {
  final List<ChatSuggestion> suggestions;
  ChatStreamSuggestions(this.suggestions);
}

class ChatStreamDone extends ChatStreamEvent {
  final String fullContent;
  final int assistantMessageServerId;
  ChatStreamDone(this.fullContent, this.assistantMessageServerId);
}

class ChatStreamError extends ChatStreamEvent {
  final String error;
  ChatStreamError(this.error);
}
