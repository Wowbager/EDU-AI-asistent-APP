import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/providers/core_providers.dart';
import 'core/services/auth_token_storage.dart';
import 'core/strings/locale_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/util/silent_log.dart';
import 'widgets/themed_svg.dart';

// Re-exports for backward compatibility — existing pages import these from
// 'package:eduai/main.dart'.
export 'app.dart' show MyApp;
export 'utils/achievement_stats.dart' show countAchievementStats;

/// Global route observer for [RouteAware] subscribers (e.g. CourseDetailPage).
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Restore the user's previously selected theme (built-in or custom).
Future<void> _restoreSavedTheme() async {
  final name = await ThemeManager.getSelectedThemeName();
  if (name == null) return;

  // Built-in themes ship as bundled assets.
  const builtIn = {
    'Default': 'assets/themes/default.json',
    'Ocean': 'assets/themes/ocean.json',
    'Sunset': 'assets/themes/sunset.json',
    'Fire': 'assets/themes/fire.json',
    'Light': 'assets/themes/light.json',
    'Neutral': 'assets/themes/neutral.json',
  };
  if (builtIn.containsKey(name)) {
    try {
      await ThemeManager.loadFromAsset(builtIn[name]!);
      return;
    } catch (e, st) {
      silentLog('main:restoreSavedTheme:builtin', e, st);
    }
  }

  // Fall back to user-saved custom themes.
  try {
    final customs = await ThemeManager.loadCustomThemes();
    for (final t in customs) {
      if (t.name == name) {
        ThemeManager.apply(t);
        return;
      }
    }
  } catch (e, st) {
    silentLog('main:restoreSavedTheme:custom', e, st);
  }
}

void main() async {
  // Ensure Flutter bindings are initialized before using plugins.
  WidgetsFlutterBinding.ensureInitialized();

  // Web: use clean URLs (no #/ hash) so /terms, /privacy etc. work as deep links.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Initialize SharedPreferences.
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize secure auth-token storage (migrates legacy plaintext token).
  final authTokenStorage = AuthTokenStorage(prefs: sharedPreferences);
  await authTokenStorage.load();

  // Restore previously selected theme.
  await _restoreSavedTheme();

  // Read the multi-colour brand SVGs up front so they can be recoloured
  // synchronously when the palette changes (BR-A6TZZX).
  await ThemedSvg.precache();

  // Restore previously selected locale (defaults to Czech).
  await LocaleManager.restore();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authTokenStorageProvider.overrideWithValue(authTokenStorage),
      ],
      child: const MyApp(),
    ),
  );
}
