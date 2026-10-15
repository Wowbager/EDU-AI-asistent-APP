import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';

// ── Color Helpers ────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length == 8) {
    // Tokens like "#1F660E0F" use RRGGBBAA ordering — convert to AARRGGBB
    // when the leading byte isn't a plausible alpha (i.e. format ambiguity
    // is resolved when caller passes explicit alpha at end).
  }
  return Color(int.parse(hex, radix: 16));
}

/// Resolve a color field from a JSON map. Falls back to [fallback] when the
/// key is missing or not a String. Lets admin-supplied theme JSON omit
/// optional fields without breaking the whole import.
Color _colorOr(Map<String, dynamic> j, String key, Color fallback) {
  final v = j[key];
  if (v is String && v.isNotEmpty) {
    try {
      return _hexToColor(v);
    } catch (_) {
      return fallback;
    }
  }
  return fallback;
}

String _colorToHex(Color c) {
  final value = c.toARGB32();
  return '#${value.toRadixString(16).substring(2).toUpperCase()}';
}

// ── ThemeColors ──────────────────────────────────────────────────────

class ThemeColors {
  // Core Brand
  final Color primary;
  final Color primaryDark;
  final Color background;
  final Color gradientPurple;
  final Color surface;

  // Status
  final Color success;
  final Color orange;
  final Color warning;
  final Color error;
  final Color errorLight;

  // UI Surfaces
  final Color surfaceLight;
  final Color progressTrack;
  final Color progressFill;
  final Color quizPurple;
  final Color inputBg;
  final Color infoBg;
  final Color disabled;
  final Color disabledButton;
  final Color progressBorder;

  // Card / Badge Backgrounds
  final Color cardBlue;
  final Color cardLavender;
  final Color cardPeach;
  final Color cardPeachDark;
  final Color cardYellow;
  final Color successBg;
  final Color errorBg;
  final Color hintBg;
  final Color hintBorder;
  final Color hintIconColor;
  final Color orangeBg;
  final Color successBgLight;
  final Color videoDark;
  final Color hintIcon;
  final Color bannerOrange;
  final Color bannerOrangeDark;

  // Avatar Colors
  final Color avatarFox;
  final Color avatarPanda;
  final Color avatarLion;
  final Color avatarFrog;
  final Color avatarOwl;
  final Color avatarCat;

  // Subject Colors
  final Color subjectGrammar;
  final Color subjectLiterature;
  final Color subjectMath;
  final Color subjectChemistry;
  final Color subjectBiology;

  // Skill Colors
  final Color skillRed;
  final Color skillBlue;

  // Gradient extras
  final Color gradientGold;

  /// Top and bottom stops of the auth-flow background gradient. Kept separate
  /// from [gradientPurple] / [primaryDark] so the gradient can match the design
  /// exactly without shifting the text and button colours those two drive.
  final Color authGradientTop;
  final Color authGradientBottom;

  // Bottom nav scrim — darkening gradient behind the floating nav bar so the
  // white bar doesn't blend into light page content scrolling underneath it.
  final Color navScrimTop;
  final Color navScrimBottom;

  const ThemeColors({
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.gradientPurple,
    required this.surface,
    required this.success,
    required this.orange,
    required this.warning,
    required this.error,
    required this.errorLight,
    required this.surfaceLight,
    required this.progressTrack,
    required this.progressFill,
    required this.quizPurple,
    required this.inputBg,
    required this.infoBg,
    required this.disabled,
    required this.disabledButton,
    required this.progressBorder,
    required this.cardBlue,
    required this.cardLavender,
    required this.cardPeach,
    required this.cardPeachDark,
    required this.cardYellow,
    required this.successBg,
    required this.errorBg,
    required this.hintBg,
    required this.hintBorder,
    required this.hintIconColor,
    required this.orangeBg,
    required this.successBgLight,
    required this.videoDark,
    required this.hintIcon,
    required this.bannerOrange,
    required this.bannerOrangeDark,
    required this.avatarFox,
    required this.avatarPanda,
    required this.avatarLion,
    required this.avatarFrog,
    required this.avatarOwl,
    required this.avatarCat,
    required this.subjectGrammar,
    required this.subjectLiterature,
    required this.subjectMath,
    required this.subjectChemistry,
    required this.subjectBiology,
    required this.skillRed,
    required this.skillBlue,
    required this.gradientGold,
    required this.authGradientTop,
    required this.authGradientBottom,

    required this.navScrimTop,
    required this.navScrimBottom,
  });

