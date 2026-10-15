import 'package:flutter/material.dart';

import '../core/strings/locale_manager.dart';
import '../core/theme/app_theme.dart';

/// Compact segmented pill for switching the UI language (`CS | EN`).
///
/// Offers every locale in [AppLocale] — the same list the profile settings
/// picker uses — so the two stay in sync automatically. Tapping a segment calls
/// [LocaleManager.setLocale], which persists the choice to SharedPreferences
/// and rebuilds the app; the selection therefore survives login and restarts.
///
/// Set [onDark] when the pill sits on a dark background (the auth screen's
/// gradient); it flips the palette to white-on-dark.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, this.onDark = false});

  /// Render for a dark backdrop (white text, translucent white track).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    // Listen directly: the pill must show the new selection even in contexts
    // where the app-wide rebuild (MyApp's locale key) does not apply, e.g. a
    // widget test that pumps this widget on its own.
    return ValueListenableBuilder<AppLocale>(
      valueListenable: LocaleManager.notifier,
      builder: (context, current, _) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: onDark ? Colors.white24 : AppColors.primaryDark08,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final locale in AppLocale.values)
                _buildSegment(locale, locale == current),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegment(AppLocale locale, bool isSelected) {
    final Color background =
        onDark ? AppColors.surface : AppColors.primaryDark;
    final Color selectedText =
        onDark ? AppColors.primaryDark : AppColors.surface;
    final Color idleText = onDark ? Colors.white : AppColors.primaryDark64;

    return Semantics(
      button: true,
      selected: isSelected,
      label: locale.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isSelected ? null : () => LocaleManager.setLocale(locale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? background : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            locale.code.toUpperCase(),
            style: AppTextStyles.badge(
              color: isSelected ? selectedText : idleText,
            ),
          ),
        ),
      ),
    );
  }
}
