import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';

/// A card that visualises a single skill with a purple confidence gradient bar,
/// a dot marker at the current level, and confidence interval text.
class SkillCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final double level; // 1.0 – 10.0
  final int confidenceLow;
  final int confidenceHigh;

  const SkillCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.level,
    required this.confidenceLow,
    required this.confidenceHigh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        border: Border.all(color: AppColors.primaryDark08, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: emoji + title/subtitle ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppDecorations.radiusS,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.statValue()),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.meta(color: AppColors.primaryDark64),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Confidence gradient bar with numbers inside ──
          _ConfidenceBar(
            level: level,
            confidenceLow: confidenceLow,
            confidenceHigh: confidenceHigh,
          ),
          const SizedBox(height: 10),

          // ── Level + confidence text ──
          Row(
            children: [
              Text(
                AppStrings.skillLevel(level),
                style: AppTextStyles.metaBold(),
              ),
              const SizedBox(width: 16),
              Text(
                AppStrings.skillConfidence(confidenceLow, confidenceHigh),
                style: AppTextStyles.meta(color: AppColors.primaryDark64),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bar with 10 cells, numbers inside. The level cell has a purple dot,
/// every cell inside the confidence interval is filled with purple that
/// steps down with distance from the level — never below a legible floor.
class _ConfidenceBar extends StatelessWidget {
  final double level;
  final int confidenceLow;
  final int confidenceHigh;

  /// Purple fill opacity per cell, indexed by the distance from the level
  /// cell (index 0 = the level itself). Cells further out than the last
  /// entry keep that floor value, so the edges of a confidence interval stay
  /// clearly visible instead of fading into the background.
  static const List<double> _shades = <double>[0.48, 0.42, 0.32, 0.24, 0.18];

  const _ConfidenceBar({
    required this.level,
    required this.confidenceLow,
    required this.confidenceHigh,
  });

  @override
  Widget build(BuildContext context) {
    final levelRound = level.round().clamp(1, 10);

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(10, (i) {
          final n = i + 1;
          final distance = (n - levelRound).abs();
          final isLevel = n == levelRound;
          final isInInterval = n >= confidenceLow && n <= confidenceHigh;

          // Purple opacity: strongest at the level, stepping down with the
          // absolute distance from it (e.g. level=7, low=4, high=10 → cells
          // 4-10 all get purple, darkest at 7, still visible at 4 and 10).
          // Intentionally not normalised by the interval width: a narrow
          // interval such as 5-7 would otherwise push its edges down to the
          // faintest shade in the palette.
          double cellAlpha = 0.0;
          if (isLevel || isInInterval) {
            final shadeIndex =
                distance < _shades.length ? distance : _shades.length - 1;
            cellAlpha = _shades[shadeIndex];
          }

          return Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: cellAlpha > 0
                    ? AppColors.primary.withValues(alpha: cellAlpha)
                    : Colors.transparent,
                // Round the ends of the bar
                borderRadius: BorderRadius.horizontal(
                  left: i == 0 ? const Radius.circular(16) : Radius.zero,
                  right: i == 9 ? const Radius.circular(16) : Radius.zero,
                ),
              ),
              child: Center(
                child: isLevel
                    ? // Purple dot for the level
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      )
                    : // Number label
                      Text(
                        '$n',
                        style: AppTextStyles.caption(
                          color: isInInterval
                              ? AppColors.primaryDark88
                              : AppColors.primaryDark32,
                        ),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
