import 'dart:ui' show Locale, PlatformDispatcher;

/// Age of digital consent per country.
///
/// The bundled map is a fallback so the age gate works offline and on first
/// launch; `/api/consent/config` overrides it once the app is online. The
/// threshold is deliberately never hardcoded at a call site — legal limits
/// differ per market and change without a release.
///
/// Fallback for an unresolved country mirrors the server
/// (`ConsentService::ageThreshold()` in eduai-api): it does NOT fall back to
/// a separately configured "default" value, it falls back to the *highest*
/// threshold currently known. Telling a parent the age of consent is higher
/// than their country's actual limit is harmless (they just answer one more
/// question); telling them it is lower understates the law. See decision in
/// the plan under Task 11 "Watch out for".
class AgeThreshold {
  AgeThreshold._();

  static const Map<String, int> _bundled = {'CZ': 15, 'SK': 16};
  static const int _bundledDefault = 15;

  static Map<String, int> _thresholds = _bundled;
  static int _default = _bundledDefault;

  /// Override the bundled thresholds with `/api/consent/config`. An empty
  /// [thresholds] map is refused rather than adopted — a malformed response
  /// must not erase the offline-first fallback the age gate depends on.
  static void applyServerConfig({
    required Map<String, int> thresholds,
    required int defaultThreshold,
  }) {
    if (thresholds.isEmpty) return;
    _thresholds = Map.unmodifiable(thresholds);
    _default = defaultThreshold;
  }

  static void resetForTest() {
    _thresholds = _bundled;
    _default = _bundledDefault;
  }

  /// Countries the app currently has a threshold for — the bundled CZ/SK
  /// pair by default, replaced wholesale by [applyServerConfig] once
  /// `/api/consent/config` lands. The age gate's country picker reads this
  /// list directly instead of hardcoding market codes, so adding e.g. Poland
  /// is a server-side config change, not an app release.
  ///
  /// Sorted so the picker's order is stable across launches — `Map.keys`
  /// iteration order is insertion order in practice but is not part of the
  /// `Map` contract, and a JSON-decoded server map should not be trusted to
  /// preserve one either.
  static List<String> get knownCountries => _thresholds.keys.toList()..sort();

  static int forCountry(String? country) {
    final key = country?.toUpperCase();
    if (key == null || key.isEmpty) return _fallback();
    return _thresholds[key] ?? _fallback();
  }

  /// Fail conservative: the highest threshold currently known, not a
  /// separately configured default. `_default` only matters in the
  /// defensive case where `_thresholds` is somehow empty — unreachable in
  /// practice since `applyServerConfig` refuses an empty map and `_bundled`
  /// is never empty, but kept symmetric with the server's own guard.
  static int _fallback() {
    if (_thresholds.isEmpty) return _default;
    return _thresholds.values.reduce((a, b) => a > b ? a : b);
  }

  /// Country the gate should default to: the device locale's region. The user
  /// can override it on the gate screen, because a Czech-locale phone in
  /// Slovakia would otherwise show the wrong limit.
  ///
  /// [locale] is injectable so this stays a pure function under test —
  /// `PlatformDispatcher.instance.locale` cannot be overridden from a plain
  /// `flutter_test` widget test (there is no `tester.platformDispatcher` hook
  /// for it the way there is for e.g. `platformBrightnessTestValue`), so
  /// production code omits the argument and gets the real platform locale,
  /// while tests pass an explicit [Locale] to exercise every branch —
  /// including the "no region", "cs_SK" and web-style "language only" cases.
  static String? detectCountry([Locale? locale]) {
    final resolved = locale ?? PlatformDispatcher.instance.locale;
    final region = resolved.countryCode;
    if (region != null && region.isNotEmpty) return region.toUpperCase();
    // 'sk' with no region still tells us which market we are in.
    return resolved.languageCode.toUpperCase() == 'SK' ? 'SK' : null;
  }
}