  /// Build [ThemeColors] from JSON. Tolerant of missing fields — falls back
  /// to [ThemeColors.defaults] for any color the JSON omits. This allows
  /// design-token exports from the admin tool (which may omit infrequently
  /// used colors) to import successfully.
  factory ThemeColors.fromJson(Map<String, dynamic> j) {
    const d = ThemeColors.defaults;
    return ThemeColors(
      primary: _colorOr(j, 'primary', d.primary),
      primaryDark: _colorOr(j, 'primaryDark', d.primaryDark),
      background: _colorOr(j, 'background', d.background),
      gradientPurple: _colorOr(j, 'gradientPurple', d.gradientPurple),
      // Fall back to this theme's own hues, not the global defaults — an
      // Ocean or Sunset theme that predates these keys must keep its blue or
      // orange auth background rather than inheriting the purple one.
      authGradientTop: _colorOr(
        j,
        'authGradientTop',
        _colorOr(j, 'gradientPurple', d.gradientPurple),
      ),
      authGradientBottom: _colorOr(
        j,
        'authGradientBottom',
        _colorOr(j, 'primaryDark', d.primaryDark),
      ),
      surface: _colorOr(j, 'surface', d.surface),
      success: _colorOr(j, 'success', d.success),
      orange: _colorOr(j, 'orange', d.orange),
      warning: _colorOr(j, 'warning', d.warning),
      error: _colorOr(j, 'error', d.error),
      errorLight: _colorOr(j, 'errorLight', d.errorLight),
      surfaceLight: _colorOr(j, 'surfaceLight', d.surfaceLight),
      progressTrack: _colorOr(j, 'progressTrack', d.progressTrack),
      progressFill: _colorOr(j, 'progressFill', d.progressFill),
      quizPurple: _colorOr(j, 'quizPurple', d.quizPurple),
      inputBg: _colorOr(j, 'inputBg', d.inputBg),
      infoBg: _colorOr(j, 'infoBg', d.infoBg),
      disabled: _colorOr(j, 'disabled', d.disabled),
      disabledButton: _colorOr(j, 'disabledButton', d.disabledButton),
      progressBorder: _colorOr(j, 'progressBorder', d.progressBorder),
      cardBlue: _colorOr(j, 'cardBlue', d.cardBlue),
      cardLavender: _colorOr(j, 'cardLavender', d.cardLavender),
      cardPeach: _colorOr(j, 'cardPeach', d.cardPeach),
      cardPeachDark: _colorOr(j, 'cardPeachDark', d.cardPeachDark),
      cardYellow: _colorOr(j, 'cardYellow', d.cardYellow),
      successBg: _colorOr(j, 'successBg', d.successBg),
      errorBg: _colorOr(j, 'errorBg', d.errorBg),
      hintBg: _colorOr(j, 'hintBg', d.hintBg),
      hintBorder: _colorOr(j, 'hintBorder', d.hintBorder),
      hintIconColor: _colorOr(j, 'hintIconColor', d.hintIconColor),
      orangeBg: _colorOr(j, 'orangeBg', d.orangeBg),
      successBgLight: _colorOr(j, 'successBgLight', d.successBgLight),
      videoDark: _colorOr(j, 'videoDark', d.videoDark),
      hintIcon: _colorOr(j, 'hintIcon', d.hintIcon),
      bannerOrange: _colorOr(j, 'bannerOrange', d.bannerOrange),
      bannerOrangeDark: _colorOr(j, 'bannerOrangeDark', d.bannerOrangeDark),
      avatarFox: _colorOr(j, 'avatarFox', d.avatarFox),
      avatarPanda: _colorOr(j, 'avatarPanda', d.avatarPanda),
      avatarLion: _colorOr(j, 'avatarLion', d.avatarLion),
      avatarFrog: _colorOr(j, 'avatarFrog', d.avatarFrog),
      avatarOwl: _colorOr(j, 'avatarOwl', d.avatarOwl),
      avatarCat: _colorOr(j, 'avatarCat', d.avatarCat),
      subjectGrammar: _colorOr(j, 'subjectGrammar', d.subjectGrammar),
      subjectLiterature: _colorOr(j, 'subjectLiterature', d.subjectLiterature),
      subjectMath: _colorOr(j, 'subjectMath', d.subjectMath),
      subjectChemistry: _colorOr(j, 'subjectChemistry', d.subjectChemistry),
      subjectBiology: _colorOr(j, 'subjectBiology', d.subjectBiology),
      skillRed: _colorOr(j, 'skillRed', d.skillRed),
      skillBlue: _colorOr(j, 'skillBlue', d.skillBlue),
      gradientGold: _colorOr(j, 'gradientGold', d.gradientGold),
      navScrimTop: _colorOr(j, 'navScrimTop', d.navScrimTop),
      navScrimBottom: _colorOr(j, 'navScrimBottom', d.navScrimBottom),
    );
  }

