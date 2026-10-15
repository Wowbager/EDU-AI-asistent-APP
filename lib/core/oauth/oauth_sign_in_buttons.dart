import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/repositories/oauth_repository.dart';
import '../providers/core_providers.dart';
import '../strings/app_strings.dart';
import '../theme/app_theme.dart';
import 'google_web_button.dart';
import 'oauth_clients.dart';

/// The Google / Microsoft / Apple sign-in buttons, plus the credential →
/// session exchange behind them.
///
/// Lifted out of AuthPage so the registration dialog opened from the "sign up
/// for full access" banner offers the same providers (BR-79QSEV). Callers own
/// the surrounding layout (divider, legal notice) and what happens on success.
class OAuthSignInButtons extends ConsumerStatefulWidget {
  const OAuthSignInButtons({
    super.key,
    required this.onSuccess,
    required this.sharedDevice,
    this.persistSharedPreference = true,
    this.onError,
    this.beforeExchange,
  });

  /// Called once a provider credential has been exchanged for a session.
  final ValueChanged<OAuthExchangeResult> onSuccess;

  /// Session mode to request from the backend. Callers must pass the value
  /// that is correct for *their* context — the auth screen passes the user's
  /// checkbox choice, an in-session dialog passes the mode the running session
  /// was actually issued with. The backend skips folding a guest's data into
  /// the account when this is true (OAuthController, BR-ZDXP7C), so a wrong
  /// value here silently orphans the guest's courses.
  final bool sharedDevice;

  /// Whether to also record [sharedDevice] as the user's pending preference.
  /// True when the user just made that choice (auth screen); false when it was
  /// merely read off the running session (dialogs), which must not overwrite a
  /// preference the user never expressed.
  final bool persistSharedPreference;

  /// Receives a failure message instead of the default SnackBar. Callers that
  /// sit behind a modal barrier want this — a SnackBar renders under the
  /// barrier and is easy to miss.
  final ValueChanged<String>? onError;

  /// Runs when the credential in hand turns out to belong to *no* account
  /// yet, i.e. when continuing would register rather than sign in. Returning
  /// false abandons the flow with nothing created.
  ///
  /// The exchange is what creates the account (`OAuthController` creates the
  /// user row for an unknown email), so anything that must gate account
  /// creation belongs here — not in front of the buttons, which would also
  /// stop people merely signing back in (BR-N9Y48J). Unlike the magic-link
  /// flow, OAuth has no separate "does this email exist" step, so the sign-in
  /// itself asks the backend not to register and reports back instead
  /// (BR-VTNTMQ) — see [_completeOAuth].
  final Future<bool> Function()? beforeExchange;

  @override
  ConsumerState<OAuthSignInButtons> createState() => _OAuthSignInButtonsState();
}

class _OAuthSignInButtonsState extends ConsumerState<OAuthSignInButtons> {
  bool _isOAuthInProgress = false;

  /// Web-only: the GIS button drives Google sign-in and results arrive on this
  /// subscription. [_googleWebReady] gates rendering the button until the SDK
  /// is initialized. Both stay null/false on native.
  StreamSubscription<OAuthClientResult>? _googleWebSub;
  bool _googleWebReady = false;

  @override
  void initState() {
    super.initState();

    // Web: Google sign-in can't be triggered imperatively — a GIS button
    // renders it and results arrive on the event stream. Subscribe once and
    // initialize the SDK so the button can render.
    if (kIsWeb) {
      final client = ref.read(googleOAuthClientProvider);
      _googleWebSub = client.signInResults().listen(_completeOAuth);
      client.ensureInitialized().then((_) {
        if (mounted) setState(() => _googleWebReady = true);
      });
    }
  }

  @override
  void dispose() {
    _googleWebSub?.cancel();
    super.dispose();
  }

