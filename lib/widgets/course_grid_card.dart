import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'course_cover_image.dart';

/// A pill drawn over a grid card's illustration panel.
class CourseCardPill {
  final String label;
  final Color color;
  final IconData? icon;

  const CourseCardPill({
    required this.label,
    required this.color,
    this.icon,
  });
}

/// Vertical course tile used by the wide Kurzy and Knihovna grids.
///
/// The list-style cards put their icon beside the text, which stops working
/// the moment a card is 300px wide instead of full-width. This is the same
/// information stacked: illustration header, title, meta, optional progress,
/// footer action.
///
/// The design shows a per-course illustration: the header panel paints the
/// course cover when one is set in admin, and falls back to a tinted panel with
/// the emoji blown up when it isn't.
class CourseGridCard extends StatelessWidget {
  final String emoji;

  /// Course cover (`header_image.url`). Fills the header panel; null keeps the
  /// emoji (BR-YKYXC6).
  final String? coverImageUrl;

  /// Tint for the illustration panel. Callers cycle a palette by position so a
  /// grid does not come out one flat colour.
  final Color headerColor;

  final String title;

  /// Optional line under the title. Knihovna shows the course blurb here;
  /// Kurzy leaves it out because its cards are shorter.
  final String? description;

  /// Right-hand side of the meta line, e.g. "4 lekce · 50 min".
  final String meta;

  /// Pills over the illustration (update available, completed, login-only…).
  final List<CourseCardPill> pills;

  /// Progress bar with a percentage. Hidden when [totalProgress] is 0.
  final int currentProgress;
  final int totalProgress;

  /// Paint the bar and percentage in the success colour.
  final bool progressIsComplete;

  /// Action row at the bottom — a CTA button, a download button, whatever the
  /// page needs. Given the full card width.
  final Widget footer;

  final VoidCallback? onTap;

  /// Per-card overflow menu, top-right of the header. Omitted when null.
  final VoidCallback? onMenuTap;

  const CourseGridCard({
    super.key,
    required this.emoji,
    this.coverImageUrl,
    required this.headerColor,
    required this.title,
    required this.meta,
    required this.footer,
    this.description,
    this.pills = const [],
    this.currentProgress = 0,
    this.totalProgress = 0,
    this.progressIsComplete = false,
    this.onTap,
    this.onMenuTap,
  });

  double get _fraction => totalProgress <= 0
      ? 0
      : (currentProgress / totalProgress).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusXL,
          boxShadow: AppDecorations.shadowLight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 124,
      color: headerColor.withValues(alpha: 0.48),
      child: Stack(
        children: [
          Positioned.fill(
            child: CourseCoverImage(
              url: coverImageUrl,
              fallback: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 48)),
              ),
            ),
          ),
          if (pills.isNotEmpty)
            Positioned(
              top: 10,
              left: 10,
              right: onMenuTap != null ? 44 : 10,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final pill in pills) _Pill(pill: pill)],
              ),
            ),
          if (onMenuTap != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onMenuTap,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppDecorations.shadowLight,
                  ),
                  child: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: AppColors.primaryDark64,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.cardTitleSmall(),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta(color: AppColors.primaryDark64),
          ),
          const Spacer(),
          if (totalProgress > 0) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _fraction,
                      minHeight: 6,
                      backgroundColor: AppColors.progressTrack,
                      valueColor: AlwaysStoppedAnimation(
                        progressIsComplete
                            ? AppColors.success
                            : AppColors.progressFill,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_fraction * 100).round()}%',
                  style: AppTextStyles.meta(color: AppColors.primaryDark64),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          footer,
        ],
      ),
    );
  }
}

/// Outlined full-width button — the default grid-card footer.
class CourseGridCardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;

  const CourseGridCardButton({
    super.key,
    required this.label,
    this.icon = Icons.play_arrow_rounded,
    this.background,
    this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.primaryDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppDecorations.radiusM,
          border: background == null
              ? Border.all(color: AppColors.primaryDark12)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.actionSmall(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final CourseCardPill pill;

  const _Pill({required this.pill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXS,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pill.icon != null) ...[
            Icon(pill.icon, size: 12, color: pill.color),
            const SizedBox(width: 4),
          ],
          Text(pill.label, style: AppTextStyles.badgeSmall(color: pill.color)),
        ],
      ),
    );
  }
}
