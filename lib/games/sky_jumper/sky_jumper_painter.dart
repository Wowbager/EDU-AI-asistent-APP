import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'sky_jumper_sprites.dart';
import 'sky_jumper_world.dart';

/// Draws a [SkyJumperWorld].
///
/// Platforms and coins use the delivered artwork when [sprites] is available
/// and fall back to coloured blocks when it is not — a failed asset load costs
/// the game its looks, never its playability. The player is the user's own
/// avatar when one could be composed, and a primitive shape otherwise.
class SkyJumperPainter extends CustomPainter {
  final SkyJumperWorld world;

  /// Rendered separately from the world so the parallax backdrop can drift at
  /// its own rate without touching the simulation.
  final double cloudScroll;

  /// Null until the assets finish loading, and after a load failure.
  final SkyJumperSprites? sprites;

  /// The player's composed avatar, already flattened to a bitmap.
  ///
  /// Rasterising the layered SVGs here would mean redoing it 60 times a
  /// second; the caller does it once and hands over a sprite to blit. Null
  /// keeps the primitive player below.
  final ui.Image? avatarSprite;

  SkyJumperPainter({
    required this.world,
    required this.cloudScroll,
    this.sprites,
    this.avatarSprite,
  });

  /// Full turns per second of the coin spin.
  static const _coinSpinSpeed = 0.9;

  /// How flat a coin gets edge-on. Never fully zero, or it vanishes.
  static const _coinMinSquash = 0.12;

  static const _skyTop = Color(0xFF7EC8EE);
  static const _skyBottom = Color(0xFFCDEBF9);
  static const _coinFill = Color(0xFFA855F7);
  static const _coinRim = Color(0xFF7E22CE);
  static const _boostFill = Color(0xFFE9A227);
  static const _boostRim = Color(0xFF9C5A12);
  static const _playerFill = Color(0xFFC792EA);
  static const _playerDark = Color(0xFF4C1D95);

  static const _platformColors = {
    PlatformKind.grass: (Color(0xFF7CC576), Color(0xFF9A7B4F)),
    PlatformKind.wood: (Color(0xFFC08A4A), Color(0xFF8A5F30)),
  };

  /// World y → screen y. The world grows upwards, the canvas downwards.
  double _screenY(double worldY, double height) => height - (worldY - world.cameraY);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawClouds(canvas, size);

