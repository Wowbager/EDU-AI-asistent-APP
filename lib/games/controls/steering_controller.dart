import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'slingshot.dart';
import 'tilt_math.dart';

/// How the player is currently steering.
enum SteeringMode {
  /// Device tilt — the intended scheme.
  tilt,

  /// Arrow keys, which is what the web build gets on a desktop.
  keyboard,

  /// The on-screen arrow buttons, for a touch device with no usable sensor.
  touch,

  /// Drag-and-release fallback for anything with neither.
  slingshot,
}

/// Picks the steering scheme and reduces it to a single axis (-1..1).
///
/// The mode is discovered, not assumed: a phone browser has a tilt sensor while
/// the desktop browser next to it does not, so `kIsWeb` is the wrong question.
/// It starts on [SteeringMode.slingshot] — the one scheme that works
/// everywhere — and upgrades the moment a real sensor, key press or on-screen
/// arrow shows up. That ordering is also what the brief asks for: no gyroscope
/// (or permission refused) leaves the screen steering the run, and nothing has
/// to time out first.
class SteeringController {
  final Slingshot slingshot;

  StreamSubscription<AccelerometerEvent>? _sensor;
  double _tiltAxis = 0;
  bool _leftHeld = false;
  bool _rightHeld = false;
  bool _touchLeftHeld = false;
  bool _touchRightHeld = false;

  SteeringMode _mode = SteeringMode.slingshot;

  /// Fired when [mode] changes, so the hint on screen can follow.
  final void Function(SteeringMode mode)? onModeChanged;

  SteeringController({Slingshot? slingshot, this.onModeChanged})
      : slingshot = slingshot ?? Slingshot();

  SteeringMode get mode => _mode;

  /// Begin listening for device tilt. Safe to call on platforms without a
  /// sensor: the stream simply never delivers, and the mode stays put.
  void start() {
    try {
      _sensor = accelerometerEventStream().listen(
        (event) {
          _tiltAxis = normalizeTilt(event.x);
          // Keyboard wins once used: someone on a tilting laptop who reached
          // for the arrow keys meant it.
          if (_mode == SteeringMode.slingshot) _setMode(SteeringMode.tilt);
        },
        onError: (_) {
          // No usable sensor on this device — the fallback is already active.
        },
        cancelOnError: true,
      );
    } on Exception catch (_) {
      // Plugin missing entirely (some web/desktop targets). Nothing to do.
    }
  }

  /// Feed a raw key event. Returns true when the key was one we steer with.
  bool handleKey(KeyEvent event) {
    final key = event.logicalKey;
    final isLeft = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA;
    final isRight = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD;
    if (!isLeft && !isRight) return false;

    final down = event is KeyDownEvent || event is KeyRepeatEvent;
    if (isLeft) _leftHeld = down;
    if (isRight) _rightHeld = down;

    if (down) _setMode(SteeringMode.keyboard);
    return true;
  }

  /// Press or release one of the on-screen arrow buttons.
  ///
  /// Takes over the same way the keyboard does: someone who reached for the
  /// buttons meant it, so a tilt reading arriving later must not snatch the
  /// steering back mid-run.
  void holdTouch({bool? left, bool? right}) {
    if (left != null) _touchLeftHeld = left;
    if (right != null) _touchRightHeld = right;
    if (_touchLeftHeld || _touchRightHeld) _setMode(SteeringMode.touch);
  }

  /// Let go of both buttons. The run can be paused with a finger still down,
  /// and the pointer-up then lands on the overlay rather than on the button.
  void releaseTouch() {
    _touchLeftHeld = false;
    _touchRightHeld = false;
  }

  /// The steering axis for this frame.
  double axis(double dt) {
    // The slingshot is always stepped: a shot fired just before the mode
    // changed must still play out rather than freeze mid-flight.
    final shot = slingshot.step(dt);

    switch (_mode) {
      case SteeringMode.keyboard:
        return axisFromKeys(left: _leftHeld, right: _rightHeld);
      case SteeringMode.touch:
        return axisFromKeys(left: _touchLeftHeld, right: _touchRightHeld);
      case SteeringMode.tilt:
        return _tiltAxis;
      case SteeringMode.slingshot:
        return shot;
    }
  }

  void _setMode(SteeringMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    onModeChanged?.call(mode);
  }

  void dispose() {
    _sensor?.cancel();
    _sensor = null;
  }
}
