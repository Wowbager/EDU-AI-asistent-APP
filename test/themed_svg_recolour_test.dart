import 'dart:io';

import 'package:eduai/widgets/themed_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette swap behind BR-A6TZZX: brand SVGs bake their colours in, so a
/// theme change has to rewrite the source before it reaches flutter_svg.
void main() {
  const ocean = <String, Color>{
    '#AFA3F6': Color(0xFF64B5F6),
    '#3C315B': Color(0xFF1A3A5C),
    'white': Color(0xFFFFFFFF),
  };

  test('swaps both fill and stroke, and leaves fill="none" alone', () {
    const svg = '<svg><path fill="#AFA3F6"/><path fill="none" '
        'stroke="#3C315B"/><path stroke="white"/></svg>';

    expect(
      ThemedSvg.recolour(svg, ocean),
      '<svg><path fill="#64B5F6"/><path fill="none" '
      'stroke="#1A3A5C"/><path stroke="#FFFFFF"/></svg>',
    );
  });

  test('matches hexes however the design tool cased them', () {
    expect(
      ThemedSvg.recolour('<path fill="#afa3f6"/>', ocean),
      '<path fill="#64B5F6"/>',
    );
  });

  test('leaves the source untouched when the palette equals the defaults', () {
    // Default.json maps 1:1 onto the baked colours, so the mark must not shift
    // for users who never picked a profile.
    const defaults = <String, Color>{
      '#AFA3F6': Color(0xFFAFA3F6),
      '#3C315B': Color(0xFF3C315B),
      'white': Color(0xFFFFFFFF),
    };
    const svg = '<svg><path fill="#AFA3F6" stroke="#3C315B"/></svg>';

    expect(ThemedSvg.recolour(svg, defaults), svg);
  });

  test('every baked colour in the personalisation icon is themed', () {
    final source =
        File('assets/icons/personalisation.svg').readAsStringSync();
    final themed = ThemedSvg.recolour(source, ocean);

    expect(themed, isNot(contains('#AFA3F6')));
    expect(themed, isNot(contains('#3C315B')));
    expect(themed, isNot(contains('="white"')));
    expect(themed, contains('#64B5F6'));
  });

  testWidgets('falls back to the raw asset when precache never ran',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ThemedSvg('assets/icons/does-not-exist.svg', width: 24),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
