// Sky Jumper physics and level generation.
//
// Pure Dart — no widgets, no plugins:
//   flutter test test/games/sky_jumper_world_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/games/sky_jumper/sky_jumper_setup.dart';
import 'package:eduai/games/sky_jumper/sky_jumper_world.dart';

const _view = Size2D(width: 400, height: 800);

SkyJumperWorld makeWorld({SkyJumperSetup? setup, int seed = 1}) {
  return SkyJumperWorld(
    setup: setup ?? const SkyJumperSetup(),
    view: _view,
    seed: seed,
  );
}

/// Player centre for "feet resting just above [platform]".
///
/// Derived from the radius rather than a fixed offset: a bigger avatar would
/// otherwise start already sunk into the platform and never register a landing.
double justAbove(Platform platform, {SkyJumperSetup? setup}) =>
    platform.y + (setup ?? const SkyJumperSetup()).playerRadius + 2;

/// Sideways distance between two platforms, counting the screen wrap — leaving
/// one edge puts the player back on the other, so that is the shorter route.
double wrappedDistance(double a, double b, double width) {
  final direct = (a - b).abs();
  return direct <= width - direct ? direct : width - direct;
}

double averageGap(List<Platform> platforms) {
  final ys = platforms.map((p) => p.y).toList()..sort();
  if (ys.length < 2) return 0;
  return (ys.last - ys.first) / (ys.length - 1);
}

/// Advance the world by [seconds] in 60 Hz slices, as the render loop does.
void run(SkyJumperWorld world, double seconds, {double tilt = 0}) {
  const frame = 1 / 60;
  for (var t = 0.0; t < seconds; t += frame) {
    world.step(frame, tilt);
  }
}

