import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported UI locales.
enum AppLocale {
  cs('cs', 'Čeština', 'CZ'),
  sk('sk', 'Slovenčina', 'SK'),
  en('en', 'English', 'EN');

  final String code;
  final String displayName;

  /// Two-letter label for compact switchers (login, welcome).
  final String shortLabel;

  const AppLocale(this.code, this.displayName, this.shortLabel);

  Locale toFlutterLocale() => Locale(code);

  static AppLocale fromCode(String? code) {
    for (final l in AppLocale.values) {
      if (l.code == code) return l;
    }
    return AppLocale.cs;
  }
}

/// Holds the active [AppLocale] for the app. UI rebuilds when this changes
/// — `MyApp` listens via `ValueListenableBuilder` and re-builds `MaterialApp`,
/// which causes every `Text(AppStrings.x)` to re-read the locale-aware string.
class LocaleManager {
  LocaleManager._();

  static const _prefsKey = 'app_locale';

  /// Czech is the default locale.
  static final ValueNotifier<AppLocale> notifier =
      ValueNotifier<AppLocale>(AppLocale.cs);

  static AppLocale get current => notifier.value;

  /// Apply a new locale. Persists asynchronously; UI updates immediately.
  static Future<void> setLocale(AppLocale locale) async {
    if (notifier.value == locale) return;
    notifier.value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.code);
  }

  /// Restore the previously saved locale from local storage. Call once at
  /// app startup before `runApp`.
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    notifier.value = AppLocale.fromCode(code);
  }
}
