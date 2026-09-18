// Stateless widget that renders ONE step from a block.
//
// Handles text, image, video, and question step types.
// All answer state is managed externally (by BlockStepEngine)
// and passed in via answerState / callbacks.

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:video_player/video_player.dart';
import '../core/utils/image_url.dart';
import '../core/utils/content_embeds.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/block_model.dart';
import '../models/step_navigation.dart';
import '../preview/preview_mode.dart';
import 'markdown_latex_widget.dart';
import 'network_image_with_fallback.dart';

/// Renders one step's content.
///
/// Inside the editor's preview (see `preview/preview_mode.dart`) the passive leaves
/// — text, media, the solution, an option's feedback — are wrapped in a
/// `PreviewTarget`, so clicking one takes the author to the field that produced it.
/// The interactive controls are deliberately left alone: clicking an answer in the
/// preview answers the question, which is what "try it" has to mean.
class StepContentRenderer extends StatelessWidget {
  final BlockStep step;
  final StepAnswerState? answerState;
  final ExportMode exportMode;
  final bool showSolution;  // Whether we're in SHOWING_SOLUTION state
  final bool hideResults;   // When true, suppress correct/incorrect highlighting on option cards
  final bool hideFeedback;  // When true, suppress feedback banners and solution text
  final bool revealCorrectAnswer; // When false, mark the wrong pick but don't reveal the correct one (AGAIN retry)

  // Callbacks
  final void Function(String optionId)? onOptionSelected;
  final void Function(Set<String> optionIds)? onMultipleOptionsSelected;
  final void Function(String text)? onTextAnswerChanged;
  final void Function()? onTextAnswerSubmitted;

  // Video controller provider (to reuse controllers from parent)
  final VideoPlayerController? Function(String url)? getVideoController;

  // Audio controller provider (reuses VideoPlayerController for MP3/WAV)
  final VideoPlayerController? Function(String url)? getAudioController;

  const StepContentRenderer({
    super.key,
    required this.step,
    this.answerState,
    this.exportMode = ExportMode.courseV2,
    this.showSolution = false,
    this.hideResults = false,
    this.hideFeedback = false,
    this.revealCorrectAnswer = true,
    this.onOptionSelected,
    this.onMultipleOptionsSelected,
    this.onTextAnswerChanged,
    this.onTextAnswerSubmitted,
    this.getVideoController,
    this.getAudioController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildStepContent(context),
    );
  }

  List<Widget> _buildStepContent(BuildContext context) {
    switch (step.type) {
      case StepType.text:
      case StepType.display:
      case StepType.displayTask:
        return _buildTextStep();
      case StepType.image:
        return _buildImageStep();
      case StepType.video:
        return _buildVideoStep();
      case StepType.audio:
        return _buildAudioStep();
      case StepType.question:
      case StepType.evaluation:
        return _buildQuestionStep(context);
      case StepType.hint:
      case StepType.displaySolution:
        return _buildTextStep(); // Render same as text
    }
  }

  // ─── Text Step ───────────────────────────────────────────

  List<Widget> _buildTextStep() {
    final widgets = <Widget>[];

    // Image above text (position "above" or default)
    if (step.hasImage && (step.position == null || step.position == 'above')) {
      widgets.add(_buildStepImage(step.image!));
      widgets.add(const SizedBox(height: 12));
    }

    // Video above text
    if (step.hasVideo && (step.position == null || step.position == 'above')) {
      widgets.add(_buildStepVideo());
      widgets.add(const SizedBox(height: 12));
    }

    // Text content
    final text = step.displayText;
    if (text.isNotEmpty) {
      final isMarkdown = step.hasMarkdownContent || _looksLikeMarkdown(text);
      widgets.add(_buildRichContent(text, step.htmlContent, isMarkdown));
    }

    // Image below text
    if (step.hasImage && step.position == 'below') {
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildStepImage(step.image!));
    }