  Map<String, dynamic> toJson() => {
        'primary': _colorToHex(primary),
        'primaryDark': _colorToHex(primaryDark),
        'background': _colorToHex(background),
        'gradientPurple': _colorToHex(gradientPurple),
        'authGradientTop': _colorToHex(authGradientTop),
        'authGradientBottom': _colorToHex(authGradientBottom),
        'surface': _colorToHex(surface),
        'success': _colorToHex(success),
        'orange': _colorToHex(orange),
        'warning': _colorToHex(warning),
        'error': _colorToHex(error),
        'errorLight': _colorToHex(errorLight),
        'surfaceLight': _colorToHex(surfaceLight),
        'progressTrack': _colorToHex(progressTrack),
        'progressFill': _colorToHex(progressFill),
        'quizPurple': _colorToHex(quizPurple),
        'inputBg': _colorToHex(inputBg),
        'infoBg': _colorToHex(infoBg),
        'disabled': _colorToHex(disabled),
        'disabledButton': _colorToHex(disabledButton),
        'progressBorder': _colorToHex(progressBorder),
        'cardBlue': _colorToHex(cardBlue),
        'cardLavender': _colorToHex(cardLavender),
        'cardPeach': _colorToHex(cardPeach),
        'cardPeachDark': _colorToHex(cardPeachDark),
        'cardYellow': _colorToHex(cardYellow),
        'successBg': _colorToHex(successBg),
        'errorBg': _colorToHex(errorBg),
        'hintBg': _colorToHex(hintBg),
        'hintBorder': _colorToHex(hintBorder),
        'hintIconColor': _colorToHex(hintIconColor),
        'orangeBg': _colorToHex(orangeBg),
        'successBgLight': _colorToHex(successBgLight),
        'videoDark': _colorToHex(videoDark),
        'hintIcon': _colorToHex(hintIcon),
        'bannerOrange': _colorToHex(bannerOrange),
        'bannerOrangeDark': _colorToHex(bannerOrangeDark),
        'avatarFox': _colorToHex(avatarFox),
        'avatarPanda': _colorToHex(avatarPanda),
        'avatarLion': _colorToHex(avatarLion),
        'avatarFrog': _colorToHex(avatarFrog),
        'avatarOwl': _colorToHex(avatarOwl),
        'avatarCat': _colorToHex(avatarCat),
        'subjectGrammar': _colorToHex(subjectGrammar),
        'subjectLiterature': _colorToHex(subjectLiterature),
        'subjectMath': _colorToHex(subjectMath),
        'subjectChemistry': _colorToHex(subjectChemistry),
        'subjectBiology': _colorToHex(subjectBiology),
        'skillRed': _colorToHex(skillRed),
        'skillBlue': _colorToHex(skillBlue),
        'gradientGold': _colorToHex(gradientGold),
        'navScrimTop': _colorToHex(navScrimTop),
        'navScrimBottom': _colorToHex(navScrimBottom),
      };

