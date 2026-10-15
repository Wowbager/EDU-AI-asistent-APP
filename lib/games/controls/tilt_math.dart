import 'dart:math';

/// Steering axis from the arrow keys. Holding both is treated as holding
/// neither, so a stuck key-up event cannot pin the player to one side.
double axisFromKeys({required bool left, required bool right}) {
  if (left == right) return 0;
  return right ? 1 : -1;
}

/// Turn the device's sideways acceleration into a steering axis (-1..1).
///
/// [accelX] is `AccelerometerEvent.x` in m/s². The reading is inverted because
/// the accelerometer reports which way is *up*: tipping the right edge down
/// puts device -x upwards, so a right-hand tilt arrives as a negative x.
///
/// [deadZone] swallows the small constant offset of a hand-held device — most
/// people do not hold a phone perfectly level, and without it the player drifts
/// on its own.
double normalizeTilt(
  double accelX, {
  double range = 5.0,
  double deadZone = 0.4,
}) {
  final magnitude = accelX.abs();
  if (magnitude <= deadZone) return 0;

  // Rescale past the dead zone so the axis still reaches ±1 at full tilt.
  final scaled = (magnitude - deadZone) / max(range - deadZone, 0.001);
  final axis = scaled.clamp(0.0, 1.0).toDouble();

  return accelX > 0 ? -axis : axis;
}
