import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';

const double _ringSize = 92;
const double _ringStroke = 9;

/// Side of the square inscribed in the ring's hole — the largest box whose
/// corners all stay clear of the stroke.
const double _ringLabelBox = (_ringSize - 2 * _ringStroke) / math.sqrt2;

/// "Tvůj postup" — overall completion across all enrolled courses.
///
/// Lives in the dashboard's right-hand rail on wide layouts. Phones do not
/// show it: the same numbers are already one tap away on the achievements
/// page, and the rail is the only place with room for a ring this size.
class ProgressRingCard extends StatelessWidget {
  final int lessonsDone;
  final int lessonsTotal;
  final VoidCallback? onDetailTap;

  /// Replaces the encouragement line. The course page says "finish it and earn
  /// a trophy" rather than a generic well-done.
  final String? hintOverride;

  /// Extra linear bar under the ring — the course page's design has one, the
  /// dashboard's does not.
  final bool showBar;

  /// Icon badge beside the lesson count (a trophy on the course page).
  final IconData? trailingIcon;

  /// XP pill in the card's top-right, e.g. "+3 XP". The lesson page shows the
  /// current lesson's reward here now that it has no header of its own.
  final String? xpLabel;

  /// Defaults to "Zobrazit detail". The action row is dropped entirely when
  /// both this and [onDetailTap] are null.
  final String? actionLabel;

  const ProgressRingCard({
    super.key,
    required this.lessonsDone,
    required this.lessonsTotal,
    this.onDetailTap,
    this.hintOverride,
    this.showBar = false,
    this.trailingIcon,
    this.xpLabel,
    this.actionLabel,
  });

  double get _fraction =>
      lessonsTotal <= 0 ? 0 : (_lessonsDone / lessonsTotal).clamp(0.0, 1.0);

  /// The count actually printed in "{done} z {total} lekcí".
  ///
  /// A caller can hold a done count without a matching total — the dashboard
  /// sums enrolled courses, and a course whose payload has not been downloaded
  /// knows how many lessons were finished but not how many exist. The rail read
  /// "3 z 0 lekcí" beside a 0 % ring that way (BR-NTB3JW). An unknown total
  /// prints as 0/0, matching the ring, instead of a number pair that cannot be.
  int get _lessonsDone =>
      lessonsTotal <= 0 ? 0 : math.min(lessonsDone, lessonsTotal);

  String get _hint {
    if (hintOverride != null) return hintOverride!;
    if (lessonsTotal > 0 && lessonsDone >= lessonsTotal) {
      return AppStrings.progressCardHintDone;
    }
    return _fraction >= 0.5
        ? AppStrings.progressCardHintGoing
        : AppStrings.progressCardHintStart;
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_fraction * 100).round();

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
                  AppStrings.progressCardTitle,
                  style: AppTextStyles.heading4(),
                ),
              ),
              if (xpLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: AppDecorations.radiusPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 14, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        xpLabel!,
                        style: AppTextStyles.badgeSmall(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: _ringSize,
                height: _ringSize,
                child: CustomPaint(
                  painter: _RingPainter(
                    fraction: _fraction,
                    trackColor: AppColors.progressTrack,
                    fillColor: AppColors.progressFill,
                  ),
                  // The caption sits below the centre, where the hole is
                  // narrower than its diameter — "Dokončeno" ran into the
                  // stroke there (BR-H4ZWEK). Kept inside the inscribed
                  // square, a label too long for the hole shrinks instead.
                  child: Center(
                    child: SizedBox.square(
                      dimension: _ringLabelBox,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$percent%',
                                style: AppTextStyles.statValueAlt()),
                            Text(
                              AppStrings.progressCardCompleted,
                              style: AppTextStyles.caption(
                                color: AppColors.primaryDark64,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.progressCardLessons(
                                _lessonsDone, lessonsTotal),
                            style: AppTextStyles.bodySemiBold(),
                          ),
                        ),
                        if (trailingIcon != null)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: AppDecorations.radiusS,
                            ),
                            child: Icon(trailingIcon,
                                size: 18, color: AppColors.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hint,
                      style: AppTextStyles.bodySmall(
                        color: AppColors.primaryDark64,
                      ),
                    ),
                    if (showBar) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _fraction,
                          minHeight: 8,
                          backgroundColor: AppColors.progressTrack,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.progressFill),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // No action row unless the caller wants one — the lesson page has
          // nowhere useful to send you from here.
          if (onDetailTap != null || actionLabel != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onDetailTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      actionLabel ?? AppStrings.progressCardDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextStyles.actionSmall(color: AppColors.primary),
                    ),
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

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color trackColor;
  final Color fillColor;

  _RingPainter({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - _ringStroke) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke;
    canvas.drawCircle(center, radius, track);

    if (fraction <= 0) return;

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * fraction,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.trackColor != trackColor;
}
