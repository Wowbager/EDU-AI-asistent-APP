import 'dart:math';

/// Tunables for [SkyJumperWorld].
///
/// Every number the game feel depends on lives here, and every one of them can
/// be overridden per game row through `mini_games.setup` — so balancing does
/// not need an app release. Unknown keys are ignored and missing keys fall back
/// to the defaults below, which is what makes a null `setup` valid.
class SkyJumperSetup {
  /// Downward acceleration, px/s². Positive magnitude.
  final double gravity;

  /// Upward speed handed to the player on every landing, px/s.
  ///
  /// Together with [gravity] this fixes the maximum jump height, which is what
  /// the platform generator uses to guarantee the level stays climbable.
  final double bounceVelocity;

  /// Cap on steering speed, px/s.
  final double maxHorizontalSpeed;

  /// How quickly horizontal speed catches up with the stick, 1/s.
  ///
  /// Deliberately not instant: a raw tilt reading jitters, and snapping vx to
  /// it makes the player twitch even when the device is held still.
  final double steerResponsiveness;

  /// Half the player's width. Not just a drawing size — landing tolerance,
  /// coin reach and the fall-out-of-view check are all derived from it, so the
  /// avatar cannot be scaled up in the painter alone without the hitbox
  /// drifting away from what is on screen.
  final double playerRadius;

  final double platformWidth;
  final double platformHeight;

  /// Vertical spacing between platforms, px. [maxPlatformGap] must stay below
  /// the jump height implied by [gravity] and [bounceVelocity].
  final double minPlatformGap;
  final double maxPlatformGap;

  /// Gap ceiling at the very bottom of a run, ramping to [maxPlatformGap] over
  /// [difficultyRampHeight].
  final double startPlatformGap;

  /// World height over which the gap ceiling grows to its maximum, px.
  final double difficultyRampHeight;

  /// Fraction of the theoretically reachable sideways distance the generator
  /// will actually use, 0..1. The remainder is the margin a player needs for
  /// reacting, and for starting a bounce drifting the wrong way.
  final double reachSafety;

  /// Smallest share of the reachable distance a platform is placed at, 0..1.
  ///
  /// The upper bound alone only stops levels being impossible. Without a floor
  /// the generator keeps dropping the next platform almost overhead and the run
  /// plays itself — every jump has to be worth steering for.
  final double minReachFraction;

  /// Chance of a wooden relief platform between two grass ones, 0..1.
  ///
  /// Reliefs are extras, never part of the climbable spine: they collapse after
  /// a single bounce, so a run has to stay winnable on grass alone.
  final double reliefChance;

  final double coinRadius;

  /// Probability that a platform carries a coin above it, 0..1.
  final double coinChance;

  /// How far above its platform a coin floats, px.
  final double coinHeight;

  /// Share of coins that are boost coins rather than Edux coins, 0..1.
  final double boostCoinChance;

  /// Multiple of [bounceVelocity] a boost coin launches the player at.
  final double boostMultiplier;

  /// Score awarded per collected coin.
  final int coinPoints;

  /// Score awarded per collected boost coin.
  final int boostCoinPoints;

  /// Score awarded per world pixel climbed.
  final double heightPoints;

  /// Fraction of the view height the player may rise to before the camera
  /// starts following. 0.5 keeps the player mid-screen.
  final double cameraLead;

  /// How far below the camera a platform is kept before it is dropped, px.
  final double recycleMargin;

  const SkyJumperSetup({
    this.gravity = 2200,
    this.bounceVelocity = 950,
    this.maxHorizontalSpeed = 320,
    this.steerResponsiveness = 8,
    this.playerRadius = 26,
    this.platformWidth = 84,
    this.platformHeight = 16,
    this.minPlatformGap = 95,
    this.maxPlatformGap = 175,
    this.startPlatformGap = 125,
    this.difficultyRampHeight = 2500,
    this.reachSafety = 0.8,
    this.minReachFraction = 0.45,
    this.reliefChance = 0.3,
    this.coinRadius = 12,
    this.coinChance = 0.35,
    this.boostCoinChance = 0.12,
    this.boostMultiplier = 2.2,
    this.coinHeight = 56,
    this.coinPoints = 250,
    this.boostCoinPoints = 1000,
    this.heightPoints = 10,
    this.cameraLead = 0.5,
    this.recycleMargin = 200,
  });

  /// Highest a single bounce can carry the player, px.
  double get maxJumpHeight => (bounceVelocity * bounceVelocity) / (2 * gravity);

