// Sky Jumper artwork: rasterising the delivered SVGs and measuring them.
//
// Guards the asset pipeline, which is otherwise invisible — the painter falls
// back to coloured blocks when loading fails, so a wrong path or a broken SVG
// would ship as "the game looks like placeholders" and nothing louder.
//
//   flutter test test/games/sky_jumper_sprites_test.dart
import 'package:eduai/games/sky_jumper/sky_jumper_sprites.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rasterising needs real async work, which `runAsync` allows and the fake
/// async of a plain pump does not.
Future<SkyJumperSprites> loadSprites(WidgetTester tester) async {
  SkyJumperSprites? loaded;
  await tester.runAsync(() async {
    loaded = await SkyJumperSprites.load();
  });

  final sprites = loaded;
  if (sprites == null) {
    fail('all four Sky Jumper assets must load');
  }
  return sprites;
}

void main() {
  testWidgets('every delivered asset rasterises', (tester) async {
    final sprites = await loadSprites(tester);

    expect(sprites.grassPlatform.image.width, greaterThan(0));
    expect(sprites.woodPlatform.image.width, greaterThan(0));
    expect(sprites.eduCoin.image.width, greaterThan(0));
    expect(sprites.boostCoin.image.width, greaterThan(0));

    sprites.dispose();
  });

  testWidgets('a platform is measured as the wide block it is', (tester) async {
    final sprites = await loadSprites(tester);

    // The artwork sits in a square canvas with a lot of empty space; measuring
    // its opaque bounds is what stops it being drawn a fifth of its size.
    // Both delivered blocks are roughly 3.6:1.
    for (final platform in [sprites.grassPlatform, sprites.woodPlatform]) {
      expect(platform.aspectRatio, greaterThan(3.0));
      expect(platform.aspectRatio, lessThan(4.5));
      expect(
        platform.content.height,
        lessThan(platform.image.height * 0.5),
        reason: 'measured bounds must be tighter than the whole canvas',
      );
    }

    sprites.dispose();
  });

  testWidgets('a coin is measured as round', (tester) async {
    final sprites = await loadSprites(tester);

    for (final coin in [sprites.eduCoin, sprites.boostCoin]) {
      expect(coin.aspectRatio, closeTo(1.0, 0.05));
      // Measured at ~34% of the canvas; anything near 100% would mean the
      // bounds were never measured.
      expect(coin.content.width / coin.image.width, lessThan(0.6));
    }

    sprites.dispose();
  });
}
