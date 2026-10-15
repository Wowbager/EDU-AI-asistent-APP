import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Buttons for the auth journey (login, age gate, guardian consent), styled
/// after the login form's controls so every step of the journey reads as one
/// flow: 56px tall, [AppDecorations.radiusM] corners, [AppTextStyles
/// .buttonLarge] / [AppTextStyles.bodyLarge] labels.

/// The filled call-to-action — the login screen's "Pokračovat".
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// The login button trails an arrow on actions that move the flow forward;
  /// plain answers (yes/no) leave it off.
  final bool arrow;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.arrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryDark48,
          disabledForegroundColor: Colors.white.withAlpha(179),
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.radiusM,
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.buttonLarge(color: Colors.white),
              ),
            ),
            if (arrow) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// The quiet alternative — the login screen's outlined "Přihlášení /
/// Registrace".
class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primaryDark16, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.radiusM,
          ),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge(),
        ),
      ),
    );
  }
}
