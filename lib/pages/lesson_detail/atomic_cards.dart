import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../core/theme/app_theme.dart';
import '../../core/strings/app_strings.dart';
import '../../core/utils/content_format.dart';
import '../../core/utils/image_url.dart';
import '../../core/evaluation/ai_answer_evaluator.dart';
import '../../models/course_model.dart';
import '../../models/open_answer_feedback.dart';
import '../../widgets/answer_photo_picker.dart';
import '../../widgets/lesson_image.dart';
import '../../widgets/markdown_latex_widget.dart';
import '../../widgets/open_answer_feedback_card.dart';
import 'card_container.dart';
import 'network_image.dart';
import '../../widgets/video_embed.dart';

bool _looksMarkdown(String content) => looksLikeMarkdown(content);

bool _looksHtml(String content) => looksLikeHtml(content);

/// Display card for atomic format blocks (v2). Shows formatted text content
/// plus optional video/image.
class LessonAtomicDisplayCard extends StatelessWidget {
  final ContentBlock block;
  final Widget actionRow;

  const LessonAtomicDisplayCard({
    super.key,
    required this.block,
    required this.actionRow,
  });

  @override
  Widget build(BuildContext context) {
    final content = block.displayContent;
    final hasMarkdown = _looksMarkdown(content);
    final hasHtml = _looksHtml(content);

    return LessonCardContainer(
      children: [
        if (hasMarkdown)
          MarkdownLatexWidget(
            content: content,
            textColor: AppColors.primaryDark,
          )
        else if (hasHtml)
          Html(
            data: resolveHtmlImageUrls(content),
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
            content,
            style: AppTextStyles.body(
              color: AppColors.primaryDark.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
        if (block.hasVideo) ...[
          const SizedBox(height: 16),
          AppVideoEmbed(videoUrl: block.videoUrl!),
        ],
        if (block.hasImage) ...[
          const SizedBox(height: 16),
          LessonBlockImage(image: block.blockImage!),
        ],
        const SizedBox(height: 24),
        actionRow,
      ],
    );
  }
}

/// Question card for atomic format blocks. Supports both open-text input
/// (via [openInput]) and multiple-choice options.
class LessonAtomicQuestionCard extends StatelessWidget {
  final ContentBlock block;
  final AtomicQuestion? question;
  final bool isAnswered;
  final bool evaluate;
  final Widget? openInput;
  final Widget actionRow;
  final ValueChanged<String> onOptionSelected;

  const LessonAtomicQuestionCard({
    super.key,
    required this.block,
    required this.question,
    required this.isAnswered,
    required this.evaluate,
    required this.openInput,
    required this.actionRow,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final content = block.displayContent;
    final hasMarkdown = _looksMarkdown(content);
    final hasHtml = _looksHtml(content);

    return LessonCardContainer(
      children: [
        if (hasMarkdown)
          MarkdownLatexWidget(
            content: content,
            textColor: AppColors.primaryDark,
          )
        else if (hasHtml)
          Html(
            data: resolveHtmlImageUrls(content),
            extensions: lessonHtmlImageExtensions(),
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(16),
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
                lineHeight: const LineHeight(1.4),
                fontFamily: 'Poppins',
              ),
            },
          )
        else
          Text(content, style: AppTextStyles.buttonLarge()),
        const SizedBox(height: 16),
        if (openInput != null)
          openInput!
        else if (question != null && question!.options.isNotEmpty) ...[
          ...question!.options.map((option) {
            final isSelected = block.selectedOptionId == option.id;
            final isCorrect = option.isCorrect;
            final showResult = isAnswered || block.isCompleted;
            final isLocked = showResult || block.isCompleted;

            Color bgColor = AppColors.surface;
            Color borderColor = AppColors.primaryDark16;

            if (showResult && isSelected && evaluate) {
              bgColor = isCorrect
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1);
              borderColor =
                  isCorrect ? AppColors.success : AppColors.error;
            } else if (showResult && isCorrect && evaluate) {
              bgColor = AppColors.success.withValues(alpha: 0.05);
              borderColor = AppColors.success.withValues(alpha: 0.5);
            } else if (isSelected) {
              bgColor = AppColors.primary.withValues(alpha: 0.1);
              borderColor = AppColors.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: isLocked ? null : () => onOptionSelected(option.id),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppDecorations.radiusS,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Text(
                    option.label,
                    style: isSelected
                        ? AppTextStyles.body(color: AppColors.primaryDark)
                            .copyWith(fontWeight: FontWeight.w600)
                        : AppTextStyles.body(),
                  ),
                ),
              ),
            );
          }),
          if ((isAnswered || block.isCompleted) &&
              evaluate &&
              question!.solution != null &&
              question!.showSolution) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppDecorations.radiusS,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 ${AppStrings.lessonExplanation}',
                    style: AppTextStyles.actionSmall(),
                  ),
                  const SizedBox(height: 4),
                  // Multiple-choice was the last solution site still hardcoded
                  // to plain Text, so its citations, lists and formulas showed
                  // up as raw markdown — the open-answer card below already
                  // renders the same field through the markdown widget.
                  if (_looksMarkdown(question!.solution!))
                    MarkdownLatexWidget(
                      content: question!.solution!,
                      textColor: AppColors.primaryDark80,
                    )
                  else
                    Text(
                      question!.solution!,
                      style: AppTextStyles.bodySmall(
                          color: AppColors.primaryDark80),
                    ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        actionRow,
      ],
    );
  }
}

