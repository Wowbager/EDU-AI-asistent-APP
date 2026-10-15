/// Transient, non-blocking feedback ("Nejprve vyber odpověď", "Uloženo", …).
///
/// ## Why this exists rather than a plain [SnackBar]
///
/// On a wide viewport the shells (`AdaptiveShell`, `DetailShell`) wrap each
/// page's own `Scaffold` in an outer, window-level one that carries `SideNav`
/// and `DesktopTopBar`. Flutter only ever renders a `SnackBar` in the *root*
/// `Scaffold` of a nested set (`ScaffoldMessengerState._isRoot`), so the bar
/// escaped the content pane and landed at the bottom edge of the whole window,
/// spanning its full width — behind the sidebar, ~800px below the card the user
/// had just clicked. On a phone `DetailShell` returns the page untouched, the
/// page's `Scaffold` *is* root, and the bar is fine — hence "only on desktop"
/// (BR-8H9WTT).
///
/// A `SnackBar` also cannot be placed anywhere but the bottom: `width` merely
/// centres it, and there is no alignment knob. Web users expect a toast in the
/// top-right corner, so wide viewports get a real overlay instead.
///
/// ## Shape of the fix
///
/// * **compact** — unchanged. Phones keep the bottom `SnackBar`; that is the
///   platform convention and it was never the broken case.
/// * **medium / expanded** — a capped-width card in the top-right corner,
///   stacked newest-first, auto-dismissed, tap to close.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';

/// How a toast reads. Only the palette differs; layout is identical.
enum ToastVariant {
  /// "You need to do something first" — the default.
  warning,
  success,
  error,
  info,
}

extension _ToastVariantStyle on ToastVariant {
  Color get background => switch (this) {
        ToastVariant.warning => AppColors.orangeBg,
        ToastVariant.success => AppColors.successBg,
        ToastVariant.error => AppColors.errorBg,
        ToastVariant.info => AppColors.infoBg,
      };

  Color get accent => switch (this) {
        ToastVariant.warning => AppColors.warning,
        ToastVariant.success => AppColors.success,
        ToastVariant.error => AppColors.error,
        ToastVariant.info => AppColors.primary,
      };

  IconData get icon => switch (this) {
        ToastVariant.warning => Icons.error_outline,
        ToastVariant.success => Icons.check_circle_outline,
        ToastVariant.error => Icons.cancel_outlined,
        ToastVariant.info => Icons.info_outline,
      };
}

/// Widest a toast card may grow. Narrow enough to read as a notification
/// rather than a banner, wide enough for a two-line sentence.
const double kToastMaxWidth = 380;

/// Distance from the top/right edges of the window.
const double _kToastInset = 20;

const Duration _kEnterDuration = Duration(milliseconds: 220);
const Duration _kExitDuration = Duration(milliseconds: 160);
const Duration _kDefaultDuration = Duration(seconds: 3);

/// Beyond this the oldest toast is dropped, so a stuck loop cannot paper over
/// the page.
const int _kMaxVisible = 3;

/// Shows [message] as a toast (wide) or a bottom snack bar (phones).
///
/// Repeating the same message — tapping a disabled confirm button over and
/// over — restarts the visible toast instead of stacking copies.
void showAppToast(
  BuildContext context,
  String message, {
  ToastVariant variant = ToastVariant.warning,
  Duration duration = _kDefaultDuration,
}) {
  final host = context.widthClass == WidthClass.compact
      ? null
      : ToastHost.maybeOf(context);

  // No host (compact, or a widget pumped outside `MyApp`) → the snack bar
  // path, which on those layouts renders exactly where it should.
  if (host == null) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.body(color: AppColors.primaryDark),
          ),
          backgroundColor: variant.background,
          duration: duration,
        ),
      );
    return;
  }

  host.show(message, variant: variant, duration: duration);
}

