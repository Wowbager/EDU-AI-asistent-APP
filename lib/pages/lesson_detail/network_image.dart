import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/block_model.dart';
import '../../widgets/lesson_image.dart';

/// Network image renderer that handles both raster and SVG sources, and keeps
/// working offline through [LessonImage] (BR-BX9AA4).
class LessonNetworkImage extends StatelessWidget {
  final String rawUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const LessonNetworkImage({
    super.key,
    required this.rawUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        Icon(Icons.broken_image, size: 48, color: AppColors.progressFill);

    return LessonImage(
      url: rawUrl,
      fit: fit,
      width: width,
      height: height,
      svgPlaceholder: loadingWidget,
      errorBuilder: (context, error, stack) => fallback,
      loadingBuilder: loadingWidget != null
          ? (context, child, progress) {
              if (progress == null) return child;
              return loadingWidget!;
            }
          : null,
    );
  }
}

/// Block image with rounded corners and a styled error state.
///
/// BR-5VYB78 — no explicit width, so the image stops at its own resolution
/// (100 %) instead of being stretched across the card; a picture wider than
/// the card still shrinks to fit, and anything narrower sits centred.
class LessonBlockImage extends StatelessWidget {
  final StepImage image;

  const LessonBlockImage({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ClipRRect(
        borderRadius: AppDecorations.radiusM,
        child: LessonNetworkImage(
          rawUrl: image.url,
          fit: BoxFit.contain,
          errorWidget: Container(
            padding: const EdgeInsets.all(32),
            color: AppColors.background,
            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
