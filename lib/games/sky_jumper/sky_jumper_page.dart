import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../controls/steering_controller.dart';
import '../../models/mini_game_model.dart';
import 'sky_jumper_painter.dart';
import 'sky_jumper_setup.dart';
import 'sky_jumper_sprites.dart';
import 'sky_jumper_world.dart';

/// The Sky Jumper run.
///
/// Pops with a [MiniGameOutcome] — the score reached and the EDUX coins
/// collected — or null if the run never started. The caller owns the API side
/// of things: the attempt is spent before this page opens, and the outcome is
/// reported after it closes. Keeping that out of here means the engine can be
/// played, tested and tuned with no server at all.
class SkyJumperPage extends StatefulWidget {
  final String title;
  final SkyJumperSetup setup;

  /// Seed for the level. Fixed per run so a crash report can be reproduced.
  final int seed;

  /// The player's avatar, pre-flattened to a bitmap. Null falls back to the
  /// primitive player shape — a run must never depend on artwork being there.
  final ui.Image? avatarSprite;

  const SkyJumperPage({
    super.key,
    required this.title,
    required this.setup,
    required this.seed,
    this.avatarSprite,
  });

  @override
  State<SkyJumperPage> createState() => _SkyJumperPageState();
}

enum _Phase { ready, playing, paused, over }

/// Same artwork the painter rasterises, reused as flat icons in the rules.
const _eduCoinAsset = 'assets/games/sky_jumper/educoin_outline.svg';
const _boostCoinAsset = 'assets/games/sky_jumper/boostcoin_outline.svg';

