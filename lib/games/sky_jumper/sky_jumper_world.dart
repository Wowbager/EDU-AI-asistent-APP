import 'dart:math';

import 'sky_jumper_setup.dart';

/// Play area in logical pixels.
///
/// Deliberately not `dart:ui`'s Size: this file is pure Dart so the physics can
/// be unit-tested without a widget binding.
class Size2D {
  final double width;
  final double height;

  const Size2D({required this.width, required this.height});
}

/// What a platform is made of. Affects rendering only — every platform behaves
/// the same until the design says otherwise.
/// One value per delivered block. A kind with no artwork of its own would
/// silently borrow another's, which reads as a missing asset rather than a bug.
enum PlatformKind { grass, wood }

/// A ledge the player can land on. [y] is the top surface.
class Platform {
  final int id;
  final double x;

  /// Top surface. Not final: a used wooden platform drops out of the level.
  double y;

  final double width;
  final double height;
  final PlatformKind kind;

  /// True once a wooden platform has been bounced off and is on its way down.
  /// A falling platform is scenery — it can no longer be landed on.
  bool isFalling = false;

  /// Current downward speed while falling, px/s.
  double fallSpeed = 0;

  Platform({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.kind,
  });

  /// Whether the player can still land on this.
  bool get isSolid => !isFalling;
}

/// What a coin does when collected.
enum CoinKind {
  /// Edux coin: points only.
  edu,

  /// Boost coin: points plus a launch well above a normal bounce.
  boost,
}

/// A collectible coin.
class Coin {
  final int id;
  final double x;
  final double y;
  final double radius;
  final CoinKind kind;

  /// Starting angle of the spin, so a screenful of coins is not in lockstep.
  final double spinPhase;

  const Coin({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
    required this.kind,
    this.spinPhase = 0,
  });
}

/// The Sky Jumper simulation.
///
/// World coordinates run **upwards**: y grows as the player climbs, and the
/// camera is the world y of the bottom edge of the view. Nothing here knows
/// about Flutter — [SkyJumperPage] renders whatever state this exposes, and the
/// control scheme only ever reaches it as a single `tilt` number.
class SkyJumperWorld {
  final SkyJumperSetup setup;
  final Size2D view;

  final Random _random;

  double _playerX;
  double _playerY = 0;
  double _playerVx = 0;
  double _playerVy = 0;

  double _cameraY = 0;
  double _peakY = 0;
  int _collectedCoins = 0;
  int _boostCoins = 0;
  bool _isGameOver = false;

  /// Seconds the world has been running, for view-only animation.
  double _elapsed = 0;

  final List<Platform> _platforms = [];
  final List<Coin> _coins = [];

  /// World y the generator has already filled up to.
  double _generatedTo = 0;

  /// Where the last generated platform sits, so the next one can be placed
  /// within reach of it rather than anywhere across the width.
  double _lastPlatformX = 0;
  int _nextId = 0;

  SkyJumperWorld({
    required this.setup,
    required this.view,
    int seed = 0,
  })  : _random = Random(seed),
        _playerX = view.width / 2 {
    // The run starts standing on a wide patch of ground rather than falling
    // from nowhere, so the first bounce is never a surprise.
    _platforms.add(Platform(
      id: _nextId++,
      x: view.width / 2,
      y: 0,
      width: view.width * 0.5,
      height: setup.platformHeight,
      kind: PlatformKind.grass,
    ));
    _playerY = setup.playerRadius;
    _playerVy = setup.bounceVelocity;
    _lastPlatformX = view.width / 2;
    _generateUpTo(view.height * 2);
  }

  // ── State ─────────────────────────────────────────────────────────────────

  double get playerX => _playerX;

  double get playerY => _playerY;

  double get playerVx => _playerVx;

  double get playerVy => _playerVy;

  /// World y of the bottom edge of the view.
  double get cameraY => _cameraY;

  bool get isGameOver => _isGameOver;

  int get collectedCoins => _collectedCoins;

  int get boostCoins => _boostCoins;

  /// Coins that count as EDUX currency (BR-HK9828).
  ///
  /// A boost coin is a power-up wearing the same sprite sheet — it launches
  /// the player and is spent doing so. Banking those would pay the student
  /// twice for one pickup.
  int get eduxCoins => _collectedCoins - _boostCoins;

  /// Seconds since the run started. Drives the coin spin and the backdrop.
  double get elapsed => _elapsed;

