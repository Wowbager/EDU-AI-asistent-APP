import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../services/session_meta.dart';
import '../services/work_time_tracker.dart';

/// Wraps the app and enforces shared-device idle logout.
///
/// Active only when [SessionMeta.sharedDevice] is true. Hooks pointer and
/// keyboard events to refresh last-active, runs a periodic check + lifecycle
/// resume check, and invokes [onLogout] when the inactivity limit (or hard
/// cap) is hit.
///
/// Both input hooks are *global* (binding-level), not subtree listeners. This
/// widget lives inside the root route, and every detail page — Můj účet,
/// Doplňky, lesson/course pages — is an imperative `Navigator.push`, i.e. a
/// sibling overlay entry above that route. A `Listener` here would never
/// hit-test those pages, so working in them looked like idling and the session
/// was logged out mid-use (BR-CMB8RU).
class InactivityWatcher extends ConsumerStatefulWidget {
  final Widget child;
  final Future<void> Function() onLogout;

  const InactivityWatcher({
    super.key,
    required this.child,
    required this.onLogout,
  });

  @override
  ConsumerState<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends ConsumerState<InactivityWatcher>
    with WidgetsBindingObserver {
  Timer? _checkTimer;
  bool _loggingOut = false;

  /// Held rather than re-read in [dispose]: Riverpod forbids `ref` once the
  /// element is disposed, and throwing there would skip the timer teardown
  /// below. The tree does get torn down — switching language re-keys the whole
  /// MaterialApp.
  late final WorkTimeTracker _workTime;

  @override
  void initState() {
    super.initState();
    _workTime = ref.read(workTimeTrackerProvider);
    WidgetsBinding.instance.addObserver(this);
    // 5s cadence keeps the shared-device banner countdown honest: logout fires
    // within a few seconds of the visible timer reaching 00:00 (not up to 30s
    // later). The check itself is a couple of cheap timestamp comparisons.
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    // Keyboard input counts as activity too. Pointer events (below) miss typing
    // entirely — a student answering exercises or reading a lesson with only the
    // keyboard/scroll wheel would otherwise be treated as idle and logged out
    // mid-lesson (BR-ZKY22S).
    HardwareKeyboard.instance.addHandler(_onKey);
    // Taps, drags and scroll wheel, from anywhere in the app. A global route on
    // the pointer router sees every event the binding dispatches, including
    // those landing on pushed routes, dialogs and bottom sheets — see the class
    // doc for why a subtree Listener is not enough (BR-CMB8RU).
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    // Run a check next frame in case we resumed from a long sleep before
    // build wired up the lifecycle observer.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    // Start work-time heartbeat tracking (BR-9SAH2R) — independent of the
    // shared-device idle logout; runs for all authenticated users.
    _workTime.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _checkTimer?.cancel();
    _workTime.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_loggingOut) return;
    final session = ref.read(sessionMetaProvider);
    if (!session.sharedDevice) return;

    if (session.isInactivityExpired() || session.isHardCapExceeded()) {
      _loggingOut = true;
      try {
        await widget.onLogout();
      } finally {
        _loggingOut = false;
      }
    }
  }

  /// Global pointer route. Fires for every event the binding dispatches, so it
  /// filters down to the ones a person actually caused:
  ///  * down/move/up — taps and drags (a move only arrives with a button held),
  ///  * signal — scroll wheel; scrolling a long page is not idling,
  ///  * pan/zoom update — the trackpad equivalent of the above.
  /// Hover is deliberately excluded: Flutter synthesizes hover events when the
  /// tree changes under a stationary cursor, which would keep an unattended
  /// session alive forever.
  void _onPointer(PointerEvent event) {
    if (event.synthesized) return;
    if (event is PointerDownEvent ||
        event is PointerMoveEvent ||
        event is PointerUpEvent ||
        event is PointerSignalEvent ||
        event is PointerPanZoomUpdateEvent) {
      _markActivity();
    }
  }

  // Keyboard handler: observe keystrokes as activity without consuming them, so
  // text fields still receive the key. Must return false.
  bool _onKey(KeyEvent _) {
    _markActivity();
    return false;
  }

  void _markActivity() {
    // Work-time activity is tracked for everyone.
    _workTime.markActive();

    // Idle-logout activity only matters for shared-device sessions.
    final session = ref.read(sessionMetaProvider);
    if (!session.sharedDevice) return;
    session.touchActivity();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
