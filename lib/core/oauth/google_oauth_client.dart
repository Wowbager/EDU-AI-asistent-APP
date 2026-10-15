import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../util/silent_log.dart';
import 'oauth_payload.dart';
import 'oauth_provider.dart';

/// Google sign-in wrapper.
///
/// google_sign_in 7.x splits platforms into two models:
///  - **Native (iOS/Android)**: imperative — [signIn] calls `authenticate()`
///    and returns the account.
///  - **Web**: `authenticate()` is unsupported; a GIS-rendered button drives
///    the flow and results arrive on [signInResults] (the event stream).
class GoogleOAuthClient {
  GoogleOAuthClient({required this.webClientId});

  /// The Google **Web** OAuth client ID. On web it is the GIS `clientId`
  /// (also read from the `<meta>` tag in index.html); on iOS/Android it is
  /// passed as `serverClientId` so the returned id_token carries the backend's
  /// audience.
  final String webClientId;

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final id = webClientId.isNotEmpty ? webClientId : null;
    await GoogleSignIn.instance.initialize(
      // Web: the client ID comes from the <meta> tag when this is null.
      clientId: kIsWeb ? id : null,
      // Native: request a backend-audience id_token.
      serverClientId: kIsWeb ? null : id,
    );
    _initialized = true;
  }

  /// Imperative sign-in for platforms that support it (iOS/Android). Returns
  /// null when the user cancels, or on web (which must use [signInResults]).
  Future<OAuthClientResult?> signIn() async {
    await ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) return null;
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['openid', 'email', 'profile'],
      );
      return _toResult(account);
    } on GoogleSignInException catch (e, st) {
      // Android maps a Google Cloud misconfiguration (missing Android-type
      // OAuth client for this package+SHA-1) to `canceled` too — Credential
      // Manager dismisses its sheet after the account pick. Log it so the
      // "picked account, nothing happened" reports carry the real code.
      silentLog('google_oauth', e, st);
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Completed sign-ins from the GIS event stream. Used on web, where the
  /// rendered button (not [signIn]) triggers authentication.
  Stream<OAuthClientResult> signInResults() {
    return GoogleSignIn.instance.authenticationEvents
        .where((e) => e is GoogleSignInAuthenticationEventSignIn)
        .map((e) => _toResult((e as GoogleSignInAuthenticationEventSignIn).user))
        .where((r) => r != null)
        .cast<OAuthClientResult>();
  }

  OAuthClientResult? _toResult(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null) return null;
    return OAuthClientResult(
      provider: OAuthProvider.google,
      idToken: idToken,
      email: account.email,
      fullName: account.displayName,
    );
  }

  Future<void> signOut() => GoogleSignIn.instance.signOut();
}
