import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/connectivity_service.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../widgets/chat/chat_message_views.dart';
import 'package:eduai/core/util/silent_log.dart';
import '../core/layout/breakpoints.dart';
import '../widgets/detail_shell.dart';

/// Chat Detail Page for individual conversation
class ChatDetailPage extends ConsumerStatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final ChatPersona persona;

  /// Optional task context for a chat opened from a block. When set with an
  /// empty sessionId, a new session is created and the conversation opens with
  /// [initialQuestion].
  ///
  /// It rides along as the hidden `message_type: context` message, the same
  /// channel the mentor sheet uses: the model reads the task, the transcript
  /// shows the student's question. Sending the blob as the visible message put
  /// the whole assembled context — image placeholders and all — in the
  /// student's own bubble (BR-NAH3TR).
  final String? initialContext;

  /// The visible opening message sent with [initialContext]. Defaults to a
  /// plain request for help, which is what tapping "Zeptat se AI" means.
  final String? initialQuestion;

  /// Rendered as the right-hand pane of the wide chat layout instead of as a
  /// pushed route: no back button (there is nothing to pop) and no status-bar
  /// inset (the shell already handled it).
  final bool embedded;

  const ChatDetailPage({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    required this.persona,
    this.initialContext,
    this.initialQuestion,
    this.embedded = false,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isStreaming = false;
  bool _hasText = false;
  bool _isOffline = false;
  String? _effectiveSessionId;
  StreamSubscription<ChatStreamEvent>? _streamSub;

  @override
  void initState() {
    super.initState();
    _effectiveSessionId = widget.sessionId.isNotEmpty ? widget.sessionId : null;
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });

    // If opened with context (from block), create session and auto-send
    if (widget.initialContext != null && _effectiveSessionId == null) {
      _createSessionAndSendContext();
    }
  }

  Future<void> _createSessionAndSendContext() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final user = await ref.read(activeUserProvider.future);
      if (user == null) return;

      final session = await chatRepo.createSession(user.id, widget.persona.id);
      _effectiveSessionId = session.id;
      if (mounted) setState(() {});

      // Open the conversation with the student's question; the task context
      // goes along hidden.
      if (widget.initialContext != null && _effectiveSessionId != null) {
        _sendMessage(
          widget.initialQuestion ?? AppStrings.chatContextOpeningQuestion,
          widget.initialContext,
        );
      }
    } catch (e, st) { silentLog('chat_detail_page', e, st); }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Sends [question] when given — that is a follow-up button the student
  /// tapped, or the opening question of a chat started from a block —
  /// otherwise whatever is in the composer.
  ///
  /// [taskContext] is the hidden task context that goes with the opening
  /// question only; the server keeps it out of the transcript.
  void _sendMessage([String? question, String? taskContext]) {
    final typed = question ?? _messageController.text;
    if (typed.trim().isEmpty || _isStreaming || _isOffline) return;
    final sessionId = _effectiveSessionId;
    if (sessionId == null) return;
    final content = typed.trim();
    _messageController.clear();

    setState(() => _isStreaming = true);

    final chatRepo = ref.read(chatRepositoryProvider);
    _streamSub =
        chatRepo.sendMessage(sessionId, content, context: taskContext).listen(
      (event) {
        switch (event) {
          case ChatStreamSuggestions():
            // Stored by the repository; the bubble picks them up from the
            // watch stream like the answer text does.
            break;
          case ChatStreamToken():
            // Content is already updated in local DB by the repository
            // The watchMessages stream will trigger UI rebuild automatically
            _scrollToBottom();
            break;
          case ChatStreamDone():
            setState(() => _isStreaming = false);
            _scrollToBottom();
            // Sync to pick up server-generated title after first message
            ref.read(syncServiceProvider).sync();
            break;
          case ChatStreamError():
            setState(() => _isStreaming = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppStrings.chatStreamError)),
              );
            }
            break;
        }
      },
      onError: (e) {
        setState(() => _isStreaming = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.chatStreamError)),
          );
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// The in-page back button. Only the phone route needs one: the wide layouts
  /// get theirs from the shell's top bar (pushed) or have nothing to pop
  /// (embedded pane).
  bool get _showInPageBack =>
      !widget.embedded && context.widthClass == WidthClass.compact;

  @override
  Widget build(BuildContext context) {
    // Embedded: the pane is already the right size, so no clamp.
    if (widget.embedded) return _buildPage(context);

    if (context.widthClass == WidthClass.compact) {
      return ContentWidth(
        maxWidth: ContentWidth.reading,
        child: _buildPage(context),
      );
    }

    // Pushed on a wide viewport — from a lesson's "ask the AI" action, say.
    // Without the shell this landed as a bare 720px column with no navigation,
    // looking nothing like the two-pane chat tab.
    return DetailShell(
      backLabel: widget.sessionTitle.isNotEmpty
          ? widget.sessionTitle
          : widget.persona.displayName,
      child: _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final sessionId = _effectiveSessionId ?? widget.sessionId;
    final messagesAsync =
        ref.watch(chatMessagesStreamProvider(sessionId));
    final connectivityAsync = ref.watch(connectivityStateProvider);
    _isOffline = connectivityAsync.whenOrNull(
      data: (state) => !state.isOnline,
    ) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header (extends to top)
          _buildHeader(),
          // Offline banner
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.orange,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.chatDetailOfflineBanner,
                    style: AppTextStyles.caption(color: Colors.white),
                  ),
                ],
              ),
            ),
          // Messages
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                // Auto-scroll when new messages arrive
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: messages.length +
                      1 +
                      (_isStreaming ? 1 : 0), // +1 for date separator
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ChatDateSeparator(
                          label: AppStrings.chatDetailToday);
                    }
                    if (index > messages.length) {
                      return ChatTypingIndicator(
                          avatarEmoji: widget.persona.emoji);
                    }
                    return ChatMessageBubble(
                      message: messages[index - 1],
                      avatarEmoji: widget.persona.emoji,
                      onSuggestionTap: (_isStreaming || _isOffline)
                          ? null
                          : _sendMessage,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(AppStrings.genericError(e.toString()))),
            ),
          ),
          // Input bar
          ChatComposer(
            controller: _messageController,
            hintText: AppStrings.chatDetailInputHint,
            helperText: AppStrings.chatDetailHelperText,
            canSend: !_isStreaming && _hasText && !_isOffline,
            onSend: _sendMessage,
            bottomPadding: MediaQuery.paddingOf(context).bottom,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Only the phone route sits under the status bar.
    final topPadding =
        _showInPageBack ? MediaQuery.paddingOf(context).top : 0.0;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: topPadding + 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppDecorations.shadowLight,
      ),
      child: Row(
        children: [
          // Back button — the wide layouts get theirs from the shell.
          if (_showInPageBack)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.primaryDark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.persona.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sessionTitle.isNotEmpty
                      ? widget.sessionTitle
                      : widget.persona.displayName,
                  style: AppTextStyles.cardTitleSmall(),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.chatDetailOnline,
                      style:
                          AppTextStyles.meta(color: AppColors.primaryDark64),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
