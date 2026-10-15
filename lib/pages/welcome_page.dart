import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/layout/breakpoints.dart';
import '../widgets/auth_hero_scaffold.dart';

class WelcomePage extends StatefulWidget {
  final VoidCallback onLoginSignUp;
  final Function(String pin) onPinSubmit;

  const WelcomePage({
    super.key,
    required this.onLoginSignUp,
    required this.onPinSubmit,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _pin => _pinControllers.map((c) => c.text).join();

  void _onPinChanged(int index, String value) {
    // Paste handling — user pasted the whole 6-digit PIN into one field.
    // The formatter accepts up to 6 chars (no maxLength on the field) so
    // we can read the full paste here and spread it across the row.
    if (value.length > 1) {
      final chars = value.split('').take(6 - index).toList();
      for (var i = 0; i < chars.length; i++) {
        _pinControllers[index + i].value = TextEditingValue(
          text: chars[i],
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
      final lastFilled = (index + chars.length - 1).clamp(0, 5);
      final nextFocus = (lastFilled + 1).clamp(0, 5);
      _focusNodes[nextFocus].requestFocus();
      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _handleKeyPress(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _pinControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _handlePinSubmit() {
    if (_pin.length == 6) {
      widget.onPinSubmit(_pin);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.authGradient,
        ),
        child: Stack(
          children: [
            // Background decorative image above white container
            Positioned(
              bottom: 430,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/login_bg.png',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            // Logo centered on top of background
            Positioned(
              bottom: 490,
              left: 0,
              right: 0,
              child: Center(
                child: buildAuthWordmark(width: 276),
              ),
            ),
            // White form container at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppDecorations.radiusSheet,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Headline
                        Text(
                          AppStrings.authHeadline,
                          style: AppTextStyles.heading1().copyWith(height: 1.2),
                        ),
                        const SizedBox(height: 24),
                      // PIN input fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 48,
                            height: 56,
                            child: KeyboardListener(
                              focusNode: FocusNode(),
                              onKeyEvent: (event) => _handleKeyPress(index, event),
                              child: TextField(
                                controller: _pinControllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                // No maxLength — see _onPinChanged for the
                                // paste flow; cap is enforced via the length
                                // formatter so a pasted 6-digit PIN can be
                                // detected and distributed.
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                style: AppTextStyles.heading3Alt(),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: AppDecorations.radiusM,
                                    borderSide: BorderSide(
                                      color: AppColors.primaryDark16,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: AppDecorations.radiusM,
                                    borderSide: BorderSide(
                                      color: AppColors.primaryDark16,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: AppDecorations.radiusM,
                                    borderSide: BorderSide(
                                      color: AppColors.primaryDark,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (value) => _onPinChanged(index, value),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      // Access Free Courses button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _pin.length == 6 ? _handlePinSubmit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primaryDark.withAlpha(128),
                            disabledForegroundColor: Colors.white.withAlpha(179),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppDecorations.radiusM,
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppStrings.welcomeAccessPin,
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
                      // Divider with "or"
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
                              AppStrings.authOr,
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
                      // Log In / Sign Up button
                      GestureDetector(
                        onTap: widget.onLoginSignUp,
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
                          child: Center(
                            child: Text(
                              AppStrings.authLoginSignUp,
                              style: AppTextStyles.bodyLarge(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                        // Terms and Privacy Policy
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // TODO: Open terms
                                },
                                child: Text(
                                  AppStrings.authTerms,
                                  style: AppTextStyles.caption(
                                    color: AppColors.primaryDark48,
                                  ).copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () {
                                  // TODO: Open privacy
                                },
                                child: Text(
                                  AppStrings.authPrivacy,
                                  style: AppTextStyles.caption(
                                    color: AppColors.primaryDark48,
                                  ).copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
