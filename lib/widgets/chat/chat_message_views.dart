import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../markdown_latex_widget.dart';
import 'feedback_bottom_sheet.dart';

/// The conversation pieces shared by the chat page and the lesson mentor sheet.
///
/// Both render the same transcript — mentor bubble on the left, student bubble
/// on the right, timestamp and rating actions underneath — so the widgets live
/// here rather than being copied into the sheet. Keep them free of page state:
/// everything they need arrives as arguments.

/// Round mentor/student avatar shown beside a bubble.
class ChatAvatar extends StatelessWidget {
  /// Emoji fallback, used whenever [imageUrl] is null or fails to load.
  final String emoji;
  final String? imageUrl;
  final bool isUser;
  final double size;

  const ChatAvatar({
    super.key,
    required this.emoji,
    this.imageUrl,
    this.isUser = false,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isUser ? AppColors.cardLavender : AppColors.background,
        shape: BoxShape.circle,
      ),
      child: isUser
          ? Icon(Icons.person, size: size * 0.56, color: AppColors.primaryDark)
          : (imageUrl != null && imageUrl!.isNotEmpty)
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _emoji(),
                )
              : _emoji(),
    );
  }

  Widget _emoji() => Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
      );
}

/// One conversation bubble, with avatar, timestamp and optional actions.
///
/// Takes plain values rather than a database row so the mentor sheet can render
/// the block's own hint and help text through the very same bubble as a
/// streamed AI answer.
class ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;

  /// Mentor avatar emoji. Ignored for [isUser] bubbles.
  final String avatarEmoji;
  final String? avatarUrl;

  /// `HH:mm` label under the bubble. Omitted when null.
  final String? timeLabel;

  /// Rating actions (thumbs) rendered next to [timeLabel].
  final List<Widget> actions;

  /// Follow-up questions offered by the answer, drawn as buttons under the
  /// text. Tapping one hands its question to [onSuggestionTap] (BR-UE8KK4).
  final List<String> suggestions;

  /// Null while the mentor is busy, which greys the buttons out — asking a new
  /// question mid-answer would race the stream that is still writing.
  final ValueChanged<String>? onSuggestionTap;

  const ChatBubble({
    super.key,
    required this.content,
    required this.isUser,
    this.avatarEmoji = '🤖',
    this.avatarUrl,
    this.timeLabel,
    this.actions = const [],
    this.suggestions = const [],
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            ChatAvatar(emoji: avatarEmoji, imageUrl: avatarUrl),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.background : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: isUser
                        ? Border.all(color: AppColors.primaryDark08)
                        : null,
                    boxShadow: isUser ? null : AppDecorations.shadowLight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarkdownLatexWidget(
                        content: content,
                        textStyle:
                            AppTextStyles.bodySmall().copyWith(height: 1.5),
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.chatSuggestionsTitle,
                          style: AppTextStyles.bodySmall()
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < suggestions.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          ChatSuggestionButton(
                            question: suggestions[i],
                            onTap: onSuggestionTap == null
                                ? null
                                : () => onSuggestionTap!(suggestions[i]),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (timeLabel != null || actions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timeLabel != null)
                        Text(
                          timeLabel!,
                          style: AppTextStyles.chipLabel(
                              color: AppColors.primaryDark48),
                        ),
                      ...actions,
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const ChatAvatar(emoji: '', isUser: true),
          ],
        ],
      ),
    );
  }
}

/// One tappable follow-up question under a mentor answer.
///
/// Full width rather than a [Wrap] pill: these are whole sentences, so a
/// pill row would leave most of them wrapping onto two ragged lines anyway.
class ChatSuggestionButton extends StatelessWidget {
  final String question;

  /// Null renders the button disabled — see [ChatBubble.onSuggestionTap].
  final VoidCallback? onTap;