    for (final platform in world.platforms) {
      _drawPlatform(canvas, size, platform);
    }
    for (final coin in world.coins) {
      _drawCoin(canvas, size, coin);
    }
    _drawTrail(canvas, size);
    _drawPlayer(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyBottom],
        ).createShader(rect),
    );
  }

  void _drawClouds(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.75);

    // Deterministic positions from the index — a cloud must not jitter between
    // frames, and this avoids keeping a second list in the world.
    for (var i = 0; i < 8; i++) {
      final band = size.height / 4;
      final y = ((i * 137.0 + cloudScroll * 0.25) % (size.height + band)) - band / 2;
      final x = (i.isEven ? 0.18 : 0.66) * size.width + (i % 3) * 24.0;
      final scale = 0.7 + (i % 3) * 0.25;

      _drawCloud(canvas, Offset(x, y), 34 * scale, paint);
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center.translate(radius * 0.8, radius * 0.2), radius * 0.75, paint);
    canvas.drawCircle(center.translate(-radius * 0.8, radius * 0.25), radius * 0.65, paint);
  }

  void _drawPlatform(Canvas canvas, Size size, Platform platform) {
    final screenY = _screenY(platform.y, size.height);
    if (screenY < -platform.height * 4 || screenY > size.height + platform.height * 4) {
      return;
    }

    final sprite = switch (platform.kind) {
      PlatformKind.grass => sprites?.grassPlatform,
      PlatformKind.wood => sprites?.woodPlatform,
    };

    if (sprite != null) {
      // The art is drawn at its own aspect ratio and hung off the collision
      // surface, so what the player lands on is the top of what they see.
      final height = platform.width / sprite.aspectRatio;
      sprite.paint(
        canvas,
        Rect.fromLTWH(
          platform.x - platform.width / 2,
          screenY,
          platform.width,
          height,
        ),
      );
      return;
    }

    _drawPlatformPlaceholder(canvas, platform, screenY);
  }

  void _drawPlatformPlaceholder(Canvas canvas, Platform platform, double screenY) {
    final (top, side) = _platformColors[platform.kind]!;

    final rect = Rect.fromLTWH(
      platform.x - platform.width / 2,
      screenY,
      platform.width,
      platform.height,
    );
    final radius = BorderRadius.circular(platform.height * 0.35);

    // Body first, then a lighter cap: reads as a solid block at a glance,
    // which is what the placeholder needs to do.
    canvas.drawRRect(radius.toRRect(rect.translate(0, 2)), Paint()..color = side);
    canvas.drawRRect(
      radius.toRRect(Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.6)),
      Paint()..color = top,
    );
  }

  /// Coins spin about their vertical axis.
  ///
  /// A real 3D rotation is not worth a matrix here: squashing the horizontal
  /// axis by cos(angle) is exactly what a spinning disc projects to. The face
  /// is darkened as it turns away so the flip reads as depth rather than as a
  /// coin being squeezed.
  void _drawCoin(Canvas canvas, Size size, Coin coin) {
    final screenY = _screenY(coin.y, size.height);
    if (screenY < -coin.radius * 2 || screenY > size.height + coin.radius * 2) return;

    final center = Offset(coin.x, screenY);
    final angle = coin.spinPhase + world.elapsed * _coinSpinSpeed * pi * 2;
    final facing = cos(angle);
    final squash = max(facing.abs(), _coinMinSquash);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(squash, 1);

    final sprite =
        coin.kind == CoinKind.boost ? sprites?.boostCoin : sprites?.eduCoin;

    if (sprite != null) {
      // Edge-on is the darkest point of the turn, head-on the brightest.
      final shade = 0.55 + 0.45 * facing.abs();
      sprite.paint(
        canvas,
        Rect.fromCircle(center: Offset.zero, radius: coin.radius),
        paint: Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.black.withValues(alpha: 1 - shade),
            BlendMode.srcATop,
          ),
      );
    } else {
      _drawCoinPlaceholder(canvas, coin);
    }

    canvas.restore();
  }

  void _drawCoinPlaceholder(Canvas canvas, Coin coin) {
    final boost = coin.kind == CoinKind.boost;
    canvas.drawCircle(
      Offset.zero,
      coin.radius,
      Paint()..color = boost ? _boostRim : _coinRim,
    );
    canvas.drawCircle(
      Offset.zero,
      coin.radius * 0.82,
      Paint()..color = boost ? _boostFill : _coinFill,
    );

    final label = TextPainter(
      text: TextSpan(
        text: boost ? '★' : 'E',
        style: TextStyle(
          color: Colors.white,
          fontSize: coin.radius,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, -Offset(label.width / 2, label.height / 2));
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final radius = world.setup.playerRadius;
    final center = Offset(world.playerX, _screenY(world.playerY, size.height));

    // Squash while falling, stretch while rising — the cheapest way to make a
    // placeholder circle read as a character with weight.
    final speed = (world.playerVy / world.setup.bounceVelocity).clamp(-1.0, 1.0);
    final stretch = 1 + speed * 0.12;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1 / stretch, stretch);

    final sprite = avatarSprite;
    if (sprite != null) {
      // The avatar is authored on a square canvas standing upright, so it maps
      // onto a square centred on the player. Slightly taller than the collision
      // radius so the character reads as a body rather than a ball — the
      // physics still use `radius`, only the artwork overhangs.
      final box = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.6,
        height: radius * 2.6,
      );

      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
          0,
          0,
          sprite.width.toDouble(),
          sprite.height.toDouble(),
        ),
        box,
        Paint()..filterQuality = FilterQuality.medium,
      );

      canvas.restore();
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2.2),
        Radius.circular(radius * 0.8),
      ),
      Paint()..color = _playerFill,
    );

    // Face, so left/right is readable at speed.
    final eyeDx = radius * 0.34;
    final eyeDy = -radius * 0.2;
    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawCircle(Offset(dx, eyeDy), radius * 0.16, Paint()..color = _playerDark);
    }

    canvas.restore();
  }

  /// Rocket flame, shown only while riding a boost coin — that is the moment
  /// the design pictures. Drawn outside the player's squash transform.
  void _drawTrail(Canvas canvas, Size size) {
    if (!world.isBoosting) return;

    final radius = world.setup.playerRadius;
    final center = Offset(world.playerX, _screenY(world.playerY, size.height));
    final length = radius * 1.6 * (world.playerVy / world.setup.bounceVelocity);

    final path = Path()
      ..moveTo(center.dx - radius * 0.5, center.dy + radius)
      ..lineTo(center.dx + radius * 0.5, center.dy + radius)
      ..lineTo(center.dx, center.dy + radius + max(0, length))
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant SkyJumperPainter oldDelegate) => true;
}
