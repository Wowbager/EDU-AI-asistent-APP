import 'package:flutter/material.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/layout/breakpoints.dart';

class AddPage extends StatelessWidget {
  const AddPage({super.key});

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/placeholder.png',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.addTitle,
              style: AppTextStyles.heading2Bold(),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.contentComingSoon,
              style: AppTextStyles.bodyLarge(color: AppColors.primaryDark48),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
