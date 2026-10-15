import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_queue.dart';
import '../../models/chat_models.dart';
import '../datasources/local/chat_local_datasource.dart';
import '../datasources/remote/chat_remote_datasource.dart';

/// Repository for chat operations.
/// Uses server-first pattern for messages (requires internet),
/// SyncQueue for feedback only.
class ChatRepository {
  final ChatLocalDataSource _local;
  final ChatRemoteDataSource _remote;
  final ConnectivityService _connectivity;
  final SyncQueue _syncQueue;

  ChatRepository({
    required ChatLocalDataSource localDataSource,
    required ChatRemoteDataSource remoteDataSource,
    required ConnectivityService connectivity,
    required SyncQueue syncQueue,
  })  : _local = localDataSource,
        _remote = remoteDataSource,
        _connectivity = connectivity,
        _syncQueue = syncQueue;

  // === Reactive streams (from local cache) ===

  Stream<List<ChatSessionsTableData>> watchSessions(String userId) =>
      _local.watchSessions(userId);

  Stream<List<ChatMessagesTableData>> watchMessages(String sessionId) =>
      _local.watchMessages(sessionId);

  // === Mentors ===

  /// The last new-chat list the server sent, kept for the requests that cannot
  /// get a fresh one.
  ///
  /// [ChatMentor.builtIns] is a frozen snapshot of the six mentors that
  /// predate the `mentors` table, so falling back to it hands the student a
  /// mentor the admin has since switched off (BR-EER4ME). Whatever the server
  /// last said is closer to the truth, so it wins; the compiled-in six only
  /// stand in until this app run has heard from the server once.
  List<ChatMentor>? _lastServerMentors;

  /// The last server list, or null while this app run has never seen one.
  List<ChatMentor>? get lastServerMentors => _lastServerMentors;

  /// Mentors offered in the new-chat list, or a course's mentors when
  /// [courseId] is given.
  ///
  /// Falls back to the last list the server sent when offline or when the
  /// request fails, and to the mentors built into this app until there is one
  /// — the picker must never come up empty on a fresh install (BR-N7FC2B).
  Future<List<ChatMentor>> fetchMentors({int? courseId}) async {
    if (!await _connectivity.isOnline) {
      return courseId == null ? _mentorFallback : const [];
    }

    final result = await _remote.fetchMentors(courseId: courseId);
    if (result.isFailure || result.data == null) {
      return courseId == null ? _mentorFallback : const [];
    }

    final mentors = result.data!
        .whereType<Map<String, dynamic>>()
        .map(ChatMentor.fromJson)
        .toList();

    // An empty list is the admin's answer, not a broken response: every mentor
    // is switched off, so the picker has nothing to offer and says so.
    if (courseId == null) _lastServerMentors = mentors;

    return mentors;
  }

  List<ChatMentor> get _mentorFallback =>
      _lastServerMentors ?? ChatMentor.builtIns;

  // === Create session (server-first) ===

  Future<ChatSessionsTableData> createSession(
      String userId, String personaSlug) async {
    if (!await _connectivity.isOnline) {
      throw Exception('Requires internet');
    }

    final result = await _remote.createSession(persona: personaSlug);
    if (result.isFailure) throw Exception(result.error);

    final serverData = result.data!;
    // API wraps in 'data' key
    final data =
        serverData.containsKey('data') ? serverData['data'] as Map<String, dynamic> : serverData;
    final localId = const Uuid().v4();

    await _local.insertSession(ChatSessionsTableCompanion(
      id: Value(localId),
      userId: Value(userId),
      serverId: Value(data['id'] as int),
      title: Value(data['title'] as String? ?? ''),
      persona: Value(personaSlug),
      syncStatus: const Value('synced'),
    ));

    return (await _local.getSessionById(localId))!;
  }

