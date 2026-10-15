// Cropping avatar artwork to its content (BR-7JRBCN).
//
// Assets are drawn where they belong on the body, so a crown is a small patch
// near the top of an otherwise empty 1024x1024 canvas. That is what makes
// layering work with no offsets — and what makes an item rendered on its own
// look like a speck in a big frame. These tests pin the measurement and the
// transform that fixes it, including the property that matters most: the whole
// figure is cropped by ONE shared box, never per layer.
//
//   flutter test test/avatar_bounds_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/util/svg_bounds.dart';

/// A filled square covering a known patch of the shared canvas.
String _svgRect({
  required double x,
  required double y,
  required double w,
  required double h,
}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<rect x="$x" y="$y" width="$w" height="$h" fill="#000"/></svg>';

/// Within one scan pixel (the measurement runs at 96x96).
const _tolerance = 1 / 96 + 1e-6;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeSvgContentBounds', () {
    test('measures a patch in the corner of an otherwise empty canvas',
        () async {
      // The crown case: 20% of the canvas, up and to the left.
      final bounds =
          await computeSvgContentBounds(_svgRect(x: 10, y: 5, w: 20, h: 20));

      expect(bounds, isNotNull);
      expect(bounds!.left, closeTo(0.10, _tolerance));
      expect(bounds.top, closeTo(0.05, _tolerance));
      expect(bounds.right, closeTo(0.30, _tolerance));
      expect(bounds.bottom, closeTo(0.25, _tolerance));
    });

    test('a full-bleed asset measures as the whole canvas', () async {
      final bounds =
          await computeSvgContentBounds(_svgRect(x: 0, y: 0, w: 100, h: 100));

      expect(bounds, isNotNull);
      expect(bounds!.left, closeTo(0, _tolerance));
      expect(bounds.top, closeTo(0, _tolerance));
      expect(bounds.right, closeTo(1, _tolerance));
      expect(bounds.bottom, closeTo(1, _tolerance));
    });

    test('artwork that draws nothing has no bounds', () async {
      final bounds = await computeSvgContentBounds(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"></svg>',
      );

      expect(bounds, isNull);
    });

    test('malformed markup measures as nothing rather than throwing', () async {
      // A truncated download must degrade to "not measured", because the
      // caller stores this result and a thrown error would lose the artwork.
      expect(await computeSvgContentBounds('not an svg at all'), isNull);
    });
  });

  group('unionBounds', () {
    test('covers every layer', () {
      final union = unionBounds([
        const Rect.fromLTRB(0.2, 0.6, 0.8, 0.9), // body, low and wide
        const Rect.fromLTRB(0.35, 0.05, 0.65, 0.2), // hat, high and narrow
      ]);

      expect(union, const Rect.fromLTRB(0.2, 0.05, 0.8, 0.9));
    });

    test('is null when nothing was measured', () {
      expect(unionBounds(const []), isNull);
    });
  });

  group('cropTransform', () {
    test('scales a small patch up to fill the box', () {
      // A quarter-canvas item in a 200 px box should end up 200 px across.
      const content = Rect.fromLTRB(0.1, 0.1, 0.35, 0.35);
      final m = cropTransform(content, 200);

      final topLeft = MatrixUtils.transformPoint(m, const Offset(0.1 * 200, 0.1 * 200));
      final bottomRight =
          MatrixUtils.transformPoint(m, const Offset(0.35 * 200, 0.35 * 200));

      expect(topLeft.dx, closeTo(0, 0.01));
      expect(topLeft.dy, closeTo(0, 0.01));
      expect(bottomRight.dx, closeTo(200, 0.01));
      expect(bottomRight.dy, closeTo(200, 0.01));
    });

    test('fill leaves margin on all sides', () {
      const content = Rect.fromLTRB(0.1, 0.1, 0.35, 0.35);
      final m = cropTransform(content, 200, fill: 0.8);

      final topLeft = MatrixUtils.transformPoint(m, const Offset(20, 20));
      final bottomRight = MatrixUtils.transformPoint(m, const Offset(70, 70));

      // 80% of 200 = 160, centred → 20 px of air on each side.
      expect(topLeft.dx, closeTo(20, 0.01));
      expect(bottomRight.dx, closeTo(180, 0.01));
    });

    test('a non-square box keeps its aspect ratio', () {
      // A tall figure must not be stretched sideways to fill the square.
      const content = Rect.fromLTRB(0.4, 0.1, 0.6, 0.9);
      final m = cropTransform(content, 200);

      final left = MatrixUtils.transformPoint(m, const Offset(0.4 * 200, 0));
      final right = MatrixUtils.transformPoint(m, const Offset(0.6 * 200, 0));
      final top = MatrixUtils.transformPoint(m, const Offset(0, 0.1 * 200));
      final bottom = MatrixUtils.transformPoint(m, const Offset(0, 0.9 * 200));

      expect(bottom.dy - top.dy, closeTo(200, 0.01), reason: 'long edge fills');
      expect(right.dx - left.dx, closeTo(50, 0.01), reason: '1:4 stays 1:4');
    });

    test('one shared transform keeps layers aligned', () {
      // The whole point of cropping by the union: a hat and a body must move
      // and scale together, or the figure tears apart.
      const body = Rect.fromLTRB(0.2, 0.6, 0.8, 0.9);
      const hat = Rect.fromLTRB(0.35, 0.05, 0.65, 0.2);

      final m = cropTransform(unionBounds([body, hat])!, 200);

      // The hat sits above the body before the crop, and must still sit above
      // it after — by a proportionally identical gap.
      final hatBottom = MatrixUtils.transformPoint(m, const Offset(0, 0.2 * 200)).dy;
      final bodyTop = MatrixUtils.transformPoint(m, const Offset(0, 0.6 * 200)).dy;
      final bodyBottom = MatrixUtils.transformPoint(m, const Offset(0, 0.9 * 200)).dy;

      expect(hatBottom, lessThan(bodyTop));
      expect(
        (bodyTop - hatBottom) / (bodyBottom - bodyTop),
        closeTo((0.6 - 0.2) / (0.9 - 0.6), 0.001),
      );
    });

    test('a degenerate box is left alone rather than scaled to infinity', () {
      expect(cropTransform(Rect.zero, 200), Matrix4.identity());
    });
  });
}