  /// Native (iOS/Android) button handler: obtain the provider credential
  /// imperatively, then exchange it. Web Google sign-in does not use this —
  /// its GIS button feeds [_completeOAuth] via the event subscription.
  Future<void> _handleOAuthLogin(String provider) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _isOAuthInProgress = true);

    final OAuthClientResult? clientResult;
    try {
      clientResult = await switch (provider) {
        'apple' => ref.read(appleOAuthClientProvider).signIn(),
        'google' => ref.read(googleOAuthClientProvider).signIn(),
        'microsoft' => ref.read(microsoftOAuthClientProvider).signIn(),
        _ => Future<OAuthClientResult?>.value(null),
      };
    } catch (e) {
      _reportError(messenger, '$e');
      if (mounted) setState(() => _isOAuthInProgress = false);
      return;
    }

    if (clientResult == null) {
      if (mounted) setState(() => _isOAuthInProgress = false);
      return; // user cancelled
    }

    await _completeOAuth(clientResult);
  }

  /// Exchange a provider credential for a session and notify the caller.
  /// Shared by the native handler and the web Google event subscription.
  ///
  /// The buttons are login and registration at once, and the exchange is
  /// find-or-create, so the only way to tell the two apart without creating
  /// anything is to ask the backend for a sign-in only first: an unknown email
  /// comes back as [OAuthRegistrationRequiredException] instead of a new
  /// account. Returning users are therefore never asked [beforeExchange] — the
  /// gate used to run on every single sign-in (BR-VTNTMQ). Registration costs
  /// a second exchange, which is the rarer path by far.
  Future<void> _completeOAuth(OAuthClientResult clientResult) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _isOAuthInProgress = true);

    final gate = widget.beforeExchange;

    try {
      if (widget.persistSharedPreference) {
        await ref
            .read(sessionMetaProvider)
            .setPendingSharedDevice(widget.sharedDevice);
      }
      final repository = ref.read(oauthRepositoryProvider);

      OAuthExchangeResult exchange;
      try {
        exchange = await repository.exchange(
          clientResult,
          sharedDevice: widget.sharedDevice,
          // No gate to run means nothing to protect the account creation from,
          // so let the first exchange register straight away.
          allowRegistration: gate == null,
        );
      } on OAuthRegistrationRequiredException {
        // Signing in would have registered. Ask now — nothing exists yet, so
        // backing out here leaves no half-made account behind.
        if (!await gate!()) {
          if (mounted) setState(() => _isOAuthInProgress = false);
          return;
        }
        if (!mounted) return;
        exchange = await repository.exchange(
          clientResult,
          sharedDevice: widget.sharedDevice,
        );
      }

      widget.onSuccess(exchange);
    } on OAuthExchangeException catch (e) {
      _reportError(messenger, e.message);
    } catch (e) {
      _reportError(messenger, '$e');
    } finally {
      if (mounted) setState(() => _isOAuthInProgress = false);
    }
  }

  void _reportError(ScaffoldMessengerState? messenger, String message) {
    if (!mounted) return;
    final onError = widget.onError;
    if (onError != null) {
      onError(message);
      return;
    }
    messenger?.showSnackBar(SnackBar(
      content: Text(AppStrings.genericError(message)),
      backgroundColor: AppColors.error,
    ));
  }

  /// Apple Sign In is only offered on Apple platforms. On web and Android it
  /// would require the Apple Services ID web OAuth flow (not configured), so
  /// the button is hidden there.
  bool get _showAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// On web the Google button is GIS-rendered and capped at
  /// [kGisButtonMaxWidth]; constrain the other social buttons to match so the
  /// column aligns. No-op on native, where all social buttons are full-width
  /// custom buttons.
  Widget _constrainSocialWeb(Widget child) {
    if (!kIsWeb) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kGisButtonMaxWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google OAuth button. Web must use the GIS-rendered button (no
        // imperative authenticate() on web); native uses the custom button.
        if (kIsWeb)
          GoogleWebButtonSlot(ready: _googleWebReady)
        else
          _buildOAuthButton(
            onTap:
                _isOAuthInProgress ? null : () => _handleOAuthLogin('google'),
            icon: SvgPicture.asset(
              'assets/icons/google.svg',
              width: 24,
              height: 24,
            ),
            label: AppStrings.authGoogleLogin,
          ),
        const SizedBox(height: 12),
        // Microsoft OAuth button — constrained to the GIS button's width on
        // web so all three social buttons align.
        _constrainSocialWeb(_buildOAuthButton(
          onTap:
              _isOAuthInProgress ? null : () => _handleOAuthLogin('microsoft'),
          icon: SvgPicture.asset(
            'assets/icons/microsoft.svg',
            width: 24,
            height: 24,
          ),
          label: AppStrings.authMicrosoftLogin,
        )),
        // Apple OAuth button — only on Apple devices. Web/Android would need
        // the Apple Services ID web flow, which isn't set up, so hide it there.
        if (_showAppleSignIn) ...[
          const SizedBox(height: 12),
          _constrainSocialWeb(_buildOAuthButton(
            onTap: _isOAuthInProgress ? null : () => _handleOAuthLogin('apple'),
            icon: SvgPicture.asset(
              'assets/icons/apple.svg',
              width: 24,
              height: 24,
            ),
            label: AppStrings.authAppleLogin,
          )),
        ],
      ],
    );
  }

  Widget _buildOAuthButton({
    required VoidCallback? onTap,
    required Widget icon,
    required String label,
  }) {
    // On web the Google button is Google-rendered (fixed ~40px tall, ~4px
    // corners, logo pinned left, text centered, regular weight). Match the
    // custom social buttons to it so the set looks uniform.
    const bool matchGis = kIsWeb;

    final Widget content = matchGis
        // GIS layout: icon pinned left, label centered across the full width.
        ? Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: icon,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge().copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Text(label, style: AppTextStyles.bodyLarge()),
            ],
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: matchGis ? 40 : 56,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primaryDark16,
            width: 1,
          ),
          borderRadius:
              matchGis ? BorderRadius.circular(4) : AppDecorations.radiusM,
        ),
        child: content,
      ),
    );
  }
}

/// The widest GIS will draw its button; it caps wider requests at this.
const double kGisButtonMaxWidth = 400;

/// Web-only slot for the GIS-rendered Google button: a spinner until the SDK
/// is [ready], then the button at the width the slot actually has.
///
/// GIS draws the button at a fixed pixel width, and google_sign_in_web centres
/// it in an `overflow: hidden` box the size of this slot — so asking for more
/// than the slot is wide clips both edges. It always asked for 400px, and the
/// 340px auth form column (`kAuthFormColumnWidth`) cut 30px off each side,
/// logo included (BR-N3MXDH). The width is floored because a fractional
/// request could round up past the edge.
@visibleForTesting
class GoogleWebButtonSlot extends StatelessWidget {
  const GoogleWebButtonSlot({
    super.key,
    required this.ready,
    this.buttonBuilder = googleRenderedSignInButton,
  });

  final bool ready;

  /// Renders the GIS button at the given width. Swappable for tests, which
  /// run on the VM where the real button is a no-op stub.
  final Widget Function({required double width}) buttonBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? math.min(constraints.maxWidth.floorToDouble(), kGisButtonMaxWidth)
            : kGisButtonMaxWidth;
        return SizedBox(
          height: 48,
          child: Center(
            child: ready
                ? buttonBuilder(width: width)
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          ),
        );
      },
    );
  }
}