  const ChatSuggestionButton({
    super.key,
    required this.question,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDecorations.radiusXL,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppDecorations.radiusXL,
            border: Border.all(color: AppColors.primaryDark08),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.north_east,
                size: 16,
                color: enabled
                    ? AppColors.primaryDark48
                    : AppColors.primaryDark08,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: AppTextStyles.bodySmall(
                    color: enabled
                        ? AppColors.primaryDark
                        : AppColors.primaryDark48,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [ChatBubble] backed by a stored message, with the like/dislike actions
/// wired to the chat repository.
class ChatMessageBubble extends ConsumerWidget {
  final ChatMessagesTableData message;
  final String avatarEmoji;
  final String? avatarUrl;

  /// Asks one of the answer's follow-up questions. Null leaves the buttons
  /// disabled, which is what the mentor sheet wants while a reply streams.
  final ValueChanged<String>? onSuggestionTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.avatarEmoji,
    this.avatarUrl,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isFromUser;

    // An assistant row with no content yet is still streaming — the typing
    // indicator stands in for it, so render nothing.
    if (!isUser && message.content.isEmpty) return const SizedBox.shrink();

    final time = message.createdAt;
    final timeLabel =
        '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    return ChatBubble(
      // displayContent, not content: a RAG answer also carries its follow-up
      // questions as markdown, which the buttons below replace (BR-UE8KK4).
      content: message.displayContent,
      isUser: isUser,
      avatarEmoji: avatarEmoji,
      avatarUrl: avatarUrl,
      timeLabel: timeLabel,
      suggestions: isUser
          ? const []
          : message.suggestions.map((s) => s.question).toList(),
      onSuggestionTap: onSuggestionTap,
      actions: isUser
          ? const []
          : [
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => ref.read(chatRepositoryProvider).submitFeedback(
                      message.id,
                      message.isLiked ? null : 'like',
                      null,
                    ),
                child: Icon(
                  message.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 16,
                  color: message.isLiked
                      ? AppColors.primaryDark
                      : AppColors.primaryDark48,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showChatFeedbackSheet(
                  context: context,
                  messageId: message.id,
                  chatRepo: ref.read(chatRepositoryProvider),
                ),
                child: Icon(
                  message.isDisliked
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined,
                  size: 16,
                  color: message.isDisliked
                      ? AppColors.primaryDark
                      : AppColors.primaryDark48,
                ),
              ),
            ],
    );
  }
}

/// Three-dot bubble shown while the mentor's answer is still streaming.
class ChatTypingIndicator extends StatelessWidget {
  final String avatarEmoji;
  final String? avatarUrl;

  const ChatTypingIndicator({
    super.key,
    required this.avatarEmoji,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatAvatar(emoji: avatarEmoji, imageUrl: avatarUrl),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: AppDecorations.shadowLight,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(0),
                SizedBox(width: 4),
                _TypingDot(1),
                SizedBox(width: 4),
                _TypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  final int index;

  const _TypingDot(this.index);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryDark48,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Message input row: text field plus send button.
///
/// Enter sends, Shift+Enter inserts a newline — the behaviour the chat page has
/// always had on desktop, kept here so the mentor sheet matches it.
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  /// Small caption under the field. Omitted when null.
  final String? helperText;

  /// False while a reply is streaming, the field is empty, or the device is
  /// offline — all reasons the send button must not fire.
  final bool canSend;
  final VoidCallback onSend;

  /// Bottom inset. The chat page adds the safe area; a bottom sheet already
  /// sits above it and passes 0.
  final double bottomPadding;

  /// The chat page floats the bar over the transcript; inside the sheet the
  /// shadow would draw a stray line, so it can be turned off.
  final bool elevated;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.hintText,
    required this.canSend,
    required this.onSend,
    this.helperText,
    this.bottomPadding = 0,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottomPadding + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.primaryDark08,
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppDecorations.radiusS,
                  ),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        if (canSend) onSend();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: AppTextStyles.bodySmall(
                            color: AppColors.primaryDark48),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: AppTextStyles.bodySmall(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: canSend ? onSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: canSend
                        ? AppColors.primaryDark
                        : AppColors.primaryDark32,
                    borderRadius: AppDecorations.radiusS,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText!,
              style: AppTextStyles.chipLabel(color: AppColors.primaryDark48),
            ),
          ],
        ],
      ),
    );
  }
}

/// Date divider used at the top of a transcript.
class ChatDateSeparator extends StatelessWidget {
  final String label;

  const ChatDateSeparator({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.primaryDark08)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: AppTextStyles.caption(color: AppColors.primaryDark48),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.primaryDark08)),
        ],
      ),
    );
  }
}
