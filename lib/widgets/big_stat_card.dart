import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/gamification/dashboard_tiers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';

/// Streak / trophies tile for the wide dashboard.
///
/// The phone [StatCard] tucks its value into a small white pill and its icon
/// beside it — at 400px wide that reads fine, at 600px it is mostly empty
/// space. This is the design's desktop treatment: a tall coloured panel with
/// the value, a two-line caption, and the icon blown up on the right.
///
/// The caption is onboarding copy and stops once the learner is past
/// `DashboardTiers.statEncouragement`, at which point the panel goes [compact]
/// (BR-Q7FFF3).
class BigStatCard extends StatelessWidget {
  /// Tall enough for the two-line caption to sit under the value.
  static const double _height = 168;

  /// Without the caption the panel only has to clear the 76px illustration and
  /// the title + value stack; 168 left a band of empty colour (BR-Q7FFF3).
  /// Still leaves room for the shop's two-line caption, which cannot go.
  static const double _compactHeight = 124;

  final Color backgroundColor;
  final String title;
  final Color foreground;

  /// Null for tiles that are a shortcut rather than a statistic (the shop):
  /// the panel then leans on [subtitle] alone.
  final String? value;

  /// Unit after the value, e.g. "den".
  final String? suffix;

  /// Caption under the value. Null on the stat tiles past
  /// `DashboardTiers.statEncouragement`; the shop keeps its own, which is the
  /// only thing that tile has to say.
  final String? subtitle;

  /// Past `DashboardTiers.statEncouragement` the panel loses the band of empty
  /// colour the caption used to fill (BR-Q7FFF3). It is a property of the whole
  /// row, not of one tile: streak and shop sit side by side and must agree on a
  /// height, so all three factories read it off the same threshold.
  final bool compact;

  /// SVG asset for the illustration. Mutually exclusive with [iconWidget].
  final String? iconAsset;

  /// Illustration for tiles with no SVG of their own (Material icon).
  final Widget? iconWidget;

  final VoidCallback? onTap;

  const BigStatCard({
    super.key,
    required this.backgroundColor,
    required this.title,
    required this.foreground,
    this.value,
    this.subtitle,
    this.iconAsset,
    this.iconWidget,
    this.suffix,
    this.compact = false,
    this.onTap,
  })  : assert(iconAsset != null || iconWidget != null,
            'a tile needs an illustration'),
        assert(value != null || subtitle != null,
            'a tile with no value has only its subtitle to say what it is');

  factory BigStatCard.streak({
    required int days,
    required int xp,
    VoidCallback? onTap,
  }) {
    final encourage = DashboardTiers.showsStatEncouragement(xp);
    return BigStatCard(
      backgroundColor: AppColors.orange,
      title: AppStrings.statStreak,
      foreground: Colors.white,
      value: '$days',
      suffix: AppStrings.statDaysPlural(days),
      subtitle: encourage ? AppStrings.statStreakSubtitle : null,
      compact: !encourage,
      iconAsset: 'assets/icons/flame.svg',
      onTap: onTap,
    );
  }

  factory BigStatCard.trophies({
    required int count,
    required int xp,
    VoidCallback? onTap,
  }) {
    final encourage = DashboardTiers.showsStatEncouragement(xp);
    return BigStatCard(
      backgroundColor: AppColors.cardYellow,
      title: AppStrings.statTrophies,
      foreground: AppColors.primaryDark,
      value: '$count',
      subtitle: encourage ? AppStrings.statTrophiesSubtitle : null,
      compact: !encourage,
      iconAsset: 'assets/icons/trophy.svg',
      onTap: onTap,
    );
  }

  /// The avatar shop, which takes the trophy tile's slot past
  /// `DashboardTiers.shopInsteadOfTrophies`. Items are free, so there is no
  /// balance to put where the number goes — the caption stays even when
  /// [compact], because without it the tile would be a title and an icon.
  factory BigStatCard.shop({required int xp, VoidCallback? onTap}) =>
      BigStatCard(
        backgroundColor: AppColors.cardLavender,
        title: AppStrings.shellShop,
        foreground: AppColors.primaryDark,
        subtitle: AppStrings.statShopSubtitle,
        compact: !DashboardTiers.showsStatEncouragement(xp),
        iconWidget: Icon(
          Icons.storefront_rounded,
          size: 76,
          color: AppColors.primaryDark,
        ),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: compact ? _compactHeight : _height,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppDecorations.radiusXL,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.statValueAlt(color: foreground)),
                  const SizedBox(height: 8),
                  if (value != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value!,
                          style: AppTextStyles.heading2Bold(color: foreground)
                              .copyWith(fontSize: 34),
                        ),
                        if (suffix != null) ...[
                          const SizedBox(width: 6),
                          Text(suffix!,
                              style: AppTextStyles.bodySemiBold(
                                  color: foreground)),
                        ],
                      ],
                    ),
                  if (subtitle != null) ...[
                    // The tall panel pushes the caption to the bottom edge; the
                    // compact one has no room to spare and tucks it under the
                    // title. Only the shop gets here compact, and only its
                    // caption can wrap past two lines on a narrow tile — hence
                    // the Flexible, so a third line ellipses instead of
                    // overflowing the panel.
                    if (compact) ...[
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall(
                            color: foreground.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall(
                          color: foreground.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sized generously — the design leans on the illustration for
            // character, and a 24px icon here reads as a bug.
            iconAsset != null
                ? SvgPicture.asset(iconAsset!, width: 76, height: 76)
                : iconWidget!,
          ],
        ),
      ),
    );
  }
}