/// Open-text question input with check button + result/solution feedback.
class LessonAtomicOpenQuestionInput extends StatelessWidget {
  final TextEditingController controller;
  final AtomicQuestion question;
  final String userAnswer;
  final bool isAnswered;
  final bool isCorrect;
  final bool showEvaluation;
  final VoidCallback onChanged;
  final VoidCallback onCheckAnswer;

  /// Flat feedback string. Only used for responses that predate the three-part
  /// contract (BR-FFVVYR); [feedback] is what normally renders.
  final String? aiFeedback;

  /// True while the answer is out for AI evaluation — the check button spins
  /// and cannot be tapped again.
  final bool isEvaluating;

  // ─── Formative feedback + photo answers (BR-P745Q8) ───────────────────────

  /// The three-part feedback the student is shown.
  final FormativeFeedback? feedback;

  final PickedAnswerPhoto? pickedPhoto;
  final String? uploadedPhotoName;
  final bool isUploadingPhoto;

  /// The evaluation asked for a better picture.
  final bool photoUnreadable;

  /// Set when evaluation produced nothing — the student sees a retry rather
  /// than a verdict, and the question stays open.
  final AiEvaluationFailure? evaluationFailure;

  final void Function(PickedAnswerPhoto photo)? onPhotoPicked;
  final VoidCallback? onPhotoRemoved;
  final VoidCallback? onRetryEvaluation;

  const LessonAtomicOpenQuestionInput({
    super.key,
    required this.controller,
    required this.question,
    required this.userAnswer,
    required this.isAnswered,
    required this.isCorrect,
    required this.showEvaluation,
    required this.onChanged,
    required this.onCheckAnswer,
    this.aiFeedback,
    this.isEvaluating = false,
    this.feedback,
    this.pickedPhoto,
    this.uploadedPhotoName,
    this.isUploadingPhoto = false,
    this.photoUnreadable = false,
    this.evaluationFailure,
    this.onPhotoPicked,
    this.onPhotoRemoved,
    this.onRetryEvaluation,
  });

  /// AI-evaluated open questions are formative: no verdict, no colour-coding,
  /// and never the expected answer.
  bool get _formative => question.aiEvaluation;

