import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../core/theme/app_theme.dart';
import '../../core/strings/app_strings.dart';
import '../../core/utils/image_url.dart';
import '../../models/course_model.dart';
import '../../widgets/lesson_image.dart';
import '../../widgets/markdown_latex_widget.dart';
import 'card_container.dart';
import 'network_image.dart';
import '../../widgets/video_embed.dart';

/// Text card for ContentBlock step (markdown / HTML / plain text + optional
/// step image).
class LessonContentTextCard extends StatelessWidget {
  final BlockStep step;
  final Widget actionRow;

  const LessonContentTextCard({
    super.key,
    required this.step,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        step.content?.imageUrl != null || step.content?.imageEmoji != null;

    return LessonCardContainer(
      children: [
        if (step.hasMarkdownContent)
          MarkdownLatexWidget(
            content: step.rawOutputText ?? step.displayText,
            textColor: AppColors.primaryDark,
          )
        else if (step.hasHtmlContent)
          Html(
            data: resolveHtmlImageUrls(step.htmlContent!),
            extensions: lessonHtmlImageExtensions(),
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(15),
                fontWeight: FontWeight.w500,
                color: AppColors.primaryDark88,
                lineHeight: const LineHeight(1.5),
                fontFamily: 'Poppins',
              ),
              'p': Style(margin: Margins.only(bottom: 12)),
              'h3': Style(
                fontSize: FontSize(18),
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
                margin: Margins.only(bottom: 12, top: 8),
              ),
              'strong': Style(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
              'em': Style(fontStyle: FontStyle.italic),
              'ul': Style(margin: Margins.only(bottom: 12)),
              'li': Style(margin: Margins.only(bottom: 6)),
            },
          )
        else
          Text(
            step.displayText,
            style: AppTextStyles.body(
              color: AppColors.primaryDark.withValues(alpha: 0.72),
              height: 1.33,
            ),
          ),
        if (hasImage) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            // BR-5VYB78 — the frame keeps the card width, the picture inside it
            // does not: it is centred and never drawn above 100 % of its own
            // resolution.
            alignment: Alignment.center,
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppDecorations.radiusM,
            ),
            child: ClipRRect(
              borderRadius: AppDecorations.radiusM,
              child: step.content?.imageEmoji != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          step.content!.imageEmoji!,
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    )
                  : LessonNetworkImage(
                      rawUrl: step.content!.imageUrl!,
                      fit: BoxFit.contain,
                      errorWidget: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: AppColors.progressFill,
                        ),
                      ),
                      loadingWidget: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.progressFill,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
        if (step.hasImage) ...[
          const SizedBox(height: 16),
          LessonBlockImage(image: step.image!),
        ],
        const SizedBox(height: 24),
        actionRow,
      ],
    );
  }
}

/// Image card for ContentBlock step.
class LessonContentImageCard extends StatelessWidget {
  final BlockStep step;
  final Widget actionRow;

