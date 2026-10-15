import 'package:flutter/material.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';

/// "Pokračuj v lekci" — the single lesson the learner is currently inside.
///
/// Rail card on wide layouts. Everything it shows is derived from data the app
/// already keeps (`UserCourse.progressData`), so it needs no new backend.
class ContinueLessonCard extends StatelessWidget {
  /// Course name, e.g. "Co umí EDU AI asistent".
  final String courseTitle;

  /// Lesson line under the title, e.g. "Lekce 1: Úvod".
  final String lessonLabel;

  final int stepsDone;

  /// Number of blocks in the lesson. Zero when the card points at a course
  /// rather than a lesson (see [ContinueLessonCard.course]) — the step bar
  /// is dropped then, because "0 z 0 kroků" says nothing.
  final int stepsTotal;
  final VoidCallback? onContinue;

  /// Overrides "Pokračovat v lekci" on the button.
  final String? buttonLabel;

  const ContinueLessonCard({
    super.key,
    required this.courseTitle,
    required this.lessonLabel,
    required this.stepsDone,
    required this.stepsTotal,
    this.onContinue,
    this.buttonLabel,
  });

  /// The learner has started something, but no lesson inside it is still open —
  /// every lesson is finished, or the course is quiz-only. The rail used to
  /// fall back to [ContinueLessonCard.empty] here and claim nothing had been
  /// started at all, contradicting the activity card right below it
  /// (BR-NTB3JW). Points at the course overview instead.
  const ContinueLessonCard.course({
    super.key,
    required this.courseTitle,
    required this.lessonLabel,
    required this.buttonLabel,
    this.onContinue,
  })  : stepsDone = 0,
        stepsTotal = 0;

  /// Shown when nothing has been started yet — an empty rail slot reads as a
  /// loading bug, a worded one does not.
  const ContinueLessonCard.empty({super.key})
      : courseTitle = '',
        lessonLabel = '',
        stepsDone = 0,
        stepsTotal = 0,
        onContinue = null,
        buttonLabel = null;

  bool get _isEmpty => courseTitle.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.continueLessonTitle,
                  style: AppTextStyles.heading4(),
                ),
              ),
              if (!_isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: AppDecorations.radiusXS,
                  ),
                  child: Text(
                    AppStrings.continueLessonBadge,
                    style: AppTextStyles.badgeSmall(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isEmpty)
            Text(
              AppStrings.continueLessonEmpty,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppDecorations.radiusM,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        courseTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitleSmall(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lessonLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall(
                          color: AppColors.primaryDark64,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (stepsTotal > 0) ...[
              const SizedBox(height: 16),
              _buildStepBar(),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onContinue,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: AppDecorations.radiusM,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        color: AppColors.surface, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      buttonLabel ?? AppStrings.continueLessonButton,
                      style:
                          AppTextStyles.actionSmall(color: AppColors.surface),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepBar() {
    final fraction =
        stepsTotal <= 0 ? 0.0 : (stepsDone / stepsTotal).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppColors.progressTrack,
              valueColor: AlwaysStoppedAnimation(AppColors.progressFill),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          AppStrings.continueLessonSteps(stepsDone, stepsTotal),
          style: AppTextStyles.meta(color: AppColors.primaryDark64),
        ),
      ],
    );
  }
}
