import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/navigation_providers.dart';
import 'deep_link.dart';
import 'root_navigator.dart';
import 'tab_routes.dart';

/// The one widget behind every route that hosts the signed-in app: `/`, the
/// `/course|/pin|/join` deep links, and the tab routes in [mainTabPaths].
///
/// One widget for all of them — paired with the one shared page key in
/// `buildAppRouter` — is what makes the browser's back button usable.
/// `Page.canUpdate` matches on runtime type and key, so identical pages make
/// Navigator *update* the route rather than replace it: the router reports the
/// new URL to the browser (which records a history entry) while [AuthWrapper]
/// underneath keeps its State. Give these routes a per-path `state.pageKey`, or
/// let them render different widgets, and every navigation tears the signed-in
/// app down — auth check, sync, pushed pages and all.
class ShellEntry extends ConsumerStatefulWidget {
  /// Tab to select, for the routes in [mainTabPaths]. Null on the deep links,
  /// which leave the current tab to whoever consumes the code.
  final int? tabIndex;

  /// Course join code/PIN from a `/course/:code` or `/pin/:code` link. Parked
  /// in [pendingDeepLinkCodeProvider] for whichever screen the boot flow
  /// reaches first — `AuthPage` when logged out, `MainScreen` when logged in.
  final String? deepLinkCode;

  /// Mentor slug from a `/chat/:mentor` link. Parked in
  /// [pendingChatMentorSlugProvider] for `ChatyPage`, which the [tabIndex]
  /// this route carries is what brings on screen.
  final String? chatMentorSlug;

  /// Class code from a `/join/:code` link (BR-TT6TD7). Parked in
  /// [pendingClassroomJoinCodeProvider] for `MainScreen`; the login screen
  /// never sees it, since joining a class needs an account, not a PIN.
  final String? classroomJoinCode;

  /// The signed-in app. Only ever overridden by tests: [AuthWrapper] wraps
  /// every state in `InactivityWatcher`, which starts real periodic timers that
  /// `flutter_test` refuses to end a test with — the same reason
  /// test/widgets/root_navigator_minor_test.dart reproduces the boot sequence
  /// instead of mounting the wrapper. The URL→state wiring below is testable
  /// on its own; the wrapper it hosts is not.
  final Widget child;

  const ShellEntry({
    super.key,
    this.tabIndex,
    this.deepLinkCode,
    this.chatMentorSlug,
    this.classroomJoinCode,
    this.child = const AuthWrapper(),
  });

  @override
  ConsumerState<ShellEntry> createState() => _ShellEntryState();
}

class _ShellEntryState extends ConsumerState<ShellEntry> {
  @override
  void initState() {
    super.initState();
    _applyRoute();
  }

  @override
  void didUpdateWidget(ShellEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The route is reused across every shell URL (see the class doc), so a
    // browser back/forward between tabs arrives here as a widget update, not
    // as a fresh mount.
    if (oldWidget.tabIndex != widget.tabIndex ||
        oldWidget.deepLinkCode != widget.deepLinkCode ||
        oldWidget.chatMentorSlug != widget.chatMentorSlug ||
        oldWidget.classroomJoinCode != widget.classroomJoinCode) {
      _applyRoute();
    }
  }

  /// Push what the URL means into app state.
  ///
  /// Deferred by a frame: Riverpod forbids writing a provider from a widget
  /// life-cycle callback, and popping a route mid-build is equally illegal.
  /// It still lands in time — [AuthWrapper] always renders a loading frame
  /// first while it checks auth asynchronously.
  void _applyRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final code = widget.deepLinkCode;
      if (code != null && code.isNotEmpty) {
        ref.read(pendingDeepLinkCodeProvider.notifier).state = code;
      }

      final mentorSlug = widget.chatMentorSlug;
      if (mentorSlug != null && mentorSlug.isNotEmpty) {
        ref.read(pendingChatMentorSlugProvider.notifier).state = mentorSlug;
      }

      final joinCode = widget.classroomJoinCode;
      if (joinCode != null && joinCode.isNotEmpty) {
        ref.read(pendingClassroomJoinCodeProvider.notifier).state = joinCode;
      }

      final tab = widget.tabIndex;
      if (tab == null) return;

      // Detail pages (course, lesson, profile, Doplňky) are imperative pushes
      // the router knows nothing about. A back/forward that only swapped the
      // URL would leave one of them on screen while the section underneath
      // changed — the URL would move and the app would not. Close them first.
      Navigator.maybeOf(context)?.popUntil((route) => route.isFirst);
      ref.read(mainTabIndexProvider.notifier).state = tab;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
