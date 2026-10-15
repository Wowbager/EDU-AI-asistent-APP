import 'package:flutter/material.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/content_format.dart';
import '../models/open_answer_feedback.dart';
import 'markdown_latex_widget.dart';

/// Renders formative feedback on an open answer (BR-P745Q8).
///
/// Two fixed sections — what went well and what to improve — plus, while the
/// student is still working at the answer, one next step, and — when the author
/// asked for it — the model answer as a closing section (BR-BC3SYR, BR-PM7XQ3,
/// BR-Y3A5M8).
///
/// There used to be a fourth section, "Zamysli se", carrying the model's
/// `hint_question`. It is gone (BR-XTCYD2): asked for on every imperfect answer,
/// it restated "what to improve" and "what to do next" as a question, so the
/// card said the same thing three times and read as a wall of text. The field
/// still arrives on older stored feedback and still reaches the teacher view;
/// it simply has no reader here.
///
/// What this widget deliberately does not render, and must never learn to:
/// a score, a percentage, a "correct/incorrect" verdict, or the student's
/// expected answer (`correct_answer`). The internal score exists (it feeds ELO
/// and FSRS and the teacher view) and never reaches this widget. [retryPending]
/// is the nearest thing that does, and it may only ever decide what is left
/// out — see its own comment. The container is intentionally neutral-coloured
/// rather than green or red, because colour alone is a verdict.
///
/// [solution] is the one exception, and it is not a verdict: it is the author's
/// own explanation (`solution`, "Solution (shown after answering)" in the
/// editor), shown only when the author turned `show_solution` on. It lives
/// inside this card rather than in a card of its own because two stacked panels
/// about the same answer read as two unrelated verdicts.
class OpenAnswerFeedbackCard extends StatelessWidget {
  final FormativeFeedback feedback;

  /// Older responses carry only a flat string. Shown as one block when
  /// [feedback] could not be parsed into parts — see [OpenAnswerFeedbackCard.flat].
  final String? flatText;

  /// The authored explanation, or null when `show_solution` is off or the
  /// author left the field empty.
  final String? solution;

  /// Whether the student is coming back for another go at this answer with
  /// nothing else to work from: it did not land, an attempt is available, and
  /// the model answer is not on screen.
  ///
  /// Used for exactly one thing: keeping the forward-pointing section, "what to
  /// do next". It is an instruction for the next attempt, so it needs a next
  /// attempt to be an instruction for. Without one it is noise at best: a
  /// correct answer already did the thing it sends the student off to do
  /// (BR-PM7XQ3), and once the model answer is on screen — which, with the AI
  /// guide switched off, is the moment the answer is graded — it answers the
  /// section outright (BR-Y3A5M8).
  ///
  /// It must never grow into a rendered verdict — see the class comment above;
  /// the neutral container and the absent score are the point of this widget.
  /// The dropped text still arrives from the server and still reaches the
  /// teacher view; it just has no reader here.
  final bool retryPending;

  const OpenAnswerFeedbackCard({
    super.key,
    required this.feedback,
    this.solution,
    this.retryPending = false,
  }) : flatText = null;

  const OpenAnswerFeedbackCard._flat(this.flatText, this.feedback, this.solution)
      : retryPending = false;

