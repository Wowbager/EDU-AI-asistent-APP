import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// The in-app currency icon.
///
/// Placeholder: a flat orange circle stands in until the real coin asset is
/// delivered. Swap the [Container] child for the artwork then — every call
/// site already sizes itself from [size].
class CoinIcon extends StatelessWidget {
  final double size;

  const CoinIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Coin icon + amount, used both in the shop header and under item cards.
class CoinBadge extends StatelessWidget {
  final int amount;
  final double iconSize;
  final TextStyle? textStyle;

  const CoinBadge({
    super.key,
    required this.amount,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: iconSize),
        const SizedBox(width: 6),
        Text(
          '$amount',
          style: textStyle ?? AppTextStyles.metaBold(),
        ),
      ],
    );
  }
}
