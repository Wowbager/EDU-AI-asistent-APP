import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/chat_repository.dart';

/// Thumbs-down feedback sheet for a single assistant message.
///
/// Lifted out of `chat_detail_page.dart` so the lesson mentor sheet can offer
/// the same rating actions on the answers it streams inline.
void showChatFeedbackSheet({
  required BuildContext context,
  required String messageId,
  required ChatRepository chatRepo,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FeedbackBottomSheet(
      messageId: messageId,
      chatRepo: chatRepo,
    ),
  );
}

/// Feedback reason options
enum FeedbackReason {
  incorrectInfo,
  incompleteAnswer,
  unclearExplanation,
  inappropriateAnswer,
  otherReason,
}

/// Feedback Bottom Sheet Widget
class FeedbackBottomSheet extends StatefulWidget {
  final String messageId;
  final ChatRepository chatRepo;

  const FeedbackBottomSheet({
    super.key,
    required this.messageId,
    required this.chatRepo,
  });

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> {
  FeedbackReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _getReasonEmoji(FeedbackReason reason) {
    switch (reason) {
      case FeedbackReason.incorrectInfo:
        return '❌';
      case FeedbackReason.incompleteAnswer:
        return '📝';
      case FeedbackReason.unclearExplanation:
        return '❓';
      case FeedbackReason.inappropriateAnswer:
        return '⚠️';
      case FeedbackReason.otherReason:
        return '💬';
    }
  }

  String _getReasonText(FeedbackReason reason) {
    switch (reason) {
      case FeedbackReason.incorrectInfo:
        return AppStrings.chatFeedbackIncorrect;
      case FeedbackReason.incompleteAnswer:
        return AppStrings.chatFeedbackIncomplete;
      case FeedbackReason.unclearExplanation:
        return AppStrings.chatFeedbackUnclear;
      case FeedbackReason.inappropriateAnswer:
        return AppStrings.chatFeedbackInappropriate;
      case FeedbackReason.otherReason:
        return AppStrings.chatFeedbackOther;
    }
  }

  void _submitFeedback() {
    if (_selectedReason == null) return;

    widget.chatRepo.submitFeedback(
      widget.messageId,
      'dislike',
      _getReasonText(_selectedReason!),
    );
    Navigator.pop(context);

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.chatFeedbackThanks,
          style: AppTextStyles.bodySmall(),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusS,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbs down icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppDecorations.radiusS,
                    ),
                    child: const Center(
                      child: Text(
                        '👎',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.chatFeedbackTitle,
                          style: AppTextStyles.cardTitle(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.chatFeedbackSubtitle,
                          style: AppTextStyles.meta(
                              color: AppColors.primaryDark64),
                        ),
                      ],
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: AppColors.primaryDark48,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Reason label
              Row(
                children: [
                  Text(
                    AppStrings.chatFeedbackSelectReason,
                    style: AppTextStyles.labelMedium(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '*',
                    style: AppTextStyles.labelMedium(color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reason options
              ...FeedbackReason.values
                  .map((reason) => _buildReasonOption(reason)),

              const SizedBox(height: 24),

              // Additional details label
              Text(
                AppStrings.chatFeedbackDetails,
                style: AppTextStyles.labelMedium(),
              ),
              const SizedBox(height: 12),

              // Text area
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primaryDark16,
                  ),
                  borderRadius: AppDecorations.radiusS,
                ),
                child: TextField(
                  controller: _detailsController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: AppStrings.chatFeedbackHint,
                    hintStyle: AppTextStyles.bodySmall(
                        color: AppColors.primaryDark48),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    counterStyle: AppTextStyles.caption(
                        color: AppColors.primaryDark48),
                  ),
                  style: AppTextStyles.bodySmall(),
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primaryDark16,
                          ),
                          borderRadius: AppDecorations.radiusS,
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.chatFeedbackCancel,
                            style: AppTextStyles.labelMedium(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Submit button
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          _selectedReason != null ? _submitFeedback : null,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _selectedReason != null
                              ? AppColors.primaryDark
                              : AppColors.primaryDark32,
                          borderRadius: AppDecorations.radiusS,
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.chatFeedbackSubmit,
                            style:
                                AppTextStyles.labelMedium(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonOption(FeedbackReason reason) {
    final isSelected = _selectedReason == reason;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedReason = reason;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryDark
                  : AppColors.primaryDark16,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: AppDecorations.radiusS,
          ),
          child: Row(
            children: [
              // Radio button
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.primaryDark32,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Emoji
              Text(
                _getReasonEmoji(reason),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 12),
              // Text
              Text(
                _getReasonText(reason),
                style: AppTextStyles.bodySmall(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
