import 'dart:math';

/// The fallback steering scheme: drag the player back and let go.
///
/// Used when the device has no usable tilt sensor and no keyboard. It feeds the
/// same single steering axis as every other control, so the simulation stays
/// identical whichever way the player is steering — scores from a tilt run and
/// a slingshot run remain comparable.
///
/// Pull direction is inverted like a real slingshot: pull left, shoot right.
class Slingshot {
  /// Drag distance at which the shot is at full power, px.
  final double maxPull;

  /// How long a full-power shot keeps pushing, s.
  final double shotDuration;

  double _aimDx = 0;
  double _aimDy = 0;

  /// Signed power of the shot currently in flight, -1..1.
  double _shotAxis = 0;

  /// Seconds left of the shot currently in flight.
  double _remaining = 0;

  Slingshot({this.maxPull = 120, this.shotDuration = 0.45});

  /// Vector from where the drag started to where the finger is now.
  void aim(double dx, double dy) {
    _aimDx = dx;
    _aimDy = dy;
  }

  /// How far the band is stretched, 0..1. For drawing the aim guide.
  double get pullFraction {
    final pull = sqrt(_aimDx * _aimDx + _aimDy * _aimDy);
    return (pull / maxPull).clamp(0.0, 1.0).toDouble();
  }

  /// Horizontal component of the current aim, for drawing the aim guide.
  double get aimDx => _aimDx;

  /// Vertical component of the current aim, for drawing the aim guide.
  double get aimDy => _aimDy;

  /// Let go. Replaces whatever shot was still fading — the newest input wins,
  /// otherwise a player tapping quickly fights their own previous shot.
  void release() {
    final pull = sqrt(_aimDx * _aimDx + _aimDy * _aimDy);
    final power = (pull / maxPull).clamp(0.0, 1.0).toDouble();

    if (power > 0) {
      // Only the sideways part of the pull steers; the simulation owns the
      // jumping, so an upward drag is not a second way to gain height.
      final direction = _aimDx == 0 ? 0.0 : (_aimDx > 0 ? -1.0 : 1.0);
      _shotAxis = direction * power;
      _remaining = shotDuration * power;
    }

    _aimDx = 0;
    _aimDy = 0;
  }

  /// Advance by [dt] and return the steering axis for this frame.
  double step(double dt) {
    if (_remaining <= 0) return 0;

    _remaining -= dt;
    if (_remaining <= 0) {
      _remaining = 0;
      _shotAxis = 0;
      return 0;
    }

    return _shotAxis;
  }
}
