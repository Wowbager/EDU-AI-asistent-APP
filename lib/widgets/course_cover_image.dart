import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/utils/image_url.dart';

/// The course cover ("Header Image (Course Cover)" in admin), with the emoji
/// tile as its fallback.
///
/// Courses used to carry only an emoji, so every card blew that up on a tinted
/// panel. A course that sets a cover shows it instead; everything else keeps
/// the emoji — including while the image is still loading and when its URL is
/// dead, so a broken cover never leaves a hole in a card (BR-YKYXC6).
///
/// On web the cover is fetched straight from its URL first and only then
/// through the API image proxy. Going through the proxy alone made covers
/// drop back to the emoji at random (BR-MMAESQ): its rate limit is a single
/// bucket shared by every web user, and each image waits for one of the few
/// PHP workers. Our R2 buckets answer CORS for the app, so the direct fetch
/// normally just works; the proxy stays as the second attempt for covers
/// hosted anywhere that doesn't.
///
/// An SVG cover is drawn with flutter_svg. Image.network cannot decode SVG on
/// any platform, so such a cover always ended up as the emoji, while the admin
/// preview (a browser `<img>`) showed it fine (BR-NE9RTA).
class CourseCoverImage extends StatelessWidget {
  /// Cover URL from the course JSON (`header_image.url`). Null/blank falls
  /// straight through to [fallback].
  final String? url;

  /// What to draw when there is no usable cover — normally the emoji tile.
  final Widget fallback;

  final BoxFit fit;
  final double? width;
  final double? height;

  const CourseCoverImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  /// The cover URL held in a course JSON map, or null when it has none.
  static String? urlFrom(Map<String, dynamic>? courseData) {
    final image = courseData?['header_image'];
    if (image is! Map) return null;
    final url = (image['url'] as String?)?.trim();
    return (url == null || url.isEmpty) ? null : url;
  }

  /// The URLs to try for [url], in order.
  @visibleForTesting
  static List<String> sourcesFor(String url, {bool web = kIsWeb}) {
    if (!web) return [url];
    final proxied = proxyImageUrl(url);
    return proxied == url ? [url] : [url, proxied];
  }

  /// Lets tests exercise the web path, which `kIsWeb` pins off in the VM.
  @visibleForTesting
  static bool? debugWebOverride;

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim();
    if (raw == null || raw.isEmpty) return fallback;

    // Decided on the cover URL itself: the proxied one has it percent-encoded.
    final lower = raw.toLowerCase();
    final isSvg = lower.endsWith('.svg') || lower.contains('.svg?');

    return _load(sourcesFor(raw, web: debugWebOverride ?? kIsWeb), isSvg);
  }

  /// Loads the first of [sources] and moves on to the next when it fails.
  Widget _load(List<String> sources, bool isSvg) {
    if (sources.isEmpty) return fallback;

    if (isSvg) {
      return SvgPicture.network(
        sources.first,
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: (context) => fallback,
        errorBuilder: (context, error, stack) =>
            _load(sources.sublist(1), isSvg),
      );
    }

    return Image.network(
      sources.first,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stack) =>
          _load(sources.sublist(1), isSvg),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null ? child : fallback,
    );
  }
}
