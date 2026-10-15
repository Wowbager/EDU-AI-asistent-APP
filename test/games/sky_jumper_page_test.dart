// The Sky Jumper screen: loop, HUD, pause and how a run reports its score.
//
//   flutter test test/games/sky_jumper_page_test.dart
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/games/sky_jumper/sky_jumper_painter.dart';
import 'package:eduai/games/sky_jumper/sky_jumper_page.dart';
import 'package:eduai/games/sky_jumper/sky_jumper_setup.dart';
import 'package:eduai/models/mini_game_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The start button. Kept in one place so a copy change is a one-line edit
/// rather than a sweep through every test that opens the game.
final startButton = find.text(AppStrings.gameTapToStart);

/// Nothing to land on but the starting ground: every generated platform is put
/// far out of jumping range, so steering off the ground is certain death and
/// the run ends on a schedule instead of on a dice roll.
const _noSafetyNet = SkyJumperSetup(
  minPlatformGap: 500,
  maxPlatformGap: 501,
  coinChance: 0,
);

class GameResult {
  bool closed = false;
  MiniGameOutcome? outcome;

  int? get score => outcome?.score;
  int? get coins => outcome?.coins;
}

/// Open the game the way the listing does, so the pop value is observable.
Future<GameResult> openGame(
  WidgetTester tester, {
  SkyJumperSetup setup = const SkyJumperSetup(),
}) async {
  final result = GameResult();

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result.outcome =
                await Navigator.of(context).push<MiniGameOutcome>(
              MaterialPageRoute(
                builder: (_) => SkyJumperPage(
                  title: 'Sky Jumper',
                  setup: setup,
                  seed: 1,
                ),
              ),
            );
            result.closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return result;
}

/// The score currently on the HUD.
int readScore(WidgetTester tester) {
  final text = tester.widget<Text>(find.textContaining('Skóre:')).data!;
  return int.parse(text.split(':').last.trim());
}

