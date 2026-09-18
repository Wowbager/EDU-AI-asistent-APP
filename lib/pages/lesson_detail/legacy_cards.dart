import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_url.dart';
import '../../models/course_model.dart';
import '../../widgets/network_image_with_fallback.dart';
import 'card_container.dart';

/// Legacy text block card (LessonBlock format).
class LessonLegacyTextCard extends StatelessWidget {
  final LessonBlock block;
  final Widget actionRow;

  const LessonLegacyTextCard({
    super.key,
    required this.block,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    return LessonCardContainer(
      children: [
        Text(block.title, style: AppTextStyles.cardTitle()),
        const SizedBox(height: 16),
        Text(
          block.content,
          style: AppTextStyles.body(
            color: AppColors.primaryDark.withValues(alpha: 0.72),
            height: 1.33,
          ),
        ),
        const SizedBox(height: 24),
        actionRow,
      ],
    );
  }
}

/// Legacy image block card.
class LessonLegacyImageCard extends StatelessWidget {
  final LessonBlock block;
  final Widget actionRow;

  const LessonLegacyImageCard({
    super.key,
    required this.block,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    return LessonCardContainer(
      children: [
        Text(block.title, style: AppTextStyles.cardTitle()),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppDecorations.radiusM,
          ),
          child: Center(
            child: block.imageEmoji != null
                ? Text(
                    block.imageEmoji!,
                    style: const TextStyle(fontSize: 64),
                  )
                : block.imageUrl != null
                    ? ClipRRect(
                        borderRadius: AppDecorations.radiusM,
                        // Direct URL first, proxy only as a fallback — see
                        // `NetworkImageWithFallback`. Passed the raw
                        // `block.imageUrl`, not pre-resolved, since the
                        // widget only reaches for `resolveImageUrl` itself
                        // on the second attempt.
                        child: NetworkImageWithFallback(
                          url: block.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          errorBuilder: (context, error, stack) => Icon(
                            Icons.image,
                            size: 64,
                            color: AppColors.progressFill,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.image,
                        size: 64,
                        color: AppColors.progressFill,
                      ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          block.content,
          style: AppTextStyles.body(
            color: AppColors.primaryDark.withValues(alpha: 0.72),
            height: 1.33,
          ),
        ),
        const SizedBox(height: 24),
        actionRow,
      ],
    );
  }
}

/// Legacy video block card. Shows a thumbnail with play overlay; tap is a
/// no-op placeholder (legacy format).
class LessonLegacyVideoCard extends StatelessWidget {
  final LessonBlock block;
  final Widget actionRow;

  const LessonLegacyVideoCard({
    super.key,
    required this.block,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    return LessonCardContainer(
      children: [
        Text(block.title, style: AppTextStyles.cardTitle()),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {},
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.videoDark,
                  borderRadius: AppDecorations.radiusM,
                  // Left on the single proxied attempt rather than moved onto
                  // `NetworkImageWithFallback`: this is a `DecorationImage`
                  // built from a plain `ImageProvider`, not an `Image`/
                  // `SvgPicture` widget with an `errorBuilder` to hook a
                  // retry into, and it's a video thumbnail, not the
                  // step/solution content the direct-first fix targets — on
                  // failure it just leaves the dark placeholder background
                  // showing under the play button, not a broken-image icon
                  // blocking the lesson.
                  image: block.videoThumbnail != null
                      ? DecorationImage(
                          image: NetworkImage(
                              resolveImageUrl(block.videoThumbnail!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: block.videoThumbnail == null
                    ? const Center(
                        child: Icon(
                          Icons.videocam,
                          size: 64,
                          color: Colors.white54,
                        ),
                      )
                    : null,
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: AppColors.primaryDark,
                      size: 32,
                    ),
                  ),
                ),
              ),
              if (block.videoDuration != null)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      block.videoDuration!,
                      style: AppTextStyles.captionBold(color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppDecorations.radiusXS,
                  ),
                  child: Icon(
                    Icons.videocam,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          block.content,
          style: AppTextStyles.body(
            color: AppColors.primaryDark.withValues(alpha: 0.72),
            height: 1.33,
          ),
        ),
        const SizedBox(height: 24),
        actionRow,
      ],
    );
  }
}

/// Legacy key-concepts block card with yellow callout container.
class LessonLegacyKeyConceptsCard extends StatelessWidget {
  final LessonBlock block;
  final Widget actionRow;

  const LessonLegacyKeyConceptsCard({
    super.key,
    required this.block,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    return LessonCardContainer(
      children: [
        Text(block.title, style: AppTextStyles.cardTitle()),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.hintBg,
            borderRadius: AppDecorations.radiusM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.keyConcepts != null)
                ...block.keyConcepts!.asMap().entries.map((entry) {
                  final concept = entry.value;
                  final isLast = entry.key == block.keyConcepts!.length - 1;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✦  ',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${concept.term}: ',
                                    style: AppTextStyles.bodyBold(),
                                  ),
                                  TextSpan(
                                    text: concept.definition,
                                    style: AppTextStyles.body(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isLast) ...[
                        const SizedBox(height: 12),
                        Divider(
                          color: AppColors.primaryDark.withValues(alpha: 0.1),
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        actionRow,
      ],
    );
  }
}

/// Legacy multiple-choice quiz block card.
class LessonLegacyQuizCard extends StatelessWidget {
  final LessonBlock block;
  final Widget actionRow;
  final ValueChanged<String> onOptionSelected;

  const LessonLegacyQuizCard({
    super.key,
    required this.block,
    required this.actionRow,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedId = block.selectedOptionId;

    return LessonCardContainer(
      children: [
        Row(
          children: [
            Text(block.title, style: AppTextStyles.cardTitle()),
            const SizedBox(width: 8),
            const Text('✨', style: TextStyle(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          block.quizQuestion ?? block.content,
          style: AppTextStyles.body(
            color: AppColors.primaryDark.withValues(alpha: 0.72),
            height: 1.33,
          ),
        ),
        const SizedBox(height: 20),
        if (block.quizOptions != null)
          ...block.quizOptions!.map((option) {
            final isSelected = selectedId == option.id;
            final isCorrect = option.isCorrect;
            final showResult = block.isCompleted && isSelected;

            Color borderColor = AppColors.surfaceLight;
            Color bgColor = AppColors.surface;
            Color textColor = AppColors.primaryDark;

            if (isSelected && !block.isCompleted) {
              borderColor = AppColors.success;
              bgColor = AppColors.successBg;
            } else if (showResult) {
              if (isCorrect) {
                borderColor = AppColors.success;
                bgColor = AppColors.successBg;
              } else {
                borderColor = AppColors.orange;
                bgColor = AppColors.orangeBg;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: block.isCompleted
                    ? null
                    : () => onOptionSelected(option.id),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppDecorations.radiusS,
                    border: Border.all(
                      color: borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isSelected ? borderColor : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? borderColor
                                : AppColors.surfaceLight,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.text,
                          style: AppTextStyles.body(color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        actionRow,
      ],
    );
  }
}
