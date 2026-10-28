// Stateless widget that renders ONE step from a block.
//
// Handles text, image, video, and question step types.
// All answer state is managed externally (by BlockStepEngine)
// and passed in via answerState / callbacks.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:video_player/video_player.dart';
import '../core/util/numeric_formatter.dart';
import '../core/utils/image_url.dart';
import '../core/utils/content_embeds.dart';
import '../core/utils/content_format.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/block_model.dart';
import '../models/step_navigation.dart';
import '../preview/preview_mode.dart';
import 'answer_photo_picker.dart';
import 'lesson_image.dart';
import 'markdown_latex_widget.dart';
import 'open_answer_feedback_card.dart';

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
  /// The editor's "Náhled": the step is drawn as answered so the author reads
  /// every part of it, but nobody answered, so nothing is graded. The right
  /// answers are revealed as on a graded card; no verdict, and no red for an
  /// answer that was never given.
  final bool revealOnly;

  /// Attached to the first widget that only exists because the answer was
  /// graded — the option feedback, the AI feedback card or the solution
  /// banner, whichever comes first. The host scrolls it into view once an
  /// answer is evaluated (BR-E6MWSB).
  ///
  /// Null on every rendering that is not the step being answered: a GlobalKey
  /// may only sit in one place at a time, and a multi-question card renders
  /// several of these side by side.
  final Key? feedbackAnchorKey;

  // Callbacks
  final void Function(String optionId)? onOptionSelected;
  final void Function(Set<String> optionIds)? onMultipleOptionsSelected;
  final void Function(String text)? onTextAnswerChanged;
  final void Function()? onTextAnswerSubmitted;

  // ─── Photographed answers + retry (BR-P745Q8) ─────────────────────────────
  // All state lives in BlockStepEngine; this widget only renders it.

  /// Photo the student picked but that has not been uploaded yet.
  final PickedAnswerPhoto? pickedPhoto;

  /// Handle of an uploaded photo, when it is not yet on the answer state.
  final String? uploadedPhotoName;

  final bool isUploadingPhoto;

  /// The evaluation reported it could not read the photo.
  final bool photoUnreadable;

  /// True when the failed evaluation failed because the device is offline —
  /// picks the wording, and suppresses a retry button that could not work.
  final bool evaluationOffline;

  /// False when the server rejected the request outright (422). Retrying an
  /// unevaluable question just fails again, so no button is offered.
  final bool evaluationRetryable;

  /// True when the student may answer again after an evaluation. Practice
  /// invites repeated attempts; a quiz allows one (BR-P745Q8).
  ///
  /// The attempt is reopened by an explicit "try again" button rather than by
  /// typing into the field: once feedback (and possibly the explanation) is on
  /// screen, an answered question is a finished attempt, and a live field
  /// invited the student to overwrite it by accident (BR-BC3SYR).
  final bool canReanswer;

  /// Whether the course reports how the answer came out
  /// (CourseV2.quiz_evaluate). Only the status — the expected answer is never
  /// revealed on a formative question, and no score is ever shown.
  final bool showAnswerStatus;

  final void Function(PickedAnswerPhoto photo)? onPhotoPicked;
  final void Function()? onPhotoRemoved;
  final void Function()? onEvaluationRetry;

  /// Reopens an answered formative question for another attempt — unlocks the
  /// text field and the photo picker. Null when the host has no way to reopen
  /// the step, in which case no button is offered (BR-BC3SYR).
  final void Function()? onReworkAnswer;

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
    this.revealOnly = false,
    this.feedbackAnchorKey,
    this.onOptionSelected,
    this.onMultipleOptionsSelected,
    this.onTextAnswerChanged,
    this.onTextAnswerSubmitted,
    this.pickedPhoto,
    this.uploadedPhotoName,
    this.isUploadingPhoto = false,
    this.photoUnreadable = false,
    this.evaluationOffline = false,
    this.evaluationRetryable = true,
    this.canReanswer = false,
    this.showAnswerStatus = false,
    this.onPhotoPicked,
    this.onPhotoRemoved,
    this.onEvaluationRetry,
    this.onReworkAnswer,
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

    // The anchor goes on the first post-grading widget only: pointing the
    // scroll at the solution below the feedback would skip past the feedback.
    var anchored = false;
    Widget anchorFeedback(Widget child) {
      final key = feedbackAnchorKey;
      if (key == null || anchored) return child;
      anchored = true;
      return KeyedSubtree(key: key, child: child);
    }

    // Render based on question type
    final qType = config.type;

    if (qType == 'true_false') {
      widgets.addAll(_buildTrueFalseButtons(context, config, isAnswered));
    } else if (qType == 'numeric') {
      widgets.addAll(_buildNumericQuestion(config, isAnswered));
    } else if (qType == 'open') {
      widgets.addAll(_buildOpenQuestion(config, isAnswered, anchorFeedback));
    } else if (config.allowMultiple) {
      // allow_multiple: checkbox-style multi-select (takes priority over show_answers)
      widgets.addAll(_buildCheckboxOptions(context, config, isAnswered));
    } else {
      // Default: radio-style single select
      // (show_answers only controls whether correct answer is revealed after answering)
      widgets.addAll(_buildRadioOptions(context, config, isAnswered));
    }

    // Verdict for a multi-select answer (BR-J3KNJS).
    //
    // Every other question type carries its verdict on the card the student
    // picked — one green tick or one red cross. Multi-select has no such
    // card: tick one of two correct options and the only coloured card on
    // screen is green, followed by that option's own approving feedback, so a
    // graded-wrong answer reads as a pass. This row says which it was.
    if (config.allowMultiple && isAnswered && !hideResults && !revealOnly) {
      final answeredCorrectly = answerState?.isCorrect ?? false;
      widgets.add(const SizedBox(height: 12));
      // First thing the student is shown after grading, so it takes the
      // scroll anchor — landing on the feedback below would skip the verdict.
      widgets.add(anchorFeedback(Row(
        children: [
          Icon(
            answeredCorrectly ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: answeredCorrectly ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            answeredCorrectly
                ? AppStrings.exerciseCorrect
                : AppStrings.exerciseIncorrect,
            style: AppTextStyles.labelMedium(
              color: answeredCorrectly ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      )));
    }

    // Feedback for selected option(s)
    if (isAnswered && !hideFeedback) {
      if (config.allowMultiple) {
        // Multi-select: show feedback for each selected option.
        //
        // The banner's tone follows the verdict on the whole answer, not the
        // option it hangs off (BR-6AWJS2). Tick one of two correct options and
        // that option's feedback is approving on its own terms — a green tick
        // and "Výborně" directly under a red Špatně, which is the answer being
        // called right and wrong at once. The author's words stay; only the
        // success styling goes, leaving the neutral note an aside deserves.
        //
        // Skipped when the results are hidden (AGAIN retry, show_answers off):
        // there no verdict is on screen to contradict, and the whole-answer
        // tone would say more about the grading than that state means to.
        final approving = hideResults ? null : (answerState?.isCorrect ?? false);
        final selectedIds = answerState?.selectedOptionIds ?? {};
        for (final opt in config.options) {
          if (selectedIds.contains(opt.id) && opt.feedback != null) {
            widgets.add(const SizedBox(height: 12));
            widgets.add(
                anchorFeedback(_buildFeedbackBanner(opt, approving: approving)));
          }
        }
      } else {
        final selectedOpt = _findSelectedOption(config);
        if (selectedOpt != null && selectedOpt.feedback != null) {
          widgets.add(const SizedBox(height: 12));
          widgets.add(anchorFeedback(_buildFeedbackBanner(selectedOpt)));
        }
      }
    }

    // AI feedback is shown only on `ai_evaluation` questions, and only by the
    // card _buildOpenQuestion renders for them. Every other open answer is
    // graded by AI too (BR-N26ACB), but its student sees right/wrong and the
    // solution — the feedback is stored for the teacher, not shown here.
    final rendersFormativeCard = config.type == 'open' && config.aiEvaluation;

    // Solution (unless show_solution=false or feedback is hidden).
    //
    // Skipped for AI-evaluated open questions (BR-BC3SYR): there the
    // explanation is a section of the feedback card, not a panel below it.
    // Two stacked panels about the same answer read as two verdicts.
    if (showSolution && config.showSolution && !hideFeedback && !rendersFormativeCard) {
      if (config.solution != null && config.solution!.isNotEmpty) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(anchorFeedback(_buildSolutionBanner(config)));
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
                    option.label,
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

    // A correct option left unticked is part of the mistake, so once the
    // answer is graded it has to read as one (BR-J3KNJS). Only the ticked
    // cards used to be coloured, which left a student who picked one of two
    // correct options looking at a single green card and nothing else.
    //
    // Held back on an AGAIN retry and when the author hid the answers — both
    // mean "mark the pick, don't give the answer away", same as the radio
    // path.
    final revealMissed =
        isAnswered && !hideResults && config.showAnswers && revealCorrectAnswer;

    return config.options.map((option) {
      final isSelected = selectedIds.contains(option.id);
      final isCorrect = option.isCorrect;
      final isMissedCorrect = !isSelected && isCorrect && revealMissed;

      Color bgColor = AppColors.surface;
      Color borderColor = AppColors.primaryDark16;

      if (isAnswered && !hideResults) {
        if (isSelected) {
          bgColor = isCorrect
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.error.withValues(alpha: 0.1);
          borderColor = isCorrect ? AppColors.success : AppColors.error;
        } else if (isMissedCorrect && revealOnly) {
          // Nothing was picked, so nothing was missed: the right answers read
          // as the radio path reveals them.
          bgColor = AppColors.success.withValues(alpha: 0.05);
          borderColor = AppColors.success.withValues(alpha: 0.5);
        } else if (isMissedCorrect) {
          bgColor = AppColors.error.withValues(alpha: 0.1);
          borderColor = AppColors.error;
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
                  color: isSelected
                      ? AppColors.primary
                      : isMissedCorrect && !revealOnly
                          ? AppColors.error
                          : AppColors.surfaceLight,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionText(option.label),
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
                      option.label,
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

  List<Widget> _buildOpenQuestion(
    EvaluationConfig config,
    bool isAnswered,
    Widget Function(Widget) anchorFeedback,
  ) {
    final textAnswer = answerState?.textAnswer ?? '';
    final isCorrect = answerState?.isCorrect ?? false;

    // AI-evaluated open questions are formative (BR-P745Q8): no verdict, no
    // score, and never the expected answer. Everything below that would read
    // as a mark — the green/red fill, the correct-answer reveal — is switched
    // off for them, not merely restyled.
    final formative = config.aiEvaluation;
    final failed = answerState?.evaluationFailed ?? false;
    final feedback = answerState?.feedback;

    // Offline, or the AI gave nothing back, so the answer was graded by
    // comparing it with the expected one (BR-N26ACB). No feedback exists to
    // fill the card with.
    final gradedByComparison =
        isAnswered && !failed && !(answerState?.evaluatedByAi ?? false);

    // AI-guided solving (BR-V9TQA7): the explanation is rationed rather than
    // switched off. While attempts remain and the answer has not landed, the
    // student gets the feedback and another go; the explanation arrives when
    // they get there or when the last attempt is spent.
    //
    // Quiz mode is excluded because it grants a single attempt — a loop with
    // one iteration is just a question whose solution never appears.
    //
    // Also requires a live input: read-only renderings (block history, a
    // sibling question in a multi-question card) have no callbacks wired, so
    // withholding the explanation there would leave the student staring at a
    // field that cannot be typed into. Those keep revealing it as before, and
    // BlockStepEngine._isGuided draws the same line for the button.
    final guided = formative &&
        config.aiGuided &&
        exportMode != ExportMode.quizV2 &&
        onTextAnswerChanged != null;
    final attemptsSpent = answerState?.attemptCount ?? 0;
    final attemptsLeft = config.aiGuidedAttempts - attemptsSpent;
    final guidedWithholds = guided && !isCorrect && attemptsLeft > 0;

    // Graded, wrong, attempts left: the field reopens instead of locking, so
    // the student answers again in place. Typing reopens the attempt (see
    // BlockStepEngine._onTextAnswerChangedFor), which keeps the feedback on
    // screen to work from.
    final guidedRetryOpen = guidedWithholds && isAnswered;

    // The same loop mid-rework: the attempt has been reopened by typing, so
    // `isAnswered` is already false but the feedback that prompted the rework
    // is still what the student is reading.
    final guidedReworking = guided &&
        !isAnswered &&
        attemptsSpent > 0 &&
        attemptsLeft > 0 &&
        (feedback != null || (answerState?.aiFeedback?.isNotEmpty ?? false));

    // The formative card belongs on screen after a grading, and throughout a
    // guided rework.
    final showFormativeBlock = isAnswered || guidedReworking;

    // The author's own explanation, shown inside the feedback card once the
    // answer has been graded (BR-BC3SYR). `solution` is authored content, not
    // the student's expected answer, so revealing it breaks no promise the
    // formative brief makes.
    final solutionText = config.solution;
    final revealSolution = showSolution &&
        config.showSolution &&
        !hideFeedback &&
        !guidedWithholds &&
        solutionText != null &&
        solutionText.isNotEmpty;

    // Whether the feedback's forward-pointing sections still have a job
    // (BR-Y3A5M8): the answer did not land, the student has a way to answer
    // again, and the explanation is not already on screen answering them.
    //
    // With the AI guide off, the explanation appears with the very first
    // grading, so those sections never had anything to add there — which is
    // what the report is about. Guided solving is the case they were written
    // for, and mid-loop they are the only thing the student has to work from.
    // The two retry paths differ: guided leaves the field open, everything
    // else reopens through the "try again" button below, so the condition
    // mirrors that button's own gating.
    final retryPending = !isCorrect &&
        !revealSolution &&
        (guidedWithholds || (canReanswer && onReworkAnswer != null));

    // A finished attempt stays put until the student asks for another one.
    // Reopening is what the "try again" button below is for — except under
    // guided solving, where answering again *is* the next step and a locked
    // field would be a dead end.
    final locked = isAnswered && !guidedRetryOpen;

    Color fillColor() {
      if (formative || !isAnswered || hideResults || revealOnly) return AppColors.background;
      return isCorrect
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.error.withValues(alpha: 0.1);
    }

    Color disabledBorderColor() {
      if (formative || hideResults || revealOnly) return AppColors.primaryDark16;
      return isCorrect ? AppColors.success : AppColors.error;
    }

    return [
      _AnswerTextField(
        // Per step, so moving to the next question starts from an empty field
        // instead of inheriting the previous one's state.
        key: ValueKey('open:${step.stepId}'),
        text: textAnswer,
        // Locked once the answer is in. Practice still lets the student rework
        // it (BR-P745Q8) — through the button under the feedback, which
        // reopens the attempt and unlocks this field again (BR-BC3SYR).
        enabled: !locked,
        style: AppTextStyles.subtitle(),
        // Formative answers are written in sentences, so they get a left-aligned
        // multi-line field rather than the single centred line a one-word
        // answer wants.
        textAlign: formative ? TextAlign.start : TextAlign.center,
        maxLines: formative ? 5 : 1,
        minLines: formative ? 3 : 1,
        keyboardType: formative ? TextInputType.multiline : TextInputType.text,
        decoration: InputDecoration(
          hintText: AppStrings.stepWriteAnswer,
          hintStyle: AppTextStyles.bodyLarge(color: AppColors.primaryDark.withValues(alpha: 0.4)),
          filled: true,
          fillColor: fillColor(),
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
            borderSide: BorderSide(color: disabledBorderColor(), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (value) => onTextAnswerChanged?.call(value),
        onSubmitted: formative ? null : (_) => onTextAnswerSubmitted?.call(),
      ),

      // Photo attach. Rendered only when the author enabled it — the brief
      // requires the option to be absent, not disabled, when the switch is off.
      if (config.allowPhoto) ...[
        const SizedBox(height: 8),
        AnswerPhotoPicker(
          picked: pickedPhoto,
          uploadedName: uploadedPhotoName ?? answerState?.photoName,
          isUploading: isUploadingPhoto,
          unreadable: photoUnreadable,
          // Same rule as the text field: a guided retry is still being worked
          // on, so the photo stays swappable.
          onPicked: locked ? null : onPhotoPicked,
          onRemoved: locked ? null : onPhotoRemoved,
        ),
      ],

      // An exact-match question says how the answer came out in words, not
      // just through the border colour (BR-RBUR29). This takes the place the
      // expected answer used to have: authors write that field as a grading
      // key — "1/4 nebo slovy jedna čtvrtina nebo čtvrtka" — and the editor
      // promises them the student never sees it. The authored explanation
      // below is what teaches the answer.
      if (!formative && isAnswered && !hideResults && !revealOnly) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: isCorrect ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(
              isCorrect ? AppStrings.lessonCorrect : AppStrings.lessonIncorrect,
              style: AppTextStyles.labelMedium(
                color: isCorrect ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ],

      // The expected answer itself is never printed — not in practice either
      // (BR-N26ACB). The status above and the authored solution are the
      // feedback an answer graded without the AI's words gets.

      // Status, not a grade: no score, no percentage, and never the expected
      // answer. Shown when the course asked for evaluation to be visible, so an
      // open question behaves like every other type in that course — and always
      // under guided solving, where a student who cannot tell whether the last
      // attempt landed has no way to read the loop they are being held in
      // (BR-V9TQA7). Also always when the AI could not be reached and the
      // answer was compared instead (BR-N26ACB): with no feedback to read, the
      // status is the only thing that says how it went.
      if (formative &&
          showFormativeBlock &&
          !hideFeedback &&
          (showAnswerStatus || guided || gradedByComparison) &&
          !failed) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.info_outline,
              size: 18,
              color: isCorrect ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              isCorrect ? AppStrings.lessonCorrect : AppStrings.lessonIncorrect,
              style: AppTextStyles.labelMedium(
                color: isCorrect ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ],

      // The evaluation never came back. A failure leaves the answer unanswered
      // (BlockStepEngine._handleEvaluationFailure), so tying this to
      // `isAnswered` like the feedback card below kept it off screen for good:
      // the student saw "Promýšlím tvou odpověď..." and then the question as it
      // was before the tap, with nothing to say why (BR-5FWNTK). Not about
      // right or wrong either, so neither `ai_evaluation` nor a course that
      // hides evaluation gets a say — the quiz's atomic card shows it the same
      // way.
      if (failed) ...[
        const SizedBox(height: 12),
        anchorFeedback(OpenAnswerRetryNotice(
          offline: evaluationOffline,
          canRetry: evaluationRetryable,
          onRetry: onEvaluationRetry,
        )),
      ],

      if (formative && showFormativeBlock && !hideFeedback && !failed)
        ...(() {
          final Widget? card = feedback != null
              ? OpenAnswerFeedbackCard(
                  feedback: feedback,
                  solution: revealSolution ? solutionText : null,
                  retryPending: retryPending,
                )
              // Feedback from a server that predates the three-part contract.
              : OpenAnswerFeedbackCard.flat(
                  answerState?.aiFeedback,
                  solution: revealSolution ? solutionText : null,
                );

          return card == null
              ? const <Widget>[]
              : <Widget>[const SizedBox(height: 12), anchorFeedback(card)];
        })(),

      // How many goes are left before the explanation appears. Guided solving
      // asks the student to keep working at it, and an open-ended "try again"
      // with no visible end is a worse deal than the one the author offered.
      //
      // Dropped once the attempts are gone: the explanation is on screen by
      // then, and it says everything a counter at zero would.
      if (guided &&
          !hideFeedback &&
          !failed &&
          showFormativeBlock &&
          !isCorrect &&
          attemptsLeft > 0) ...[
        const SizedBox(height: 8),
        Text(
          AppStrings.openFeedbackAttemptsLeft(attemptsLeft),
          style: AppTextStyles.meta(color: AppColors.primaryDark80),
        ),
      ],

      // Another attempt, explicitly asked for. The field above is locked, so
      // without this the student reads the feedback and has nowhere to go
      // (BR-BC3SYR). A failed evaluation gets its own retry inside the notice
      // above — offering both would be two buttons for two different things.
      // Guided solving leaves the field open instead, so the button would be a
      // second way to do what the student can already do.
      //
      // A correct answer ends the question (BR-PM7XQ3): offering another go at
      // something already answered right reads as "that wasn't good enough".
      // Deliberately not conditioned on the status row above — a course that
      // hides right/wrong would otherwise leak the verdict through the presence
      // of this button.
      //
      // So does the model answer (BR-XWBT8W). With the AI guide off it is on
      // screen from the very first grading, and an attempt made after reading
      // it measures nothing — the reason guided solving closes the field once
      // it hands the explanation over (BR-K8TDU4). While the author keeps it
      // hidden the feedback is all the student has, and the button stays.
      if (formative &&
          isAnswered &&
          !hideFeedback &&
          !failed &&
          !isCorrect &&
          !revealSolution &&
          !guidedRetryOpen &&
          canReanswer &&
          onReworkAnswer != null) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onReworkAnswer,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(AppStrings.engineTryAgain),
          ),
        ),
      ],

      // Quiz mode withholds feedback until the block is done. Without this the
      // student gets no acknowledgement at all and re-submits.
      if (formative && isAnswered && hideFeedback) ...[
        const SizedBox(height: 12),
        Text(
          AppStrings.openFeedbackQuizPending,
          style: AppTextStyles.meta(color: AppColors.primaryDark80),
        ),
      ],
    ];
  }

  // ─── Feedback Banner ─────────────────────────────────────

  /// [approving] overrides whose correctness the banner is styled after —
  /// used by multi-select, where the option is only part of the answer.
  Widget _buildFeedbackBanner(EvaluationOption option, {bool? approving}) {
    return PreviewTarget(
      stepId: step.stepId,
      optionId: option.id,
      field: 'feedback',
      child: _buildFeedbackBannerBody(option, approving: approving),
    );
  }

  Widget _buildFeedbackBannerBody(EvaluationOption option, {bool? approving}) {
    final isCorrect = approving ?? option.isCorrect;
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
      _AnswerTextField(
        key: ValueKey('numeric:${step.stepId}'),
        text: textAnswer,
        enabled: !isAnswered,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        // keyboardType alone is only a soft-keyboard hint — on web and desktop
        // a physical keyboard types straight into the field, so the answer has
        // to be filtered here as well (BR-WAEZE3).
        inputFormatters: [DecimalNumberFormatter()],
        style: AppTextStyles.subtitle(),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: AppStrings.stepNumericHint,
          hintStyle: AppTextStyles.bodyLarge(color: AppColors.primaryDark.withValues(alpha: 0.4)),
          filled: true,
          fillColor: isAnswered && !hideResults && !revealOnly
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
              color: hideResults || revealOnly
                  ? AppColors.primaryDark16
                  : (isCorrect ? AppColors.success : AppColors.error),
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
          AppStrings.stepTolerance(config.tolerance),
          style: AppTextStyles.caption(color: AppColors.primaryDark64),
        ),
      ],
      if (isAnswered && !isCorrect && !hideResults && config.correctNumber != null) ...[
        const SizedBox(height: 12),
        Text(
          AppStrings.stepCorrectNumber(config.correctNumber!),
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

    // BR-5VYB78 — the raster branch carries no width, so the image is drawn at
    // its own resolution (100 %) at most; a wider one still scales down to the
    // step width. Align keeps it centred once it no longer fills the row.
    // BR-BX9AA4 — LessonImage keeps the picture for offline use.
    return Align(
      child: ClipRRect(
        borderRadius: AppDecorations.radiusM,
        child: LessonImage(
          url: image.url,
          fit: BoxFit.contain,
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

  bool _looksLikeMarkdown(String text) => looksLikeMarkdown(text);

  bool _looksLikeHtml(String text) => looksLikeHtml(text);
}

/// Answer field that owns its [TextEditingController].
///
/// The host rebuilds this renderer on every keystroke (BlockStepEngine calls
/// setState from onChanged). A controller built inside build() is a new
/// instance each time, and TextField adopts the new instance's selection —
/// which put the caret at the end of the text after every character, so an
/// edit in the middle of an answer was impossible (BR-FR3M93).
///
/// Keeping the controller in State fixes that; [text] is then only pushed back
/// into the field when it changed somewhere other than this field — a cleared
/// answer after "try again", or a draft restored with the step.
class _AnswerTextField extends StatefulWidget {
  final String text;
  final bool enabled;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;

  /// What the field will accept at all. [keyboardType] is only a soft-keyboard
  /// hint, so a numeric question needs this to keep letters out on web and
  /// desktop (BR-WAEZE3).
  final List<TextInputFormatter>? inputFormatters;

  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _AnswerTextField({
    super.key,
    required this.text,
    required this.enabled,
    required this.decoration,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_AnswerTextField> createState() => _AnswerTextFieldState();
}

class _AnswerTextFieldState extends State<_AnswerTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(covariant _AnswerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Our own keystroke coming back through the host's state — the field
    // already holds this text, and rewriting it would move the caret.
    if (widget.text == _controller.text) return;
    _controller.value = TextEditingValue(
      text: widget.text,
      selection: TextSelection.collapsed(offset: widget.text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      decoration: widget.decoration,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
