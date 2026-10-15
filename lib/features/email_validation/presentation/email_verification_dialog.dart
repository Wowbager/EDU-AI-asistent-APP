import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/oauth/oauth_sign_in_buttons.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/strings/locale_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/consent_repository.dart';
import '../../../data/repositories/oauth_repository.dart';
import '../../../pages/consent/age_gate_route.dart';
import '../../../pages/consent/consent_request_page.dart';
import '../providers/email_validation_providers.dart';

/// Dialog for email verification with support for two flows:
/// 1. Guest users (email is empty): Enter email → Send code → Enter PIN → Verify
/// 2. Registered users (email exists): Show email → Send code → Enter PIN → Verify
///
/// Both flows also offer SSO, so the banner's "sign up for full access" prompt
/// reaches the same providers as the auth screen (BR-79QSEV).
class EmailVerificationDialog extends ConsumerStatefulWidget {
  final String email;

  /// Called when the user signed in through a social provider instead of the
  /// email code. Null hides the SSO section (no one to hand the session to).
  final ValueChanged<OAuthExchangeResult>? onOAuthSuccess;

  const EmailVerificationDialog({
    super.key,
    required this.email,
    this.onOAuthSuccess,
  });

  @override
  ConsumerState<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends ConsumerState<EmailVerificationDialog> {
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  late bool _isGuest;
  late String _activeEmail;

  /// Failure from the SSO exchange, rendered inline. A SnackBar would come up
  /// behind this dialog's modal barrier.
  String? _ssoError;

  @override
  void initState() {
    super.initState();
    _isGuest = widget.email.isEmpty;
    _activeEmail = widget.email;
    _emailController.text = widget.email;
    // Reset provider state so the dialog always starts fresh
    // (e.g. after a previous successful verification left state as Success).
    ref.read(emailVerificationProvider.notifier).reset();
  }

  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  String get _pin => _pinControllers.map((c) => c.text).join();

  bool get _isEmailValid {
    final email = _emailController.text.trim();
    return email.contains('@') && email.contains('.');
  }

  void _onPinChanged(int index, String value) {
    // Paste handling — user pasted the whole 6-digit code into one field.
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

  void _clearPinFields() {
    for (final controller in _pinControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _handleSendCode() async {
    _activeEmail = _emailController.text.trim();
    final notifier = ref.read(emailVerificationProvider.notifier);
    // Same rule as the auth screen: an unknown e-mail is a registration and
    // meets the age gate before a code goes anywhere (BR-J2WJEQ).
    if (!await notifier.screenNewAccount(
          _activeEmail,
          onNewAccount: _ageGateBeforeRegistration,
        ) ||
        !mounted) {
      return;
    }
    notifier.sendCode(_activeEmail);
  }

  /// The gate is passed again here only as the fallback for when
  /// [_handleSendCode]'s account check could not reach the server; the
  /// notifier skips it for an e-mail that was already asked about.
  void _verifyCode() {
    ref
        .read(emailVerificationProvider.notifier)
        .verifyCode(_pin, onNewAccount: _ageGateBeforeRegistration);
  }

  /// The age gate for an account this dialog is about to create — an unknown
  /// e-mail, or a provider credential with no account behind it. Returns
  /// whether the registration may proceed.
  ///
  /// This dialog registers guests too, and used to do it without ever asking,
  /// by e-mail or by provider. A minor is handed to the guardian consent flow
  /// the same way MainScreen's login route does it: the child types the code
  /// their parent receives on the normal PIN screen.
  Future<bool> _ageGateBeforeRegistration() async {
    // Captured up front: a minor's answer closes this dialog, after which
    // neither its context nor its ref may be touched.
    final navigator = Navigator.of(context);
    final consentRepository = ref.read(consentRepositoryProvider);
    final guestLogin = ref.read(requestGuestLoginProvider.notifier);

    final result = await showAgeGate(context);
    if (!mounted) return false;

    switch (result.outcome) {
      case AgeGateOutcome.oldEnough:
        return true;
      case AgeGateOutcome.needsConsent:
        final country = result.country;
        ref.read(emailVerificationProvider.notifier).reset();
        navigator.pop();
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ConsentRequestPage(
              country: country,
              onSubmit: (email) => consentRepository.requestConsent(
                email: email,
                locale: LocaleManager.current.code,
                country: country,
              ),
              onEnterCode: () {
                navigator.pop();
                guestLogin.state++;
              },
              onBack: () => navigator.pop(),
            ),
          ),
        );
        return false;
      case AgeGateOutcome.dismissed:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailVerificationProvider);

    // Listen for state changes
    ref.listen(emailVerificationProvider, (previous, current) {
      if (current is EmailVerificationSuccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isGuest
                  ? AppStrings.dialogRegistrationSuccess
                  : AppStrings.dialogEmailVerified,
              style: AppTextStyles.bodySmall(),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.radiusS,
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else if (current is EmailVerificationError) {
        // Clear PIN fields on error for retry
        if (current.type == EmailVerificationErrorType.invalidCode) {
          _clearPinFields();
        }
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppDecorations.radiusXL,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        // 400 content + 2×24 padding: room for the GIS-rendered Google button
        // at its full 400px on web (it shrinks to fit anything narrower).
        constraints: const BoxConstraints(maxWidth: 448),
        // With the SSO block added, the initial step can outgrow a short
        // viewport (small phone, or any phone with the keyboard up).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bannerOrange16,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_outlined,
                      color: AppColors.bannerOrangeDark,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ref.read(emailVerificationProvider.notifier).reset();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    color: AppColors.primaryDark48,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                _isGuest ? AppStrings.dialogRegistration : AppStrings.dialogEmailVerification,
                style: AppTextStyles.heading3(),
              ),
              const SizedBox(height: 8),

              // Subtitle — only show email for non-guests when not in initial state
              if (!_isGuest && state is! EmailVerificationInitial)
                Text(
                  _activeEmail,
                  style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
                ),
              if (!_isGuest && state is! EmailVerificationInitial)
                const SizedBox(height: 24),

              // Content based on state
              _buildContent(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(EmailVerificationState state) {
    return switch (state) {
      // SSO rides along with the initial step only — once a code is in flight
      // the user has committed to the email path.
      EmailVerificationInitial() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _isGuest ? _buildEmailInputStep() : _buildSendCodeStep(),
            if (widget.onOAuthSuccess != null) _buildSsoStep(),
          ],
        ),
      EmailVerificationLoading(:final message) => _buildLoadingStep(message),
      EmailVerificationCodeSent() => _buildEnterCodeStep(),
      EmailVerificationError(:final type, :final message) => _buildErrorStep(type, message),
      EmailVerificationSuccess() => const SizedBox.shrink(),
    };
  }

  /// Step for guest users: enter email address first
  Widget _buildEmailInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.dialogEmailInputPrompt,
          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: AppTextStyles.bodyLarge(),
          decoration: InputDecoration(
            hintText: AppStrings.dialogEmailHint,
            hintStyle: AppTextStyles.bodyLarge(color: AppColors.primaryDark32),
            prefixIcon: Icon(
              Icons.mail_outline,
              color: AppColors.primaryDark48,
            ),
            border: OutlineInputBorder(
              borderRadius: AppDecorations.radiusM,
              borderSide: BorderSide(
                color: AppColors.primaryDark16,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusM,
              borderSide: BorderSide(
                color: AppColors.primaryDark16,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppDecorations.radiusM,
              borderSide: BorderSide(
                color: AppColors.primaryDark,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _isEmailValid ? (_) => _handleSendCode() : null,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isEmailValid ? _handleSendCode : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryDark32,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.48),
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.radiusM,
              ),
              elevation: 0,
            ),
            child: Text(
              AppStrings.actionContinue,
              style: AppTextStyles.buttonLarge(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// "Nebo" divider + the social sign-in buttons, mirroring the auth screen.
  Widget _buildSsoStep() {
    // The mode the *running* session was issued with — not
    // SessionMeta.pendingSharedDevice, whose `true` default would make the
    // backend skip absorbGuest and orphan this guest's courses (BR-79QSEV).
    final sharedDevice = ref.read(sessionMetaProvider).sharedDevice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(height: 1, color: AppColors.primaryDark12),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppStrings.authOrCzech,
                style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
              ),
            ),
            Expanded(
              child: Container(height: 1, color: AppColors.primaryDark12),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_ssoError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error08,
              borderRadius: AppDecorations.radiusS,
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _ssoError!,
                    style: AppTextStyles.bodySmall(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        OAuthSignInButtons(
          sharedDevice: sharedDevice,
          // Read off the session, not chosen here — must not overwrite the
          // preference the user states when logging in fresh.
          persistSharedPreference: false,
          beforeExchange: _ageGateBeforeRegistration,
          onError: (message) {
            if (mounted) setState(() => _ssoError = message);
          },
          onSuccess: (exchange) {
            Navigator.of(context).pop();
            widget.onOAuthSuccess?.call(exchange);
          },
        ),
      ],
    );
  }

  Widget _buildSendCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _activeEmail,
          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.dialogSendCodePrompt,
          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _handleSendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.radiusM,
              ),
              elevation: 0,
            ),
            child: Text(
              AppStrings.dialogSendCode,
              style: AppTextStyles.buttonLarge(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingStep(String message) {
    return Column(
      children: [
        const SizedBox(height: 24),
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEnterCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.dialogEnterCode,
          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
        ),
        const SizedBox(height: 16),

        // PIN input fields
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 44,
              height: 52,
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
                  style: AppTextStyles.cardTitleAlt(),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: AppDecorations.radiusS,
                      borderSide: BorderSide(
                        color: AppColors.primaryDark16,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppDecorations.radiusS,
                      borderSide: BorderSide(
                        color: AppColors.primaryDark16,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppDecorations.radiusS,
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
            onPressed: _pin.length == 6
                ? () {
                    _verifyCode();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryDark32,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.48),
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.radiusM,
              ),
              elevation: 0,
            ),
            child: Text(
              AppStrings.emailVerificationVerify,
              style: AppTextStyles.buttonLarge(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend code link
        Center(
          child: TextButton(
            onPressed: () {
              ref.read(emailVerificationProvider.notifier).resendCode();
            },
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

  Widget _buildErrorStep(EmailVerificationErrorType type, String message) {
    final showRetryCodeEntry = type == EmailVerificationErrorType.invalidCode;
    final showResendOption = type == EmailVerificationErrorType.codeExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error08,
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
                  message,
                  style: AppTextStyles.bodySmall(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Show code entry if invalid code
        if (showRetryCodeEntry) ...[
          Text(
            AppStrings.dialogEnterCode,
            style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
          ),
          const SizedBox(height: 16),

          // PIN input fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 44,
                height: 52,
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
                    style: AppTextStyles.cardTitleAlt(),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: AppDecorations.radiusS,
                        borderSide: BorderSide(
                          color: AppColors.error32,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppDecorations.radiusS,
                        borderSide: BorderSide(
                          color: AppColors.error32,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppDecorations.radiusS,
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
              onPressed: _pin.length == 6
                  ? () {
                      _verifyCode();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryDark32,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.48),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.radiusM,
                ),
                elevation: 0,
              ),
              child: Text(
                AppStrings.emailVerificationRetry,
                style: AppTextStyles.buttonLarge(color: Colors.white),
              ),
            ),
          ),
        ],

        // Show resend option if code expired
        if (showResendOption) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                ref.read(emailVerificationProvider.notifier).resendCode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.radiusM,
                ),
                elevation: 0,
              ),
              child: Text(
                AppStrings.dialogSendNewCode,
                style: AppTextStyles.buttonLarge(color: Colors.white),
              ),
            ),
          ),
        ],

        // Show general retry for other errors
        if (!showRetryCodeEntry && !showResendOption) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                ref.read(emailVerificationProvider.notifier).reset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.radiusM,
                ),
                elevation: 0,
              ),
              child: Text(
                AppStrings.emailVerificationRetry,
                style: AppTextStyles.buttonLarge(color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