  const LessonContentImageCard({
    super.key,
    required this.step,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    return LessonCardContainer(
      children: [
        Text(step.displayTitle, style: AppTextStyles.cardTitle()),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppDecorations.radiusM,
          ),
          child: Center(
            child: step.content?.imageEmoji != null
                ? Text(
                    step.content!.imageEmoji!,
                    style: const TextStyle(fontSize: 64),
                  )
                : step.content?.imageUrl != null
                    ? ClipRRect(
                        borderRadius: AppDecorations.radiusM,
                        child: LessonNetworkImage(
                          rawUrl: step.content!.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          errorWidget: Icon(
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
        if (step.displayText.isNotEmpty)
          Text(
            step.displayText,
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

/// Video card for ContentBlock step.
class LessonContentVideoCard extends StatelessWidget {
  final BlockStep step;
  final Widget actionRow;

  const LessonContentVideoCard({
    super.key,
    required this.step,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    String? videoUrl;
    if (step.video != null) {
      videoUrl = step.video!.url;
    } else if (step.content?.videoUrl != null) {
      videoUrl = step.content!.videoUrl;
    }

    return LessonCardContainer(
      children: [
        Text(step.displayTitle, style: AppTextStyles.cardTitle()),
        const SizedBox(height: 16),
        if (videoUrl != null)
          AppVideoEmbed(videoUrl: videoUrl)
        else
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.videoDark,
              borderRadius: AppDecorations.radiusM,
            ),
            child: const Center(
              child: Icon(Icons.videocam, size: 64, color: Colors.white54),
            ),
          ),
        if (step.content?.videoDuration != null) ...[
          const SizedBox(height: 8),
          Text(
            step.content!.videoDuration!,
            style: AppTextStyles.captionBold(color: AppColors.primaryDark88),
          ),
        ],
        const SizedBox(height: 16),
        if (step.displayText.isNotEmpty)
          Text(
            step.displayText,
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

/// Key-concepts card for ContentBlock step (yellow callout container).
class LessonContentKeyConceptsCard extends StatelessWidget {
  final BlockStep step;
  final Widget actionRow;

  const LessonContentKeyConceptsCard({
    super.key,
    required this.step,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    final keyConcepts = step.content?.keyConcepts ?? [];

    return LessonCardContainer(
      children: [
        Text(step.displayTitle, style: AppTextStyles.cardTitle()),
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
              ...keyConcepts.asMap().entries.map((entry) {
                final concept = entry.value;
                final isLast = entry.key == keyConcepts.length - 1;
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

/// Quiz card for ContentBlock step. Supports both multiple-choice and
/// free-text (exact_match / free_text) evaluation.
class LessonContentQuizCard extends StatelessWidget {
  final ContentBlock block;
  final BlockStep? displayStep;
  final BlockStep evaluationStep;
  final TextEditingController? freetextController;
  final Widget actionRow;
  final ValueChanged<String?> onFreetextChanged;
  final ValueChanged<String> onOptionSelected;

  const LessonContentQuizCard({
    super.key,
    required this.block,
    required this.displayStep,
    required this.evaluationStep,
    required this.freetextController,
    required this.actionRow,
    required this.onFreetextChanged,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedId = block.selectedOptionId;
    final config = evaluationStep.evaluationConfig;
    final options = config?.options ?? [];
    final isFreetextQuiz = options.isEmpty &&
        (config?.type == 'exact_match' || config?.type == 'free_text');

    return LessonCardContainer(
      children: [
        Row(
          children: [
            Text(
              displayStep?.displayTitle ?? AppStrings.lessonQuestionLabel,
              style: AppTextStyles.cardTitle(),
            ),
            const SizedBox(width: 8),
            const Text('✨', style: TextStyle(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          config?.question ?? displayStep?.displayText ?? '',
          style: AppTextStyles.body(
            color: AppColors.primaryDark.withValues(alpha: 0.72),
            height: 1.33,
          ),
        ),
        const SizedBox(height: 20),
        if (isFreetextQuiz) ...[
          TextField(
            controller: freetextController,
            enabled: !block.isCompleted,
            decoration: InputDecoration(
              hintText: AppStrings.lessonWriteAnswer,
              hintStyle: AppTextStyles.body(
                color: AppColors.primaryDark.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: block.isCompleted
                  ? AppColors.background
                  : AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: AppDecorations.radiusS,
                borderSide: BorderSide(
                  color: block.isCompleted
                      ? AppColors.success
                      : AppColors.surfaceLight,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppDecorations.radiusS,
                borderSide: BorderSide(
                  color: selectedId != null
                      ? AppColors.success
                      : AppColors.surfaceLight,
                  width: selectedId != null ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppDecorations.radiusS,
                borderSide: BorderSide(
                  color: AppColors.progressFill,
                  width: 2,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: AppTextStyles.body(),
            onChanged: (value) =>
                onFreetextChanged(value.isNotEmpty ? value : null),
          ),
          const SizedBox(height: 12),
        ],
        if (!isFreetextQuiz)
          ...options.map((option) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
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
                              color: isSelected
                                  ? borderColor
                                  : Colors.transparent,
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
                              option.label,
                              style: AppTextStyles.body(color: textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showResult && option.feedback != null)
                    Container(
                      margin: const EdgeInsets.only(
                          top: 8, left: 8, right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.successBg
                            : AppColors.orangeBg,
                        borderRadius: AppDecorations.radiusXS,
                        border: Border.all(
                          color: isCorrect
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCorrect
                                ? Icons.check_circle
                                : Icons.info_outline,
                            size: 18,
                            color: isCorrect
                                ? AppColors.success
                                : AppColors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option.feedback!,
                              style: AppTextStyles.meta(
                                  color: AppColors.primaryDark88),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),
        actionRow,
      ],
    );
  }
}