  /// True while the player is still riding a boost, i.e. climbing faster than
  /// an ordinary bounce could. Drives the rocket trail.
  bool get isBoosting => _playerVy > setup.bounceVelocity;

  List<Platform> get platforms => List.unmodifiable(_platforms);

  List<Coin> get coins => List.unmodifiable(_coins);

  /// Height climbed plus coins. Driven by the peak, never by where the player
  /// happens to be — falling back down must not cost points.
  int get score =>
      (_peakY * setup.heightPoints).round() +
      (_collectedCoins - _boostCoins) * setup.coinPoints +
      _boostCoins * setup.boostCoinPoints;

  // ── Simulation ────────────────────────────────────────────────────────────

  /// Advance by [dt] seconds with the steering axis at [tilt] (-1..1).
  ///
  /// [dt] is sliced into fixed sub-steps: a long frame must not let the player
  /// tunnel straight through a platform, which is what a single big integration
  /// step would do after a stutter or a backgrounded tab.
  void step(double dt, double tilt) {
    if (_isGameOver) return;

    const maxSlice = 1 / 120;
    var remaining = dt.clamp(0.0, 0.25);

    while (remaining > 0) {
      final slice = remaining < maxSlice ? remaining : maxSlice;
      _integrate(slice, tilt.clamp(-1.0, 1.0));
      remaining -= slice;
      if (_isGameOver) return;
    }
  }

  void _integrate(double dt, double tilt) {
    _elapsed += dt;
    _steer(dt, tilt);

    final previousBottom = _playerY - setup.playerRadius;
    _playerVy -= setup.gravity * dt;
    _playerY += _playerVy * dt;

    _bounceIfLanded(previousBottom);
    _advanceFallingPlatforms(dt);
    _collectCoins();
    _followPlayer();

    // Entirely below the view: nothing can save the run any more.
    if (_playerY + setup.playerRadius < _cameraY) {
      _isGameOver = true;
    }
  }

  void _steer(double dt, double tilt) {
    final target = tilt * setup.maxHorizontalSpeed;
    final catchUp = (setup.steerResponsiveness * dt).clamp(0.0, 1.0);
    _playerVx += (target - _playerVx) * catchUp;
    _playerX += _playerVx * dt;

    // Wrap around the sides, as the genre does — a wall would turn the edges
    // into dead ends the generator cannot account for.
    if (_playerX < 0) {
      _playerX += view.width;
    } else if (_playerX > view.width) {
      _playerX -= view.width;
    }
  }

  /// Land only when falling and only from above: a platform must be steppable
  /// from the top and pass-through from below, or the whole climb stalls.
  void _bounceIfLanded(double previousBottom) {
    if (_playerVy > 0) return;

    final bottom = _playerY - setup.playerRadius;

    for (final platform in _platforms) {
      if (!platform.isSolid) continue;
      if (previousBottom < platform.y || bottom > platform.y) continue;

      final halfWidth = platform.width / 2;
      if ((_playerX - platform.x).abs() > halfWidth + setup.playerRadius * 0.5) {
        continue;
      }

      _playerY = platform.y + setup.playerRadius;
      _playerVy = setup.bounceVelocity;

      // The relief collapses *after* handing over the bounce, so it is a
      // shortcut rather than a trap — the player always leaves it climbing.
      if (platform.kind == PlatformKind.wood) {
        platform.isFalling = true;
      }
      return;
    }
  }

  /// Carry used platforms out of the level.
  void _advanceFallingPlatforms(double dt) {
    for (final platform in _platforms) {
      if (!platform.isFalling) continue;
      platform.fallSpeed += setup.gravity * dt;
      platform.y -= platform.fallSpeed * dt;
    }
  }

  void _collectCoins() {
    final reach = setup.playerRadius + setup.coinRadius;

    _coins.removeWhere((coin) {
      final dx = coin.x - _playerX;
      final dy = coin.y - _playerY;
      if (dx * dx + dy * dy > reach * reach) return false;

      _collectedCoins++;
      if (coin.kind == CoinKind.boost) {
        _boostCoins++;
        // Overwrite rather than add: stacking boosts would let a lucky cluster
        // fire the player off the top of the level for good.
        _playerVy = setup.bounceVelocity * setup.boostMultiplier;
      }
      return true;
    });
  }

  void _followPlayer() {
    if (_playerY > _peakY) _peakY = _playerY;

    // The camera only ever rises. Letting it drop with the player would hide
    // the ground they are about to miss.
    final wanted = _playerY - view.height * setup.cameraLead;
    if (wanted > _cameraY) _cameraY = wanted;

    _generateUpTo(_cameraY + view.height * 2);
    _recycle();
  }

