/// Barrel export + ThemeData for the app.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../layout/breakpoints.dart';
import 'app_colors.dart';
import 'app_decorations.dart';
import 'theme_config.dart';

export 'app_colors.dart';
export 'app_text_styles.dart';
export 'app_decorations.dart';
export 'theme_aware.dart';
export 'theme_config.dart';

/// Provides the app-wide [ThemeData].
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.getTextTheme(ThemeManager.typography.headingFont),
        // Capped centrally rather than at each of the ~110 showDialog /
        // showModalBottomSheet call sites. Removing the global 640px clamp
        // (BR-UWJD4M) also uncapped every modal, because the clamp used to sit
        // above the Navigator.
        bottomSheetTheme: const BottomSheetThemeData(
          constraints: BoxConstraints(maxWidth: 640),
        ),
        dialogTheme: const DialogThemeData(
          constraints: BoxConstraints(maxWidth: 560),
        ),
      );

  /// Widest a snack bar may grow on a non-phone viewport.
  static const double snackBarMaxWidth = 480;

  /// Snack bar defaults that depend on the viewport.
  ///
  /// These cannot live in [light]: `ThemeData` is built once, with no
  /// `BuildContext`, and a fixed `width` would overflow a phone. Applied in
  /// `MaterialApp.builder`, which is the one place that has both a
  /// `MediaQuery` and sits above the `Navigator`.
  ///
  /// Without the cap a floating snack bar takes the full viewport less its
  /// margin — a ~2950px strip on a 4K browser window, which is what made
  /// "Nejprve vyber odpověď" unreadable (BR-8H9WTT). New code should prefer
  /// `showAppToast`; this keeps the ~50 existing call sites from spanning the
  /// window in the meantime.
  static SnackBarThemeData snackBarThemeFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusS),
      // Below the compact breakpoint the default full-width-less-margin bar is
      // exactly what a phone should get, so leave it null there.
      width: width >= kCompactMaxWidth ? snackBarMaxWidth : null,
    );
  }
}
