import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/silent_log.dart';
import '../../models/chat_models.dart';
import '../../models/course_model.dart';
import '../../widgets/chat/chat_message_views.dart';

/// Fired for every question the student sends to the mentor.
///
/// [isFirst] marks the question that opened the conversation — the caller uses
/// it to log the block's content feedback exactly once, while still counting
/// every question for the admin's progress timeline.
typedef MentorQuestionCallback = void Function(
  String question, {
  required bool isFirst,
});

/// Whether "Přidat k procvičování" would be a no-op for [block] in [course],
/// and so must not be offered in the mentor sheet.
///
/// Two reasons, both ending with an option that claims something was added when
/// nothing was:
///   * the block is already in the practice set — bookmarked, or admin-flagged
///     `default_practice` (BR-FEQ97Q);
///   * the course is flagged `only_once`, typically a test, and never feeds
///     practice at all (BR-E495XK).
bool practiceOptionUnavailable({
  required ContentBlock block,
  required Course course,
}) =>
    block.isBookmarked || course.onlyOnce;

/// Open the course mentor for a content block (BR-C7TYTT).
///
/// The sheet is a conversation, not a static panel: the block's hint arrives as
/// the mentor's first message, the three quick replies sit under it, and
/// "Nerozumím tomu" pushes the block's `help` text into the same transcript
/// before handing over to the live AI mentor. The student never leaves the
/// lesson — closing the sheet is the way out.
///
/// Side-effects stay with the caller so the ELO/XP bookkeeping keeps living
/// next to the rest of the page's tracking:
///   * [onShown] — the hint was opened (hint level 1);
///   * [onEscalateToHelp] — "Nerozumím tomu" revealed the help text (level 2);
///   * [onAskMentor] — a question went to the AI;
///   * [onSavePractice] — null hides the practice option entirely (the quiz has
///     no bookmark store), otherwise combine with [practiceOptionUnavailable].
///
/// [buildAiContext] produces the task context sent with the first question. It
/// is a callback because the lesson and the quiz assemble it differently, and
/// because it must be read at send time, not at open time.
///
/// [allowAi] is false for graded tests, where the AI mentor stays out of reach
/// and the sheet stops at the help text.
///
/// [stepId] scopes the hint and the help text to the step whose "?" was tapped.
/// A step carrying its own hint/help overrides the block's shared one, each
/// field independently; omit it (or pass null) for atomic blocks, which have no
/// steps and always show the block's own text (BR-JHDNB3).
Future<void> showMentorSheet({
  required BuildContext context,
  required ContentBlock block,
  required String Function() buildAiContext,
  required VoidCallback onShown,
  required VoidCallback onEscalateToHelp,
  required MentorQuestionCallback onAskMentor,
  String? stepId,
  VoidCallback? onSavePractice,
  bool allowAi = true,
}) {
  // Notify caller the hint was shown (so it can record the XP penalty).
  onShown();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MentorSheet(
      block: block,
      stepId: stepId,
      buildAiContext: buildAiContext,
      onEscalateToHelp: onEscalateToHelp,
      onAskMentor: onAskMentor,
      onSavePractice: onSavePractice,
      allowAi: allowAi,
    ),
  );
}

/// A bubble the sheet owns itself: the hint, the help text, the echo of a
/// tapped quick reply. They all precede the first real chat message, so simple
/// concatenation in front of the live transcript keeps the order right.
///
/// The one exception is the question still on its way to the server, which
/// sits after the live transcript until its stored copy arrives.
class _LocalBubble {
  final String text;
  final bool isUser;
  final DateTime at;

  _LocalBubble(this.text, {required this.isUser}) : at = DateTime.now();
}

class _MentorSheet extends ConsumerStatefulWidget {
  final ContentBlock block;

  /// The step the "?" was tapped on — its hint/help wins over the block's.
  final String? stepId;
  final String Function() buildAiContext;
  final VoidCallback onEscalateToHelp;
  final MentorQuestionCallback onAskMentor;
  final VoidCallback? onSavePractice;
  final bool allowAi;

  const _MentorSheet({
    required this.block,
    required this.stepId,
    required this.buildAiContext,
    required this.onEscalateToHelp,
    required this.onAskMentor,
    required this.onSavePractice,
    required this.allowAi,
  });

  @override
  ConsumerState<_MentorSheet> createState() => _MentorSheetState();
}

class _MentorSheetState extends ConsumerState<_MentorSheet> {
  static const _persona = ChatPersona.mathMentor;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_LocalBubble> _local = [];

