import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';

/// A stat card widget for displaying streak or trophy statistics.
///
/// Features:
/// - Colored background with rounded corners
/// - Title at top
/// - White inner container with value and icon
class StatCard extends StatelessWidget {
  /// Background color of the card
  final Color backgroundColor;

  /// Title text (e.g., "Streak", "Trofeje")
  final String title;

  /// Title text color
  final Color titleColor;

  /// Main value to display (e.g., "23", "3").
  ///
  /// Null for tiles that are a shortcut rather than a statistic (the shop):
  /// the white pill then carries just [suffix] as its label and the icon.
  final String? value;

  /// Optional suffix text (e.g., "dní")
  final String? suffix;

  /// Widget for the icon (emoji or custom widget)
  final Widget icon;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.backgroundColor,
    required this.title,
    this.titleColor = Colors.white,
    this.value,
    this.suffix,
    required this.icon,
    this.onTap,
  });

  /// Factory constructor for Streak card
  factory StatCard.streak({
    Key? key,
    required int days,
    VoidCallback? onTap,
  }) {
    return StatCard(
      key: key,
      backgroundColor: AppColors.orange,
      title: AppStrings.statStreak,
      titleColor: Colors.white,
      value: days.toString(),
      suffix: AppStrings.statDaysPlural(days),
      icon: SvgPicture.asset(
        'assets/icons/flame.svg',
        width: 24,
        height: 24,
      ),
      onTap: onTap,
    );
  }

  /// Factory constructor for Trofeje (Trophies) card
  factory StatCard.trophies({
    Key? key,
    required int count,
    VoidCallback? onTap,
  }) {
    return StatCard(
      key: key,
      backgroundColor: AppColors.cardYellow,
      title: AppStrings.statTrophies,
      titleColor: AppColors.primaryDark,
      value: count.toString(),
      icon: SvgPicture.asset(
        'assets/icons/trophy.svg',
        width: 24,
        height: 24,
      ),
      onTap: onTap,
    );
  }

  /// Factory constructor for the avatar shop.
  ///
  /// Takes the trophy half-tile's slot once the learner is past
  /// `DashboardTiers.shopInsteadOfTrophies`. Shop items are free, so there is
  /// no balance to show — the pill carries a label instead of a number.
  factory StatCard.shop({Key? key, VoidCallback? onTap}) {
    return StatCard(
      key: key,
      backgroundColor: AppColors.cardLavender,
      title: AppStrings.shellShop,
      titleColor: AppColors.primaryDark,
      suffix: AppStrings.statShopAction,
      icon: Icon(
        Icons.storefront_rounded,
        size: 24,
        color: AppColors.primaryDark,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppDecorations.radiusXL,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                title,
                style: AppTextStyles.statValue(color: titleColor),
              ),
            ),
            const SizedBox(height: 8),
            // White inner container with value and icon - fits content
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppDecorations.radiusM,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Value
                  if (value != null)
                    Text(
                      value!,
                      style: AppTextStyles.heading1(),
                    ),
                  // Suffix if provided
                  if (suffix != null) ...[
                    if (value != null) const SizedBox(width: 4),
                    Text(
                      suffix!,
                      style: AppTextStyles.statSuffix(
                        color: AppColors.primaryDark64,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Icon
                  icon,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
