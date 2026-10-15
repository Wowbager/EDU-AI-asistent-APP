import 'package:flutter/material.dart';

import '../core/elo/domain_elo_delta.dart';
import '../core/evaluation/quiz_block_summary.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_text_styles.dart';
import '../core/util/decimal_display.dart';

/// End-of-quiz feedback popup (BR-JCUJVR).
///
/// Replaces the ad-hoc dialog that used to live inline in `quiz_page.dart` and
/// implements the "Quiz Feedback v1" overview: the outcome breakdown (correct
/// without a hint / correct with a hint / wrong / unanswered) plus the average
/// ELO movement per GPF domain.
///
/// It is deliberately a plain widget with no Riverpod and no I/O so the same
/// popup serves both a course quiz and an FSRS practice session — the caller
/// assembles the data and hands it over.
///
/// Passing a null [summary] renders the popup without any outcome counts. That
/// is the shape used for courses with `quiz_evaluate` off: the student still
/// gets a confirmation and their domain progress, but the score stays hidden,
/// which is exactly what that course setting asks for.
class QuizFeedbackDialog extends StatefulWidget {
  const QuizFeedbackDialog({
    super.key,
    required this.title,
    required this.headline,
    required this.icon,
    required this.iconColor,
    required this.onDone,
    this.subline,
    this.summary,
    this.domainDeltas = const [],
    this.domainNames = const {},
    this.successPercent,
    this.xpEarned,
    this.onRetry,
    this.aiCommentFuture,
  });

  final String title;

  /// Big line under the icon — the score, or a neutral confirmation.
  final String headline;

  /// Optional encouraging line under [headline].
  final String? subline;

  final IconData icon;
  final Color iconColor;

  /// Outcome counts, or null to hide the breakdown entirely.
  final QuizBlockSummary? summary;

  /// Per-domain ELO movement; empty hides the section.
  final List<DomainEloDelta> domainDeltas;

  /// Domain code → Czech display name, from `GpfLabelRepository.domainNames()`.
  final Map<String, String> domainNames;

  /// Success rate over the block, 0-100. Null hides the section — the shape
  /// used when the score must stay hidden (`quiz_evaluate` off) or when there
  /// was nothing to score.
  final int? successPercent;

  /// XP banked by the session. Only FSRS practice earns XP today, so a quiz
  /// passes null and the line is left out rather than printed as "+0 XP".
  final int? xpEarned;

  /// AI comment on how the block went, resolving to null on any failure
  /// (offline, timeout, server error) — the section then never appears.
  /// Null future = the caller never asked, section hidden outright.
  final Future<String?>? aiCommentFuture;

  final VoidCallback onDone;
  final VoidCallback? onRetry;

  @override
  State<QuizFeedbackDialog> createState() => _QuizFeedbackDialogState();
}