void main() {
  group('gravity and bouncing', () {
    test('gravity slows the player every frame while rising', () {
      final world = makeWorld();
      // Rising, so no landing can interfere: the bounce only fires falling.
      world.debugPlacePlayer(x: 200, y: 5000, vy: 500);

      world.step(1 / 60, 0);
      final afterOneFrame = world.playerVy;
      world.step(1 / 60, 0);

      expect(afterOneFrame, lessThan(500));
      expect(world.playerVy, lessThan(afterOneFrame));
    });

    test('landing on a platform from above bounces the player up', () {
      final world = makeWorld();
      final platform = world.platforms.first;
      world.debugPlacePlayer(
        x: platform.x,
        y: justAbove(platform),
        vy: -400,
      );

      world.step(1 / 60, 0);

      expect(world.playerVy, greaterThan(0));
    });

    test('rising through a platform does not bounce the player', () {
      final world = makeWorld();
      final platform = world.platforms.first;
      world.debugPlacePlayer(
        x: platform.x,
        y: platform.y - const SkyJumperSetup().playerRadius - 2,
        vy: 400,
      );

      world.step(1 / 60, 0);

      expect(world.playerVy, lessThan(400));
      expect(world.playerVy, greaterThan(0));
    });

    test('the bounce is the same however hard the player lands', () {
      // Constant bounce height is what lets the generator promise every gap is
      // jumpable, so impact speed must not feed back into it.
      double bounceAfterImpact(double vy) {
        final world = makeWorld();
        final platform = world.platforms.first;
        world.debugPlacePlayer(x: platform.x, y: justAbove(platform), vy: vy);
        world.step(1 / 60, 0);
        return world.playerVy;
      }

      expect(bounceAfterImpact(-1200), closeTo(bounceAfterImpact(-400), 0.001));
    });
  });

  group('steering', () {
    test('tilting right moves the player right', () {
      final world = makeWorld();
      final startX = world.playerX;

      run(world, 0.5, tilt: 1);

      expect(world.playerX, greaterThan(startX));
    });

    test('tilting left moves the player left', () {
      final world = makeWorld();
      world.debugPlacePlayer(x: 200, y: world.playerY, vy: 0);

      run(world, 0.5, tilt: -1);

      expect(world.playerX, lessThan(200));
    });

    test('horizontal speed is capped', () {
      final world = makeWorld();

      run(world, 5, tilt: 1);

      expect(
        world.playerVx.abs(),
        lessThanOrEqualTo(const SkyJumperSetup().maxHorizontalSpeed + 0.01),
      );
    });

    test('leaving the screen on one side re-enters on the other', () {
      final world = makeWorld();
      world.debugPlacePlayer(x: _view.width - 1, y: world.playerY, vy: 0);

      run(world, 0.3, tilt: 1);

      expect(world.playerX, lessThan(100));
      expect(world.playerX, greaterThanOrEqualTo(0));
    });
  });

  group('camera and game over', () {
    test('the camera rises with the player but never falls back', () {
      final world = makeWorld();
      world.debugPlacePlayer(x: 200, y: 4000, vy: 0);
      world.step(1 / 60, 0);
      final raised = world.cameraY;

      // Now drop the player far below without letting it die yet.
      world.debugPlacePlayer(x: 200, y: 3900, vy: 0);
      world.step(1 / 60, 0);

      expect(raised, greaterThan(0));
      expect(world.cameraY, closeTo(raised, 0.01));
    });

    test('falling below the bottom of the view ends the run', () {
      final world = makeWorld();
      world.debugPlacePlayer(x: 200, y: 3000, vy: 0);
      world.step(1 / 60, 0);
      final bottom = world.cameraY;

      world.debugPlacePlayer(x: 200, y: bottom - 200, vy: -100);
      world.step(1 / 60, 0);

      expect(world.isGameOver, isTrue);
    });

    test('a finished run ignores further steps', () {
      final world = makeWorld();
      world.debugPlacePlayer(x: 200, y: -10000, vy: -100);
      world.step(1 / 60, 0);
      final frozenY = world.playerY;

      run(world, 1);

      expect(world.isGameOver, isTrue);
      expect(world.playerY, closeTo(frozenY, 0.01));
    });
  });

  group('score', () {
    test('score grows as the player climbs', () {
      final world = makeWorld();
      world.debugPlacePlayer(x: 200, y: 2000, vy: 0);
      world.step(1 / 60, 0);
      final low = world.score;

      world.debugPlacePlayer(x: 200, y: 6000, vy: 0);
      world.step(1 / 60, 0);

      expect(world.score, greaterThan(low));
    });

    test('score never drops when the player falls back down', () {
      final world = makeWorld();
      world.debugPlacePlayer(x: 200, y: 6000, vy: 0);
      world.step(1 / 60, 0);
      final peak = world.score;

      world.debugPlacePlayer(x: 200, y: 5500, vy: 0);
      world.step(1 / 60, 0);

      expect(world.score, peak);
    });

    test('a collected coin adds to the score', () {
      // coinChance 1 so "the first coin" is a fixture, not a dice roll.
      const setup = SkyJumperSetup(coinChance: 1);
      final world = makeWorld(setup: setup);
      final coin = world.coins.first;
      world.debugPlacePlayer(x: coin.x, y: coin.y, vy: 0);
      final before = world.score;

      world.step(1 / 60, 0);

      expect(world.collectedCoins, 1);
      expect(world.score, greaterThanOrEqualTo(before + setup.coinPoints));
    });

    test('a coin is collected only once', () {
      final world = makeWorld(setup: const SkyJumperSetup(coinChance: 1));
      final coin = world.coins.first;
      world.debugPlacePlayer(x: coin.x, y: coin.y, vy: 0);

      world.step(1 / 60, 0);
      world.step(1 / 60, 0);

      expect(world.collectedCoins, 1);
      expect(world.coins.any((c) => c.id == coin.id), isFalse);
    });
  });

  group('boost coins', () {
    test('a boost coin launches the player higher than a bounce', () {
      const setup = SkyJumperSetup(coinChance: 1, boostCoinChance: 1);
      final world = makeWorld(setup: setup);
      final coin = world.coins.first;
      expect(coin.kind, CoinKind.boost);

      world.debugPlacePlayer(x: coin.x, y: coin.y, vy: 0);
      world.step(1 / 60, 0);

      expect(world.playerVy, greaterThan(setup.bounceVelocity));
      expect(world.isBoosting, isTrue);
    });

    test('an ordinary coin does not launch the player', () {
      final world = makeWorld(
        setup: const SkyJumperSetup(coinChance: 1, boostCoinChance: 0),
      );
      final coin = world.coins.first;
      expect(coin.kind, CoinKind.edu);

      world.debugPlacePlayer(x: coin.x, y: coin.y, vy: 0);
      world.step(1 / 60, 0);

      expect(world.playerVy, lessThanOrEqualTo(0));
      expect(world.isBoosting, isFalse);
    });

    test('a boost coin is worth more than an ordinary one', () {
      int scoreAfterCoin({required double boostChance}) {
        final world = makeWorld(
          setup: SkyJumperSetup(coinChance: 1, boostCoinChance: boostChance),
        );
        final coin = world.coins.first;
        world.debugPlacePlayer(x: coin.x, y: coin.y, vy: 0);
        world.step(1 / 60, 0);
        return world.score;
      }

      expect(
        scoreAfterCoin(boostChance: 1),
        greaterThan(scoreAfterCoin(boostChance: 0)),
      );
    });

    test('the boost wears off so a run cannot climb forever', () {
      // No coins in this level: a world where every platform carries a boost
      // keeps topping the player up, which tests the fixture, not the decay.
      const setup = SkyJumperSetup(coinChance: 0);
      final world = makeWorld(setup: setup);
      world.debugPlacePlayer(
        x: 200,
        y: 3000,
        vy: setup.bounceVelocity * setup.boostMultiplier,
      );
      expect(world.isBoosting, isTrue);

      // Gravity alone must bring the launch speed back down.
      run(world, 1);

      expect(world.isBoosting, isFalse);
    });
  });

  group('player size', () {
    test('the player is narrower than the platforms it lands on', () {
      const setup = SkyJumperSetup();

      // Landing tolerance is derived from the radius, so a player as wide as a
      // platform would stick to ledges it is visibly nowhere near.
      expect(setup.playerRadius * 2, lessThan(setup.platformWidth));
    });

    test('an oversized player from the database is cut back down', () {
      final setup = SkyJumperSetup.fromJson(const {'player_radius': 400.0});

      expect(setup.playerRadius * 2, lessThan(setup.platformWidth));
    });

    test('the player still fits the view after growing', () {
      const setup = SkyJumperSetup();

      expect(setup.playerRadius * 2, lessThan(_view.width / 4));
    });
  });

  group('collapsing wooden platforms', () {
    /// A world holding one wooden platform and nothing else within reach.
    (SkyJumperWorld, Platform) worldWithWood() {
      final world = makeWorld(setup: const SkyJumperSetup(reliefChance: 1));
      final wood = world.platforms.firstWhere(
        (p) => p.kind == PlatformKind.wood,
      );
      return (world, wood);
    }

    test('landing on wood still launches the player onward', () {
      // The relief has to actually relieve: it collapses *after* handing over
      // the bounce, or it would be a trap rather than a shortcut.
      final (world, wood) = worldWithWood();
      world.debugPlacePlayer(x: wood.x, y: justAbove(wood), vy: -400);

      world.step(1 / 60, 0);

      expect(world.playerVy, closeTo(const SkyJumperSetup().bounceVelocity, 20));
    });

    test('wood starts falling once it has been used', () {
      final (world, wood) = worldWithWood();
      expect(wood.isFalling, isFalse);

      world.debugPlacePlayer(x: wood.x, y: justAbove(wood), vy: -400);
      world.step(1 / 60, 0);

      expect(wood.isFalling, isTrue);
    });

    test('a falling platform cannot be landed on again', () {
      final (world, wood) = worldWithWood();
      world.debugPlacePlayer(x: wood.x, y: justAbove(wood), vy: -400);
      world.step(1 / 60, 0);

      // Come back down onto the same spot while it is on its way out.
      final fallenTo = wood.y;
      world.debugPlacePlayer(x: wood.x, y: fallenTo + 30, vy: -400);
      world.step(1 / 60, 0);

      expect(world.playerVy, lessThan(0));
    });

    test('a used platform drops out of the level', () {
      final (world, wood) = worldWithWood();
      final startedAt = wood.y;
      world.debugPlacePlayer(x: wood.x, y: justAbove(wood), vy: -400);
      world.step(1 / 60, 0);

      run(world, 0.5);

      expect(wood.y, lessThan(startedAt));
    });

    test('grass never collapses, however often it is used', () {
      final world = makeWorld();
      final grass = world.platforms.first;
      expect(grass.kind, PlatformKind.grass);

      for (var i = 0; i < 3; i++) {
        world.debugPlacePlayer(x: grass.x, y: justAbove(grass), vy: -400);
        world.step(1 / 60, 0);
      }

      expect(grass.isFalling, isFalse);
      expect(world.playerVy, greaterThan(0));
    });
  });

  group('level generation', () {
    test('every platform is within reach of the one below it', () {
      const setup = SkyJumperSetup();
      final maxJump =
          (setup.bounceVelocity * setup.bounceVelocity) / (2 * setup.gravity);
      final world = makeWorld(setup: setup);

      // Climb far enough that the generator has produced many screens.
      for (var i = 0; i < 40; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      final ys = world.platforms.map((p) => p.y).toList()..sort();
      for (var i = 1; i < ys.length; i++) {
        expect(
          ys[i] - ys[i - 1],
          lessThanOrEqualTo(maxJump),
          reason: 'gap between platforms must be jumpable',
        );
      }
    });

    test('platforms stay inside the view horizontally', () {
      final world = makeWorld();

      for (var i = 0; i < 20; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      for (final p in world.platforms) {
        expect(p.x - p.width / 2, greaterThanOrEqualTo(0));
        expect(p.x + p.width / 2, lessThanOrEqualTo(_view.width));
      }
    });

    test('platforms left behind are dropped instead of piling up', () {
      final world = makeWorld();

      for (var i = 0; i < 60; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      expect(world.platforms.length, lessThan(60));
      expect(world.platforms.every((p) => p.y > world.cameraY - 400), isTrue);
    });

    test('every platform is horizontally reachable from the one below it', () {
      // The vertical gap alone does not make a level playable: a ledge one
      // bounce up but most of a screen sideways cannot be reached, because the
      // player only has the airtime of that bounce to cross the distance.
      const setup = SkyJumperSetup();
      final world = makeWorld(setup: setup);

      for (var i = 0; i < 60; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      final ordered = world.platforms.toList()..sort((a, b) => a.y.compareTo(b.y));
      for (var i = 1; i < ordered.length; i++) {
        final gap = ordered[i].y - ordered[i - 1].y;
        final dx = wrappedDistance(ordered[i].x, ordered[i - 1].x, _view.width);

        expect(
          dx,
          lessThanOrEqualTo(setup.horizontalReachForGap(gap) + 0.01),
          reason: 'platform $i is $dx px sideways over a $gap px climb',
        );
      }
    });

    test('the climb starts gentler than it ends', () {
      final world = makeWorld();

      for (var i = 0; i < 60; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      // Only the tail is still in memory by now, so compare against what the
      // generator produced down at the start.
      final fresh = makeWorld();
      final early = averageGap(fresh.platforms);
      final late = averageGap(world.platforms);

      expect(early, lessThan(late));
    });

    test('both delivered block styles are actually generated', () {
      // Grass used to appear only on the starting ground, which scrolls away
      // within a second — minihra_blok1.svg was effectively never seen.
      final world = makeWorld();
      for (var i = 0; i < 40; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      final kinds = world.platforms.map((p) => p.kind).toSet();
      expect(kinds, contains(PlatformKind.grass));
      expect(kinds, contains(PlatformKind.wood));
    });

    test('every kind has its own artwork', () {
      // A kind with no sprite of its own silently borrows another's, which
      // reads as "the asset is missing" rather than as a bug.
      expect(PlatformKind.values.toSet(),
          {PlatformKind.grass, PlatformKind.wood});
    });

    test('the grass chain alone is climbable', () {
      // This is what keeps the game solvable. Wooden platforms fall away after
      // one use, so a run where every one of them has already broken must
      // still be winnable on grass alone — the grass spine, not the full set,
      // is the guaranteed path.
      const setup = SkyJumperSetup();
      final world = makeWorld(setup: setup);

      for (var i = 0; i < 60; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      final grass = world.platforms
          .where((p) => p.kind == PlatformKind.grass)
          .toList()
        ..sort((a, b) => a.y.compareTo(b.y));

      for (var i = 1; i < grass.length; i++) {
        final gap = grass[i].y - grass[i - 1].y;
        final dx = wrappedDistance(grass[i].x, grass[i - 1].x, _view.width);

        expect(gap, lessThanOrEqualTo(setup.maxJumpHeight));
        expect(
          dx,
          lessThanOrEqualTo(setup.horizontalReachForGap(gap) + 0.01),
          reason: 'grass $i is unreachable once the wood below it has gone',
        );
      }
    });

    test('reaching the next grass platform always takes real steering', () {
      // The reach bound stops levels being impossible; without a floor as well
      // the generator stacks platforms almost overhead and the run plays
      // itself.
      const setup = SkyJumperSetup();
      final world = makeWorld(setup: setup);

      for (var i = 0; i < 60; i++) {
        world.debugPlacePlayer(x: 200, y: 400.0 * i, vy: 0);
        world.step(1 / 60, 0);
      }

      // The floor applies to the grass spine. Wooden platforms are deliberately
      // placed on the easy line between two grass ones — being a relief is the
      // whole point of them.
      final grass = world.platforms
          .where((p) => p.kind == PlatformKind.grass)
          .toList()
        ..sort((a, b) => a.y.compareTo(b.y));

      for (var i = 1; i < grass.length; i++) {
        final gap = grass[i].y - grass[i - 1].y;
        final dx = wrappedDistance(grass[i].x, grass[i - 1].x, _view.width);
        final reach = setup.horizontalReachForGap(gap);

        expect(
          dx,
          greaterThanOrEqualTo(reach * setup.minReachFraction - 0.01),
          reason: 'grass $i is only $dx px sideways — a free ride',
        );
      }
    });

    test('the same seed produces the same level', () {
      final a = makeWorld(seed: 7);
      final b = makeWorld(seed: 7);

      expect(
        a.platforms.map((p) => '${p.x}:${p.y}').toList(),
        b.platforms.map((p) => '${p.x}:${p.y}').toList(),
      );
    });
  });
}