    // Video below text
    if (step.hasVideo && step.position == 'below') {
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildStepVideo());
    }

    return widgets;
  }

  // ─── Image Step ──────────────────────────────────────────

  List<Widget> _buildImageStep() {
    final widgets = <Widget>[];

    if (step.hasImage) {
      widgets.add(_buildStepImage(step.image!));
    }
    // Alt text / description below
    final text = step.displayText;
    if (text.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(Text(
        text,
        style: AppTextStyles.body(color: AppColors.primaryDark88),
      ));
    }

    return widgets;
  }

  // ─── Video Step ──────────────────────────────────────────

  List<Widget> _buildVideoStep() {
    final widgets = <Widget>[];

    widgets.add(_buildStepVideo());

    // Description below
    final text = step.displayText;
    if (text.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(Text(
        text,
        style: AppTextStyles.body(color: AppColors.primaryDark88),
      ));
    }

    return widgets;
  }

  // ─── Question Step ───────────────────────────────────────

  List<Widget> _buildQuestionStep(BuildContext context) {
    final config = step.evaluationConfig;
    if (config == null) return _buildTextStep(); // fallback

    final widgets = <Widget>[];
    final isAnswered = answerState?.isAnswered ?? false;

    // Question text
    final questionText = config.question ?? step.displayText;
    if (questionText.isNotEmpty) {
      widgets.add(_buildRichContent(questionText, null, _looksLikeMarkdown(questionText)));
      widgets.add(const SizedBox(height: 16));
    }

    // Question image if present
    if (step.hasImage) {
      widgets.add(_buildStepImage(step.image!));
      widgets.add(const SizedBox(height: 16));
    }

    // Render based on question type
    final qType = config.type;

    if (qType == 'true_false') {
      widgets.addAll(_buildTrueFalseButtons(context, config, isAnswered));
    } else if (qType == 'numeric') {
      widgets.addAll(_buildNumericQuestion(config, isAnswered));
    } else if (qType == 'open') {
      widgets.addAll(_buildOpenQuestion(config, isAnswered));
    } else if (config.allowMultiple) {
      // allow_multiple: checkbox-style multi-select (takes priority over show_answers)
      widgets.addAll(_buildCheckboxOptions(context, config, isAnswered));
    } else {
      // Default: radio-style single select
      // (show_answers only controls whether correct answer is revealed after answering)
      widgets.addAll(_buildRadioOptions(context, config, isAnswered));
    }

    // Feedback for selected option(s)
    if (isAnswered && !hideFeedback) {
      if (config.allowMultiple) {
        // Multi-select: show feedback for each selected option
        final selectedIds = answerState?.selectedOptionIds ?? {};
        for (final opt in config.options) {
          if (selectedIds.contains(opt.id) && opt.feedback != null) {
            widgets.add(const SizedBox(height: 12));
            widgets.add(_buildFeedbackBanner(opt));
          }
        }
      } else {
        final selectedOpt = _findSelectedOption(config);
        if (selectedOpt != null && selectedOpt.feedback != null) {
          widgets.add(const SizedBox(height: 12));
          widgets.add(_buildFeedbackBanner(selectedOpt));
        }
      }
    }

    // Solution (unless show_solution=false or feedback is hidden)
    if (showSolution && config.showSolution && !hideFeedback) {
      if (config.solution != null && config.solution!.isNotEmpty) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(_buildSolutionBanner(config));
      }
    }

    return widgets;
  }

  // ─── Radio Option Cards (single select) ──────────────────

  /// What tapping an answer does.
  ///
  /// Normally it answers. In the editor's expanded preview the author is reading
  /// the card, not taking it, so the tap reports where that option is authored and
  /// the editor focuses it. Outside preview mode `interactive` is true and this is
  /// exactly the callback it always was.
  VoidCallback? _onOptionTap(
    BuildContext context,
    String optionId,
    bool isAnswered,
    VoidCallback answer,
  ) {
    final mode = PreviewMode.of(context);
    if (mode.enabled && !mode.interactive) {
      return () => mode.onRefTapped?.call(
            mode.refFor(stepId: step.stepId, optionId: optionId, field: 'text'),
          );
    }
    return isAnswered ? null : answer;
  }

  List<Widget> _buildRadioOptions(BuildContext context, EvaluationConfig config, bool isAnswered) {
    return config.options.map((option) {
      final isSelected = answerState?.selectedOptionId == option.id;
      final isCorrect = option.isCorrect;

      Color bgColor = AppColors.surface;
      Color borderColor = AppColors.primaryDark16;

      if (isAnswered && config.showAnswers && !hideResults) {
        if (isSelected) {
          bgColor = isCorrect
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.error.withValues(alpha: 0.1);
          borderColor = isCorrect ? AppColors.success : AppColors.error;
        } else if (isCorrect && revealCorrectAnswer) {
          // Highlight correct answer too
          bgColor = AppColors.success.withValues(alpha: 0.05);
          borderColor = AppColors.success.withValues(alpha: 0.5);
        }
      } else if (isAnswered && (!config.showAnswers || hideResults)) {
        if (isSelected) {
          bgColor = AppColors.primary.withValues(alpha: 0.1);
          borderColor = AppColors.primary;
        }
      } else if (isSelected) {
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        borderColor = AppColors.primary;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onOptionTap(
            context,
            option.id,
            isAnswered,
            () => onOptionSelected?.call(option.id),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppDecorations.radiusS,
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                _buildRadioIndicator(isSelected, isAnswered, isCorrect, config.showAnswers),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionText(
                    option.text,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRadioIndicator(bool isSelected, bool isAnswered, bool isCorrect, bool showAnswers) {
    if (isAnswered && isSelected && showAnswers && !hideResults) {
      return Icon(
        isCorrect ? Icons.check_circle : Icons.cancel,
        color: isCorrect ? AppColors.success : AppColors.error,
        size: 24,
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  // ─── Checkbox Option Cards (multi select) ─────────────────

  List<Widget> _buildCheckboxOptions(BuildContext context, EvaluationConfig config, bool isAnswered) {
    final selectedIds = answerState?.selectedOptionIds ?? {};

    return config.options.map((option) {
      final isSelected = selectedIds.contains(option.id);
      final isCorrect = option.isCorrect;

      Color bgColor = AppColors.surface;
      Color borderColor = AppColors.primaryDark16;

      if (isAnswered && !hideResults) {
        if (isSelected) {
          bgColor = isCorrect
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.error.withValues(alpha: 0.1);
          borderColor = isCorrect ? AppColors.success : AppColors.error;
        }
      } else if (isSelected) {
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        borderColor = AppColors.primary;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onOptionTap(context, option.id, isAnswered, () {
            final newSet = Set<String>.from(selectedIds);
            if (isSelected) {
              newSet.remove(option.id);
            } else {
              newSet.add(option.id);
            }
            onMultipleOptionsSelected?.call(newSet);
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppDecorations.radiusS,
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionText(option.text),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // ─── True/False Buttons ──────────────────────────────────

  List<Widget> _buildTrueFalseButtons(BuildContext context, EvaluationConfig config, bool isAnswered) {
    return [
      Row(
        children: config.options.map((option) {
          final isSelected = answerState?.selectedOptionId == option.id;
          final isCorrect = option.isCorrect;

          Color bgColor = AppColors.surface;
          Color borderColor = AppColors.primaryDark16;

          if (isAnswered && isSelected && !hideResults) {
            bgColor = isCorrect
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1);
            borderColor = isCorrect ? AppColors.success : AppColors.error;
          } else if (isSelected) {
            bgColor = AppColors.primary.withValues(alpha: 0.1);
            borderColor = AppColors.primary;
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onOptionTap(
                  context,
                  option.id,
                  isAnswered,
                  () => onOptionSelected?.call(option.id),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppDecorations.radiusM,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Center(
                    child: _buildOptionText(
                      option.text,
                      color: isSelected ? AppColors.primaryDark : AppColors.primaryDark88,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  // ─── Open Question (free text) ────────────────────────────

  List<Widget> _buildOpenQuestion(EvaluationConfig config, bool isAnswered) {
    final textAnswer = answerState?.textAnswer ?? '';
    final isCorrect = answerState?.isCorrect ?? false;

    return [
      TextField(
        controller: TextEditingController(text: textAnswer)
          ..selection = TextSelection.collapsed(offset: textAnswer.length),
        enabled: !isAnswered,
        style: AppTextStyles.subtitle(),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: AppStrings.stepWriteAnswer,
          hintStyle: AppTextStyles.bodyLarge(color: AppColors.primaryDark.withValues(alpha: 0.4)),
          filled: true,
          fillColor: isAnswered && !hideResults
              ? (isCorrect
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1))
              : AppColors.background,
          border: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(color: AppColors.primaryDark16, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(color: AppColors.primaryDark16, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(
              color: hideResults ? AppColors.primaryDark16 : (isCorrect ? AppColors.success : AppColors.error),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (value) => onTextAnswerChanged?.call(value),
        onSubmitted: (_) => onTextAnswerSubmitted?.call(),
      ),
      if (isAnswered && !isCorrect && !hideResults && revealCorrectAnswer && config.correctAnswer != null) ...[
        const SizedBox(height: 12),
        Text(
          AppStrings.stepCorrectAnswer(config.correctAnswer!),
          style: AppTextStyles.actionSmall(color: AppColors.success),
        ),
      ],
    ];
  }

  // ─── Feedback Banner ─────────────────────────────────────

  Widget _buildFeedbackBanner(EvaluationOption option) {
    return PreviewTarget(
      stepId: step.stepId,
      optionId: option.id,
      field: 'feedback',
      child: _buildFeedbackBannerBody(option),
    );
  }

  Widget _buildFeedbackBannerBody(EvaluationOption option) {
    final isCorrect = option.isCorrect;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.successBg
            : AppColors.orangeBg,
        borderRadius: AppDecorations.radiusS,
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: isCorrect ? AppColors.success : AppColors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _looksLikeMarkdown(option.feedback!)
                    ? MarkdownLatexWidget(
                        content: option.feedback!,
                        textColor: AppColors.primaryDark88,
                      )
                    : Text(
                        option.feedback!,
                        style: AppTextStyles.meta(color: AppColors.primaryDark88),
                      ),
              ),
            ],
          ),
          if (option.feedbackImage != null) ...[
            const SizedBox(height: 8),
            _buildStepImage(option.feedbackImage!),
          ],
        ],
      ),
    );
  }

  // ─── Solution Banner ─────────────────────────────────────

  Widget _buildSolutionBanner(EvaluationConfig config) {
    return PreviewTarget(
      stepId: step.stepId,
      field: 'question.solution',
      child: _buildSolutionBannerBody(config),
    );
  }

  Widget _buildSolutionBannerBody(EvaluationConfig config) {
    return Container(
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
            AppStrings.stepExplanation,
            style: AppTextStyles.actionSmall(),
          ),
          const SizedBox(height: 4),
          if (_looksLikeMarkdown(config.solution!))
            MarkdownLatexWidget(
              content: config.solution!,
              textColor: AppColors.primaryDark80,
            )
          else
            Text(
              config.solution!,
              style: AppTextStyles.meta(color: AppColors.primaryDark80),
            ),
          if (config.solutionImage != null) ...[
            const SizedBox(height: 8),
            _buildStepImage(config.solutionImage!),
          ],
        ],
      ),
    );
  }

  // ─── Audio Step ─────────────────────────────────────────

  List<Widget> _buildAudioStep() {
    final widgets = <Widget>[];

    if (step.hasAudio) {
      final controller = getAudioController?.call(step.audio!.url);
      if (controller != null) {
        widgets.add(_buildAudioPlayer(controller));
      } else {
        // Fallback placeholder
        widgets.add(Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppDecorations.radiusM,
            border: Border.all(color: AppColors.primaryDark16),
          ),
          child: const Center(
            child: Icon(Icons.audiotrack, size: 48, color: Colors.grey),
          ),
        ));
      }
    }

    // Description below
    final text = step.displayText;
    if (text.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(Text(
        text,
        style: AppTextStyles.body(color: AppColors.primaryDark88),
      ));
    }

    return widgets;
  }

  Widget _buildAudioPlayer(VideoPlayerController controller) {
    final value = controller.value;

    if (value.hasError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppDecorations.radiusM,
          border: Border.all(color: AppColors.primaryDark16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.grey),
            const SizedBox(height: 8),
            Text(AppStrings.stepAudioError,
                style: AppTextStyles.caption(color: AppColors.primaryDark64)),
          ],
        ),
      );
    }

    if (!value.isInitialized) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppDecorations.radiusM,
          border: Border.all(color: AppColors.primaryDark16),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppDecorations.radiusM,
        border: Border.all(color: AppColors.primaryDark16),
      ),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: () {
              value.isPlaying ? controller.pause() : controller.play();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Time label
          Text(
            _formatDuration(position),
            style: AppTextStyles.caption(color: AppColors.primaryDark64),
          ),
          const SizedBox(width: 8),
          // Seek bar
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: AppColors.primaryDark,
                inactiveTrackColor: AppColors.primaryDark16,
                thumbColor: AppColors.primaryDark,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (val) {
                  final newPosition = Duration(
                    milliseconds: (val * duration.inMilliseconds).round(),
                  );
                  controller.seekTo(newPosition);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Duration label
          Text(
            _formatDuration(duration),
            style: AppTextStyles.caption(color: AppColors.primaryDark64),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ─── Numeric Question ──────────────────────────────────

  List<Widget> _buildNumericQuestion(EvaluationConfig config, bool isAnswered) {
    final textAnswer = answerState?.textAnswer ?? '';
    final isCorrect = answerState?.isCorrect ?? false;

    return [
      TextField(
        controller: TextEditingController(text: textAnswer)
          ..selection = TextSelection.collapsed(offset: textAnswer.length),
        enabled: !isAnswered,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTextStyles.subtitle(),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: AppStrings.stepNumericHint,
          hintStyle: AppTextStyles.bodyLarge(color: AppColors.primaryDark.withValues(alpha: 0.4)),
          filled: true,
          fillColor: isAnswered && !hideResults
              ? (isCorrect
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1))
              : AppColors.background,
          border: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(color: AppColors.primaryDark16, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(color: AppColors.primaryDark16, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: AppDecorations.radiusS,
            borderSide: BorderSide(
              color: hideResults ? AppColors.primaryDark16 : (isCorrect ? AppColors.success : AppColors.error),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (value) => onTextAnswerChanged?.call(value),
        onSubmitted: (_) => onTextAnswerSubmitted?.call(),
      ),
      if (!isAnswered && config.tolerance > 0) ...[
        const SizedBox(height: 8),
        Text(
          AppStrings.stepTolerance('${config.tolerance % 1 == 0 ? config.tolerance.toInt() : config.tolerance}'),
          style: AppTextStyles.caption(color: AppColors.primaryDark64),
        ),
      ],
      if (isAnswered && !isCorrect && !hideResults && config.correctNumber != null) ...[
        const SizedBox(height: 12),
        Text(
          AppStrings.stepCorrectNumber('${config.correctNumber! % 1 == 0 ? config.correctNumber!.toInt() : config.correctNumber}'),
          style: AppTextStyles.actionSmall(color: AppColors.success),
        ),
      ],
    ];
  }

  // ─── Shared Helpers ──────────────────────────────────────

  /// Render rich content. Extracts inline <video> embeds first, then renders
  /// the remaining text segments as markdown/HTML in document order.
  Widget _buildRichContent(String text, String? html, bool isMarkdown) {
    return PreviewTarget(
      stepId: step.stepId,
      field: 'content',
      child: _buildRichContentBody(text, html, isMarkdown),
    );
  }

  Widget _buildRichContentBody(String text, String? html, bool isMarkdown) {
    if (hasVideoEmbed(text)) {
      final parts = parseContentEmbeds(text);
      final children = <Widget>[];
      for (final part in parts) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        if (part is VideoPart) {
          children.add(_buildStepVideoUrl(part.url));
        } else if (part is TextPart) {
          // Recompute markdown detection per segment (html not applicable here).
          children.add(_buildTextBody(part.text, null, _looksLikeMarkdown(part.text)));
        }
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }
    return _buildTextBody(text, html, isMarkdown);
  }

  /// Render a single text segment: markdown first, then HTML, then plain text.
  Widget _buildTextBody(String text, String? html, bool isMarkdown) {
    if (isMarkdown) {
      return MarkdownLatexWidget(
        content: text,
        textColor: AppColors.primaryDark,
      );
    }
    // Use explicit html parameter, or detect HTML tags in the text itself
    final htmlData = html ?? (_looksLikeHtml(text) ? text : null);
    if (htmlData != null) {
      return Html(
        data: resolveHtmlImageUrls(htmlData),
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
          'strong': Style(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
          'em': Style(fontStyle: FontStyle.italic),
          'ul': Style(margin: Margins.only(bottom: 12)),
          'li': Style(margin: Margins.only(bottom: 6)),
        },
      );
    }
    return Text(
      text,
      style: AppTextStyles.body(color: AppColors.primaryDark.withValues(alpha: 0.72), height: 1.5),
    );
  }

  Widget _buildStepImage(StepImage image) {
    if (image.url.isEmpty) return const SizedBox.shrink();
    return PreviewTarget(
      stepId: step.stepId,
      field: 'image.url',
      child: _buildStepImageBody(image),
    );
  }

  Widget _buildStepImageBody(StepImage image) {
    // Direct URL first, proxy only as a fallback — see
    // `NetworkImageWithFallback` for why. `image.url` is passed raw (not
    // pre-resolved with `resolveImageUrl`): the widget resolves it itself,
    // only for the second attempt.
    return ClipRRect(
      borderRadius: AppDecorations.radiusM,
      child: NetworkImageWithFallback(
        url: image.url,
        fit: BoxFit.contain,
        width: double.infinity,
        // Matches the SVG branch's previous ConstrainedBox(maxHeight: 240) —
        // an SVG has no intrinsic size, so without a cap it can blow up to
        // fill all available height.
        svgMaxHeight: 240,
        svgPlaceholderBuilder: (_) => Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppDecorations.radiusM,
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryDark24,
            ),
          ),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppDecorations.radiusM,
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.primaryDark24,
              ),
            ),
          );
        },
        errorBuilder: (_, error, ___) {
          return Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppDecorations.radiusM,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                if (image.alt != null)
                  Text(
                    image.alt!,
                    style: AppTextStyles.meta(color: AppColors.primaryDark64),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepVideo() {
    String? videoUrl;
    if (step.video != null) {
      videoUrl = step.video!.url;
    } else if (step.content?.videoUrl != null) {
      videoUrl = step.content!.videoUrl;
    }
    if (videoUrl == null || videoUrl.isEmpty) return const SizedBox.shrink();
    return _buildStepVideoUrl(videoUrl);
  }

  /// Build a video player for an explicit [url] (used by both the dedicated
  /// video step and inline <video> embeds extracted from text content).
  Widget _buildStepVideoUrl(String url) {
    return PreviewTarget(
      stepId: step.stepId,
      field: 'video.url',
      child: _buildStepVideoUrlBody(url),
    );
  }

  Widget _buildStepVideoUrlBody(String url) {
    if (url.isEmpty) return const SizedBox.shrink();

    // Use parent-provided pooled controller if available
    final controller = getVideoController?.call(url);
    if (controller != null) {
      return _buildVideoPlayer(controller);
    }

    // Fallback: show a placeholder
    return ClipRRect(
      borderRadius: AppDecorations.radiusM,
      child: Container(
        width: double.infinity,
        height: 200,
        color: AppColors.videoDark,
        child: const Center(
          child: Icon(Icons.play_circle_outline, size: 56, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(VideoPlayerController controller) {
    final value = controller.value;
    return ClipRRect(
      borderRadius: AppDecorations.radiusM,
      child: Container(
        width: double.infinity,
        height: 200,
        color: AppColors.videoDark,
        child: value.hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 36, color: Colors.white54),
                    const SizedBox(height: 8),
                    Text(AppStrings.stepVideoError,
                        style: AppTextStyles.caption(color: Colors.white54)),
                  ],
                ),
              )
            : !value.isInitialized
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  )
                : GestureDetector(
                    onTap: () {
                      value.isPlaying ? controller.pause() : controller.play();
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        ),
                        if (!value.isPlaying)
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  EvaluationOption? _findSelectedOption(EvaluationConfig config) {
    final selectedId = answerState?.selectedOptionId;
    if (selectedId == null) return null;
    try {
      return config.options.firstWhere((o) => o.id == selectedId);
    } catch (_) {
      return null;
    }
  }

  /// Render option text with markdown/LaTeX support when needed.
  /// Non-selectable so the wrapping GestureDetector receives taps over LaTeX
  /// regions instead of SelectableText capturing them.
  Widget _buildOptionText(String text, {FontWeight? fontWeight, Color? color}) {
    if (_looksLikeMarkdown(text)) {
      return MarkdownLatexWidget(
        content: text,
        textColor: color ?? AppColors.primaryDark,
        selectable: false,
      );
    }
    return Text(
      text,
      style: AppTextStyles.body(color: color ?? AppColors.primaryDark).copyWith(
        fontWeight: fontWeight,
      ),
    );
  }

  bool _looksLikeMarkdown(String text) {
    return text.contains('*') ||
        text.contains('__') ||
        text.contains('##') ||
        text.contains('```') ||
        text.contains(r'$') ||
        text.contains('![');
  }

  bool _looksLikeHtml(String text) {
    return text.contains('<') && text.contains('>');
  }
}