class _QuizFeedbackDialogState extends State<QuizFeedbackDialog> {
  /// Owned here only so the [Scrollbar] can keep its thumb permanently on
  /// screen — `thumbVisibility` needs a controller attached to the scroll view.
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final showScore = widget.successPercent != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusL),
      title: Text(widget.title, style: AppTextStyles.subtitle()),
      content: ConstrainedBox(
        // The breakdown plus five domains is taller than the old two-line
        // dialog, so the content scrolls instead of overflowing on short
        // screens (and in landscape on phones).
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        // "Hotovo" is the last thing in the scroll view, so on a short screen
        // it sits below the fold and the popup looks like it has no way out
        // (BR-9SCMRQ). A permanently visible, chunky thumb says "there is more
        // down here" the moment the popup opens, instead of only while the
        // student happens to be dragging.
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 8,
          radius: const Radius.circular(4),
          child: SingleChildScrollView(
            controller: _scrollController,
            // Keeps the thumb off the content it would otherwise sit on top of.
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 64, color: widget.iconColor),
                const SizedBox(height: 16),
                Text(
                  widget.headline,
                  style: AppTextStyles.heading3(),
                  textAlign: TextAlign.center,
                ),
                if (widget.subline != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subline!,
                    style:
                        AppTextStyles.statSuffix(color: AppColors.primaryDark64),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (s != null && !s.isEmpty) ...[
                  const SizedBox(height: 20),
                  _breakdownSection(s),
                ],
                if (widget.domainDeltas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _eloSection(),
                ],
                if (widget.aiCommentFuture != null) _aiCommentSection(),
                if (showScore) ...[
                  const SizedBox(height: 16),
                  _scoreSection(),
                ],
                const SizedBox(height: 24),
                _doneButton(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.onRetry != null)
          TextButton(
            onPressed: widget.onRetry,
            child: Text(AppStrings.quizRetry, style: AppTextStyles.subtitle()),
          ),
      ],
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _breakdownSection(QuizBlockSummary s) {
    return _panel(
      background: AppColors.primaryDark06,
      children: [
        _sectionLabel(AppStrings.quizBreakdownHeading),
        const SizedBox(height: 8),
        _countRow(
          AppStrings.quizBreakdownCorrectNoHint,
          s.correctNoHint,
          AppColors.success,
        ),
        _countRow(
          AppStrings.quizBreakdownCorrectWithHint,
          s.correctWithHint,
          AppColors.quizPurple,
        ),
        _countRow(
          AppStrings.quizBreakdownWrong,
          s.wrong,
          AppColors.errorLight,
        ),
        // Only shown when it happened — a zero here would read as an accusation
        // on a fully answered quiz. Same for guessed answers below.
        if (s.unanswered > 0)
          _countRow(
            AppStrings.quizBreakdownUnanswered,
            s.unanswered,
            AppColors.primaryDark48,
          ),
        if (s.gamed > 0)
          _countRow(
            AppStrings.quizBreakdownGamed,
            s.gamed,
            AppColors.warning,
          ),
      ],
    );
  }

  Widget _eloSection() {
    return _panel(
      background: AppColors.primaryDark06,
      children: [
        _sectionLabel(AppStrings.quizEloHeading),
        const SizedBox(height: 4),
        Text(
          AppStrings.quizEloExplainer,
          style: AppTextStyles.caption(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 8),
        for (final d in widget.domainDeltas) _deltaRow(d),
      ],
    );
  }

  /// AI comment, three-state: spinner while pending, panel when it arrived,
  /// nothing at all when it failed — an apology row would only advertise the
  /// outage to a student who never asked for the feature.
  Widget _aiCommentSection() {
    return FutureBuilder<String?>(
      future: widget.aiCommentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.quizAiCommentLoading,
                  style: AppTextStyles.caption(color: AppColors.primaryDark64),
                ),
              ],
            ),
          );
        }
        final comment = snapshot.data;
        if (comment == null || comment.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _panel(
            background: AppColors.primaryDark06,
            children: [
              _sectionLabel(AppStrings.quizAiCommentHeading),
              const SizedBox(height: 8),
              Text(
                comment,
                style: AppTextStyles.bodySmall(color: AppColors.primaryDark80),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The green success panel. Practice has always ended on it; a quiz gets the
  /// same close (BR-9SCMRQ), minus the XP line it does not earn.
  Widget _scoreSection() {
    final xp = widget.xpEarned;
    return _panel(
      background: AppColors.successBg,
      children: [
        Text(
          AppStrings.practiceSummarySuccess(widget.successPercent!),
          style: AppTextStyles.bodyBold(color: AppColors.primaryDark),
        ),
        if (xp != null && xp > 0) ...[
          const SizedBox(height: 4),
          Text(
            AppStrings.practiceSummaryXp(xp),
            style: AppTextStyles.bodyBold(color: AppColors.success),
          ),
        ],
      ],
    );
  }

  // ── Building blocks ───────────────────────────────────────────────────────

  Widget _panel({required Color background, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppDecorations.radiusM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTextStyles.bodyBold(color: AppColors.primaryDark),
      );

  Widget _countRow(String label, int count, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark80),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: AppTextStyles.bodyBold(color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }

  Widget _deltaRow(DomainEloDelta d) {
    final color = d.isImprovement ? AppColors.success : AppColors.errorLight;
    // formatDecimal already emits the minus sign and the locale's decimal
    // separator; only the plus has to be added by hand.
    final value = formatDecimal(d.delta, fractionDigits: 1);
    final label = widget.domainNames[d.domain.code] ?? d.domain.code;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(d.domain.emoji, style: AppTextStyles.bodySmall()),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark80),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            d.isImprovement ? '+$value' : value,
            style: AppTextStyles.bodyBold(color: color),
          ),
        ],
      ),
    );
  }

  Widget _doneButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: widget.onDone,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: AppDecorations.radiusS,
          ),
          child: Text(
            AppStrings.quizDone,
            textAlign: TextAlign.center,
            style: AppTextStyles.statValue(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
