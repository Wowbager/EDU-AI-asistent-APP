import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/util/svg_bounds.dart';
import '../models/avatar_display.dart';
import '../models/avatar_model.dart';
import 'coin_badge.dart';

/// One item tile in the shop: a bordered artwork card with price/state, name
/// and slot label underneath.
class ShopItemCard extends StatelessWidget {
  /// How much of the tile the cropped artwork fills. The remainder is the
  /// breathing room between the item and the rarity border.
  static const _cardFill = 0.78;

  final AvatarItem item;

  /// Whether this item is the one currently worn in its slot.
  final bool isEquipped;

  /// What the labels under the tile are drawn on. The shop paints three
  /// different surfaces depending on width — a white sheet, the app
  /// background, the panel wash — and the text has to clear whichever one it
  /// lands on (BR-YXSVVC).
  final Color backdrop;

  final VoidCallback? onTap;

  const ShopItemCard({
    super.key,
    required this.item,
    required this.backdrop,
    this.isEquipped = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.rarity.accent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppDecorations.radiusL,
                // The worn item gets a thicker border — the only state that
                // has to be readable at a glance across a 3-column grid.
                border: Border.all(color: accent, width: isEquipped ? 4 : 2),
              ),
              child: Center(child: _artwork(accent)),
            ),
          ),
          const SizedBox(height: 8),
          // Prices run to six digits while the tile is only ~90 px wide on a
          // 320 px phone — scale down rather than overflow.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _status(),
          ),
          const SizedBox(height: 2),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // The name is what the user is reading, so it takes the body
            // colour. Rarity is carried by the border, which is a shape and
            // can afford a pastel; the same pastel on a 13 px glyph was
            // 1.4:1 (BR-YXSVVC).
            style: AppTextStyles.metaBold(color: AppColors.primaryDark),
          ),
          Text(
            item.slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(color: AppColors.primaryDark80),
          ),
        ],
      ),
    );
  }

  /// Price for something still to acquire, state for something already owned.
  ///
  /// The two emphasised states keep the rarity hue — darkened to a legible
  /// version of itself rather than dropped (BR-YXSVVC).
  Widget _status() {
    final rarity = item.rarity.labelOn(backdrop);

    if (isEquipped) {
      return Text(
        AppStrings.shopEquipped,
        style: AppTextStyles.metaBold(color: rarity),
      );
    }

    if (item.owned) {
      return Text(
        AppStrings.shopEquip,
        style: AppTextStyles.meta(color: AppColors.primaryDark80),
      );
    }

    // Everything is free during the launch period, and a "0" coin badge reads
    // as broken rather than generous.
    if (item.price == 0) {
      return Text(
        AppStrings.shopGetFree,
        style: AppTextStyles.metaBold(color: rarity),
      );
    }

    return CoinBadge(amount: item.price);
  }

  Widget _artwork(Color accent) {
    final svg = item.svgSource;

    if (svg != null) {
      final content = item.contentBounds;
      final picture = SvgPicture.string(svg, fit: BoxFit.contain);

      // On the avatar a crown sits near the top of an otherwise empty canvas.
      // Shown on its own that reads as a tiny speck in a big frame, so the
      // tile crops to the artwork. `_cardFill` is what leaves the padding.
      if (content == null) {
        return Padding(padding: const EdgeInsets.all(8), child: picture);
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;

          return ClipRect(
            child: Transform(
              transform: cropTransform(content, side, fill: _cardFill),
              child: SizedBox(width: side, height: side, child: picture),
            ),
          );
        },
      );
    }

    // Catalog row known, artwork not downloaded yet — e.g. a first run with no
    // connection. The item still lists; it just cannot be drawn.
    return LayoutBuilder(
      builder: (context, constraints) {
        final d = constraints.biggest.shortestSide * 0.55;
        return Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.24),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
