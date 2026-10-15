// Steering maths for Sky Jumper: slingshot, keyboard and tilt normalisation.
//
// Pure Dart — no plugins:
//   flutter test test/games/controls_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/games/controls/slingshot.dart';
import 'package:eduai/games/controls/steering_controller.dart';
import 'package:eduai/games/controls/tilt_math.dart';
import 'package:flutter/services.dart';

KeyEvent _key(LogicalKeyboardKey key, {required bool down}) {
  final data = (
    physicalKey: PhysicalKeyboardKey.arrowRight,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
  return down
      ? KeyDownEvent(
          physicalKey: data.physicalKey,
          logicalKey: data.logicalKey,
          timeStamp: data.timeStamp,
        )
      : KeyUpEvent(
          physicalKey: data.physicalKey,
          logicalKey: data.logicalKey,
          timeStamp: data.timeStamp,
        );
}

void main() {
  group('slingshot', () {
    test('an untouched slingshot steers nowhere', () {
      final sling = Slingshot();

      expect(sling.step(1 / 60), 0);
    });

    test('aiming without releasing does not steer yet', () {
      final sling = Slingshot()..aim(-100, 0);

      expect(sling.step(1 / 60), 0);
    });

    test('pulling left shoots right', () {
      final sling = Slingshot()
        ..aim(-100, 0)
        ..release();

      expect(sling.step(1 / 60), greaterThan(0));
    });

    test('pulling right shoots left', () {
      final sling = Slingshot()
        ..aim(100, 0)
        ..release();

      expect(sling.step(1 / 60), lessThan(0));
    });

    test('a longer pull shoots harder', () {
      double shot(double dx) {
        final sling = Slingshot()
          ..aim(dx, 0)
          ..release();
        return sling.step(1 / 60).abs();
      }

      expect(shot(-100), greaterThan(shot(-30)));
    });

    test('pulling past the limit does not shoot harder', () {
      final sling = Slingshot(maxPull: 100);
      sling
        ..aim(-10000, 0)
        ..release();

      expect(sling.step(1 / 60).abs(), lessThanOrEqualTo(1.0));
    });

    test('a shot fades out instead of steering forever', () {
      final sling = Slingshot(maxPull: 100, shotDuration: 0.5)
        ..aim(-100, 0)
        ..release();

      final opening = sling.step(0.1).abs();
      // Burn through the rest of the shot.
      for (var i = 0; i < 10; i++) {
        sling.step(0.1);
      }

      expect(opening, greaterThan(0));
      expect(sling.step(1 / 60), 0);
    });

    test('a new shot replaces the one still fading', () {
      final sling = Slingshot(maxPull: 100, shotDuration: 1)
        ..aim(-100, 0)
        ..release();
      sling.step(0.9);

      sling
        ..aim(100, 0)
        ..release();

      expect(sling.step(1 / 60), lessThan(0));
    });

    test('releasing a pull that never moved does nothing', () {
      final sling = Slingshot()..release();

      expect(sling.step(1 / 60), 0);
    });

    test('pull fraction reports how far the band is stretched', () {
      final sling = Slingshot(maxPull: 100);

      expect(sling.pullFraction, 0);
      sling.aim(-50, 0);
      expect(sling.pullFraction, closeTo(0.5, 0.001));
      sling.aim(-500, 0);
      expect(sling.pullFraction, 1);
    });
  });

  group('keyboard', () {
    test('no key held steers nowhere', () {
      expect(axisFromKeys(left: false, right: false), 0);
    });

    test('right alone steers right', () {
      expect(axisFromKeys(left: false, right: true), 1);
    });

    test('left alone steers left', () {
      expect(axisFromKeys(left: true, right: false), -1);
    });

    test('both keys cancel out', () {
      expect(axisFromKeys(left: true, right: true), 0);
    });
  });

  group('steering controller', () {
    test('the slingshot is the scheme that always works, so it is the default',
        () {
      expect(SteeringController().mode, SteeringMode.slingshot);
    });

    test('an arrow key switches to keyboard steering', () {
      final controller = SteeringController();

      controller.handleKey(_key(LogicalKeyboardKey.arrowRight, down: true));

      expect(controller.mode, SteeringMode.keyboard);
      expect(controller.axis(1 / 60), 1);
    });

    test('releasing the key stops the player', () {
      final controller = SteeringController()
        ..handleKey(_key(LogicalKeyboardKey.arrowRight, down: true))
        ..handleKey(_key(LogicalKeyboardKey.arrowRight, down: false));

      expect(controller.axis(1 / 60), 0);
    });

    test('keys we do not steer with are left to the rest of the app', () {
      final controller = SteeringController();

      final handled =
          controller.handleKey(_key(LogicalKeyboardKey.space, down: true));

      expect(handled, isFalse);
      expect(controller.mode, SteeringMode.slingshot);
    });

    test('the slingshot drives the axis until something better shows up', () {
      final controller = SteeringController();
      controller.slingshot
        ..aim(-120, 0)
        ..release();

      expect(controller.axis(1 / 60), greaterThan(0));
    });

    test('a shot mid-flight does not fight the keyboard once it takes over',
        () {
      final controller = SteeringController();
      controller.slingshot
        ..aim(-120, 0)
        ..release();
      controller.handleKey(_key(LogicalKeyboardKey.arrowLeft, down: true));

      expect(controller.axis(1 / 60), -1);
    });
  });

  group('on-screen arrows', () {
    test('pressing an arrow takes the steering over', () {
      final controller = SteeringController()..holdTouch(right: true);

      expect(controller.mode, SteeringMode.touch);
      expect(controller.axis(1 / 60), 1);
    });

    test('lifting the finger stops the player', () {
      final controller = SteeringController()
        ..holdTouch(left: true)
        ..holdTouch(left: false);

      expect(controller.axis(1 / 60), 0);
    });

    test('a finger on each arrow cancels out', () {
      final controller = SteeringController()
        ..holdTouch(left: true)
        ..holdTouch(right: true);

      expect(controller.axis(1 / 60), 0);
    });

    test('releasing lets go of both arrows at once', () {
      // A run paused under a held finger never gets the pointer-up.
      final controller = SteeringController()
        ..holdTouch(left: true)
        ..releaseTouch();

      expect(controller.axis(1 / 60), 0);
    });

    test('touching an arrow does not arm the mode on its own', () {
      final controller = SteeringController()..holdTouch(left: false);

      expect(controller.mode, SteeringMode.slingshot);
    });

    test('a keyboard still wins once used', () {
      final controller = SteeringController()..holdTouch(left: true);

      controller.handleKey(_key(LogicalKeyboardKey.arrowRight, down: true));

      expect(controller.mode, SteeringMode.keyboard);
      expect(controller.axis(1 / 60), 1);
    });
  });

  group('tilt normalisation', () {
    test('a level device steers nowhere', () {
      expect(normalizeTilt(0), 0);
    });

    test('small wobble is ignored', () {
      expect(normalizeTilt(0.2, deadZone: 0.5), 0);
    });

    test('tilt is clamped to the steering range', () {
      expect(normalizeTilt(-100).abs(), lessThanOrEqualTo(1.0));
      expect(normalizeTilt(100).abs(), lessThanOrEqualTo(1.0));
    });

    test('opposite tilts steer opposite ways', () {
      expect(normalizeTilt(3), -normalizeTilt(-3));
      expect(normalizeTilt(3), isNot(0));
    });

    test('a stronger tilt steers harder', () {
      expect(normalizeTilt(-5).abs(), greaterThan(normalizeTilt(-2).abs()));
    });
  });
}
