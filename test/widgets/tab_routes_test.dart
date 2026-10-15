import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:eduai/core/providers/navigation_providers.dart';
import 'package:eduai/routing/app_router.dart';
import 'package:eduai/routing/deep_link.dart';
import 'package:eduai/routing/shell_entry.dart';
import 'package:eduai/routing/tab_routes.dart';
import 'package:eduai/widgets/nav_destinations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-7RNBZ9: the whole signed-in app lived on `/`. Switching tabs moved
// mainTabIndexProvider and nothing else, so the browser recorded no history
// and its back button left the site instead of returning to the previous
// section.
//
// The fix gives each tab a URL and hangs every shell route off one shared
// page key, so the router can change the URL — and with it the history — while
// Navigator updates the route in place and AuthWrapper below keeps its State.
// Both halves are pinned here: the page-key invariant against the real
// buildAppRouter, the URL→state wiring against the real ShellEntry.
//
// Not covered: AuthWrapper actually surviving the update, which needs a
// signed-in session. It cannot be mounted in a widget test at all —
// InactivityWatcher starts real periodic timers that flutter_test will not let
// a test end with, which is why root_navigator_minor_test.dart reproduces the
// boot sequence rather than pumping the wrapper. Checked in a local web build
// that every path here serves and boots the app rather than the router's error
// page; back/forward between tabs is a stage check.
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the page a path resolves to, without mounting it. `context` is only
/// forwarded to `pageBuilder`, which the shell routes ignore.
Page<Object?> _pageAt(GoRouter router, BuildContext context, String path) {
  final config = router.configuration;
  final matches = config.findMatch(Uri.parse(path));
  expect(matches.isError, isFalse, reason: '$path does not route');

  final match = matches.matches.last as RouteMatch;
  return match.route.pageBuilder!(context, match.buildState(config, matches));
}

