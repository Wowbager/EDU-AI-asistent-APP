import 'package:flutter/material.dart';

import '../core/strings/app_strings.dart';

/// A destination that opens a pushed route rather than switching tabs.
///
/// Doplňky is a full-screen page with its own header and back button, pushed
/// on top of `MainScreen`. Turning it into a tab would mean gutting that
/// header and changing the phone layout, which the sidebar work deliberately
/// leaves alone — so the sidebar asks the shell to push it and the shell
/// decides how (see `ShellIntent`).
enum NavPush { doplnky }

/// One entry in the main navigation.
///
/// The bottom bar and the desktop sidebar render the same destinations very
/// differently (the library tab is a wordless "+" button on phones, a labelled
/// row in the sidebar), but they must agree on the *index* — that index is the
/// tab selector in `MainScreen`. Keeping the list in one place is what stops
/// the two from drifting apart.
class NavDestination {
  /// Index into `MainScreen.pages`. Not the position in this list — the two
  /// happen to match for the tabs, but the index is the contract.
  ///
  /// Null for [push] destinations, which have no tab of their own.
  final int? index;

  /// Set instead of [index] for destinations that push a route. Exactly one of
  /// the two is non-null.
  final NavPush? push;

  /// SVG icon. Null when the destination has no bespoke artwork and falls back
  /// to [icon].
  final String? iconAsset;

  /// Material icon, used when [iconAsset] is null.
  final IconData? icon;

  /// Resolved lazily: [AppStrings] getters read the active locale at call
  /// time, so a `const` label here would freeze the first language used.
  final String Function() label;

  /// Carries the unread-news count. A flag rather than a hard-coded index so
  /// the badge cannot end up on whatever destination drifts into slot 4.
  final bool showsNewsBadge;

  const NavDestination({
    this.index,
    this.push,
    this.iconAsset,
    this.icon,
    required this.label,
    this.showsNewsBadge = false,
  })  : assert((index == null) != (push == null),
            'a destination either selects a tab or pushes a page'),
        assert(iconAsset != null || icon != null, 'a destination needs an icon');
}

/// The main destinations, in sidebar order.
///
/// The phone bottom bar draws its five tabs itself — it has a fixed slot layout
/// built around the floating centre button — so the push destinations at the
/// end are sidebar-only by construction, and the phone layout is unaffected.
final List<NavDestination> navDestinations = [
  NavDestination(
    index: 0,
    iconAsset: 'assets/icons/home.svg',
    label: () => AppStrings.navPrehled,
  ),
  NavDestination(
    index: 1,
    iconAsset: 'assets/icons/chat.svg',
    label: () => AppStrings.navChat,
  ),
  NavDestination(
    index: 2,
    iconAsset: 'assets/icons/add.svg',
    label: () => AppStrings.libraryTitle,
  ),
  NavDestination(
    index: 3,
    iconAsset: 'assets/icons/kurzy.svg',
    label: () => AppStrings.navKurzy,
  ),
  // "Notifications" in the design is this: there is no separate notification
  // feed, the unread badge has always belonged to Novinky.
  NavDestination(
    index: 4,
    iconAsset: 'assets/icons/novinky.svg',
    label: () => AppStrings.navNovinky,
    showsNewsBadge: true,
  ),
  // Games and the shop have no standalone entries any more — both live on the
  // Doplňky page, together with the theme editor.
  NavDestination(
    push: NavPush.doplnky,
    iconAsset: 'assets/icons/doplnky.svg',
    label: () => AppStrings.doplnkyTitle,
  ),
];