  /// How far sideways the player can realistically travel while climbing [gap].
  ///
  /// Clearing the vertical gap is only half of reaching a platform — the player
  /// also has to be over it, and has only the airtime of one bounce to get
  /// there. Placing platforms anywhere across the width made the worst case
  /// need ~158 px of travel against ~163 px of reach: technically possible,
  /// unplayable in practice.
  ///
  /// The model is the descending crossing of [gap] (landing needs to come from
  /// above), with the steering ramp integrated rather than assuming instant top
  /// speed, then discounted by [reachSafety] because a real player starts the
  /// bounce drifting the wrong way as often as not.
  double horizontalReachForGap(double gap) {
    final discriminant = bounceVelocity * bounceVelocity - 2 * gravity * gap;
    if (discriminant <= 0) return 0;

    final airtime = (bounceVelocity + sqrt(discriminant)) / gravity;
    final ramp = (1 - exp(-steerResponsiveness * airtime)) / steerResponsiveness;

    return maxHorizontalSpeed * (airtime - ramp) * reachSafety;
  }

  /// Ceiling on the vertical gap at world height [y].
  ///
  /// The first screens are deliberately tighter than the rest: a run that opens
  /// on a full-height gap is a coin flip before the player has taken a single
  /// bounce.
  double gapCeilingAt(double y) {
    final progress = (y / difficultyRampHeight).clamp(0.0, 1.0);
    return startPlatformGap + (maxPlatformGap - startPlatformGap) * progress;
  }

  /// Build from a `mini_games.setup` payload. A null or malformed value yields
  /// the defaults rather than throwing — a bad row must not break the game.
  factory SkyJumperSetup.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SkyJumperSetup();

    const defaults = SkyJumperSetup();

    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    // The generator's reachability guarantee rests on this, so it is enforced
    // here rather than trusted from the database.
    final gravity = number('gravity', defaults.gravity);
    final bounce = number('bounce_velocity', defaults.bounceVelocity);
    final jumpHeight = (bounce * bounce) / (2 * gravity);
    final maxGap = number('max_platform_gap', defaults.maxPlatformGap)
        .clamp(1.0, jumpHeight * 0.9)
        .toDouble();
    final minGap = number('min_platform_gap', defaults.minPlatformGap)
        .clamp(1.0, maxGap)
        .toDouble();
    final platformWidth = number('platform_width', defaults.platformWidth);

    return SkyJumperSetup(
      gravity: gravity,
      bounceVelocity: bounce,
      maxHorizontalSpeed:
          number('max_horizontal_speed', defaults.maxHorizontalSpeed),
      steerResponsiveness:
          number('steer_responsiveness', defaults.steerResponsiveness),
      playerRadius: number('player_radius', defaults.playerRadius)
          // Landing tolerance grows with the radius, so a player as wide as a
          // platform would stick to ledges it is visibly nowhere near.
          .clamp(4.0, platformWidth * 0.45)
          .toDouble(),
      platformWidth: platformWidth,
      platformHeight: number('platform_height', defaults.platformHeight),
      minPlatformGap: minGap,
      maxPlatformGap: maxGap,
      startPlatformGap: number('start_platform_gap', defaults.startPlatformGap)
          .clamp(minGap, maxGap)
          .toDouble(),
      difficultyRampHeight:
          number('difficulty_ramp_height', defaults.difficultyRampHeight)
              .clamp(1.0, double.maxFinite)
              .toDouble(),
      reachSafety: number('reach_safety', defaults.reachSafety)
          .clamp(0.1, 1.0)
          .toDouble(),
      // Below the ceiling by construction, so tuning one cannot invert them.
      minReachFraction: number('min_reach_fraction', defaults.minReachFraction)
          .clamp(0.0, 0.9)
          .toDouble(),
      reliefChance: number('relief_chance', defaults.reliefChance)
          .clamp(0.0, 1.0)
          .toDouble(),
      coinRadius: number('coin_radius', defaults.coinRadius),
      coinChance:
          number('coin_chance', defaults.coinChance).clamp(0.0, 1.0).toDouble(),
      boostCoinChance: number('boost_coin_chance', defaults.boostCoinChance)
          .clamp(0.0, 1.0)
          .toDouble(),
      boostMultiplier: number('boost_multiplier', defaults.boostMultiplier)
          .clamp(1.0, 6.0)
          .toDouble(),
      boostCoinPoints:
          number('boost_coin_points', defaults.boostCoinPoints.toDouble())
              .round(),
      coinHeight: number('coin_height', defaults.coinHeight),
      coinPoints: number('coin_points', defaults.coinPoints.toDouble()).round(),
      heightPoints: number('height_points', defaults.heightPoints),
      cameraLead:
          number('camera_lead', defaults.cameraLead).clamp(0.1, 0.9).toDouble(),
      recycleMargin: number('recycle_margin', defaults.recycleMargin),
    );
  }
}
