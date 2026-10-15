import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A rasterised game asset plus the part of it that is actually drawn on.
///
/// The delivered SVGs are all square 1024×1024 canvases with the artwork
/// floating somewhere inside — a platform occupies barely a fifth of its
/// canvas height. Drawing the whole square would leave the visible block far
/// smaller than its collision box, so every sprite carries the bounds of its
/// own opaque pixels and is drawn from that sub-rect.
///
/// The bounds are *measured*, not hardcoded, so replacing an asset with one
/// cropped differently needs no code change.
class GameSprite {
  final ui.Image image;

  /// Opaque bounds within [image], in image pixels.
  final Rect content;

  const GameSprite({required this.image, required this.content});

  double get aspectRatio => content.width / content.height;

  /// Draw the artwork so it fills [destination] exactly.
  void paint(Canvas canvas, Rect destination, {Paint? paint}) {
    canvas.drawImageRect(image, content, destination, paint ?? Paint());
  }

  void dispose() => image.dispose();
}

/// Every asset Sky Jumper draws.
class SkyJumperSprites {
  final GameSprite grassPlatform;
  final GameSprite woodPlatform;
  final GameSprite eduCoin;
  final GameSprite boostCoin;

  const SkyJumperSprites({
    required this.grassPlatform,
    required this.woodPlatform,
    required this.eduCoin,
    required this.boostCoin,
  });

  static const _dir = 'assets/games/sky_jumper';

  /// Rasterise every asset once, up front.
  ///
  /// Returns null if anything fails to load. That is deliberate: the painter
  /// falls back to the coloured-block placeholders, so a missing or corrupt
  /// asset costs the game its looks and not its playability.
  static Future<SkyJumperSprites?> load() async {
    try {
      final sprites = await Future.wait([
        // The coins are drawn small; the outline variants stay legible against
        // a busy sky where the plain ones wash out.
        _rasterize('$_dir/minihra_blok1.svg', 512),
        _rasterize('$_dir/minihra_blok2.svg', 512),
        _rasterize('$_dir/educoin_outline.svg', 256),
        _rasterize('$_dir/boostcoin_outline.svg', 256),
      ]);

      return SkyJumperSprites(
        grassPlatform: sprites[0],
        woodPlatform: sprites[1],
        eduCoin: sprites[2],
        boostCoin: sprites[3],
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    grassPlatform.dispose();
    woodPlatform.dispose();
    eduCoin.dispose();
    boostCoin.dispose();
  }

  /// Render an SVG asset into a [size]×[size] image and measure its artwork.
  static Future<GameSprite> _rasterize(String assetPath, int size) async {
    final pictureInfo = await vg.loadPicture(SvgAssetLoader(assetPath), null);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(
      size / pictureInfo.size.width,
      size / pictureInfo.size.height,
    );
    canvas.drawPicture(pictureInfo.picture);
    pictureInfo.picture.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();

    return GameSprite(
      image: image,
      content: await _opaqueBounds(image) ?? Offset.zero & Size(size.toDouble(), size.toDouble()),
    );
  }

  /// Bounding box of the pixels that are not fully transparent.
  ///
  /// Runs once per asset at load, so a straight scan is cheap enough and
  /// avoids shipping per-asset magic numbers that silently go stale.
  static Future<Rect?> _opaqueBounds(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final pixels = data.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    var left = width, top = height, right = -1, bottom = -1;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // Ignore near-transparent edges so antialiasing does not inflate the box.
        if (pixels[(y * width + x) * 4 + 3] < 8) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }

    if (right < 0) return null;
    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      (right + 1).toDouble(),
      (bottom + 1).toDouble(),
    );
  }
}
