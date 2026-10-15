import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/media/lesson_image_cache.dart';
import 'core/oauth/oauth_clients.dart';
import 'core/providers/core_providers.dart';
import 'core/strings/app_strings.dart';
import 'core/strings/locale_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_toast.dart';
import 'core/util/drag_scroll_behavior.dart';
import 'data/repositories/consent_repository.dart';
import 'routing/app_router.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final _router = buildAppRouter(
    navigatorKey: ref.read(oauthNavigatorKeyProvider),
  );

  @override
  void initState() {
    super.initState();
    ThemeManager.notifier.addListener(_onThemeChanged);
    LocaleManager.notifier.addListener(_onLocaleChanged);

    // Refresh the bundled age-of-consent thresholds (AgeThreshold) from the
    // server as early as possible — at app bootstrap, not lazily in the age
    // gate's initState. The gate can appear as soon as the user taps
    // Log in/Sign up on the very first PIN screen, which is only a couple of
    // taps after cold start; kicking this off here gives it the most
    // possible time to land before that happens, instead of racing the user
    // on the gate screen itself. loadConfig() fails silently and keeps the
    // bundled CZ/SK defaults on any error (offline, timeout, 5xx), and it
    // never awaits/blocks the UI either way — fire-and-forget.
    unawaited(ref.read(consentRepositoryProvider).loadConfig());

    // Lets lesson pictures be downloaded ahead only while online, and retry
    // the moment the connection comes back (BR-BX9AA4).
    LessonImageCache.instance.useConnectivity(
      ref.read(connectivityServiceProvider),
    );
  }

  @override
  void dispose() {
    ThemeManager.notifier.removeListener(_onThemeChanged);
    LocaleManager.notifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _onLocaleChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleManager.current;
    return MaterialApp.router(
      // Keying MaterialApp by locale forces Flutter to throw away the entire
      // element tree when the user switches language, so static
      // `AppStrings.x` getters are re-invoked.
      key: ValueKey('app-locale-${locale.code}'),
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale.toFlutterLocale(),
      scrollBehavior: const DragScrollBehavior(),
      routerConfig: _router,
      // No global width clamp (BR-UWJD4M). Pages cap their own content via
      // `ContentWidth`; clamping here also caught the Navigator, so dialogs and
      // bottom sheets inherited it too, and the area outside the 640px column
      // was never painted with the theme background.
      // Everything here sits *above* the Navigator, which is the point:
      //  * `snackBarThemeFor` needs a MediaQuery, which `AppTheme.light` (built
      //    once, context-free) cannot have — see BR-8H9WTT.
      //  * `ToastHost` must outlive route pushes and be positioned against the
      //    window, not against whichever pane the caller happens to live in.
      builder: (context, child) {
        return ColoredBox(
          color: AppColors.background,
          child: Theme(
            data: Theme.of(context).copyWith(
              snackBarTheme: AppTheme.snackBarThemeFor(context),
            ),
            child: ToastHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
