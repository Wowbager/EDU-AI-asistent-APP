import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Resolution the alpha scan runs at. Coarse on purpose: the result only has
/// to be accurate to about a percent of the canvas, and 96×96 is ~9k pixels
/// instead of the million a full-size scan would touch.
const _scanResolution = 96;

/// Alpha below this counts as empty — antialiased edges and near-invisible
/// artefacts must not inflate the box.
const _alphaThreshold = 8;

/// The tight bounding box of an SVG's visible content, in normalised canvas
/// coordinates (0..1 on both axes).
///
/// Every avatar asset is authored on the same 1024×1024 canvas with the item
/// sitting wherever it belongs on the body — a crown occupies a small patch
/// near the top and nothing else. That is exactly what makes layering work
/// without offsets, and exactly what makes a single item render as mostly
/// empty space when shown on its own. Knowing the box lets the UI crop to the
/// artwork while the stored geometry stays untouched.
///
/// Returns null for artwork that draws nothing.
Future<Rect?> computeSvgContentBounds(String svg) async {
  ui.Image? image;

  try {
    final info = await vg.loadPicture(SvgStringLoader(svg), null);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(
      _scanResolution / info.size.width,
      _scanResolution / info.size.height,
    );
    canvas.drawPicture(info.picture);
    info.picture.dispose();

    final picture = recorder.endRecording();
    image = await picture.toImage(_scanResolution, _scanResolution);
    picture.dispose();

    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final pixels = data.buffer.asUint8List();

    var minX = _scanResolution;
    var minY = _scanResolution;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < _scanResolution; y++) {
      for (var x = 0; x < _scanResolution; x++) {
        // RGBA — alpha is the fourth byte of each pixel.
        if (pixels[(y * _scanResolution + x) * 4 + 3] < _alphaThreshold) {
          continue;
        }
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX < 0 || maxY < 0) return null;

    // +1 on the far edge: a hit at pixel `maxX` covers up to `maxX + 1`.
    return Rect.fromLTRB(
      minX / _scanResolution,
      minY / _scanResolution,
      (maxX + 1) / _scanResolution,
      (maxY + 1) / _scanResolution,
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
  }
}

/// The smallest box containing all of [boxes], or null when there are none.
///
/// Used to crop a composed avatar: taking the union rather than cropping each
/// layer separately is what keeps the layers aligned with one another while
/// still dropping the dead margin around the whole figure.
Rect? unionBounds(Iterable<Rect> boxes) {
  Rect? result;
  for (final box in boxes) {
    result = result == null ? box : result.expandToInclude(box);
  }
  return result;
}

/// Fits [content] (normalised 0..1) into a [side]×[side] box.
///
/// [fill] is how much of the box the artwork should occupy — 1.0 touches the
/// edges, lower values leave breathing room. Scaling by the longer edge keeps
/// the aspect ratio, so a wide item and a tall one stay comparable.
Matrix4 cropTransform(Rect content, double side, {double fill = 1.0}) {
  final extent = content.longestSide;
  if (extent <= 0) return Matrix4.identity();

  final scale = fill / extent;
  final center = content.center;

  return Matrix4.identity()
    ..translate(
      side / 2 - center.dx * side * scale,
      side / 2 - center.dy * side * scale,
    )
    ..scale(scale);
}