  /// The authored explanation when it belongs inside the feedback card, null
  /// when it does not (BR-BC3SYR).
  ///
  /// Only the three-part card takes it. The legacy flat-feedback panel below
  /// is a different widget and keeps the standalone explanation block it has
  /// always been shown with.
  String? get _revealedSolution {
    if (!_formative || feedback == null) return null;
    if (!question.showSolution) return null;
    final solution = question.solution;
    if (solution == null || solution.trim().isEmpty) return null;
    return solution;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: !isAnswered,
          style: AppTextStyles.subtitle(),
          textAlign: _formative ? TextAlign.start : TextAlign.center,
          maxLines: _formative ? 5 : 1,
          minLines: _formative ? 3 : 1,
          keyboardType:
              _formative ? TextInputType.multiline : TextInputType.text,
          decoration: InputDecoration(
            hintText: AppStrings.lessonWriteAnswer,
            hintStyle: AppTextStyles.bodyLarge(
                color: AppColors.primaryDark.withValues(alpha: 0.4)),
            filled: true,
            fillColor: isAnswered && showEvaluation && !_formative
                ? (isCorrect
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1))
                : AppColors.background,
            border: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(
                color: isAnswered && !_formative
                    ? (isCorrect ? AppColors.success : AppColors.error)
                    : AppColors.primaryDark16,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(
                color: AppColors.primaryDark16,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusS,
              borderSide: BorderSide(
                color: showEvaluation && !_formative
                    ? (isCorrect ? AppColors.success : AppColors.error)
                    : AppColors.primaryDark16,
                width: 1.5,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (_) => onChanged(),
          onSubmitted: _formative ? null : (_) => onCheckAnswer(),
        ),

        // Photo attach. Rendered only when the author enabled it — the brief
        // requires the option to be absent, not disabled, when the switch is
        // off.
        if (question.allowPhoto) ...[
          const SizedBox(height: 8),
          AnswerPhotoPicker(
            picked: pickedPhoto,
            uploadedName: uploadedPhotoName,
            isUploading: isUploadingPhoto,
            unreadable: photoUnreadable,
            onPicked: isAnswered ? null : onPhotoPicked,
            onRemoved: isAnswered ? null : onPhotoRemoved,
          ),
        ],

        if (evaluationFailure != null) ...[
          const SizedBox(height: 12),
          OpenAnswerRetryNotice(
            offline: evaluationFailure == AiEvaluationFailure.offline,
            canRetry: evaluationFailure != AiEvaluationFailure.notEvaluable,
            onRetry: onRetryEvaluation,
          ),
        ],

        const SizedBox(height: 12),
        if (!isAnswered &&
            (userAnswer.isNotEmpty || pickedPhoto != null || uploadedPhotoName != null))
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isEvaluating ? null : onCheckAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.radiusS,
                ),
              ),
              child: isEvaluating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      AppStrings.lessonCheckAnswer,
                      style: AppTextStyles.buttonLarge(),
                    ),
            ),
          ),
        if (isAnswered && showEvaluation) ...[
          const SizedBox(height: 12),
          // For a formative question the banner reports status only — never
          // the expected answer, and never a score. It appears because the
          // course asked for evaluation to be visible (quiz_evaluate); the
          // feedback card below still does the teaching.
          if (_formative)
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.info_outline,
                  size: 20,
                  color: isCorrect ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  isCorrect
                      ? AppStrings.lessonCorrect
                      : AppStrings.lessonIncorrect,
                  style: AppTextStyles.labelMedium(
                    color: isCorrect ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppDecorations.radiusS,
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? AppColors.success : AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // A status, never the expected answer — not even with the
                    // solution on (BR-RBUR29). Authors write that field as a
                    // grading key and the editor promises them the student
                    // never sees it; the explanation below does the teaching.
                    child: Text(
                      isCorrect
                          ? AppStrings.lessonCorrect
                          : AppStrings.lessonIncorrect,
                      style: AppTextStyles.labelMedium(
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // AI feedback only on an `ai_evaluation` question (BR-N26ACB). Every
          // open answer is graded by AI, but an exact-match question's student
          // gets right/wrong and the explanation, not the AI's words.
          if (_formative && feedback != null) ...[
            const SizedBox(height: 12),
            // On a formative question the explanation is a section of this
            // card, not a panel below it (BR-BC3SYR) — see the standalone
            // block further down, which now skips those.
            // No `retryPending`: this card locks its field once the answer is
            // in and offers no way back, so "what to do next" would be advice
            // the student cannot act on (BR-Y3A5M8).
            OpenAnswerFeedbackCard(
              feedback: feedback!,
              solution: _revealedSolution,
            ),
          ] else if (_formative &&
              aiFeedback != null &&
              aiFeedback!.trim().isNotEmpty) ...[
            // Feedback from a server that predates the three-part contract.
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppDecorations.radiusS,
                border: Border.all(color: AppColors.primaryDark16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.stepAiFeedback,
                        style: AppTextStyles.actionSmall(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aiFeedback!,
                    style: AppTextStyles.meta(color: AppColors.primaryDark80),
                  ),
                ],
              ),
            ),
          ],
          // Skipped when the feedback card above already carries it.
          if (question.solution != null &&
              question.showSolution &&
              _revealedSolution == null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppDecorations.radiusS,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 ${AppStrings.lessonExplanation}',
                    style: AppTextStyles.actionSmall(),
                  ),
                  const SizedBox(height: 4),
                  if (_looksMarkdown(question.solution!))
                    MarkdownLatexWidget(
                      content: question.solution!,
                      textColor: AppColors.primaryDark80,
                    )
                  else
                    Text(
                      question.solution!,
                      style: AppTextStyles.meta(
                          color: AppColors.primaryDark80),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
