import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/navigation_providers.dart';
import '../data/repositories/consent_repository.dart';
import '../main.dart' show routeObserver;
import '../pages/consent/consent_confirm_web_page.dart';
import '../pages/consent/consent_manage_web_page.dart';
import '../pages/legal/legal_page.dart';
import 'shell_entry.dart';
import 'tab_routes.dart';

GoRouter buildAppRouter({
  GlobalKey<NavigatorState>? navigatorKey,
  String initialLocation = '/',
}) {
  // Pages carry `state.pageKey` (a ValueKey of the matched path). Without it two
  // NoTransitionPages compare equal under `Page.canUpdate`, so Navigator reuses
  // the outgoing route entry instead of building the new one. That is the
  // default go_router applies to `builder:` routes; hand-written `pageBuilder:`
  // routes have to do it themselves.
  //
  // The shell routes below want exactly the opposite and share one key on
  // purpose — see [ShellEntry]. Reusing the route is what lets the URL, and the
  // browser history behind it, change without tearing the signed-in app down.
  // The legal routes must keep `state.pageKey`: each path there is a different
  // document and has to be rebuilt (BR-QVMBDN).
  const shellPageKey = ValueKey('app-shell');

  final routes = <RouteBase>[
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => const NoTransitionPage(
        key: shellPageKey,
        // Boot URL, and an alias of /dash — see [mainTabIndexForPath].
        child: ShellEntry(tabIndex: 0),
      ),
    ),
    // One route per main tab, so every section has its own URL and the browser
    // back button walks between them instead of leaving the app (BR-7RNBZ9).
    for (var i = 0; i < mainTabPaths.length; i++)
      GoRoute(
        path: mainTabPaths[i],
        pageBuilder: (context, state) => NoTransitionPage(
          key: shellPageKey,
          child: ShellEntry(tabIndex: i),
        ),
      ),
    // Deep links: both resolve a course by its join code/PIN (e.g. 676767).
    // They record the code and boot the normal auth flow; MainScreen opens the
    // course once the app reaches the main screen. No tabIndex — the enroll
    // path picks the tab itself, once the code resolves (BR-48B7DY).
    for (final prefix in const ['course', 'pin'])
      GoRoute(
        path: '/$prefix/:code',
        pageBuilder: (context, state) => NoTransitionPage(
          key: shellPageKey,
          child: ShellEntry(deepLinkCode: state.pathParameters['code'] ?? ''),
        ),
      ),
    // Class code deep link (BR-TT6TD7): `/join/AB12` joins the class whose
    // teacher set that code. Like `/course|/pin` it carries no tabIndex — the
    // join is a dialog over whatever tab is showing — and it parks the code
    // for MainScreen, not for the login screen: logged out, the visitor lands
    // on login and the join follows once they are in.
    GoRoute(
      path: '/join/:code',
      pageBuilder: (context, state) => NoTransitionPage(
        key: shellPageKey,
        child: ShellEntry(
          classroomJoinCode: state.pathParameters['code'] ?? '',
        ),
      ),
    ),
    // Mentor deep link: `/chat/skolnik` opens the chat tab and starts a
    // conversation with that mentor. Unlike `/course|/pin` it does carry a
    // tabIndex — the slug can only be acted on by ChatyPage, so the shell has
    // to be showing it (BR-HCF5AS).
    GoRoute(
      path: '/chat/:mentor',
      pageBuilder: (context, state) => NoTransitionPage(
        key: shellPageKey,
        child: ShellEntry(
          tabIndex: kChatTabIndex,
          chatMentorSlug: state.pathParameters['mentor'] ?? '',
        ),
      ),
    ),
    // Public guardian routes. Same public-web context as /privacy — the
    // parent opens these on their own device from the email, so they must
    // never boot the child's auth stack.
    GoRoute(
      path: '/consent/confirm',
      pageBuilder: (context, state) => NoTransitionPage(
        child: Consumer(
          builder: (context, ref, _) {
            final repo = ref.watch(consentRepositoryProvider);
            final publicId = state.uri.queryParameters['id'];
            return ConsentConfirmWebPage(
              publicId: publicId,
              // Prefills the field from the same email that carries the link
              // (BR-FBD2E9). Absent on older links — the page handles null.
              initialCode: state.uri.queryParameters['code'],
              onConfirm: (code) => repo.confirm(
                publicId: publicId ?? '',
                code: code,
              ),
              onRequestManageLink: repo.requestManageLink,
            );
          },
        ),
      ),
    ),
    GoRoute(
      path: '/consent/manage/:token',
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return NoTransitionPage(
          child: Consumer(
            builder: (context, ref, _) {
              final repo = ref.watch(consentRepositoryProvider);
              return ConsentManageWebPage(
                token: token,
                loadState: () => repo.loadManageState(token),
                onRegenerate: (childId) => repo.regenerateCode(token, childId),
                onRevoke: () => repo.revoke(token),
                onRequestManageLink: repo.requestManageLink,
              );
            },
          ),
        );
      },
    ),
    for (final slug in legalSlugs) ...[
      GoRoute(
        path: '/$slug',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: LegalPage(slug: slug, locale: 'cs'),
        ),
      ),
      GoRoute(
        path: '/$slug/en',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: LegalPage(slug: slug, locale: 'en'),
        ),
      ),
    ],
  ];

  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: navigatorKey,
    routes: routes,
    observers: [routeObserver],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Stránka nenalezena: ${state.uri.path}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Domů'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
