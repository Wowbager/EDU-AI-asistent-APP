import 'package:flutter/widgets.dart';

import 'theme_config.dart';

/// Rebuilds a screen when the active theme changes.
///
/// `AppColors.x` and friends are static getters resolved during `build`, so a
/// widget only picks up a new theme when it is rebuilt. The root [MyApp]
/// listens to [ThemeManager.notifier] and calls `setState`, but that rebuild
/// never reaches screens sitting in the navigator stack: Flutter caches route
/// content in `_ModalScopeState._page` and does not re-run `buildPage` when the
/// navigator above it rebuilds.
///
/// Any screen that can stay mounted while the theme is switched (the main
/// screen behind the menu, the profile page behind the theme selector) must
/// therefore listen for itself. Mix this in and it will.
mixin ThemeAwareState<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ThemeManager.notifier.addListener(_onThemeConfigChanged);
  }

  @override
  void dispose() {
    ThemeManager.notifier.removeListener(_onThemeConfigChanged);
    super.dispose();
  }

  void _onThemeConfigChanged() {
    if (mounted) setState(() {});
  }
}