void main() {
  group('mainTabIndexForPath', () {
    test('answers every tab path with its own index', () {
      for (var i = 0; i < mainTabPaths.length; i++) {
        expect(mainTabIndexForPath(mainTabPaths[i]), i);
      }
    });

    test('treats / as the dashboard, not a section of its own', () {
      // Otherwise tapping "Přehled" on the launch screen pushes a second
      // history entry for the screen already showing.
      expect(mainTabIndexForPath('/'), 0);
      expect(mainTabPaths[0], '/dash');
    });

    test('answers null for paths that are not tabs', () {
      for (final path in const [
        '/terms',
        '/course/676767',
        '/chat/skolnik',
        '/join/AB12',
        '/nope',
      ]) {
        expect(mainTabIndexForPath(path), isNull, reason: path);
      }
    });
  });

  test('there is a path for every tab destination', () {
    // navDestinations' index *is* the tab selector (see its doc). A destination
    // added there without a path here would have no URL, and one removed would
    // shift every path onto the wrong section.
    final tabIndexes = navDestinations
        .where((d) => d.index != null)
        .map((d) => d.index!)
        .toList()
      ..sort();

    expect(tabIndexes, List.generate(mainTabPaths.length, (i) => i));
  });

  group('shell routes', () {
    testWidgets('all resolve to pages Navigator can update in place',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      final router = buildAppRouter();
      addTearDown(router.dispose);

      // `/` and the deep links host the same app as the tabs, so they belong to
      // the same route: navigating between any two of them must not rebuild it.
      const shellPaths = [
        '/',
        ...mainTabPaths,
        '/course/676767',
        '/pin/676767',
        '/chat/skolnik',
        '/join/AB12',
      ];

      final pages = [
        for (final path in shellPaths) _pageAt(router, context, path),
      ];

      for (var i = 1; i < pages.length; i++) {
        expect(
          pages[i].canUpdate(pages.first),
          isTrue,
          reason: '${shellPaths[i]} would replace the route, not update it — '
              'AuthWrapper (and any pushed page) would be torn down',
        );
      }
    });

    testWidgets('legal routes still replace theirs (BR-QVMBDN)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      final router = buildAppRouter();
      addTearDown(router.dispose);

      // Each legal path is a different document and must be rebuilt — the
      // opposite of what the shell routes want from the same mechanism.
      expect(
        _pageAt(router, context, '/terms')
            .canUpdate(_pageAt(router, context, '/privacy')),
        isFalse,
      );
    });
  });

  group('ShellEntry', () {
    /// Pumps [ShellEntry] with its `AuthWrapper` stubbed out, and returns the
    /// container so the test can read what the route wrote.
    Future<ProviderContainer> pumpEntry(
      WidgetTester tester, {
      int? tabIndex,
      String? deepLinkCode,
      String? chatMentorSlug,
      String? classroomJoinCode,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ShellEntry(
              tabIndex: tabIndex,
              deepLinkCode: deepLinkCode,
              chatMentorSlug: chatMentorSlug,
              classroomJoinCode: classroomJoinCode,
              child: const Scaffold(body: Text('shell')),
            ),
          ),
        ),
      );
      await tester.pump(); // let the post-frame callback run
      return container;
    }

    testWidgets('selects the tab its route names', (tester) async {
      final container = await pumpEntry(tester, tabIndex: 3);
      expect(container.read(mainTabIndexProvider), 3);
    });

    testWidgets('follows the URL when the route is reused', (tester) async {
      // What browser back/forward looks like from here: the page key is shared,
      // so the route is updated rather than remounted and only didUpdateWidget
      // fires.
      final container = await pumpEntry(tester, tabIndex: 4);
      expect(container.read(mainTabIndexProvider), 4);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ShellEntry(
              tabIndex: 1,
              child: Scaffold(body: Text('shell')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(container.read(mainTabIndexProvider), 1);
    });

    testWidgets('closes pushed detail pages before landing on the tab',
        (tester) async {
      // Course/lesson/profile pages are imperative pushes the router knows
      // nothing about. Left alone, a back that only swapped the URL would move
      // the section underneath while the detail page stayed on screen.
      final container = await pumpEntry(tester, tabIndex: 3);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('course detail')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('course detail'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ShellEntry(
              tabIndex: 0,
              child: Scaffold(body: Text('shell')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('course detail'), findsNothing);
      expect(container.read(mainTabIndexProvider), 0);
    });

    testWidgets('parks a deep-link code without touching the tab',
        (tester) async {
      // The enroll path picks the tab itself, once the code resolves — moving
      // it here would highlight Kurzy for a code that turns out to be invalid.
      final container = await pumpEntry(tester, deepLinkCode: '676767');

      expect(container.read(pendingDeepLinkCodeProvider), '676767');
      expect(container.read(mainTabIndexProvider), 0);
    });

    testWidgets('parks a mentor slug and lands on the chat tab (BR-HCF5AS)',
        (tester) async {
      // `/chat/skolnik` used to hit the router's error page. The slug goes to
      // ChatyPage, and unlike a course code the tab does move here — that page
      // is the only one that can act on it.
      final container = await pumpEntry(
        tester,
        tabIndex: kChatTabIndex,
        chatMentorSlug: 'skolnik',
      );

      expect(container.read(pendingChatMentorSlugProvider), 'skolnik');
      expect(container.read(mainTabIndexProvider), kChatTabIndex);
    });

    testWidgets('a mentor slug never lands on the course deep-link path',
        (tester) async {
      // The login screen resolves pendingDeepLinkCodeProvider as a PIN; a slug
      // in there would be typed into the code field.
      final container = await pumpEntry(
        tester,
        tabIndex: kChatTabIndex,
        chatMentorSlug: 'skolnik',
      );

      expect(container.read(pendingDeepLinkCodeProvider), isNull);
    });

    testWidgets('parks a class code for the signed-in app (BR-TT6TD7)',
        (tester) async {
      // `/join/AB12`: the join is a dialog over whatever tab is showing, so
      // the tab stays put — and the code must stay off the course path, where
      // the login screen would try it as a six-digit PIN.
      final container = await pumpEntry(tester, classroomJoinCode: 'AB12');

      expect(container.read(pendingClassroomJoinCodeProvider), 'AB12');
      expect(container.read(pendingDeepLinkCodeProvider), isNull);
      expect(container.read(mainTabIndexProvider), 0);
    });
  });

  group('goToMainTab', () {
    testWidgets('moves the tab even with no router above it', (tester) async {
      // DetailShell is pumped under a bare MaterialApp in
      // deep_link_tab_test.dart; the helper must degrade to a plain tab switch
      // rather than throw.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      late BuildContext context;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (ctx, ref, _) {
                context = ctx;
                return ElevatedButton(
                  onPressed: () => goToMainTab(ctx, ref, 2),
                  child: const Text('library'),
                );
              },
            ),
          ),
        ),
      );

      expect(GoRouter.maybeOf(context), isNull);
      await tester.tap(find.text('library'));
      await tester.pump();

      expect(container.read(mainTabIndexProvider), 2);
    });
  });
}