/// Renders the toast stack above [child].
///
/// Mounted once in `MaterialApp.builder`, i.e. above the `Navigator`: the stack
/// then outlives route changes and is positioned against the window rather than
/// whatever pane the calling widget happens to sit in.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  /// Looks the host up *without* registering an inherited dependency — this is
  /// called from tap handlers, which have no business rebuilding when the toast
  /// stack changes (same reason `Navigator.of` does it this way).
  static ToastHostState? maybeOf(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<_ToastScope>()?.widget
              as _ToastScope?)
          ?.state;

  @override
  State<ToastHost> createState() => ToastHostState();
}

class ToastHostState extends State<ToastHost> {
  final List<_ToastData> _toasts = [];
  int _nextId = 0;

  void show(
    String message, {
    ToastVariant variant = ToastVariant.warning,
    Duration duration = _kDefaultDuration,
  }) {
    final existing = _toasts.where(
      (t) => !t.dismissing && t.message == message && t.variant == variant,
    );
    if (existing.isNotEmpty) {
      _arm(existing.first, duration);
      return;
    }

    final toast = _ToastData(
      id: _nextId++,
      message: message,
      variant: variant,
    );
    setState(() {
      _toasts.add(toast);
      while (_toasts.length > _kMaxVisible) {
        _dismiss(_toasts.firstWhere((t) => !t.dismissing, orElse: () => _toasts.first));
      }
    });
    _arm(toast, duration);
  }

  /// (Re)starts the auto-dismiss countdown for [toast].
  void _arm(_ToastData toast, Duration duration) {
    toast.timer?.cancel();
    toast.timer = Timer(duration, () => _dismiss(toast));
  }

  /// Plays the exit animation, then drops the entry a frame later.
  void _dismiss(_ToastData toast) {
    if (!mounted || toast.dismissing) return;
    toast.timer?.cancel();
    setState(() => toast.dismissing = true);
    toast.timer = Timer(_kExitDuration, () {
      if (!mounted) return;
      setState(() => _toasts.remove(toast));
    });
  }

  @override
  void dispose() {
    for (final toast in _toasts) {
      toast.timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ToastScope(
      state: this,
      child: Stack(
        children: [
          widget.child,
          if (_toasts.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + _kToastInset,
              right: _kToastInset,
              // The stack is a *sibling* of the Navigator, so nothing above it
              // supplies a `Material` and its text falls back to `WidgetsApp`'s
              // `_errorTextStyle`. `AppTextStyles.body` overrides the colour,
              // size, family and weight but not `decoration`, so all that came
              // through was the yellow double underline — a debug tell that read
              // as a rendering glitch (BR-PFXDYD). `transparency` paints nothing
              // of its own; it is here purely for the `DefaultTextStyle`.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Newest on top: the reason the user is looking is the
                    // message that just fired.
                    for (final toast in _toasts.reversed)
                      _ToastCard(key: ValueKey(toast.id), toast: toast),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToastData {
  _ToastData({required this.id, required this.message, required this.variant});

  final int id;
  final String message;
  final ToastVariant variant;
  bool dismissing = false;
  Timer? timer;
}

class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.state, required super.child});

  final ToastHostState state;

  @override
  bool updateShouldNotify(_ToastScope oldWidget) => state != oldWidget.state;
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.toast});

  final _ToastData toast;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kEnterDuration,
    reverseDuration: _kExitDuration,
  )..forward();

  @override
  void didUpdateWidget(_ToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.toast.dismissing) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.toast.variant;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        // Slides in from the right edge it is anchored to.
        position: Tween(begin: const Offset(0.12, 0), end: Offset.zero)
            .animate(curve),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ToastHost.maybeOf(context)?._dismiss(widget.toast),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kToastMaxWidth),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: variant.background,
                    borderRadius: AppDecorations.radiusS,
                    boxShadow: AppDecorations.shadowStrong,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(variant.icon, size: 20, color: variant.accent),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.toast.message,
                          style:
                              AppTextStyles.body(color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
