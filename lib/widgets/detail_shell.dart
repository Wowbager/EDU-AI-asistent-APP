import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/navigation_providers.dart';
import '../core/theme/app_theme.dart';
import '../routing/tab_routes.dart';
import 'desktop_top_bar.dart';
import 'nav_destinations.dart';
import 'shell_banners.dart';
import 'side_nav.dart';
import '../core/layout/breakpoints.dart';

/// Sidebar + top bar for pages pushed on top of `MainScreen`.
///
/// Detail pages are full routes above the main shell, so on a wide viewport
/// they would otherwise lose the navigation entirely. This redraws it and
/// routes taps back through [mainTabIndexProvider]: pick a destination, the
/// pushed route pops, and `MainScreen` is already on the right tab.
///
/// On phones it returns the child untouched — the page keeps its own back
/// button and bottom chrome.
class DetailShell extends ConsumerWidget {
  final Widget child;

  /// Left-hand link in the top bar, e.g. "Zpět na všechny kurzy". Pages the
  /// sidebar can reach directly (games, shop) leave it out and pass [title]
  /// instead — they are destinations, not a step deeper into something.
  final String? backLabel;

  /// Page heading, rendered exactly like a tab's (see `AdaptiveShell`).
  /// Mutually exclusive with [backLabel]: the top bar shows one or the other.
  final String? title;
  final String? subtitle;

  /// Defaults to popping this route.
  final VoidCallback? onBack;

  /// Which sidebar push destination this page belongs to, if any.
  ///
  /// Pages that are a step deeper into a *tab* (a course, a lesson, a chat)
  /// leave this null: the tab underneath is still the right answer for them.
  /// Pages that *are* a sidebar destination — or live inside one, like the
  /// shop under Doplňky — name it, so the sidebar lights the row the user is
  /// actually looking at instead of the tab they came from (BR-WB6EUH).
  final NavPush? activePush;

  /// This page belongs to "Můj účet", which the sidebar reaches through its
  /// account block rather than a destination row — so the highlight has to go
  /// there instead (BR-5JSXBV). Pages that only live *under* the account, like
  /// the avatar editor, set this alone: lit, and still tappable.
  final bool accountActive;

  /// This page *is* "Můj účet". Only the profile sets it, and it is what stops
  /// the account block being a button. [accountActive] used to carry this
  /// meaning too, which left the block dead on the avatar editor — the one
  /// other page that wanted the highlight (BR-NYNNM8).
  final bool isAccountPage;

  const DetailShell({
    super.key,
    required this.child,
    this.backLabel,
    this.title,
    this.subtitle,
    this.onBack,
    this.activePush,
    this.accountActive = false,
    this.isAccountPage = false,
  }) : assert(backLabel != null || title != null,
            'DetailShell needs a backLabel or a title for its top bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = context.widthClass;
    if (size == WidthClass.compact) return child;

    final expanded = size == WidthClass.expanded;
    // Same predicate the main shell uses — a bare `email.isEmpty` here showed
    // the sign-up card to code-login students and minors on every pushed page
    // (course, lesson, library, chat, games, shop) even though the main tabs
    // had already stopped doing that (BR-7CDXBR).
    final isGuest = ref.watch(canOfferSignupProvider);

    void back() => (onBack ?? () => Navigator.of(context).pop())();

    void goToTab(int index) {
      // Same helper the main shell uses, so the URL follows a sidebar tap from
      // a pushed page too (BR-7RNBZ9).
      goToMainTab(context, ref, index);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // The sidebar's actions need MainScreen's logout/OAuth callbacks, which
    // this page cannot see. Record the intent, pop, and let MainScreen carry
    // it out.
    void requestIntent(ShellIntent intent) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(pendingShellIntentProvider.notifier).state = intent;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SideNav(
            selectedIndex: ref.watch(mainTabIndexProvider),
            activePush: activePush,
            onItemTapped: goToTab,
            // Same reasoning as the profile intent: pop back to the shell
            // first, so Doplňky replaces this page rather than stacking on
            // top of it, and MainScreen gets to prepare it.
            onPushTapped: (push) => requestIntent(
              switch (push) {
                NavPush.doplnky => ShellIntent.openDoplnky,
              },
            ),
            expanded: expanded,
            isGuest: isGuest,
            // Already on the profile: tapping through would pop to the shell
            // and push an identical page, flickering for nothing. The block is
            // the "you are here" marker instead. Every other page keeps it as a
            // button — the avatar editor lights the block and hanging the check
            // on the highlight left it dead there (BR-NYNNM8).
            onProfileTap: isAccountPage
                ? null
                : () => requestIntent(ShellIntent.openProfile),
            accountActive: accountActive || isAccountPage,
            // Through the same intent channel as the rest of the footer, not
            // `requestGuestLoginProvider`: a course reached straight from a
            // PIN login is pushed by `AuthPage`, with no `MainScreen` under it
            // to hear that bump, so the card did nothing at all (BR-CMP2PX).
            onRegisterTap: () => requestIntent(ShellIntent.openGuestLogin),
            // Same place as the main shell puts them, so nothing shifts when
            // a pushed page replaces the one underneath.
            notices: expanded
                ? ShellBanners(
                    onLogout: () => requestIntent(ShellIntent.logout),
                  )
                : null,
          ),
          Expanded(
            child: SafeArea(
              left: false,
              child: Column(
                children: [
                  // Tablet rail has no room for the notices, so they stay
                  // across the top there.
                  if (!expanded)
                    ShellBanners(
                      onLogout: () => requestIntent(ShellIntent.logout),
                    ),
                  DesktopTopBar(
                    // With no back link the bar falls through to its
                    // title/subtitle block — the same heading a tab gets, which
                    // is what Hry/Obchod were missing (BR-WJMTUF).
                    title: title ?? backLabel!,
                    subtitle: subtitle,
                    backLabel: backLabel,
                    onBack: backLabel != null ? back : null,
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
