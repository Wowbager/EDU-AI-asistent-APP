import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/strings/app_strings.dart';
import '../../core/ui/app_toast.dart';
import '../../models/course_model.dart';
import 'action_button.dart';

/// Action button row used by ContentBlock cards (atomic + step-based).
/// Shows bookmark/like/dislike (and optionally help) on the left, confirm
/// checkmark on the right. Question blocks use a two-tap flow:
/// first tap evaluates ([onMarkAnswered]), second tap confirms ([onConfirm]).
class LessonContentActionButtonsRow extends StatelessWidget {
  final ContentBlock block;
  final bool isCurrent;
  final bool canConfirm;
  final bool isAnswered;
  final VoidCallback onBookmark;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onShowHint;
  final VoidCallback onMarkAnswered;
  final VoidCallback onConfirm;

  const LessonContentActionButtonsRow({
    super.key,
    required this.block,
    required this.isCurrent,
    required this.canConfirm,
    required this.isAnswered,
    required this.onBookmark,
    required this.onLike,
    required this.onDislike,
    required this.onShowHint,
    required this.onMarkAnswered,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(36),
            boxShadow: AppDecorations.shadowStrong,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LessonActionButton(
                icon: block.isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                isActive: block.isBookmarked,
                onTap: onBookmark,
              ),
              LessonActionButton(
                icon: Icons.thumb_up_outlined,
                isActive: block.isLiked,
                activeColor: AppColors.success,
                onTap: onLike,
              ),
              LessonActionButton(
                icon: Icons.thumb_down_outlined,
                isActive: block.isDisliked,
                activeColor: AppColors.orange,
                onTap: onDislike,
              ),
              if (block.hasHint)
                LessonActionButton(
                  icon: Icons.help_outline,
                  isActive: false,
                  onTap: onShowHint,
                ),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isCurrent && !block.isCompleted && canConfirm) {
              if (block.isQuestionBlock && !isAnswered) {
                onMarkAnswered();
              } else {
                onConfirm();
              }
            } else if (isCurrent && !block.isCompleted && !canConfirm) {
              showAppToast(context, AppStrings.lessonSelectAnswerFirst);
            }
          },
          child: _ConfirmCheck(
            isCompleted: block.isCompleted,
            isEvaluated: isAnswered,
          ),
        ),
      ],
    );
  }
}

/// Action button row used by legacy LessonBlock cards. No help button,
/// single-tap confirm flow.
class LessonLegacyActionButtonsRow extends StatelessWidget {
  final LessonBlock block;
  final bool isCurrent;
  final bool showConfirm;
  final VoidCallback onBookmark;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onConfirm;

  const LessonLegacyActionButtonsRow({
    super.key,
    required this.block,
    required this.isCurrent,
    required this.onBookmark,
    required this.onLike,
    required this.onDislike,
    required this.onConfirm,
    this.showConfirm = true,
  });

  @override
  Widget build(BuildContext context) {
    final canConfirm = block.type != LessonBlockType.quiz ||
        block.selectedOptionId != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(36),
            boxShadow: AppDecorations.shadowStrong,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LessonActionButton(
                icon: block.isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                isActive: block.isBookmarked,
                onTap: onBookmark,
              ),
              LessonActionButton(
                icon: Icons.thumb_up_outlined,
                isActive: block.isLiked,
                activeColor: AppColors.success,
                onTap: onLike,
              ),
              LessonActionButton(
                icon: Icons.thumb_down_outlined,
                isActive: block.isDisliked,
                activeColor: AppColors.orange,
                onTap: onDislike,
              ),
            ],
          ),
        ),
        if (showConfirm)
          GestureDetector(
            onTap: () {
              if (isCurrent && !block.isCompleted && canConfirm) {
                onConfirm();
              } else if (isCurrent && !block.isCompleted && !canConfirm) {
                showAppToast(context, AppStrings.lessonSelectAnswerFirst);
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    block.isCompleted ? AppColors.success : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark16,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.check,
                color: block.isCompleted
                    ? Colors.white
                    : AppColors.disabled,
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfirmCheck extends StatelessWidget {
  final bool isCompleted;
  final bool isEvaluated;

  const _ConfirmCheck({required this.isCompleted, required this.isEvaluated});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color iconColor;
    if (isCompleted) {
      bgColor = AppColors.success;
      iconColor = Colors.white;
    } else if (isEvaluated) {
      bgColor = AppColors.success;
      iconColor = Colors.white;
    } else {
      bgColor = AppColors.surface;
      iconColor = AppColors.disabled;
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Icon(
        Icons.check,
        color: iconColor,
        size: 24,
      ),
    );
  }
}