  // ── Level generation ──────────────────────────────────────────────────────

  /// Fill platforms (and their coins) up to world y [targetY].
  ///
  /// The gap is drawn from [SkyJumperSetup.minPlatformGap] to
  /// [SkyJumperSetup.maxPlatformGap], and the setup guarantees the upper bound
  /// stays under the jump height — so every level this produces is climbable.
  void _generateUpTo(double targetY) {
    final halfWidth = setup.platformWidth / 2;
    final left = halfWidth;
    final right = view.width - halfWidth;

    while (_generatedTo < targetY) {
      // The ceiling grows with height, so the opening screens are gentler than
      // the rest instead of opening on a coin flip.
      final gapCeiling = setup.gapCeilingAt(_generatedTo);
      final gapRange = max(0.0, gapCeiling - setup.minPlatformGap);
      final gap = setup.minPlatformGap + _random.nextDouble() * gapRange;
      final y = _generatedTo + gap;

      // Sideways placement is relative to the platform below, bounded above by
      // how far the player can actually travel during that climb — placing it
      // anywhere across the width is what made ledges technically reachable and
      // practically not — and bounded below so every jump is worth steering
      // for rather than landing itself.
      //
      // Both bounds are capped to what the view can hold from here, so the
      // distance drawn is one a side can accommodate exactly: folding an
      // over-long offset back off the edge would quietly undercut the floor.
      final reach = setup.horizontalReachForGap(gap);
      final feasible = max(_lastPlatformX - left, right - _lastPlatformX);
      final maxDistance = min(reach, feasible);
      final minDistance = min(reach * setup.minReachFraction, maxDistance);
      final distance =
          minDistance + _random.nextDouble() * (maxDistance - minDistance);
      final x = _placeSideways(_lastPlatformX, distance, left, right);

      // A wooden relief sits on the easy line between the two grass platforms,
      // so it is there to be used rather than aimed for. It is generated only
      // as an extra: the grass spine on its own stays climbable, which is what
      // keeps a run winnable once every relief has already collapsed.
      if (_random.nextDouble() < setup.reliefChance) {
        _platforms.add(Platform(
          id: _nextId++,
          x: (_lastPlatformX + x) / 2,
          y: _generatedTo + gap * 0.5,
          width: setup.platformWidth,
          height: setup.platformHeight,
          kind: PlatformKind.wood,
        ));
      }

      _platforms.add(Platform(
        id: _nextId++,
        x: x,
        y: y,
        width: setup.platformWidth,
        height: setup.platformHeight,
        kind: PlatformKind.grass,
      ));

      if (_random.nextDouble() < setup.coinChance) {
        _coins.add(Coin(
          id: _nextId++,
          x: x,
          y: y + setup.coinHeight,
          radius: setup.coinRadius,
          kind: _random.nextDouble() < setup.boostCoinChance
              ? CoinKind.boost
              : CoinKind.edu,
          spinPhase: _random.nextDouble() * pi * 2,
        ));
      }

      _lastPlatformX = x;
      _generatedTo = y;
    }
  }

  /// Place a platform exactly [distance] from [from], on whichever side fits.
  ///
  /// Preserving the distance is the point: it is the one number both the "can
  /// the player reach this" ceiling and the "is this worth steering for" floor
  /// are expressed in, so bending it silently breaks both.
  double _placeSideways(double from, double distance, double left, double right) {
    if (right <= left) return left;

    final preferLeft = _random.nextBool();
    final first = preferLeft ? from - distance : from + distance;
    if (first >= left && first <= right) return first;

    final second = preferLeft ? from + distance : from - distance;
    if (second >= left && second <= right) return second;

    // Only reachable if the view cannot hold the distance at all, which the
    // caller's cap already rules out. Clamp rather than place off-screen.
    return first.clamp(left, right);
  }

  /// Drop what the camera has left behind, so a long climb does not grow the
  /// scene without bound.
  void _recycle() {
    final floor = _cameraY - setup.recycleMargin;
    _platforms.removeWhere((p) => p.y < floor);
    _coins.removeWhere((c) => c.y < floor);
  }

  // ── Test hooks ────────────────────────────────────────────────────────────

  /// Teleport the player. Tests only — nothing in the game moves the player
  /// except [step].
  void debugPlacePlayer({
    required double x,
    required double y,
    required double vy,
  }) {
    _playerX = x;
    _playerY = y;
    _playerVy = vy;
  }
}