/// Advance the render loop by [frames] 60 Hz ticks.
Future<void> tick(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A level dense enough that steering cannot kill the run. Without it a test
/// about the player drifting is answered by a game over freezing them in
/// place, and passes whether or not the steering was ever let go of.
const _denseFloor = SkyJumperSetup(
  minPlatformGap: 40,
  maxPlatformGap: 45,
  platformWidth: 400,
  coinChance: 0,
  reliefChance: 0,
);

/// Where the player currently is, read off the painter the run is drawing.
double readPlayerX(WidgetTester tester) {
  final painter = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<SkyJumperPainter>()
      .first;
  return painter.world.playerX;
}

/// How far the player drifts over ten frames of nobody steering.
Future<double> driftOverTenFrames(WidgetTester tester) async {
  final before = readPlayerX(tester);
  await tick(tester, 10);
  return (readPlayerX(tester) - before).abs();
}

final leftArrow = find.byIcon(Icons.arrow_back_rounded);
final rightArrow = find.byIcon(Icons.arrow_forward_rounded);

/// The way back to the listing from the start screen (BR-W3A6SJ). A different
/// glyph from the steer arrows on purpose, so the two cannot be confused.
final exitButton = find.byIcon(Icons.arrow_back_ios_new_rounded);

void main() {
  testWidgets('a run does not start until the player asks for it',
      (tester) async {
    await openGame(tester);

    expect(startButton, findsOneWidget);
    // No HUD before the world exists — there is nothing to score yet.
    expect(find.textContaining('Skóre:'), findsNothing);
  });

  testWidgets('the start screen sits on the real level, not a blank colour',
      (tester) async {
    await openGame(tester);

    // The world is built as soon as the size is known, so the player sees the
    // platforms and sky they are about to play rather than a flat rectangle.
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<SkyJumperPainter>()
        .firstOrNull;

    expect(painter, isNotNull);
    expect(painter!.world.platforms, isNotEmpty);
  });

  testWidgets('the start screen explains the boost coin', (tester) async {
    await openGame(tester);

    // A star that launches you is not guessable from looking at it, and
    // nothing during a run explains it.
    expect(find.text(AppStrings.gameRuleBoost), findsOneWidget);
    expect(find.text(AppStrings.gameReadyHeadline), findsOneWidget);
  });

  testWidgets('the score is not shown before the run starts', (tester) async {
    await openGame(tester);

    expect(find.textContaining('Skóre:'), findsNothing);
  });

  testWidgets('starting the run shows the live score', (tester) async {
    await openGame(tester);

    await tester.tap(startButton);
    await tester.pump();

    expect(startButton, findsNothing);
    expect(find.textContaining('Skóre:'), findsOneWidget);
  });

  testWidgets('pausing stops the world and resuming carries on', (tester) async {
    await openGame(tester);
    await tester.tap(startButton);
    await tick(tester, 2);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('Pauza'), findsOneWidget);

    await tester.tap(find.text('Pokračovat'));
    await tester.pump();
    expect(find.text('Pauza'), findsNothing);
    expect(find.textContaining('Skóre:'), findsOneWidget);
  });

  testWidgets('a long pause does not advance the world', (tester) async {
    await openGame(tester);
    await tester.tap(startButton);
    await tick(tester, 2);
    final before = readScore(tester);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump(const Duration(seconds: 30));

    expect(readScore(tester), before);
  });

  testWidgets('falling off the level ends the run', (tester) async {
    await openGame(tester, setup: _noSafetyNet);
    await tester.tap(startButton);

    // Steer off the starting ground and keep going.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tick(tester, 180);

    expect(find.text('Konec hry'), findsOneWidget);
    expect(find.textContaining('Mince:'), findsOneWidget);
  });

  testWidgets('leaving after game over hands the score back to the caller',
      (tester) async {
    final result = await openGame(tester, setup: _noSafetyNet);
    await tester.tap(startButton);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tick(tester, 180);

    await tester.tap(find.text('Zpět na hry'));
    await tester.pumpAndSettle();

    expect(result.closed, isTrue);
    // A score of 0 is still a result — the attempt was spent either way.
    expect(result.score, isNotNull);
  });

  testWidgets('quitting from the pause menu still reports the score',
      (tester) async {
    final result = await openGame(tester);
    await tester.tap(startButton);
    await tick(tester, 30);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.tap(find.text('Ukončit hru'));
    await tester.pumpAndSettle();

    expect(result.closed, isTrue);
    expect(result.score, isNotNull);
  });


  testWidgets('a run with no tilt sensor gets on-screen arrows to steer with',
      (tester) async {
    // The reported case: an iPad browser never delivers motion readings, so
    // without these the run cannot be steered at all.
    await openGame(tester);
    expect(leftArrow, findsNothing);

    await tester.tap(startButton);
    await tester.pump();

    expect(leftArrow, findsOneWidget);
    expect(rightArrow, findsOneWidget);
  });

  testWidgets('the start screen tells the player about the arrows',
      (tester) async {
    await openGame(tester);

    expect(find.text(AppStrings.gameHintButtons), findsOneWidget);
  });

  testWidgets('holding the left arrow steers the player left', (tester) async {
    await openGame(tester);
    await tester.tap(startButton);
    await tester.pump();
    final before = readPlayerX(tester);

    final finger = await tester.startGesture(tester.getCenter(leftArrow));
    await tick(tester, 20);

    expect(readPlayerX(tester), lessThan(before));
    await finger.up();
  });

  testWidgets('holding the right arrow steers the player right',
      (tester) async {
    await openGame(tester);
    await tester.tap(startButton);
    await tester.pump();
    final before = readPlayerX(tester);

    final finger = await tester.startGesture(tester.getCenter(rightArrow));
    await tick(tester, 20);

    expect(readPlayerX(tester), greaterThan(before));
    await finger.up();
  });

  testWidgets('lifting the finger stops the player', (tester) async {
    await openGame(tester, setup: _denseFloor);
    await tester.tap(startButton);
    await tester.pump();

    final finger = await tester.startGesture(tester.getCenter(leftArrow));
    await tick(tester, 20);
    await finger.up();
    // Long enough for the sideways speed the arrow built up to bleed off.
    await tick(tester, 60);

    expect(find.text('Konec hry'), findsNothing);
    expect(await driftOverTenFrames(tester), lessThan(1));
  });

  testWidgets('pausing under a held finger does not leave the player steering',
      (tester) async {
    // The pointer-up lands on the pause overlay, so the arrow never hears it.
    await openGame(tester, setup: _denseFloor);
    await tester.tap(startButton);
    await tester.pump();

    final finger = await tester.startGesture(tester.getCenter(leftArrow));
    await tick(tester, 20);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await finger.up();

    await tester.tap(find.text('Pokračovat'));
    await tick(tester, 60);

    expect(find.text('Konec hry'), findsNothing);
    expect(await driftOverTenFrames(tester), lessThan(1));
  });

  testWidgets('the arrows step aside once the keyboard is used',
      (tester) async {
    await openGame(tester);
    await tester.tap(startButton);
    await tester.pump();
    expect(leftArrow, findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(leftArrow, findsNothing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
  });

  testWidgets('the start screen has a way back to the listing',
      (tester) async {
    // BR-W3A6SJ: with nothing to tap, a player who changed their mind had
    // only the system back gesture — which a desktop browser does not have.
    final result = await openGame(tester);
    expect(exitButton, findsOneWidget);

    await tester.tap(exitButton);
    await tester.pumpAndSettle();

    expect(result.closed, isTrue);
    // The attempt was spent when the page opened, so leaving before the run
    // still reports a result — the same one the back gesture hands over.
    expect(result.score, 0);
    expect(result.coins, 0);
  });

  testWidgets('the exit arrow is gone once the run is on', (tester) async {
    await openGame(tester);
    await tester.tap(startButton);
    await tester.pump();

    // Mid-run the way out is the pause menu, which warns about the attempt.
    expect(exitButton, findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}
