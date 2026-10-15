import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/util/svg_bounds.dart';
import '../models/avatar_model.dart';

/// Renders a composed avatar by stacking its equipped layers.
///
/// Every cosmetic is authored on one shared 1024×1024 canvas
/// (`viewBox="0 0 270.93 270.93"`), so composition is a plain [Stack] of
/// full-bleed layers — no per-item offsets, anchors or scale factors. Getting
/// the *order* right is the entire job, and that comes from
/// [AvatarState.equippedLayers], which sorts by the server-owned `layer`.
class AvatarView extends StatelessWidget {
  /// The layers to draw, already sorted back-to-front.
  final List<AvatarItem> layers;

  /// Side length of the square the avatar is drawn into. Null fills the parent.
  final double? size;

  /// How much of the box the figure should occupy once cropped. 1.0 touches
  /// the edges; the default leaves a little air so nothing looks clipped.
  final double fill;

  const AvatarView({
    super.key,
    required this.layers,
    this.size,
    this.fill = 0.98,
  });

  /// Convenience constructor from a resolved [AvatarState].
  factory AvatarView.fromState(
    AvatarState state, {
    Key? key,
    double? size,
    double fill = 0.98,
  }) {
    return AvatarView(
      key: key,
      layers: state.equippedLayers,
      size: size,
      fill: fill,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The union of the worn layers, not each layer's own box: cropping them
    // separately would scale a hat and a body by different factors and tear
    // the figure apart. One shared crop keeps the composition intact and only
    // removes the dead canvas margin around the whole thing.
    final content = unionBounds(
      layers.map((l) => l.contentBounds).whereType<Rect>(),
    );

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in layers)
          // `svgSource` is non-null for everything `equippedLayers` returns —
          // undrawable items are filtered out there rather than rendered as a
          // gap here.
          SvgPicture.string(
            layer.svgSource!,
            fit: BoxFit.contain,
            // Layers must line up pixel-for-pixel; letting one of them align
            // differently would shear the composition apart.
            alignment: Alignment.center,
          ),
      ],
    );

    Widget cropped(double side) {
      // No measurement yet — draw the raw canvas rather than guessing a crop.
      if (content == null) {
        return SizedBox(width: side, height: side, child: stack);
      }

      return SizedBox(
        width: side,
        height: side,
        child: ClipRect(
          child: Transform(
            transform: cropTransform(content, side, fill: fill),
            child: SizedBox(width: side, height: side, child: stack),
          ),
        ),
      );
    }

    final fixed = size;
    if (fixed != null) return cropped(fixed);

    return LayoutBuilder(
      builder: (context, constraints) => cropped(
        constraints.biggest.shortestSide,
      ),
    );
  }
}

/// Flattens an avatar into a single bitmap.
///
/// Games draw the player every frame from a [CustomPainter]; re-rasterising a
/// stack of SVGs at 60 fps would not hold frame budget. Composing once up front
/// turns the avatar into an ordinary sprite blit.
class AvatarRasterizer {
  const AvatarRasterizer._();

  /// Compose [layers] into a [ui.Image] of [size]×[size] logical pixels.
  ///
  /// Returns null when there is nothing drawable, so callers can fall back to
  /// their primitive artwork instead of showing an empty player.
  static Future<ui.Image?> rasterize(
    List<AvatarItem> layers, {
    double size = 256,
  }) async {
    if (layers.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Crop to the figure for the same reason the widget does: a sprite that is
    // half transparent margin draws the player at half the size the game asked
    // for. One shared transform, so the layers stay aligned.
    final content = unionBounds(
      layers.map((l) => l.contentBounds).whereType<Rect>(),
    );
    if (content != null) {
      canvas.transform(cropTransform(content, size).storage);
    }

    var drew = false;

    for (final layer in layers) {
      final svg = layer.svgSource;
      if (svg == null) continue;

      final info = await vg.loadPicture(SvgStringLoader(svg), null);

      canvas.save();
      // Every asset shares the same square viewBox, so one uniform scale maps
      // all of them onto the target canvas identically.
      canvas.scale(size / info.size.width, size / info.size.height);
      canvas.drawPicture(info.picture);
      canvas.restore();

      info.picture.dispose();
      drew = true;
    }

    if (!drew) return null;

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    picture.dispose();

    return image;
  }
}
