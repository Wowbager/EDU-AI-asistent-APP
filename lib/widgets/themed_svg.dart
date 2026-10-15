import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_theme.dart';
import '../core/util/silent_log.dart';

/// Renders an SVG asset with the palette the design file bakes in swapped for
/// the live theme colours (BR-A6TZZX).
///
/// Single-colour icons do not need this — a `colorFilter` on
/// [SvgPicture.asset] is cheaper and does the same job. This exists for marks
/// whose parts must stay distinguishable: `BlendMode.srcIn` would flatten the
/// personalisation face, its eyes and its highlights into one blob.
///
/// Sources are read once via [precache] so recolouring stays synchronous —
/// resolving `rootBundle.loadString` inside `build` would blink the header
/// empty on every theme switch.
class ThemedSvg extends StatelessWidget {
  /// Assets whose sources [precache] loads at startup.
  static const List<String> brandAssets = [
    'assets/icons/personalisation.svg',
  ];

  final String asset;
  final double? width;
  final double? height;

  /// Baked hex (as written in the file) → live colour. Defaults to
  /// [brandPalette].
  final Map<String, Color>? palette;

  const ThemedSvg(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.palette,
  });

  /// The colours the brand SVGs hard-code, mapped to their theme counterparts.
  ///
  /// The mapping is 1:1 with `assets/themes/default.json`, so the default
  /// palette renders byte-identically to the raw asset; only custom profiles
  /// shift.
  static Map<String, Color> get brandPalette => {
        '#AFA3F6': AppColors.progressFill,
        '#3C315B': AppColors.primaryDark,
        'white': AppColors.surface,
      };

  static final Map<String, String> _sources = {};

  /// asset → (palette signature, recoloured source). One entry per asset: the
  /// theme editor previews a new palette on every colour tweak, and an
  /// unbounded cache would keep every intermediate shade alive.
  static final Map<String, MapEntry<String, String>> _recoloured = {};

  /// Load the raw SVG sources. Call once during startup, before `runApp`.
  static Future<void> precache([List<String> assets = brandAssets]) async {
    for (final asset in assets) {
      try {
        _sources[asset] = await rootBundle.loadString(asset);
      } catch (e, st) {
        // A missing source only costs theming — [build] still draws the asset.
        silentLog('ThemedSvg:precache:$asset', e, st);
      }
    }
  }

  @visibleForTesting
  static void debugSetSource(String asset, String source) =>
      _sources[asset] = source;

  /// Replaces `fill=`/`stroke=` values listed in [palette]. Leaves everything
  /// else — notably `fill="none"` — untouched.
  @visibleForTesting
  static String recolour(String svg, Map<String, Color> palette) {
    var out = svg;
    palette.forEach((baked, colour) {
      final hex = '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      out = out.replaceAllMapped(
        RegExp('(fill|stroke)="${RegExp.escape(baked)}"', caseSensitive: false),
        (m) => '${m[1]}="$hex"',
      );
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final source = _sources[asset];
    if (source == null) {
      // Not precached (or the load failed): draw the asset as authored rather
      // than leaving a hole in the header.
      return SvgPicture.asset(asset, width: width, height: height);
    }

    final colours = palette ?? brandPalette;
    // Key on the resolved colours, not the theme name: the editor previews
    // unsaved palettes under a name that never changes.
    final signature = colours.values.map((c) => c.toARGB32()).join(',');
    var cached = _recoloured[asset];
    if (cached == null || cached.key != signature) {
      cached = MapEntry(signature, recolour(source, colours));
      _recoloured[asset] = cached;
    }
    final svg = cached.value;

    // `SvgStringLoader` compares by string content, so flutter_svg's picture
    // cache keeps this from re-parsing on every rebuild.
    return SvgPicture.string(svg, width: width, height: height);
  }
}
