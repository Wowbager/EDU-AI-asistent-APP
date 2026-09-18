import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/utils/image_url.dart';

/// A network image (raster or SVG) that tries the direct URL first and only
/// falls back to the Laravel image proxy (`resolveImageUrl`) if that fails.
///
/// Why two attempts instead of always going through the proxy: the proxy
/// (`/api/proxy/image`) was added to dodge CORS blocks that CanvasKit's
/// fetch()-based image loading runs into on web, but routing *every* image
/// through it made the proxy a single point of failure — when it started
/// returning 502 for every URL, every step/solution image in the app broke,
/// even though the browser could fetch most of those same URLs directly just
/// fine (most public image hosts send permissive CORS headers). Trying the
/// direct URL first costs nothing when it works, and still has the proxy as
/// a fallback for the hosts that actually do block cross-origin reads.
///
/// On native platforms CORS doesn't apply and there is no proxy to fall back
/// to, so this widget makes exactly one request — identical to a plain
/// `Image.network`/`SvgPicture.network` — and never touches `resolveImageUrl`.
class NetworkImageWithFallback extends StatefulWidget {
  /// The raw, un-proxied URL as authored. `resolveImageUrl` is applied
  /// internally, only for the fallback attempt.
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context, Widget child, ImageChunkEvent? loadingProgress)?
      loadingBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  /// SVG has no loading-progress callback, only a "still decoding" builder.
  final WidgetBuilder? svgPlaceholderBuilder;

  /// Caps the SVG branch's height (an SVG has no intrinsic size to shrink to
  /// the way a raster image does, so callers that need a bound need it
  /// applied around `SvgPicture.network` itself, not just the placeholder).
  /// Ignored for raster images, which size themselves from [width]/[height].
  final double? svgMaxHeight;

  const NetworkImageWithFallback({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.loadingBuilder,
    this.errorBuilder,
    this.svgPlaceholderBuilder,
    this.svgMaxHeight,
  });

  @override
  State<NetworkImageWithFallback> createState() => _NetworkImageWithFallbackState();
}

class _NetworkImageWithFallbackState extends State<NetworkImageWithFallback> {
  /// Which attempt is on screen: the direct URL, or the proxied one.
  bool _viaProxy = false;

  @override
  void didUpdateWidget(covariant NetworkImageWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different URL (e.g. the editor swapped the image while the card
    // stayed mounted) gets its own two-attempt cycle rather than starting
    // from wherever the previous URL happened to land.
    if (oldWidget.url != widget.url) {
      _viaProxy = false;
    }
  }

  bool get _isSvg {
    // Checked on the raw URL, not the resolved one: the resolved URL is
    // `.../api/proxy/image?url=<encoded original>`, which never ends in
    // `.svg` itself, so checking it made every proxied SVG mis-render as a
    // raster image. The extension only ever survives on the original URL.
    final lower = widget.url.toLowerCase();
    return lower.endsWith('.svg') || lower.contains('.svg?');
  }

  /// Switch to the proxied URL. Deferred to after this frame because both
  /// error builders below run *during* a build (the image stream reports
  /// its failure, which triggers the rebuild that calls this builder), and
  /// calling `setState` synchronously from inside a build is not allowed.
  void _retryViaProxy() {
    if (_viaProxy || !kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _viaProxy = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = _viaProxy ? resolveImageUrl(widget.url) : widget.url;

    if (_isSvg) {
      final svg = SvgPicture.network(
        effectiveUrl,
        // Forces flutter_svg to start a fresh load for the new URL instead of
        // reusing the failed one's image stream.
        key: ValueKey(effectiveUrl),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholderBuilder: widget.svgPlaceholderBuilder,
        errorBuilder: (context, error, stackTrace) {
          if (kIsWeb && !_viaProxy) {
            _retryViaProxy();
            // Show the loading placeholder rather than a one-frame flash of
            // the final error state, since the retry is about to land.
            return widget.svgPlaceholderBuilder?.call(context) ?? const SizedBox.shrink();
          }
          return widget.errorBuilder?.call(context, error, stackTrace) ?? const SizedBox.shrink();
        },
      );
      return widget.svgMaxHeight == null
          ? svg
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.svgMaxHeight!),
              child: svg,
            );
    }

    return Image.network(
      effectiveUrl,
      key: ValueKey(effectiveUrl),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: (context, error, stackTrace) {
        if (kIsWeb && !_viaProxy) {
          _retryViaProxy();
          return widget.loadingBuilder?.call(context, const SizedBox.shrink(), null) ??
              const SizedBox.shrink();
        }
        return widget.errorBuilder?.call(context, error, stackTrace) ?? const SizedBox.shrink();
      },
    );
  }
}
