import 'dart:convert';

import 'package:eduai/core/theme/theme_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers ThemeManager.resetToDefault(), called from LogoutCoordinator.teardown()
/// (BR-P4JUDT). The palette lives in SharedPreferences and in a *static* config,
/// neither of which the Drift wipe touches — so without this reset the next
/// (unknown) user on a shared browser inherits the previous user's colours, both
/// in-session and after a page reload (main.dart restores `selected_theme`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sunset = ThemeConfig(
    name: 'Sunset',
    version: 1,
    colors: ThemeColors.fromJson(const {'primary': '#FF7128'}),
    typography: ThemeTypography.defaults,
    radii: ThemeRadii.defaults,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeManager.apply(ThemeConfig.defaultTheme);
  });

  test('returns the live theme to the bundled default', () async {
    ThemeManager.apply(sunset);
    expect(ThemeManager.colors.primary, sunset.colors.primary);

    await ThemeManager.resetToDefault();

    expect(ThemeManager.current.name, ThemeConfig.defaultTheme.name);
    expect(ThemeManager.colors.primary, ThemeColors.defaults.primary);
  });

  test('notifies listeners so the app rebuilds without a reload', () async {
    ThemeManager.apply(sunset);
    var notified = 0;
    void listener() => notified++;
    ThemeManager.notifier.addListener(listener);
    addTearDown(() => ThemeManager.notifier.removeListener(listener));

    await ThemeManager.resetToDefault();

    expect(notified, greaterThan(0));
  });

  test('forgets the selected theme so a reload starts from default', () async {
    await ThemeManager.saveSelectedTheme('Sunset');
    expect(await ThemeManager.getSelectedThemeName(), 'Sunset');

    await ThemeManager.resetToDefault();

    expect(await ThemeManager.getSelectedThemeName(), isNull);
  });

  test('forgets user-created custom themes so none leak to the next user',
      () async {
    await ThemeManager.saveCustomTheme(sunset);
    expect(await ThemeManager.loadCustomThemes(), hasLength(1));

    await ThemeManager.resetToDefault();

    expect(await ThemeManager.loadCustomThemes(), isEmpty);
  });

  test('is a no-op when nothing was ever customised', () async {
    await ThemeManager.resetToDefault();

    expect(ThemeManager.current.name, ThemeConfig.defaultTheme.name);
    expect(await ThemeManager.getSelectedThemeName(), isNull);
    expect(await ThemeManager.loadCustomThemes(), isEmpty);
  });

  test('survives corrupt custom-theme entries left in storage', () async {
    SharedPreferences.setMockInitialValues({
      'custom_themes': <String>['{not json', jsonEncode(sunset.toJson())],
      'selected_theme': 'Sunset',
    });

    await ThemeManager.resetToDefault();

    expect(await ThemeManager.loadCustomThemes(), isEmpty);
    expect(await ThemeManager.getSelectedThemeName(), isNull);
  });
}
