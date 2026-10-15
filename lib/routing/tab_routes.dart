import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/navigation_providers.dart';

/// URL path for each main tab, indexed the way `MainScreen.pages` and
/// `navDestinations` are — the same index [mainTabIndexProvider] holds.
///
/// Before these existed the whole signed-in app lived on `/`: switching tabs
/// moved a provider and never the URL, so the browser had no history to walk
/// back through and its back button left the site outright (BR-7RNBZ9). They
/// double as shareable links into a section.
///
/// English slugs, matching the rest of `buildAppRouter` (`/course/:code`,
/// `/terms`, `/consent/...`).
const mainTabPaths = <String>[
  '/dash',
  '/chat',
  '/library',
  '/courses',
  '/news',
];

/// The tab [path] selects, or null if it is not a shell route.
///
/// `/` answers 0: it is where the app boots and it shows the dashboard, so it
/// is an alias of `/dash` rather than a section of its own. Without that,
/// tapping "Přehled" on the launch screen would push a second history entry
/// for the screen already on display.
int? mainTabIndexForPath(String path) {
  if (path == '/') return 0;
  final index = mainTabPaths.indexOf(path);
  return index == -1 ? null : index;
}

/// Switch to a main tab *and* move the browser to its URL.
///
/// Use this wherever the user asks for a tab: the bottom bar, either sidebar,
/// a "show all" link. Code that only points the shell at the tab sitting
/// *underneath* a page it is about to push keeps writing [mainTabIndexProvider]
/// directly — the `/course|/pin` deep link and the PIN login's course hand-off
/// (BR-48B7DY) both do that, and rewriting the URL there would throw the deep
/// link away and pop the page they just pushed.
///
/// `go`, not `push`: every shell route renders the same page (see `ShellEntry`),
/// so the router updates the one route in place. The browser still records a
/// history entry, but `AuthWrapper` keeps its State — no re-authentication and
/// no loading spinner on a tab tap.
void goToMainTab(BuildContext context, WidgetRef ref, int index) {
  ref.read(mainTabIndexProvider.notifier).state = index;

  // Null in widget tests that pump a page under a bare MaterialApp, and on any
  // screen drawn outside the router.
  final router = GoRouter.maybeOf(context);
  if (router == null) return;

  // Already on a URL that means this tab — the call came *from* the URL
  // (browser back/forward, cold start on a tab route), so navigating again
  // would stack a duplicate entry.
  if (mainTabIndexForPath(router.state.uri.path) == index) return;

  router.go(mainTabPaths[index]);
}
