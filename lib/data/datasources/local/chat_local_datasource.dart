import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

/// Local data source for chat operations using Drift (SQLite).
class ChatLocalDataSource {
  final AppDatabase _db;

  ChatLocalDataSource(this._db);

  // === Watch (reactive streams) ===

  /// Watch all sessions for a user, ordered by most recent.
  Stream<List<ChatSessionsTableData>> watchSessions(String userId) {
    return (_db.select(_db.chatSessionsTable)
          ..where((s) => s.userId.equals(userId))
          ..orderBy([(s) => OrderingTerm.desc(s.lastMessageAt)]))
        .watch();
  }

  /// Watch all renderable messages in a session, ordered chronologically.
  ///
  /// `message_type: context` rows are excluded: they carry the task context the
  /// lesson mentor sheet sends with the first question, are meant for the model
  /// only, and would otherwise show up as a wall-of-text user bubble. Filtering
  /// here (rather than at each call site) keeps them hidden in every chat view,
  /// including the ones the sync pull brings down on another device.
  Stream<List<ChatMessagesTableData>> watchMessages(String sessionId) {
    return (_db.select(_db.chatMessagesTable)
          ..where((m) =>
              m.sessionId.equals(sessionId) & m.messageType.equals('context').not())
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  // === CRUD ===

  Future<void> insertSession(ChatSessionsTableCompanion companion) {
    return _db.into(_db.chatSessionsTable).insert(companion);
  }

  Future<void> insertMessage(ChatMessagesTableCompanion companion) {
    return _db.into(_db.chatMessagesTable).insert(companion);
  }

  /// Store a message the server already knows, keyed by its `server_id`, and
  /// return the local row id — the existing one when the row is already here.
  ///
  /// `server_id` is the natural key for a chat message, but the table has no
  /// unique index on it (adding one to a shipped table would need a rebuild),
  /// so both writers have to dedupe themselves. The pull already did; the send
  /// path did not, and the two race: the mentor sheet kicks a full sync off
  /// milliseconds before it POSTs the message, so the sync's chat pull can
  /// insert the server rows while that POST is still in flight, after which the
  /// send inserted its own copy and the student saw their question twice
  /// (BR-M7EQY8).
  Future<String> upsertMessageByServerId({
    required int serverId,
    required String sessionId,
    required String role,
    required String content,
    String messageType = 'text',
  }) async {
    final existing = await getMessageByServerId(serverId);
    if (existing != null) return existing.id;

    final localId = const Uuid().v4();
    await insertMessage(ChatMessagesTableCompanion(
      id: Value(localId),
      sessionId: Value(sessionId),
      serverId: Value(serverId),
      role: Value(role),
      content: Value(content),
      messageType: Value(messageType),
      syncStatus: const Value('synced'),
    ));
    return localId;
  }

  /// Update message content (used during SSE streaming to append tokens).
  Future<void> updateMessageContent(String messageId, String content) {
    return (_db.update(_db.chatMessagesTable)
          ..where((m) => m.id.equals(messageId)))
        .write(ChatMessagesTableCompanion(
      content: Value(content),
    ));
  }

  /// Store a message's metadata JSON (the RAG answer's follow-up questions
  /// and sources — see ChatMessageHelpers).
  Future<void> updateMessageMetadata(String messageId, String metadata) {
    return (_db.update(_db.chatMessagesTable)
          ..where((m) => m.id.equals(messageId)))
        .write(ChatMessagesTableCompanion(
      metadata: Value(metadata),
    ));
  }

  /// Update session fields.
  Future<void> updateSession(String id, ChatSessionsTableCompanion companion) {
    return (_db.update(_db.chatSessionsTable)
          ..where((s) => s.id.equals(id)))
        .write(companion);
  }

  Future<void> updateSessionTitle(String id, String title) {
    return (_db.update(_db.chatSessionsTable)
          ..where((s) => s.id.equals(id)))
        .write(ChatSessionsTableCompanion(title: Value(title)));
  }

  /// Update feedback on a message.
  Future<void> updateMessageFeedback(
      String messageId, String? type, String? detail) {
    return (_db.update(_db.chatMessagesTable)
          ..where((m) => m.id.equals(messageId)))
        .write(ChatMessagesTableCompanion(
      feedbackType: Value(type),
      feedbackDetail: Value(detail),
      syncStatus: const Value('pending'),
    ));
  }

  /// Delete a session and cascade-delete its messages.
  Future<void> deleteSession(String id) async {
    await (_db.delete(_db.chatMessagesTable)
          ..where((m) => m.sessionId.equals(id)))
        .go();
    await (_db.delete(_db.chatSessionsTable)
          ..where((s) => s.id.equals(id)))
        .go();
  }

  // === Lookups ===

  Future<ChatSessionsTableData?> getSessionById(String id) {
    return (_db.select(_db.chatSessionsTable)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<ChatSessionsTableData?> getSessionByServerId(int serverId) async {
    final results = await (_db.select(_db.chatSessionsTable)
          ..where((s) => s.serverId.equals(serverId))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  /// The user's most recent conversation with [persona], or null when they
  /// have never talked to that mentor.
  Future<ChatSessionsTableData?> getLatestSessionForPersona(
      String userId, String persona) async {
    final results = await (_db.select(_db.chatSessionsTable)
          ..where((s) => s.userId.equals(userId) & s.persona.equals(persona))
          ..orderBy([(s) => OrderingTerm.desc(s.lastMessageAt)])
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  Future<ChatMessagesTableData?> getMessageByServerId(int serverId) async {
    final results = await (_db.select(_db.chatMessagesTable)
          ..where((m) => m.serverId.equals(serverId))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  Future<List<ChatMessagesTableData>> getMessagesBySessionId(
      String sessionId) {
    return (_db.select(_db.chatMessagesTable)
          ..where((m) => m.sessionId.equals(sessionId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  // === Sync helpers ===

  /// Get messages with pending feedback that needs syncing.
  Future<List<ChatMessagesTableData>> getMessagesWithPendingFeedback() {
    return (_db.select(_db.chatMessagesTable)
          ..where((m) => m.syncStatus.equals('pending')))
        .get();
  }
}
