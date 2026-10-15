import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// A horizontal carousel for cards that shows peek of next card
class CardCarousel extends StatelessWidget {
  /// List of card widgets to display
  final List<Widget> children;

  /// Card width as fraction of screen width (0.0 to 1.0)
  /// Default is 0.75 (75% of available width)
  final double cardWidthFraction;

  /// Spacing between cards
  final double spacing;

  /// Horizontal padding at the start and end of carousel
  final double horizontalPadding;

  /// Height of the carousel (should match card height)
  final double? height;

  /// Upper bound on a card's width, regardless of [cardWidthFraction].
  final double maxCardWidth;

  const CardCarousel({
    super.key,
    required this.children,
    this.cardWidthFraction = 0.75,
    this.spacing = 12,
    this.horizontalPadding = 16,
    this.height,
    this.maxCardWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = constraints.maxWidth;
        final availableWidth = parentWidth - (horizontalPadding * 2);

        // If only one card, use full width
        // Cap the fractional width — without the old global 640px clamp a
        // desktop window would otherwise produce ~1300px wide cards.
        final cardWidth = children.length == 1
            ? math.min(availableWidth, maxCardWidth)
            : math.min(availableWidth * cardWidthFraction, maxCardWidth);

        return SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none, // Allow shadows to overflow
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: children.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < children.length - 1 ? spacing : 0,
                ),
                child: SizedBox(
                  width: cardWidth,
                  child: children[index],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// A section combining header and carousel
class CardSection extends StatelessWidget {
  /// Section title
  final String title;

  /// Action button text
  final String? actionText;

  /// Callback when action button is tapped
  final VoidCallback? onActionTap;

  /// Cards to display in carousel
  final List<Widget> cards;

  /// Height of the carousel
  final double carouselHeight;

  /// Card width fraction (0.75 = 75% of screen width)
  final double cardWidthFraction;

  /// Spacing between header and carousel
  final double headerSpacing;

  /// Lay the cards out as a wrapping grid instead of a horizontal carousel.
  /// Swiping sideways is the right answer on a phone and the wrong one on a
  /// desktop, where there is room to show every card at once.
  final bool asGrid;

  /// Columns to use when [asGrid] is set.
  final int gridColumns;

  /// Padding either side of the header and the cards. Wide layouts already
  /// pad their content column, so they pass 0 to avoid doubling it up.
  final double horizontalPadding;

  const CardSection({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    required this.cards,
    this.carouselHeight = 220,
    this.cardWidthFraction = 0.75,
    this.headerSpacing = 16,
    this.asGrid = false,
    this.gridColumns = 2,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionHeader(
          title: title,
          actionText: actionText,
          onActionTap: onActionTap,
          horizontalPadding: horizontalPadding,
        ),
        SizedBox(height: headerSpacing),
        if (asGrid)
          _CardGrid(
            columns: gridColumns,
            itemHeight: carouselHeight,
            horizontalPadding: horizontalPadding,
            children: cards,
          )
        else
          CardCarousel(
            cardWidthFraction: cardWidthFraction,
            height: carouselHeight,
            horizontalPadding: horizontalPadding,
            children: cards,
          ),
      ],
    );
  }
}

/// Fixed-column grid of equal-height cards.
///
/// A plain [Wrap] rather than `GridView` because the section is already inside
/// a scroll view — a nested scrollable would need shrinkWrap plus
/// NeverScrollableScrollPhysics and still measure worse.
class _CardGrid extends StatelessWidget {
  final int columns;
  final double itemHeight;
  final double horizontalPadding;
  final List<Widget> children;

  const _CardGrid({
    required this.columns,
    required this.itemHeight,
    required this.horizontalPadding,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnCount = columns.clamp(1, children.length.clamp(1, 6));
          final itemWidth = (constraints.maxWidth -
                  spacing * (columnCount - 1)) /
              columnCount;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final card in children)
                SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: card,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Internal section header
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final double horizontalPadding;

  const _SectionHeader({
    required this.title,
    this.actionText,
    this.onActionTap,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.heading1(),
            ),
          ),
          if (actionText != null) ...[
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: GestureDetector(
                onTap: onActionTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppDecorations.radiusXS,
                  ),
                  child: Text(
                    actionText!,
                    style: AppTextStyles.actionText(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
