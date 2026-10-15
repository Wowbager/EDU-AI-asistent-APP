import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/media/lesson_image_cache.dart';
import '../core/utils/image_url.dart';

/// A picture inside a lesson — image blocks, step images, question feedback
/// and solution images, and pictures in markdown or HTML text.
///
/// Loads through [LessonImageCache], so a picture the device has kept still
/// shows offline (BR-BX9AA4), and one that failed tries again as soon as the
/// device is back online instead of waiting for something else to rebuild it.
/// Raster and SVG sources are both handled.
///
/// On web there is no cache: the picture loads from [resolveImageUrl] exactly
/// as `Image.network` / `SvgPicture.network` did before.
class LessonImage extends StatefulWidget {
  /// The picture's address as it appears in the course content.
  final String url;
  final BoxFit? fit;
  final double? width;

  /// Also caps an SVG's height, which defaults to 240 — an SVG has no pixel
  /// size of its own to stop at.
  final double? height;
  final ImageLoadingBuilder? loadingBuilder;

  /// Shown while an SVG loads; raster pictures use [loadingBuilder].
  final Widget? svgPlaceholder;

  /// Shown when the picture cannot be had. Defaults to nothing.
  final ImageErrorWidgetBuilder? errorBuilder;

  const LessonImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.loadingBuilder,
    this.svgPlaceholder,
    this.errorBuilder,
  });

  @override
  State<LessonImage> createState() => _LessonImageState();
}

class _LessonImageState extends State<LessonImage> {
  /// Bumped when the device is back online after this picture failed; the
  /// picture below is keyed by it, so it resolves — and loads — again.
  int _attempt = 0;
  StreamSubscription<void>? _reconnect;

  @override
  void dispose() {
    _reconnect?.cancel();
    super.dispose();
  }

  void _retryOnReconnect() {
    if (_reconnect != null) return;
    _reconnect = LessonImageCache.instance.reconnects.listen((_) {
      _reconnect?.cancel();
      _reconnect = null;
      if (mounted) setState(() => _attempt++);
    });
  }

  Widget _fallback(BuildContext context, Object error, StackTrace? stack) {
    _retryOnReconnect();
    return widget.errorBuilder?.call(context, error, stack) ??
        const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final cache = LessonImageCache.instance;
    final url = resolveImageUrl(widget.url);
    final lower = url.toLowerCase();
    final isSvg = lower.endsWith('.svg') || lower.contains('.svg?');

    if (isSvg) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: widget.height ?? 240,
          maxWidth: widget.width ?? double.infinity,
        ),
        child: SvgPicture(
          cache.isSupported
              ? LessonSvgLoader(widget.url, attempt: _attempt)
              : SvgNetworkLoader(url),
          key: ValueKey(_attempt),
          fit: widget.fit ?? BoxFit.contain,
          placeholderBuilder: widget.svgPlaceholder != null
              ? (_) => widget.svgPlaceholder!
              : null,
          errorBuilder: _fallback,
        ),
      );
    }

    return Image(
      key: ValueKey(_attempt),
      image: cache.isSupported ? LessonImageProvider(widget.url) : NetworkImage(url),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: _fallback,
    );
  }
}

/// Raster lesson picture loaded through [LessonImageCache] — network first,
/// the copy on disk when the network fails.
@immutable
class LessonImageProvider extends ImageProvider<LessonImageProvider> {
  final String url;

  const LessonImageProvider(this.url);

  @override
  Future<LessonImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<LessonImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    LessonImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode, chunkEvents),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<LessonImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _load(
    LessonImageProvider key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    try {
      final bytes = await LessonImageCache.instance.load(
        key.url,
        onProgress: (received, total) => chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: received,
          expectedTotalBytes: total,
        )),
      );
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // As NetworkImage does: forget the failed key, so the next resolve (the
      // reconnect retry, or any rebuild) loads the picture again rather than
      // replaying the failure. The microtask gives the image cache the chance
      // to have tracked the key first.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      unawaited(chunkEvents.close());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LessonImageProvider && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'LessonImageProvider')}("$url")';
}

/// SVG lesson picture loaded through [LessonImageCache].
///
/// [attempt] is part of the cache key: flutter_svg keeps a failed load as
/// pending forever, so a retry under the same key would only replay the
/// failure.
@immutable
class LessonSvgLoader extends SvgLoader<Uint8List> {
  final String url;
  final int attempt;

  const LessonSvgLoader(this.url, {this.attempt = 0});

  @override
  Future<Uint8List?> prepareMessage(BuildContext? context) =>
      LessonImageCache.instance.load(url);

  @override
  String provideSvg(Uint8List? message) =>
      utf8.decode(message!, allowMalformed: true);

  @override
  bool operator ==(Object other) =>
      other is LessonSvgLoader &&
      other.url == url &&
      other.attempt == attempt &&
      other.theme == theme &&
      other.colorMapper == colorMapper;

  @override
  int get hashCode => Object.hash(url, attempt, theme, colorMapper);

  @override
  String toString() => 'LessonSvgLoader($url, attempt: $attempt)';
}

/// `sizedImageBuilder` for flutter_markdown: `![](https://…)` pictures go
/// through [LessonImage]. flutter_markdown's own builder is a bare
/// `Image.network` whose error state is an empty box — offline, pictures in
/// lesson text simply vanished (BR-BX9AA4).
///
/// Null on web, where markdown keeps loading pictures straight from their
/// URL — [LessonImage] there would send them through the rate-limited API
/// image proxy instead.
MarkdownSizedImageBuilder? lessonMarkdownImageBuilder() {
  if (!LessonImageCache.instance.isSupported) return null;
  return (config) {
    final uri = config.uri;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return LessonImage(
        url: uri.toString(),
        width: config.width,
        height: config.height,
      );
    }
    final data = uri.data;
    if (data != null) {
      return Image.memory(
        data.contentAsBytes(),
        width: config.width,
        height: config.height,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  };
}

/// flutter_html extensions that draw `<img src="https://…">` in lesson HTML
/// through [LessonImage]. Empty on web, where the HTML's image URLs are
/// already rewritten to the proxy by `resolveHtmlImageUrls`.
List<HtmlExtension> lessonHtmlImageExtensions() {
  if (!LessonImageCache.instance.isSupported) return const [];
  return [
    ImageExtension(
      handleAssetImages: false,
      handleDataImages: false,
      builder: (context) {
        final src = context.attributes['src'];
        if (src == null || src.isEmpty) return const SizedBox.shrink();
        return LessonImage(
          url: src,
          width: double.tryParse(context.attributes['width'] ?? ''),
          height: double.tryParse(context.attributes['height'] ?? ''),
        );
      },
    ),
  ];
}
