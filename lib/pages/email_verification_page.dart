import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/core_providers.dart';
import '../core/theme/app_theme.dart';
import '../features/email_validation/providers/email_validation_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/layout/breakpoints.dart';
import '../widgets/auth_hero_scaffold.dart';

/// Full-screen page for email verification during registration/login.
class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;
  /// Called when verification succeeds or user continues without verification.
  /// Parameters: needsProfileSetup, isEmailValidated (false if user skipped offline)
  final void Function(bool needsProfileSetup, bool isEmailValidated) onVerified;
  final VoidCallback? onBack;

  /// Asked once the code proves the email has no account yet — i.e. when
  /// continuing would register rather than sign in — and before continuing
  /// offline without a code, which creates a local account no server has
  /// checked (BR-J2WJEQ). Returning false abandons the flow before anything
  /// is created; the caller owns what happens next (the age gate, and the
  /// guardian consent flow behind it — BR-N9Y48J).
  final Future<bool> Function()? onNewAccount;

  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.onVerified,
    this.onBack,
    this.onNewAccount,
  });

  @override
  ConsumerState<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _codeSent = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    // Auto-send code when page opens (after checking connectivity)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivityAndSendCode();
    });
  }

  Future<void> _checkConnectivityAndSendCode() async {
    final connectivity = ref.read(connectivityServiceProvider);
    final isOnline = await connectivity.isOnline;

    if (!isOnline) {
      if (mounted) {
        setState(() => _isOffline = true);
        // Show offline dialog to let user continue without verification
        _showOfflineDialog();
      }
      return;
    }

    setState(() => _isOffline = false);
    _sendCode();
  }

  /// "Continue without verification": the account is created on this device
  /// and nobody has checked whether the address already has one, so as far as
  /// the app can tell this is a registration. It passes the same age gate an
  /// online one does. AuthPage's account check could not have asked, since it
  /// could not reach the server either. Otherwise going offline was a way
  /// round the gate, and with it the guardian consent flow (BR-J2WJEQ).
  Future<void> _continueOffline() async {
    final gate = widget.onNewAccount;
    final screened = ref
        .read(emailVerificationProvider.notifier)
        .wasScreenedAsNew(widget.email);
    // A "no" or a back-out leaves the caller in charge (consent request,
    // back to the login form). Nothing has been created at that point.
    if (gate != null && !screened && !await gate()) return;
    if (!mounted) return;
    // User needs profile setup, email NOT validated.
    widget.onVerified(true, false);
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusXL,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryDark12,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: AppColors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppStrings.emailVerificationOfflineTitle,
              style: AppTextStyles.cardTitle(),
            ),
          ],
        ),
        content: Text(
          AppStrings.emailVerificationOfflineMessage,
          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Try again
              _checkConnectivityAndSendCode();
            },
            child: Text(
              AppStrings.emailVerificationRetry,
              style: AppTextStyles.labelMedium(color: AppColors.primaryDark64),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _continueOffline();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.radiusS,
              ),
              elevation: 0,
            ),
            child: Text(
              AppStrings.actionContinue,
              style: AppTextStyles.labelMedium(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _pin => _pinControllers.map((c) => c.text).join();

  void _onPinChanged(int index, String value) {
    // Paste handling — user pasted the whole 6-digit code into one field.
    // Without this branch Flutter's built-in maxLength would truncate the
    // paste to a single character. The formatter accepts up to 6 chars
    // so we can detect and distribute the paste here.
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
      if (_pin.length == 6) {
        _verifyCode();
      }
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});

    // Auto-submit when all 6 digits entered
    if (_pin.length == 6) {
      _verifyCode();
    }
  }

  void _handleKeyPress(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _pinControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _clearPinFields() {
    for (final controller in _pinControllers) {
      controller.clear();
    }
    if (_focusNodes[0].canRequestFocus) {
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _sendCode() async {
    // Check connectivity first to avoid unnecessary API calls
    final connectivity = ref.read(connectivityServiceProvider);
    final isOnline = await connectivity.isOnline;

    if (!isOnline) {
      if (mounted) {
        setState(() => _isOffline = true);
        _showOfflineDialog();
      }
      return;
    }

    final notifier = ref.read(emailVerificationProvider.notifier);
    final success = await notifier.sendCode(widget.email);
    if (success && mounted) {
      setState(() {
        _codeSent = true;
        _isOffline = false;
      });
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    final notifier = ref.read(emailVerificationProvider.notifier);
    await notifier.verifyCode(_pin, onNewAccount: widget.onNewAccount);
  }

  /// Fixed share of the screen the sheet takes. The login screen animates its
  /// sheet between 0.52 (welcome) and 0.72 (sign-up); this step has one fixed
  /// form, so it stays at the welcome height.
  static const double _sheetHeightFraction = 0.52;

  /// Hero placement constants, mirrored from [AuthPage] so this stop on the
  /// auth journey stands the mascot on the wave exactly as the login screen
  /// does. See `auth_page.dart` for the derivations.
  static const double _waveCompactZoom = 1.5;
  static const double _heroWaveOverlap = 0.4;
  static const double _heroTopGap = 8;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailVerificationProvider);

    // Listen for verification success
    ref.listen(emailVerificationProvider, (previous, current) {
      if (current is EmailVerificationSuccess) {
        // Email was verified successfully
        widget.onVerified(current.needsProfileSetup, true);
      } else if (current is EmailVerificationError) {
        if (current.type == EmailVerificationErrorType.invalidCode) {
          _clearPinFields();
        }
      }
    });

    // Landscape tablet / desktop: the shared hero-scene scaffold draws the
    // illustration and puts the form in the right-hand panel — the same
    // scaffold the login screen and the child-onboarding steps use, so every
    // stop on the journey keeps one backdrop.
    if (context.isExpanded) {
      return AuthHeroScaffold(panel: _buildFormColumn(state));
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.authGradient,
        ),
        child: _buildSheetLayout(context, state),
      ),
    );
  }

  /// Phone / portrait tablet: illustration on top, white sheet over the bottom,
  /// matching [AuthPage]'s bottom-sheet layout.
  Widget _buildSheetLayout(BuildContext context, EmailVerificationState state) {
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;

    // Cap the card height so its top never rises above the top safe-area inset
    // once the keyboard opens (BR-PXB3N3).
    final maxContainerHeight =
        mq.size.height - mq.viewInsets.bottom - mq.padding.top;
    final containerHeight = maxContainerHeight <= 0
        ? screenHeight * _sheetHeightFraction
        : (screenHeight * _sheetHeightFraction)
            .clamp(0.0, maxContainerHeight)
            .toDouble();
    final bgBottom = containerHeight - 20;

    // The composition stands on the wave, so it is anchored to the wave's top
    // edge and gets whatever room is left up to the status bar.
    final waveHeight = mq.size.width * _waveCompactZoom * kAuthWaveAspectRatio;
    final heroBottom = bgBottom + waveHeight * (1 - _heroWaveOverlap);
    final heroBand =
        mq.size.height - mq.padding.top - _heroTopGap - heroBottom;

    return Stack(
      children: [
        // Ground wave, tucked just behind the top edge of the card.
        Positioned(
          bottom: bgBottom,
          left: -(mq.size.width * (_waveCompactZoom - 1)) / 2,
          child: buildAuthWave(width: mq.size.width * _waveCompactZoom),
        ),
        // Wordmark + the mascot standing on the wave, drawn after it so the
        // props sit in front.
        Positioned(
          bottom: heroBottom,
          left: 0,
          right: 0,
          child: AuthCompactHero(maxHeight: heroBand),
        ),
        // White form container
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: containerHeight,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kAuthFormColumnWidth,
                    ),
                    child: _buildFormColumn(state),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The form itself — back button, title, email and the state-specific body.
  /// Shared by both layouts so the two never drift apart.
  Widget _buildFormColumn(EmailVerificationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        if (widget.onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark08,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
            ),
          ),

        // Title
        Text(
          AppStrings.emailVerificationTitle,
          style: AppTextStyles.heading1().copyWith(height: 1.2),
        ),
        const SizedBox(height: 8),

        // Email display
        Text(
          widget.email,
          style: AppTextStyles.bodyLarge(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 24),

        // Content based on state
        _buildContent(state),
      ],
    );
  }

  Widget _buildContent(EmailVerificationState state) {
    // Show offline state first if device is offline
    if (_isOffline) {
      return _buildOfflineState();
    }

    if (state is EmailVerificationLoading) {
      return _buildLoadingState(state.message);
    }

    if (state is EmailVerificationError) {
      return _buildErrorState(state);
    }

    if (_codeSent || state is EmailVerificationCodeSent) {
      return _buildCodeEntryState();
    }

    return _buildLoadingState(AppStrings.emailVerificationSending);
  }

  Widget _buildOfflineState() {
    // Simple background state while dialog is shown
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.primaryDark32,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.emailVerificationOfflineLabel,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryDark64,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEntryState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.emailVerificationCodePrompt,
          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 16),

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
                  // No maxLength — see _onPinChanged for the paste flow.
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
        const SizedBox(height: 24),

        // Verify button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _pin.length == 6 ? _verifyCode : null,
            style: ElevatedButton.styleFrom(
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
                Text(
                  AppStrings.emailVerificationVerify,
                  style: AppTextStyles.buttonLarge(color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend code link
        Center(
          child: TextButton(
            onPressed: _sendCode,
            child: Text(
              AppStrings.emailVerificationResend,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64).copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(EmailVerificationError error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryDark08,
            borderRadius: AppDecorations.radiusS,
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.message,
                  style: AppTextStyles.bodySmall(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Show code entry for retry
        _buildCodeEntryState(),
      ],
    );
  }
}