  static const ThemeColors defaults = ThemeColors(
    primary: Color(0xFFAB9FF2),
    primaryDark: Color(0xFF3C315B),
    background: Color(0xFFF6F2FF),
    gradientPurple: Color(0xFF7F68C1),
    authGradientTop: Color(0xFF806DB9),
    authGradientBottom: Color(0xFF4B378B),
    surface: Color(0xFFFFFFFF),
    success: Color(0xFF2FBE87),
    orange: Color(0xFFFF7128),
    warning: Color(0xFFFF9800),
    error: Color(0xFFE53935),
    errorLight: Color(0xFFFF6B6B),
    surfaceLight: Color(0xFFE9E4F5),
    progressTrack: Color(0xFFDDD5EF),
    progressFill: Color(0xFFAFA3F6),
    quizPurple: Color(0xFF6B5CFF),
    inputBg: Color(0xFFE8E0F4),
    infoBg: Color(0xFFF3F0FF),
    disabled: Color(0xFF827B96),
    disabledButton: Color(0xFFBEB9C9),
    progressBorder: Color(0xFF8178B5),
    cardBlue: Color(0xFFA7D9FF),
    cardLavender: Color(0xFFE8D4F8),
    cardPeach: Color(0xFFFFE4B5),
    cardPeachDark: Color(0xFFFFD4B8),
    cardYellow: Color(0xFFFFFFC6),
    successBg: Color(0xFFE6F7F1),
    errorBg: Color(0xFFFFEBEE),
    hintBg: Color(0xFFFFF9E6),
    hintBorder: Color(0xFFFFD666),
    hintIconColor: Color(0xFFFFB800),
    orangeBg: Color(0xFFFFEDE6),
    successBgLight: Color(0xFFE8F5E9),
    videoDark: Color(0xFF1A1A2E),
    hintIcon: Color(0xFFFFE082),
    bannerOrange: Color(0xFFFFB347),
    bannerOrangeDark: Color(0xFFFF8C00),
    avatarFox: Color(0xFFFFE4D6),
    avatarPanda: Color(0xFFE8E8E8),
    avatarLion: Color(0xFFFFF3D6),
    avatarFrog: Color(0xFFD6F5E6),
    avatarOwl: Color(0xFFE8DFF5),
    avatarCat: Color(0xFFFFE8F0),
    subjectGrammar: Color(0xFFFFF3D4),
    subjectLiterature: Color(0xFFFFE4E4),
    subjectMath: Color(0xFFD4F8E8),
    subjectChemistry: Color(0xFFD4F4FF),
    subjectBiology: Color(0xFFE8D4F8),
    skillRed: Color(0xFFFFE4E4),
    skillBlue: Color(0xFFE4E4FF),
    gradientGold: Color(0xFFFFD000),
    navScrimTop: Color(0xFF857FA4),
    navScrimBottom: Color(0xFF272145),
  );
}

// ── ThemeTypography ──────────────────────────────────────────────────

class ThemeTypography {
  final String headingFont;
  final String bodyFont;
  final String codeFont;

  const ThemeTypography({
    required this.headingFont,
    required this.bodyFont,
    required this.codeFont,
  });

  factory ThemeTypography.fromJson(Map<String, dynamic> j) => ThemeTypography(
        headingFont: (j['headingFont'] as String?) ?? defaults.headingFont,
        bodyFont: (j['bodyFont'] as String?) ?? defaults.bodyFont,
        codeFont: (j['codeFont'] as String?) ?? defaults.codeFont,
      );

  Map<String, dynamic> toJson() => {
        'headingFont': headingFont,
        'bodyFont': bodyFont,
        'codeFont': codeFont,
      };

  static const ThemeTypography defaults = ThemeTypography(
    headingFont: 'Nunito',
    bodyFont: 'Poppins',
    codeFont: 'Fira Code',
  );
}

// ── ThemeRadii ───────────────────────────────────────────────────────

class ThemeRadii {
  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double pill;
  final double sheet;

  const ThemeRadii({
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.pill,
    required this.sheet,
  });

  /// Build [ThemeRadii] from JSON. Accepts both short (`xs`, `s`, ...) and
  /// admin-tool long (`radiusXS`, `radiusS`, `radiusSheetTop`) key names,
  /// falling back to defaults for any missing entry.
  factory ThemeRadii.fromJson(Map<String, dynamic> j) {
    double pick(List<String> keys, double fallback) {
      for (final k in keys) {
        final v = j[k];
        if (v is num) return v.toDouble();
      }
      return fallback;
    }

    const d = ThemeRadii.defaults;
    return ThemeRadii(
      xs: pick(const ['xs', 'radiusXS'], d.xs),
      s: pick(const ['s', 'radiusS'], d.s),
      m: pick(const ['m', 'radiusM'], d.m),
      l: pick(const ['l', 'radiusL'], d.l),
      xl: pick(const ['xl', 'radiusXL'], d.xl),
      pill: pick(const ['pill', 'radiusPill'], d.pill),
      sheet: pick(const ['sheet', 'radiusSheetTop'], d.sheet),
    );
  }

  Map<String, dynamic> toJson() => {
        'xs': xs,
        's': s,
        'm': m,
        'l': l,
        'xl': xl,
        'pill': pill,
        'sheet': sheet,
      };

  static const ThemeRadii defaults = ThemeRadii(
    xs: 8,
    s: 12,
    m: 16,
    l: 20,
    xl: 24,
    pill: 30,
    sheet: 32,
  );
}