  /// Fallback for feedback produced before the three-part contract existed.
  ///
  /// Returns a card when there is anything to show — the flat feedback string,
  /// the authored explanation, or both. An explanation the author asked for
  /// must not disappear just because the server sent unstructured feedback.
  static Widget? flat(String? text, {String? solution}) {
    final hasText = text != null && text.trim().isNotEmpty;
    final hasSolution = solution != null && solution.trim().isNotEmpty;
    if (!hasText && !hasSolution) return null;
    return OpenAnswerFeedbackCard._flat(
      hasText ? text : null,
      const FormativeFeedback(strengths: '', improvements: '', nextStep: ''),
      hasSolution ? solution : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Text(AppStrings.openFeedbackTitle, style: AppTextStyles.actionSmall()),
              const Spacer(),
              // Named so a student never mistakes this for their teacher's
              // words — the brief treats AI attribution as non-negotiable.
              Text(
                AppStrings.stepAiFeedback,
                style: AppTextStyles.meta(color: AppColors.primaryDark80),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (flatText != null)
            Text(
              flatText!,
              style: AppTextStyles.meta(color: AppColors.primaryDark80),
            )
          // The flat constructor may carry an explanation and nothing else —
          // rendering the three-part layout there would print three empty
          // headings.
          else if (feedback.strengths.isNotEmpty) ...[
            _Section(
              label: AppStrings.openFeedbackStrengths,
              text: feedback.strengths,
            ),
            _Section(
              label: AppStrings.openFeedbackImprovements,
              text: feedback.improvements,
            ),
            // The forward-pointing section, kept only for a student who is
            // going to answer again and has nothing else to go on — see
            // [retryPending]. Everything it would say is either already done
            // (a correct answer) or already on screen (the model answer).
            if (retryPending)
              _Section(
                label: AppStrings.openFeedbackNextStep,
                text: feedback.nextStep,
              ),
          ],
          // Last, and only when asked for: the author's explanation. It closes
          // the card because it answers the question, and everything above it
          // is about what the student wrote.
          if (solution != null) _SolutionSection(solution: solution!),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String text;

  const _Section({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.metaBold()),
          const SizedBox(height: 2),
          Text(text, style: AppTextStyles.meta(color: AppColors.primaryDark80)),
        ],
      ),
    );
  }
}

/// The authored explanation, rendered as one more section of the card — headed
/// "model answer", because next to the student's own attempt that is what it
/// reads as (BR-PM7XQ3).
///
/// Separate from [_Section] because the solution is authored content and
/// routinely carries markdown and formulas, where the AI's parts are plain
/// prose. Passing it through [Text] printed `$a$` and list markers verbatim.
class _SolutionSection extends StatelessWidget {
  final String solution;

  const _SolutionSection({required this.solution});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.openFeedbackSolution, style: AppTextStyles.metaBold()),
          const SizedBox(height: 2),
          if (looksLikeMarkdown(solution))
            MarkdownLatexWidget(
              content: solution,
              // Meta, like every other section body. Without it the markdown
              // renderer falls back to its 15px default and this one section
              // sits two sizes above the rest of the card (BR-PM7XQ3).
              textStyle: AppTextStyles.meta(),
              textColor: AppColors.primaryDark80,
            )
          else
            Text(
              solution,
              style: AppTextStyles.meta(color: AppColors.primaryDark80),
            ),
        ],
      ),
    );
  }
}

/// Shown when evaluation could not run — offline, timed out, throttled.
///
/// This exists because the alternative is worse than showing nothing. The old
/// fallback compared the answer to the expected string and, against a
/// paragraph-long reference, reliably told a correct student they were wrong.
/// A kind message and a retry is the honest outcome.
class OpenAnswerRetryNotice extends StatelessWidget {
  final bool offline;

  /// False when retrying cannot possibly help — the question carries nothing to
  /// judge against, so the server rejects it the same way every time. Showing a
  /// retry button there is a loop, not a recovery.
  final bool canRetry;

  final VoidCallback? onRetry;

  const OpenAnswerRetryNotice({
    super.key,
    required this.offline,
    this.canRetry = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(
                offline
                    ? Icons.cloud_off
                    : canRetry
                    ? Icons.refresh
                    : Icons.info_outline,
                size: 16,
                color: AppColors.primaryDark80,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offline
                      ? AppStrings.openFeedbackOffline
                      : canRetry
                      ? AppStrings.openFeedbackFailed
                      : AppStrings.openFeedbackNotEvaluable,
                  style: AppTextStyles.meta(color: AppColors.primaryDark80),
                ),
              ),
            ],
          ),
          // Offline gets no retry button: the answer is queued and there is
          // nothing useful for the student to press until they reconnect.
          // Neither does a terminal rejection — pressing it just fails again.
          if (!offline && canRetry && onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(AppStrings.openFeedbackRetry),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