  /// The session a `/chat/:mentor` link should open: the student's most recent
  /// conversation with that mentor, and a new one only when there is none.
  ///
  /// The link is the only way into the RAG mentor on the web build, so opening
  /// it always created a fresh session — close the browser, come back to the
  /// same URL, and the chat was empty while the real transcript sat under the
  /// previous session id (BR-VC5HPV). Starting a *new* chat with the same
  /// mentor is still the picker's job, which keeps calling [createSession].
  ///
  /// A first visit on this device has nothing local to resume, so the history
  /// is pulled once before giving up — the server knows the conversation even
  /// when this browser's storage does not.
  Future<ChatSessionsTableData> resumeOrCreateSession(
      String userId, String personaSlug) async {
    final local = await _local.getLatestSessionForPersona(userId, personaSlug);
    if (local != null) return local;

    if (await _connectivity.isOnline) {
      try {
        await pullHistory(userId);
      } catch (_) {
        // Offline-ish or the endpoint failed: fall through and start a chat.
      }
      final pulled =
          await _local.getLatestSessionForPersona(userId, personaSlug);
      if (pulled != null) return pulled;
    }

    return createSession(userId, personaSlug);
  }

  // === Send message (server-first + SSE) ===

  /// Send [content] to the session's mentor and stream the answer back.
  ///
  /// [context] rides along on the first message of a lesson mentor
  /// conversation: the server keeps it as a hidden message so the model knows
  /// the task without the student seeing the blob (see [watchMessages]).
  Stream<ChatStreamEvent> sendMessage(
      String sessionId, String content, {String? context}) async* {
    if (!await _connectivity.isOnline) {
      yield ChatStreamError('Requires internet');
      return;
    }

    final session = await _local.getSessionById(sessionId);
    if (session == null || session.serverId == null) {
      yield ChatStreamError('Session not found');
      return;
    }

    // Step 1: POST message -> get both IDs
    final result =
        await _remote.sendMessage(session.serverId!, content, context: context);
    if (result.isFailure) {
      yield ChatStreamError(result.error ?? 'Failed to send');
      return;
    }

    final responseData = result.data!;
    final data = responseData.containsKey('data')
        ? responseData['data'] as Map<String, dynamic>
        : responseData;
    final userMsgData = data['user_message'] as Map<String, dynamic>;
    final assistantMsgData = data['assistant_message'] as Map<String, dynamic>;

    // Store both rows locally, keyed by their server ids. A sync running in
    // parallel may already have pulled them down (see
    // [ChatLocalDataSource.upsertMessageByServerId]) — in that case we reuse
    // its rows, and the stream below fills the assistant one it created rather
    // than a second copy.
    await _local.upsertMessageByServerId(
      serverId: userMsgData['id'] as int,
      sessionId: sessionId,
      role: 'user',
      content: content,
    );

    final assistantLocalId = await _local.upsertMessageByServerId(
      serverId: assistantMsgData['id'] as int,
      sessionId: sessionId,
      role: 'assistant',
      content: '',
    );

    // Update session lastMessageAt
    await _local.updateSession(
      sessionId,
      ChatSessionsTableCompanion(
        lastMessageAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Step 2: Open SSE stream
    String fullContent = '';
    try {
      await for (final event in _remote.streamResponse(
        session.serverId!,
        assistantMsgData['id'] as int,
      )) {
        switch (event) {
          case ChatStreamToken(:final token):
            fullContent += token;
            await _local.updateMessageContent(assistantLocalId, fullContent);
            yield event;
          case ChatStreamSuggestions(:final suggestions):
            // Persist so the buttons survive leaving and reopening the chat —
            // the history endpoint returns the same metadata (BR-UE8KK4).
            await _local.updateMessageMetadata(
              assistantLocalId,
              jsonEncode({
                'suggestions': suggestions
                    .map((s) => {
                          'question': s.question,
                          if (s.entryId != null) 'entry_id': s.entryId,
                        })
                    .toList(),
              }),
            );
            yield event;
          case ChatStreamDone():
          case ChatStreamError():
            yield event;
        }
      }
      yield ChatStreamDone(fullContent, assistantMsgData['id'] as int);
    } catch (e) {
      if (fullContent.isNotEmpty) {
        await _local.updateMessageContent(assistantLocalId, fullContent);
      }
      yield ChatStreamError(e.toString());
    }
  }

  // === Feedback (SyncQueue for offline resilience) ===

  Future<void> submitFeedback(
      String messageId, String? type, String? detail) async {
    // Update locally first (immediate UI update)
    await _local.updateMessageFeedback(messageId, type, detail);

    // Enqueue sync
    await _syncQueue.enqueue(
      tableName: 'chat_messages',
      recordId: messageId,
      operation: SyncOperation.update,
      payload: {'feedback_type': type, 'feedback_detail': detail},
    );
  }

  // === Delete session ===

  Future<void> deleteSession(String sessionId) async {
    final session = await _local.getSessionById(sessionId);

    if (session?.serverId != null) {
      if (await _connectivity.isOnline) {
        try {
          await _remote.deleteSession(session!.serverId!);
        } catch (_) {
          // If server delete fails, still delete locally and queue
          await _syncQueue.enqueue(
            tableName: 'chat_sessions',
            recordId: sessionId,
            operation: SyncOperation.delete,
            payload: {'server_id': session!.serverId},
          );
        }
      } else {
        await _syncQueue.enqueue(
          tableName: 'chat_sessions',
          recordId: sessionId,
          operation: SyncOperation.delete,
          payload: {'server_id': session!.serverId},
        );
      }
    }

    await _local.deleteSession(sessionId);
  }

  // === Pull history (called by SyncService) ===

  Future<void> pullHistory(String userId, {String? since}) async {
    // Pull sessions
    final sessResult = await _remote.fetchSessions(since: since);
    if (sessResult.isSuccess && sessResult.data != null) {
      final sessions = sessResult.data!;
      for (final item in sessions) {
        final s = item as Map<String, dynamic>;
        final existing = await _local.getSessionByServerId(s['id'] as int);
        if (existing == null) {
          await _local.insertSession(ChatSessionsTableCompanion(
            id: Value(const Uuid().v4()),
            userId: Value(userId),
            serverId: Value(s['id'] as int),
            title: Value(s['title'] as String? ?? ''),
            persona: Value(s['persona'] as String? ?? 'ai_teacher'),
            lastMessageAt: Value(DateTime.parse(s['last_message_at'] as String)),
            syncStatus: const Value('synced'),
          ));
        } else {
          // Re-key to the active user. After logout + re-login the local
          // user gets a fresh uuid; the session row still carries the old
          // uuid, so watchSessions(currentUserId) would hide it (chat
          // "disappears"). The server is the source of truth for ownership,
          // so claim every server-known session for the current user —
          // mirrors how progress restore writes userId unconditionally.
          final serverTitle = s['title'] as String? ?? '';
          await _local.updateSession(
            existing.id,
            ChatSessionsTableCompanion(
              userId: Value(userId),
              title: serverTitle.isNotEmpty && serverTitle != existing.title
                  ? Value(serverTitle)
                  : const Value.absent(),
            ),
          );
        }
      }
    }

    // Pull messages (single endpoint, all sessions)
    final msgResult = await _remote.fetchAllMessages(since: since);
    if (msgResult.isSuccess && msgResult.data != null) {
      final messages = msgResult.data!;
      for (final item in messages) {
        final m = item as Map<String, dynamic>;
        final existing = await _local.getMessageByServerId(m['id'] as int);
        if (existing == null) {
          final localSession =
              await _local.getSessionByServerId(m['chat_session_id'] as int);
          if (localSession == null) continue; // orphan message, skip

          await _local.insertMessage(ChatMessagesTableCompanion(
            id: Value(const Uuid().v4()),
            sessionId: Value(localSession.id),
            serverId: Value(m['id'] as int),
            role: Value(m['role'] as String),
            content: Value(m['content'] as String? ?? ''),
            messageType: Value(m['message_type'] as String? ?? 'text'),
            metadata: Value(_encodeMetadata(m['metadata'])),
            feedbackType: Value(m['feedback_type'] as String?),
            syncStatus: const Value('synced'),
          ));
        } else {
          // Only update feedback if server has newer data
          final serverFeedback = m['feedback_type'] as String?;
          if (serverFeedback != null && existing.feedbackType == null) {
            await _local.updateMessageFeedback(
              existing.id,
              serverFeedback,
              m['feedback_detail'] as String?,
            );
          }
          // A row inserted before the app stored metadata — or streamed, which
          // only records the follow-up questions — gets the server's full copy.
          final serverMetadata = _encodeMetadata(m['metadata']);
          if (serverMetadata != '{}' && existing.metadata != serverMetadata) {
            await _local.updateMessageMetadata(existing.id, serverMetadata);
          }
        }
      }
    }
  }

  /// The server sends `metadata` as an object; older API builds send nothing.
  /// Either way the column holds a JSON object string.
  String _encodeMetadata(dynamic raw) =>
      raw is Map ? jsonEncode(raw) : '{}';
}