// ── ThemeConfig (umbrella) ───────────────────────────────────────────

class ThemeConfig {
  final String name;
  final int version;
  final ThemeColors colors;
  final ThemeTypography typography;
  final ThemeRadii radii;

  const ThemeConfig({
    required this.name,
    required this.version,
    required this.colors,
    required this.typography,
    required this.radii,
  });

  /// Build a [ThemeConfig] from JSON. Tolerant of missing/optional fields:
  /// - `name` defaults to "Custom" when absent
  /// - `version` defaults to 1
  /// - `typography` / `radii` blocks default to [ThemeTypography.defaults] /
  ///   [ThemeRadii.defaults] when omitted
  /// - `colors` may omit individual entries (see [ThemeColors.fromJson])
  factory ThemeConfig.fromJson(Map<String, dynamic> j) {
    final colorsJson = j['colors'];
    final typographyJson = j['typography'];
    final radiiJson = j['radii'];
    return ThemeConfig(
      name: (j['name'] as String?) ?? 'Custom',
      version: (j['version'] as num?)?.toInt() ?? 1,
      colors: colorsJson is Map<String, dynamic>
          ? ThemeColors.fromJson(colorsJson)
          : ThemeColors.defaults,
      typography: typographyJson is Map<String, dynamic>
          ? ThemeTypography.fromJson(typographyJson)
          : ThemeTypography.defaults,
      radii: radiiJson is Map<String, dynamic>
          ? ThemeRadii.fromJson(radiiJson)
          : ThemeRadii.defaults,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'colors': colors.toJson(),
        'typography': typography.toJson(),
        'radii': radii.toJson(),
      };

  static const ThemeConfig defaultTheme = ThemeConfig(
    name: 'Default',
    version: 1,
    colors: ThemeColors.defaults,
    typography: ThemeTypography.defaults,
    radii: ThemeRadii.defaults,
  );
}

// ── ThemeManager (singleton) ─────────────────────────────────────────

/// Holds the active [ThemeConfig]. All `AppColors`, `AppTextStyles`, and
/// `AppDecorations` getters read from here so the entire UI reacts to
/// a single [apply] call.
class ThemeManager {
  ThemeManager._();

  static ThemeConfig _config = ThemeConfig.defaultTheme;

  /// Notifier that fires whenever the theme changes.
  /// Listen to this in the root widget to trigger a full rebuild.
  static final ValueNotifier<ThemeConfig> notifier =
      ValueNotifier(ThemeConfig.defaultTheme);

  /// Current theme configuration.
  static ThemeConfig get current => _config;

  /// Convenience accessors.
  static ThemeColors get colors => _config.colors;
  static ThemeTypography get typography => _config.typography;
  static ThemeRadii get radii => _config.radii;

  /// Apply a new theme. Automatically notifies listeners so the root
  /// widget rebuilds and all widgets pick up the new values.
  static void apply(ThemeConfig config) {
    _config = config;
    notifier.value = config;
  }

  /// Load a theme JSON from Flutter assets.
  static Future<void> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    apply(ThemeConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }

  /// Load a theme from a raw JSON string (e.g. fetched from an API).
  static void loadFromJsonString(String jsonString) {
    apply(ThemeConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>));
  }

