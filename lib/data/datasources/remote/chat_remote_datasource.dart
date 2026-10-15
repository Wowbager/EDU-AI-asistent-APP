import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../models/chat_models.dart';

/// Remote data source for chat operations via REST API + SSE.
class ChatRemoteDataSource {
  final ApiClient _apiClient;

  ChatRemoteDataSource(this._apiClient);

  /// Unwrap the 'data' key from API response, returning the list inside.
  Future<ApiResult<List<dynamic>>> _getList(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      endpoint,
      queryParameters: queryParameters,
    );
    if (result.isFailure || result.data == null) {
      return ApiResult.failure(result.error ?? 'Request failed');
    }
    final list = result.data!['data'] as List<dynamic>? ?? [];
    return ApiResult.success(list);
  }

  /// Fetch the mentors the user can start a chat with.
  ///
  /// Without [courseId] this is the new-chat list (public mentors only); with
  /// it, the mentors of that course, hidden ones included.
  Future<ApiResult<List<dynamic>>> fetchMentors({int? courseId}) {
    return _getList(
      ApiEndpoints.chatMentors,
      queryParameters: courseId != null ? {'course_id': courseId} : null,
    );
  }

  /// Fetch all chat sessions for the authenticated user.
  Future<ApiResult<List<dynamic>>> fetchSessions({String? since}) {
    final queryParams = <String, dynamic>{};
    if (since != null) queryParams['since'] = since;
    return _getList(
      ApiEndpoints.chatSessions,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  /// Create a new chat session.
  Future<ApiResult<Map<String, dynamic>>> createSession({
    required String persona,
    String title = '',
  }) {
    return _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.chatSessions,
      data: {'persona': persona, 'title': title},
    );
  }

  /// Delete a chat session.
  Future<ApiResult<Map<String, dynamic>>> deleteSession(int sessionId) {
    return _apiClient.delete<Map<String, dynamic>>(
      ApiEndpoints.chatSession(sessionId),
    );
  }

  /// Send a user message. Server creates both user + empty assistant message.
  ///
  /// [context] is optional task context (the lesson mentor sheet sends the
  /// block the student is stuck on). The server stores it as a hidden
  /// `message_type: context` message: the model sees it, the transcript
  /// does not.
  Future<ApiResult<Map<String, dynamic>>> sendMessage(
      int sessionId, String content, {String? context}) {
    return _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.chatMessages(sessionId),
      data: {
        'content': content,
        if (context != null && context.isNotEmpty) 'context': context,
      },
    );
  }

  /// Open SSE stream for an assistant message response.
  ///
  /// Frames carry either `token` (answer text) or `suggestions` (a RAG
  /// answer's follow-up questions, which arrive once, after the text).
  Stream<ChatStreamEvent> streamResponse(
      int sessionId, int assistantMessageId) async* {
    final response = await _apiClient.dio.get(
      ApiEndpoints.chatStream(sessionId),
      queryParameters: {'message_id': assistantMessageId},
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = (response.data as ResponseBody).stream;
    String buffer = '';

    await for (final chunk in stream.cast<List<int>>().transform(utf8.decoder)) {
      buffer += chunk;
      while (buffer.contains('\n\n')) {
        final eventEnd = buffer.indexOf('\n\n');
        final event = buffer.substring(0, eventEnd);
        buffer = buffer.substring(eventEnd + 2);

        for (final line in event.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') return;
            try {
              final parsed = jsonDecode(data) as Map<String, dynamic>;
              if (parsed.containsKey('error')) {
                throw Exception(parsed['error'] as String);
              }
              if (parsed.containsKey('suggestions')) {
                yield ChatStreamSuggestions(
                    ChatSuggestion.listFromJson(parsed['suggestions']));
                continue;
              }
              yield ChatStreamToken(parsed['token'] as String);
            } catch (e) {
              if (e is Exception) rethrow;
              yield ChatStreamToken(data);
            }
          }
        }
      }
    }
  }

  /// Fetch messages for a specific session.
  Future<ApiResult<List<dynamic>>> fetchMessages(
      int sessionId, {String? since}) {
    final queryParams = <String, dynamic>{};
    if (since != null) queryParams['since'] = since;
    return _getList(
      ApiEndpoints.chatMessages(sessionId),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  /// Fetch all new messages across all sessions (for sync pull).
  Future<ApiResult<List<dynamic>>> fetchAllMessages({String? since}) {
    final queryParams = <String, dynamic>{};
    if (since != null) queryParams['since'] = since;
    return _getList(
      ApiEndpoints.chatMessagesAll,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  /// Update feedback on a message.
  Future<ApiResult<Map<String, dynamic>>> updateFeedback(
      int messageId, {String? type, String? detail}) {
    return _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.chatMessageFeedback(messageId),
      data: {'feedback_type': type, 'feedback_detail': detail},
    );
  }
}