class _SkyJumperPageState extends State<SkyJumperPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final SteeringController _steering;
  final FocusNode _focus = FocusNode();

  SkyJumperWorld? _world;
  SkyJumperSprites? _sprites;
  Size? _viewSize;
  _Phase _phase = _Phase.ready;
  Duration _lastTick = Duration.zero;
  double _cloudScroll = 0;

  /// Where the current slingshot drag began, in local coordinates.
  Offset? _dragOrigin;

  /// Which on-screen arrows are under a finger, for the pressed look. The
  /// steering itself lives in the controller; this is only paint.
  bool _steerLeftHeld = false;
  bool _steerRightHeld = false;

  @override
  void initState() {
    super.initState();
    _steering = SteeringController(
      onModeChanged: (_) {
        if (mounted) setState(() {});
      },
    )..start();
    _ticker = createTicker(_onTick);
    _loadSprites();
  }

  /// Rasterise the artwork once, off the render loop. The game is playable
  /// before this finishes — the painter falls back to placeholders — so the
  /// player never waits on it.
  Future<void> _loadSprites() async {
    final sprites = await SkyJumperSprites.load();
    if (!mounted) {
      sprites?.dispose();
      return;
    }
    setState(() => _sprites = sprites);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _steering.dispose();
    _focus.dispose();
    _sprites?.dispose();
    super.dispose();
  }

  // ── Loop ──────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final world = _world;
    if (world == null) return;

    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    // The world clamps long frames itself; this only keeps the backdrop from
    // lurching after the app returns from the background.
    final axis = _steering.axis(dt);
    world.step(dt, axis);
    _cloudScroll += dt * 20;

    if (world.isGameOver) {
      _ticker.stop();
      _releaseSteer();
      setState(() => _phase = _Phase.over);
      return;
    }

    setState(() {});
  }

  void _start() {
    if (_world == null || _phase != _Phase.ready) return;
    setState(() => _phase = _Phase.playing);
    _lastTick = Duration.zero;
    _ticker.start();
    _focus.requestFocus();
  }

  void _pause() {
    if (_phase != _Phase.playing) return;
    _ticker.stop();
    // A run can be paused with a finger still on an arrow; the pointer-up
    // then lands on the overlay, so the button would never hear about it.
    _releaseSteer();
    setState(() => _phase = _Phase.paused);
  }

  void _resume() {
    if (_phase != _Phase.paused) return;
    // Ticker.start() restarts its elapsed clock from zero, so a stale
    // _lastTick would make the first dt negative and cost a frame.
    _lastTick = Duration.zero;
    _ticker.start();
    setState(() => _phase = _Phase.playing);
    _focus.requestFocus();
  }

  /// Leave, handing the score back to the listing. The attempt is already
  /// spent, so quitting early still reports what was reached.
  void _leave() {
    Navigator.of(context).pop(MiniGameOutcome(
      score: _world?.score ?? 0,
      coins: _world?.eduxCoins ?? 0,
    ));
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_phase != _Phase.playing) return KeyEventResult.ignored;
    return _steering.handleKey(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase != _Phase.playing) return;
    _dragOrigin = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final origin = _dragOrigin;
    if (origin == null) return;
    final delta = details.localPosition - origin;
    _steering.slingshot.aim(delta.dx, delta.dy);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragOrigin == null) return;
    _dragOrigin = null;
    _steering.slingshot.release();
  }

  void _pressSteer({required bool left, required bool down}) {
    if (_phase != _Phase.playing) return;
    _steering.holdTouch(left: left ? down : null, right: left ? null : down);
    setState(() {
      if (left) {
        _steerLeftHeld = down;
      } else {
        _steerRightHeld = down;
      }
    });
  }

  void _releaseSteer() {
    _steering.releaseTouch();
    _steerLeftHeld = false;
    _steerRightHeld = false;
  }

  /// Whether the run needs the on-screen arrows.
  ///
  /// An iPad browser never delivers motion readings — Safari gates them behind
  /// a permission prompt this engine cannot raise — which used to leave the
  /// slingshot as the only way to steer, and a slingshot is far too coarse to
  /// climb a tower with. So the arrows are offered whenever nothing better has
  /// taken over: a device that reports tilt, or one where an arrow key has been
  /// pressed, keeps the screen clear.
  bool get _steerButtonsVisible =>
      _steering.mode == SteeringMode.slingshot ||
      _steering.mode == SteeringMode.touch;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_phase == _Phase.playing) {
          _pause();
        } else {
          _leave();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF7EC8EE),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            // Rebuilding the world on every resize would restart the run, so
            // the size is captured once and a later resize just letterboxes.
            _viewSize ??= size;

            // Built as soon as the size is known rather than on the first tap,
            // so the start screen sits on the real level instead of a flat
            // blue rectangle. It simply does not move until the ticker runs.
            _world ??= SkyJumperWorld(
              setup: widget.setup,
              view: Size2D(width: size.width, height: size.height),
              seed: widget.seed,
            );

            return Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The playfield owns the tap-to-start and the slingshot
                  // drag. It is a sibling *below* the arrows rather than
                  // their ancestor, so a press on a button is settled by hit
                  // testing instead of by a gesture-arena fight with the pan.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _phase == _Phase.ready ? _start : null,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: _world == null
                        ? const SizedBox.expand()
                        : CustomPaint(
                            painter: SkyJumperPainter(
                              world: _world!,
                              cloudScroll: _cloudScroll,
                              sprites: _sprites,
                              avatarSprite: widget.avatarSprite,
                            ),
                          ),
                  ),
                  SafeArea(child: _buildHud()),
                  if (_phase == _Phase.playing && _steerButtonsVisible)
                    SafeArea(child: _buildSteerButtons()),
                  if (_phase == _Phase.ready) ...[
                    _buildReadyOverlay(),
                    // Above the scrim rather than in the HUD beneath it, so
                    // the arrow is the one thing on the start screen the
                    // gradient does not dim.
                    SafeArea(child: _buildExitButton()),
                  ],
                  if (_phase == _Phase.paused) _buildPausedOverlay(),
                  if (_phase == _Phase.over) _buildGameOverOverlay(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Score bottom-left as in the design, pause top-right where it cannot be
  /// hit by a thumb that is busy steering.
  Widget _buildHud() {
    // The world now exists before the run does, so the HUD keys off the phase:
    // a score of 0 behind the start screen would be noise.
    final world = _phase == _Phase.ready ? null : _world;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        // The score sits bottom-left, which is exactly where the left arrow
        // lands. Lift it clear rather than move it — the design puts it there
        // and the arrows are only on screen on some devices.
        _phase == _Phase.playing && _steerButtonsVisible
            ? _steerButtonSize + 28
            : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_phase == _Phase.playing)
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _pause,
                child: _pill(null, icon: Icons.pause_rounded),
              ),
            ),
          const Spacer(),
          if (world != null)
            _pill('${AppStrings.gameScore}: ${world.score}'),
        ],
      ),
    );
  }

  /// The way out of the start screen (BR-W3A6SJ).
  ///
  /// Top-left, where a back arrow lives everywhere else in the app. It mirrors
  /// the system back gesture — which a desktop browser does not have, so until
  /// now the start screen was a dead end there. Like that gesture it asks no
  /// confirmation: the attempt was spent when the page opened either way, and
  /// nothing has been played yet. Once the run is on, the pause menu takes
  /// over and does warn.
  ///
  /// A different glyph from the on-screen steer arrows on purpose: the left
  /// arrow already means "go left", and this one must not read as steering.
  Widget _buildExitButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Semantics(
          button: true,
          label: AppStrings.gameExit,
          child: GestureDetector(
            onTap: _leave,
            child: _pill(null, icon: Icons.arrow_back_ios_new_rounded),
          ),
        ),
      ),
    );
  }

  Widget _pill(String? text, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 20)
          : Text(
              text!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
    );
  }

  /// Diameter of an on-screen arrow. Comfortably past the 48dp tap target —
  /// this one is held for a whole run, not tapped once.
  static const double _steerButtonSize = 76;

  /// The on-screen arrows: one per bottom corner, where the thumbs already
  /// are. They are held rather than tapped and feed the same axis as the
  /// arrow keys, so a run steered this way scores like any other.
  Widget _buildSteerButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _steerButton(
              icon: Icons.arrow_back_rounded,
              label: AppStrings.gameSteerLeft,
              left: true,
            ),
            _steerButton(
              icon: Icons.arrow_forward_rounded,
              label: AppStrings.gameSteerRight,
              left: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Raw pointer events, not a tap: steering has to begin on touch-down and
  /// last exactly as long as the finger stays put.
  Widget _steerButton({
    required IconData icon,
    required String label,
    required bool left,
  }) {
    final held = left ? _steerLeftHeld : _steerRightHeld;

    return Semantics(
      button: true,
      label: label,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _pressSteer(left: left, down: true),
        onPointerUp: (_) => _pressSteer(left: left, down: false),
        onPointerCancel: (_) => _pressSteer(left: left, down: false),
        child: Container(
          width: _steerButtonSize,
          height: _steerButtonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: held ? 0.5 : 0.28),
            border: Border.all(
              color: Colors.white.withValues(alpha: held ? 0.85 : 0.45),
              width: 2,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  /// The hint names the scheme actually in use, which is only known after the
  /// sensor has had a chance to report.
  String get _controlHint => switch (_steering.mode) {
        SteeringMode.tilt => AppStrings.gameHintTilt,
        SteeringMode.keyboard => AppStrings.gameHintKeys,
        // The arrows are what the player will actually see, on a desktop
        // browser as much as on an iPad, so they are what the hint names.
        SteeringMode.touch || SteeringMode.slingshot =>
          AppStrings.gameHintButtons,
      };

  /// The start screen.
  ///
  /// Sits on the real level rather than a flat colour, so the player sees what
  /// they are about to play. The scrim is a gradient instead of a flat wash so
  /// the artwork still reads through the top of the screen.
  Widget _buildReadyOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.15),
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.72),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.gameReadyHeadline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              _buildRules(),
              const SizedBox(height: 20),
              _buildControlHint(),
              const SizedBox(height: 20),
              _primaryButton(AppStrings.gameTapToStart, _start),
            ],
          ),
        ),
      ),
    );
  }

  /// The rules, each next to the thing it is talking about. The boost coin is
  /// the reason this exists: a star that launches you is not guessable from
  /// looking at it, and nothing else in the run explains it.
  Widget _buildRules() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: AppDecorations.radiusL,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rule(
            const Icon(Icons.keyboard_double_arrow_up_rounded,
                color: Colors.white, size: 24),
            AppStrings.gameRuleClimb,
          ),
          _rule(
            SvgPicture.asset(_eduCoinAsset, width: 24, height: 24),
            AppStrings.gameRuleCoin,
          ),
          _rule(
            SvgPicture.asset(_boostCoinAsset, width: 24, height: 24),
            AppStrings.gameRuleBoost,
          ),
          _rule(
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 24),
            AppStrings.gameRuleFall,
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _rule(Widget leading, String text, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 26, height: 26, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlHint() {
    final icon = switch (_steering.mode) {
      SteeringMode.tilt => Icons.screen_rotation_rounded,
      SteeringMode.keyboard => Icons.keyboard_rounded,
      SteeringMode.touch || SteeringMode.slingshot => Icons.touch_app_rounded,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _controlHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Full-width call to action in the app's own primary colour, so the game
  /// still looks like part of the product.
  Widget _primaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppDecorations.radiusM,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return _scrim(
      children: [
        Text(AppStrings.gamePaused, style: _overlayTitle),
        const SizedBox(height: 12),
        Text(AppStrings.gameQuitConfirm, style: _overlayBody, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        _button(AppStrings.gameResume, _resume),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _leave,
          child: Text(
            AppStrings.gameQuit,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverOverlay() {
    final world = _world;

    return _scrim(
      children: [
        Text(AppStrings.gameOver, style: _overlayTitle),
        const SizedBox(height: 16),
        Text(
          '${AppStrings.gameScore}: ${world?.score ?? 0}',
          style: _overlayScore,
        ),
        const SizedBox(height: 6),
        Text(
          '${AppStrings.gameCoinsCollected}: ${world?.eduxCoins ?? 0}',
          style: _overlayBody,
        ),
        const SizedBox(height: 28),
        _button(AppStrings.gameBack, _leave),
      ],
    );
  }

  Widget _scrim({required List<Widget> children}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppDecorations.radiusS,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  static const _overlayTitle = TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  static const _overlayScore = TextStyle(
    color: Colors.white,
    fontSize: 34,
    fontWeight: FontWeight.w800,
  );

  static const _overlayBody = TextStyle(color: Colors.white70, fontSize: 16);
}