  /// Export the current theme as a formatted JSON string.
  static String exportJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_config.toJson());
  }

  // ── Persistence ─────────────────────────────────────────────────

  static const _customThemesKey = 'custom_themes';
  static const _selectedThemeKey = 'selected_theme';

  /// Save a custom theme (insert or update by name).
  static Future<void> saveCustomTheme(ThemeConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final themes = await loadCustomThemes();
    themes.removeWhere((t) => t.name == config.name);
    themes.add(config);
    final jsonList = themes.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_customThemesKey, jsonList);
  }

  /// Load all custom themes from local storage.
  static Future<List<ThemeConfig>> loadCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_customThemesKey) ?? [];
    final result = <ThemeConfig>[];
    for (final s in jsonList) {
      try {
        result.add(ThemeConfig.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupt entries.
      }
    }
    return result;
  }

  /// Delete a custom theme by name.
  static Future<void> deleteCustomTheme(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final themes = await loadCustomThemes();
    themes.removeWhere((t) => t.name == name);
    final jsonList = themes.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_customThemesKey, jsonList);
  }

  /// Persist the selected theme name so it can be restored on next launch.
  static Future<void> saveSelectedTheme(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedThemeKey, name);
  }

  /// Get the name of the previously selected theme.
  static Future<String?> getSelectedThemeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedThemeKey);
  }

  /// Forget every persisted theme and return the live UI to the bundled
  /// default. Called from the logout teardown (BR-P4JUDT).
  ///
  /// The palette lives outside Drift — in SharedPreferences (localStorage on
  /// web) and in the static [_config] — so neither `clearAllData()` nor the
  /// provider teardown resets it. Without this the next, possibly unknown, user
  /// on a shared browser inherits the previous user's colours: immediately (the
  /// static config survives) and again after a reload (`_restoreSavedTheme` in
  /// main.dart re-reads [_selectedThemeKey]). Custom themes go too — they are
  /// device-local and would otherwise stay listed for the next user.
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedThemeKey);
    await prefs.remove(_customThemesKey);
    apply(ThemeConfig.defaultTheme);
  }

  // ── API Sync ────────────────────────────────────────────────────

  static ApiClient? _apiClient;

  /// Set the API client for remote sync. Call once after login/init.
  static void setApiClient(ApiClient client) => _apiClient = client;

  /// Sync custom themes with the API (push local + pull remote).
  ///
  /// Follows the same offline-first pattern as bookmarks:
  /// 1. Push all local custom themes to the API (upsert by name).
  /// 2. Pull all remote themes and merge into local storage.
  /// 3. Restore the active theme.
  static Future<void> syncThemes() async {
    if (_apiClient == null || !_apiClient!.isAuthenticated) return;

    final localThemes = await loadCustomThemes();

    // 1. Push local themes to API.
    if (localThemes.isNotEmpty) {
      await _apiClient!.post<Map<String, dynamic>>(
        ApiEndpoints.userThemesSync,
        data: {
          'themes': localThemes.map((t) => {
            'name': t.name,
            'theme_config': {
              'colors': t.colors.toJson(),
              'typography': t.typography.toJson(),
              'radii': t.radii.toJson(),
            },
            'is_active': t.name == _config.name,
          }).toList(),
        },
      );
    }

    // 2. Pull remote themes.
    final result = await _apiClient!.get<Map<String, dynamic>>(
      ApiEndpoints.userThemes,
      fromJson: (d) => d as Map<String, dynamic>,
    );

    if (result.isSuccess && result.data != null) {
      final remoteList = result.data!['data'] as List? ?? [];
      final merged = <ThemeConfig>[];
      for (final entry in remoteList) {
        try {
          final map = entry as Map<String, dynamic>;
          final config = map['theme_config'] as Map<String, dynamic>;
          merged.add(ThemeConfig(
            name: map['name'] as String,
            version: 1,
            colors: ThemeColors.fromJson(config['colors'] as Map<String, dynamic>),
            typography: ThemeTypography.fromJson(config['typography'] as Map<String, dynamic>),
            radii: ThemeRadii.fromJson(config['radii'] as Map<String, dynamic>),
          ));
        } catch (_) {
          // Skip malformed entries.
        }
      }

      // Replace local with merged set (remote is the source of truth
      // after push).
      if (merged.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = merged.map((t) => jsonEncode(t.toJson())).toList();
        await prefs.setStringList(_customThemesKey, jsonList);
      }
    }
  }

  /// Push a single theme to the API (fire-and-forget).
  static Future<void> pushThemeToApi(ThemeConfig config, {bool isActive = false}) async {
    if (_apiClient == null || !_apiClient!.isAuthenticated) return;

    await _apiClient!.post<Map<String, dynamic>>(
      ApiEndpoints.userThemes,
      data: {
        'name': config.name,
        'theme_config': {
          'colors': config.colors.toJson(),
          'typography': config.typography.toJson(),
          'radii': config.radii.toJson(),
        },
        'is_active': isActive,
      },
    );
  }

  /// Delete a theme from the API by name.
  static Future<void> deleteThemeFromApi(String name) async {
    if (_apiClient == null || !_apiClient!.isAuthenticated) return;

    // Need to find the server ID first.
    final result = await _apiClient!.get<Map<String, dynamic>>(
      ApiEndpoints.userThemes,
      fromJson: (d) => d as Map<String, dynamic>,
    );

    if (result.isSuccess && result.data != null) {
      final list = result.data!['data'] as List? ?? [];
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        if (map['name'] == name) {
          await _apiClient!.delete<Map<String, dynamic>>(
            ApiEndpoints.userTheme(map['id'] as int),
          );
          break;
        }
      }
    }
  }
}
