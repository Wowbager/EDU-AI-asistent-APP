import 'package:flutter/material.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';

/// One row of the activity list.
class ActivityEntry {
  final IconData icon;
  final Color iconColor;

  /// What happened, e.g. "Pokračoval(a) v kurzu".
  final String action;

  /// What it happened to, e.g. the course name.
  final String subject;

  /// Relative time, already formatted (see `AppStrings.timeAgoFrom`).
  final String timeLabel;

  /// XP delta, e.g. "+5 XP". Null until the backend records XP per event.
  final String? xpLabel;

  /// Where the row takes the learner. Null leaves the row decorative — a row
  /// that reads "Pokračovat" and does nothing when tapped is the bug this
  /// callback exists to prevent (BR-9NDW6D), so pass one whenever there is
  /// somewhere to go.
  final VoidCallback? onTap;

  const ActivityEntry({
    required this.icon,
    required this.iconColor,
    required this.action,
    required this.subject,
    required this.timeLabel,
    this.xpLabel,
    this.onTap,
  });
}

/// "Nedávná aktivita" — which course was touched, and when.
///
/// The design also calls for an XP stamp per row ("+5 XP · Zodpovězen kvíz").
/// The app has no event log — only the aggregate `xpPoints` — so the rows
/// carry no [ActivityEntry.xpLabel] until an activity endpoint exists. What
/// they do carry is real (`UserCourse.updatedAt`), so the card no longer
/// captions them as a mock-up: a footnote reading "history is still being
/// built" made finished rows look broken (BR-NTB3JW).
class RecentActivityCard extends StatelessWidget {
  final List<ActivityEntry> entries;

  final VoidCallback? onShowAll;

  const RecentActivityCard({
    super.key,
    required this.entries,
    this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.recentActivityTitle,
            style: AppTextStyles.heading4(),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Text(
              AppStrings.recentActivityEmpty,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
            )
          else
            for (final entry in entries) ...[
              _ActivityRow(entry: entry),
              if (entry != entries.last) const SizedBox(height: 4),
            ],
          if (onShowAll != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onShowAll,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    AppStrings.recentActivityShowAll,
                    style: AppTextStyles.actionSmall(color: AppColors.primary),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward,
                      size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEntry entry;

  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    // 6px of padding turns the row into a comfortable tap target and, with the
    // 4px gap between rows, keeps the visual rhythm the design had before the
    // rows became tappable (6 + 4 + 6 = the original 16px gap).
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _buildRow(),
    );

    if (entry.onTap == null) return row;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: entry.onTap,
        // Opaque: the gaps between icon, text and timestamp are part of the
        // target, not holes in it.
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }

  Widget _buildRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: entry.iconColor.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(entry.icon, size: 20, color: entry.iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.action,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall(
                  color: AppColors.primaryDark64,
                ),
              ),
              Text(
                entry.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySemiBold(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.xpLabel != null)
              Text(
                entry.xpLabel!,
                style: AppTextStyles.actionSmall(color: AppColors.primary),
              ),
            Text(
              entry.timeLabel,
              style: AppTextStyles.caption(color: AppColors.primaryDark48),
            ),
          ],
        ),
      ],
    );
  }
}
