import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/block_model.dart';
import '../../widgets/network_image_with_fallback.dart';

/// Network image renderer that handles both raster and SVG sources.
///
/// Delegates the actual loading to `NetworkImageWithFallback`, which tries
/// the direct URL before the `/api/proxy/image` proxy — see that widget's
/// doc comment for why a single, unconditional proxy hop is the wrong
/// default. This class only adapts that widget's builder-style API to the
/// simpler "one error widget, one loading widget" shape this codebase's
/// lesson-detail cards already pass in.
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

    return NetworkImageWithFallback(
      url: rawUrl,
      fit: fit,
      width: width,
      height: height,
      // An SVG has no intrinsic size, so it needs the same cap the old SVG
      // branch applied via its own ConstrainedBox.
      svgMaxHeight: height ?? 240,
      svgPlaceholderBuilder: loadingWidget != null ? (_) => loadingWidget! : null,
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
class LessonBlockImage extends StatelessWidget {
  final StepImage image;

  const LessonBlockImage({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppDecorations.radiusM,
      child: LessonNetworkImage(
        rawUrl: image.url,
        fit: BoxFit.contain,
        width: double.infinity,
        errorWidget: Container(
          padding: const EdgeInsets.all(32),
          color: AppColors.background,
          child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
      ),
    );
  }
}
