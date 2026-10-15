import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// A welcome card widget with gradient background and mascot illustration.
///
/// Features:
/// - Purple gradient background (top to bottom)
/// - Small title text and large description
/// - Mascot illustration on the right (overflowing)
class WelcomeCard extends StatelessWidget {
  /// Small title text (e.g., "Skiny")
  final String title;

  /// Large description text (e.g., "Dosahl jsi\nlvl Wizard!")
  final String description;

  /// Path to the mascot illustration
  final String? illustrationPath;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  const WelcomeCard({
    super.key,
    required this.title,
    required this.description,
    this.illustrationPath,
    this.onTap,
  });

  static const double _cardHeight = 148;
  static const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(16, 24, 16, 32);

  /// Rendered size of the mascot asset.
  static const double _illustrationWidth = 162;
  static const double _illustrationHeight = 128;

  /// The asset carries a transparent margin down its left side, so the copy
  /// may reach that far in without touching the artwork.
  static const double _illustrationBleed = 12;

  /// The design draws the greeting at `heading1`; longer copy steps down
  /// rather than spilling out of the card.
  static const double _descriptionMaxFontSize = 32;
  static const double _descriptionMinFontSize = 16;
  static const double _descriptionFontSizeStep = 2;

  /// Width the copy may occupy inside the card's padding: the mascot is
  /// painted on top of the card's right edge, so anything reaching under it
  /// simply disappeared (BR-YS6VC5). The artwork eats `_illustrationWidth`
  /// minus its transparent margin, of which the right padding is already free.
  static double textWidthFor(double innerWidth) => math.max(
        0,
        innerWidth -
            (_illustrationWidth - _illustrationBleed - _cardPadding.right),
      );

  /// Largest heading size whose copy still fits `maxWidth` × `maxHeight`.
  ///
  /// The client asked for flexible type rather than a hard length cap, so the
  /// two-line design case keeps its 32px and only longer greetings shrink.
  static TextStyle _descriptionStyle(
    String text,
    double maxWidth,
    double maxHeight,
    TextScaler textScaler,
  ) {
    final base = AppTextStyles.heading1(color: Colors.white);
    for (var size = _descriptionMaxFontSize;
        size > _descriptionMinFontSize;
        size -= _descriptionFontSizeStep) {
      final style = base.copyWith(fontSize: size);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) return style;
    }
    return base.copyWith(fontSize: _descriptionMinFontSize);
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleStyle = AppTextStyles.statValue(color: Colors.white);
    final titleHeight =
        textScaler.scale(titleStyle.fontSize!) * (titleStyle.height ?? 1);
    // What is left of the card once the title and the padding have taken
    // their share — the budget the greeting has to fit into.
    final descriptionHeight = math.max(
      0.0,
      _cardHeight - _cardPadding.vertical - titleHeight - 4,
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: _cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Gradient background
            Container(
              width: double.infinity,
              height: _cardHeight,
              padding: _cardPadding,
              decoration: BoxDecoration(
                gradient: AppColors.authGradient,
                borderRadius: AppDecorations.radiusXL,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textWidth = textWidthFor(constraints.maxWidth);
                  final descriptionStyle = _descriptionStyle(
                    description,
                    textWidth,
                    descriptionHeight,
                    textScaler,
                  );
                  final lineHeight =
                      textScaler.scale(descriptionStyle.fontSize!) *
                          (descriptionStyle.height ?? 1);
                  // The card hands its child tight constraints, so the text
                  // column needs an Align to be allowed to be narrower.
                  return Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: textWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            title,
                            style: titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Description
                          Text(
                            description,
                            style: descriptionStyle,
                            // Even at the smallest step a runaway string has
                            // to stop somewhere; ellipsis beats painting
                            // outside the card.
                            maxLines: math.max(
                              1,
                              (descriptionHeight / lineHeight).floor(),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Mascot illustration - positioned on right, clipped to card radius
            if (illustrationPath != null)
              Positioned(
                right: -2,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(24),
                  ),
                  child: Image.asset(
                    illustrationPath!,
                    width: _illustrationWidth,
                    height: _illustrationHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
