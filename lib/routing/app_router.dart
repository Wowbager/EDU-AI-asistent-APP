import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart' show routeObserver;
import '../pages/legal/legal_page.dart';
import '../preview/preview_page.dart';
import 'deep_link.dart';
import 'root_navigator.dart';

/// Slugs of all legal pages. Used to generate routes for both CZ and EN.
const legalSlugs = <String>[
  'terms',
  'privacy',
  'about',
  'cookies',
  'accessibility',
  'ai',
];

GoRouter buildAppRouter({GlobalKey<NavigatorState>? navigatorKey}) {
  final routes = <RouteBase>[
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: AuthWrapper(),
      ),
    ),
    // The course editor's preview surface. Deliberately outside AuthWrapper: it is
    // driven entirely by JSON posted in from the parent frame, there is no student
    // session behind it, and nothing it does is written anywhere.
    GoRoute(
      path: '/preview',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: PreviewPage(),
      ),
    ),
    // Deep links: both resolve a course by its join code/PIN (e.g. 676767).
    // They record the code and boot the normal auth flow; MainScreen opens the
    // course once the app reaches the main screen.
    for (final prefix in const ['course', 'pin'])
      GoRoute(
        path: '/$prefix/:code',
        pageBuilder: (context, state) => NoTransitionPage(
          child: DeepLinkEntry(code: state.pathParameters['code'] ?? ''),
        ),
      ),
    for (final slug in legalSlugs) ...[
      GoRoute(
        path: '/$slug',
        pageBuilder: (context, state) => NoTransitionPage(
          child: LegalPage(slug: slug, locale: 'cs'),
        ),
      ),
      GoRoute(
        path: '/$slug/en',
        pageBuilder: (context, state) => NoTransitionPage(
          child: LegalPage(slug: slug, locale: 'en'),
        ),
      ),
    ],
  ];

  return GoRouter(
    initialLocation: '/',
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