  /// The quick replies disappear once the student escalates — from there on the
  /// conversation carries on in the input field.
  bool _showQuickReplies = true;

  /// Dropped as soon as the block has been added, so the option cannot be
  /// tapped twice.
  late bool _showPracticeReply = widget.onSavePractice != null;

  /// The composer appears only after "Nerozumím tomu": hint → help → AI is the
  /// escalation ladder the ELO penalty is built on.
  bool _composerOpen = false;

  String? _sessionId;
  bool _isStreaming = false;
  bool _hasText = false;
  String? _error;
  StreamSubscription<ChatStreamEvent>? _streamSub;

  /// The question just sent, shown the moment it leaves the field
  /// (BR-3PNK46). The repository stores it only once the server has created
  /// the session and acknowledged the POST, so until then the transcript had
  /// nothing but the typing dots to show. It gives way to the stored row as
  /// soon as that lands.
  _LocalBubble? _pending;

  /// How many stored messages there were when [_pending] was sent. Only a row
  /// after these can be its stored copy — asking the same thing twice must
  /// not hide the second question behind the first.
  int _storedBeforePending = 0;

  @override
  void initState() {
    super.initState();
    _local.add(_LocalBubble(
        widget.block.hintForStep(widget.stepId) ?? '',
        isUser: false));
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _onClear() => Navigator.of(context).pop();

  void _onSavePractice() {
    widget.onSavePractice?.call();
    setState(() {
      _showPracticeReply = false;
      _local.add(_LocalBubble(AppStrings.lessonFeedbackPracticeAdded,
          isUser: false));
    });
    _scrollToBottom();
  }

  void _onConfused() {
    widget.onEscalateToHelp();

    // The help text for this step — its own when the author wrote one, the
    // block's otherwise. Without either there is nothing more to reveal, so the
    // mentor asks the student to describe the problem instead of repeating the
    // hint verbatim.
    final help = widget.block.helpForStep(widget.stepId);
    final reply = (help != null && help.isNotEmpty)
        ? help
        : AppStrings.mentorSheetNoHelp;

    setState(() {
      _local.add(
          _LocalBubble(AppStrings.lessonFeedbackConfused, isUser: true));
      _local.add(_LocalBubble(reply, isUser: false));
      _showQuickReplies = false;
      _composerOpen = widget.allowAi;
    });
    _scrollToBottom();
  }

  /// The stored transcript of the current session, as last emitted.
  List<ChatMessagesTableData> _storedMessages() {
    final sessionId = _sessionId;
    if (sessionId == null) return const [];
    return ref.read(chatMessagesStreamProvider(sessionId)).valueOrNull ??
        const [];
  }

  /// Whether [_pending] is already in [live] as a stored row (or there is
  /// nothing pending).
  bool _pendingStored(List<ChatMessagesTableData> live) {
    final pending = _pending;
    return pending == null ||
        live
            .skip(_storedBeforePending)
            .any((m) => m.isFromUser && m.content == pending.text);
  }

  /// The question got no answer. When it never reached the server either, its
  /// bubble would claim otherwise: take it back and return the text to the
  /// field, so a retry is one tap away.
  ///
  /// [error] is what the student is told; a generic failure by default.
  void _onSendFailed([String? error]) {
    if (!mounted) return;
    final pending = _pending;
    if (pending != null &&
        !_pendingStored(_storedMessages()) &&
        _messageController.text.isEmpty) {
      _messageController.text = pending.text;
    }
    setState(() {
      _pending = null;
      _isStreaming = false;
      _error = error ?? AppStrings.chatStreamError;
    });
  }

  Future<void> _send() async {
    final question = _messageController.text.trim();
    if (question.isEmpty || _isStreaming) return;
    _messageController.clear();

    final isFirst = _sessionId == null;
    setState(() {
      _isStreaming = true;
      _error = null;
      _pending = _LocalBubble(question, isUser: true);
      _storedBeforePending = _storedMessages().length;
    });
    _scrollToBottom();

    try {
      // Offline the repository never reaches for the server, and the generic
      // "Chyba při generování odpovědi" read as if the mentor had broken. Say
      // what the Chaty tab says instead (BR-BMH4HF) — for follow-ups too, when
      // the connection drops mid-conversation.
      if (!await ref.read(connectivityServiceProvider).isOnline) {
        _onSendFailed(AppStrings.chatRequiresInternet);
        return;
      }
      if (isFirst) {
        final user = await ref.read(activeUserProvider.future);
        if (user == null) throw Exception('No active user');
        final session = await ref
            .read(chatRepositoryProvider)
            .createSession(user.id, _persona.id);
        if (!mounted) return;
        _sessionId = session.id;
      }
    } catch (e, st) {
      silentLog('mentor_sheet', e, st);
      _onSendFailed();
      return;
    }

    widget.onAskMentor(question, isFirst: isFirst);

    // The task context rides along with the opening question only: the server
    // stores it as a hidden message, so the model keeps it for the whole
    // conversation while the transcript shows just what the student typed.
    _streamSub = ref
        .read(chatRepositoryProvider)
        .sendMessage(
          _sessionId!,
          question,
          context: isFirst ? widget.buildAiContext() : null,
        )
        .listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case ChatStreamToken():
            _scrollToBottom();
          case ChatStreamSuggestions():
            // Lesson mentors are LLM-backed and never send these; the
            // repository has stored them either way.
            break;
          case ChatStreamDone():
            setState(() {
              _isStreaming = false;
              _pending = null;
            });
            _scrollToBottom();
            // Picks up the server-generated session title.
            ref.read(syncServiceProvider).sync();
          case ChatStreamError():
            _onSendFailed();
        }
      },
      onError: (Object e, StackTrace st) {
        silentLog('mentor_sheet', e, st);
        _onSendFailed();
      },
    );

    // Rebuild so the transcript starts watching the (possibly brand new)
    // session's messages.
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = _sessionId;
    final live = sessionId == null
        ? const <ChatMessagesTableData>[]
        : ref.watch(chatMessagesStreamProvider(sessionId)).valueOrNull ??
            const <ChatMessagesTableData>[];

    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      // Push content up when the keyboard is open.
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          Flexible(child: _buildTranscript(live)),
          if (_showQuickReplies) _buildQuickReplies(),
          if (_error != null) _buildError(),
          if (_composerOpen)
            ChatComposer(
              controller: _messageController,
              hintText: AppStrings.mentorSheetInputHint,
              canSend: _hasText && !_isStreaming,
              onSend: _send,
              elevated: false,
              // The sheet already sits above the safe area.
              bottomPadding: 0,
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppDecorations.radiusS,
            ),
            child: Icon(
              Icons.help_outline,
              color: AppColors.quizPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _persona.displayName,
              style: AppTextStyles.heading4(),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 20, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscript(List<ChatMessagesTableData> live) {
    final pending = _pendingStored(live) ? null : _pending;
    final itemCount = _local.length +
        live.length +
        (pending != null ? 1 : 0) +
        (_isStreaming ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < _local.length) {
          final bubble = _local[index];
          return ChatBubble(
            content: bubble.text,
            isUser: bubble.isUser,
            avatarEmoji: _persona.emoji,
            timeLabel: _timeLabel(bubble.at),
          );
        }
        final liveIndex = index - _local.length;
        if (liveIndex < live.length) {
          return ChatMessageBubble(
            message: live[liveIndex],
            avatarEmoji: _persona.emoji,
          );
        }
        if (pending != null && liveIndex == live.length) {
          return ChatBubble(
            content: pending.text,
            isUser: true,
            avatarEmoji: _persona.emoji,
            timeLabel: _timeLabel(pending.at),
          );
        }
        return ChatTypingIndicator(avatarEmoji: _persona.emoji);
      },
    );
  }

  Widget _buildQuickReplies() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _QuickReply(
            icon: Icons.check,
            iconColor: AppColors.success,
            label: AppStrings.lessonFeedbackClear,
            onTap: _onClear,
          ),
          if (_showPracticeReply)
            _QuickReply(
              icon: Icons.bookmark_border,
              iconColor: AppColors.quizPurple,
              label: AppStrings.lessonFeedbackPractice,
              onTap: _onSavePractice,
            ),
          _QuickReply(
            icon: Icons.sentiment_dissatisfied_outlined,
            iconColor: AppColors.orange,
            label: AppStrings.lessonFeedbackConfused,
            onTap: _onConfused,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AppTextStyles.caption(color: AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime at) =>
      '${at.hour}:${at.minute.toString().padLeft(2, '0')}';
}

/// One of the three quick-reply pills under the mentor's message.
class _QuickReply extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _QuickReply({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusXL,
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.bodySmall()),
          ],
        ),
      ),
    );
  }
}
