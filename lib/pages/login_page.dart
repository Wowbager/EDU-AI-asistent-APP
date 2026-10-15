import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/layout/breakpoints.dart';
import '../widgets/auth_hero_scaffold.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback? onBack;

  const LoginPage({super.key, required this.onLoginSuccess, this.onBack});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController(
    text: AppStrings.loginEmailPlaceholder,
  );

  void _handleLogin() {
    // Mock authentication - just proceed to main screen
    widget.onLoginSuccess();
  }

  void _handleOAuthLogin(String provider) {
    // Mock OAuth login - just proceed to main screen
    widget.onLoginSuccess();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topSectionHeight = screenHeight * 0.35; // Height for logo area

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.authGradient,
        ),
        child: Stack(
          children: [
            // Top section with header, background image and logo
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: topSectionHeight,
                child: Stack(
                  children: [
                    // Background decorative image at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Image.asset(
                        'assets/images/login_bg.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    // Header with back button and title
                    Positioned(
                      top: 8,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          if (widget.onBack != null)
                            GestureDetector(
                              onTap: widget.onBack,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(51),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 40),
                          Expanded(
                            child: Center(
                              child: Text(
                                AppStrings.loginTitle,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    // Logo centered on top of background, 80px above white box
                    Positioned(
                      bottom: 80,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: buildAuthWordmark(width: 276),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // White form container - positioned to overlap the top section
            Positioned(
              top: topSectionHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppDecorations.radiusSheet,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Headline
                      Text(
                        AppStrings.authHeadline,
                        style: AppTextStyles.heading1().copyWith(height: 1.2),
                      ),
                      const SizedBox(height: 24),
                      // Email input
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primaryDark16,
                            width: 1,
                          ),
                          borderRadius: AppDecorations.radiusM,
                        ),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: AppTextStyles.bodyLarge(),
                          decoration: InputDecoration(
                            hintText: AppStrings.authEmailHint,
                            hintStyle: AppTextStyles.bodyLarge(
                              color: AppColors.primaryDark48,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppDecorations.radiusM,
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppStrings.authLogin,
                                style: AppTextStyles.buttonLarge(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Divider with "Nebo"
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.primaryDark12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              AppStrings.authOrCzech,
                              style: AppTextStyles.bodySmall(
                                color: AppColors.primaryDark48,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.primaryDark12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Google OAuth button
                      _buildOAuthButton(
                        onTap: () => _handleOAuthLogin('google'),
                        icon: SvgPicture.asset(
                          'assets/icons/google.svg',
                          width: 24,
                          height: 24,
                        ),
                        label: AppStrings.authGoogleLogin,
                      ),
                      const SizedBox(height: 12),
                      // Microsoft OAuth button
                      _buildOAuthButton(
                        onTap: () => _handleOAuthLogin('microsoft'),
                        icon: SvgPicture.asset(
                          'assets/icons/microsoft.svg',
                          width: 24,
                          height: 24,
                        ),
                        label: AppStrings.authMicrosoftLogin,
                      ),
                      const SizedBox(height: 12),
                      // Apple OAuth button
                      _buildOAuthButton(
                        onTap: () => _handleOAuthLogin('apple'),
                        icon: SvgPicture.asset(
                          'assets/icons/apple.svg',
                          width: 24,
                          height: 24,
                        ),
                        label: AppStrings.authAppleLogin,
                      ),
                      const SizedBox(height: 24),
                      // Terms and Privacy Policy
                      Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: AppTextStyles.caption(
                              color: AppColors.primaryDark48,
                            ),
                            children: [
                              TextSpan(text: AppStrings.authTermsNotice),
                              TextSpan(
                                text: AppStrings.authTermsAndPrivacy,
                                style: AppTextStyles.caption(
                                  color: AppColors.primaryDark64,
                                ).copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Extra padding for safe area at bottom
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOAuthButton({
    required VoidCallback onTap,
    required Widget icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primaryDark16,
            width: 1,
          ),
          borderRadius: AppDecorations.radiusM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.bodyLarge(),
            ),
          ],
        ),
      ),
    );
  }

}
