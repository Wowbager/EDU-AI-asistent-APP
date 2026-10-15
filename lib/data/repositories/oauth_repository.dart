import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/oauth_api_port.dart';
import '../../core/oauth/oauth_payload.dart';
import '../../core/oauth/oauth_provider.dart';
import '../../core/providers/core_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Result model
// ═══════════════════════════════════════════════════════════════════════════

class OAuthExchangeResult {
  OAuthExchangeResult({
    required this.token,
    required this.tokenType,
    required this.expiresAt,
    required this.sharedDevice,
    required this.sessionStartedAt,
    required this.user,
    required this.isNewUser,
    required this.profileSetupRequired,
  });

  final String token;
  final String tokenType;
  final String? expiresAt;
  final bool sharedDevice;
  final String? sessionStartedAt;
  final Map<String, dynamic> user;
  final bool isNewUser;
  final bool profileSetupRequired;
}

// ═══════════════════════════════════════════════════════════════════════════
// Exception
// ═══════════════════════════════════════════════════════════════════════════

class OAuthExchangeException implements Exception {
  OAuthExchangeException(this.message);
  final String message;
  @override
  String toString() => 'OAuthExchangeException: $message';
}

/// The credential is valid but no account exists behind it, and the caller
/// asked not to create one ([OauthRepository.exchange]'s `allowRegistration`).
/// Nothing was created server-side — the caller may run whatever guards
/// account creation and then exchange again with registration allowed.
class OAuthRegistrationRequiredException implements Exception {
  OAuthRegistrationRequiredException(this.message);
  final String message;
  @override
  String toString() => 'OAuthRegistrationRequiredException: $message';
}

// ═══════════════════════════════════════════════════════════════════════════
// Repository
// ═══════════════════════════════════════════════════════════════════════════

class OauthRepository {
  OauthRepository(this._api);
  final OAuthApiPort _api;

  /// Exchange a provider credential for a session.
  ///
  /// [allowRegistration] false asks the backend to sign in only: an email with
  /// no account behind it comes back as [OAuthRegistrationRequiredException]
  /// with nothing created, instead of silently registering. Callers that gate
  /// account creation (the age gate) use that to leave returning users alone.
  Future<OAuthExchangeResult> exchange(
    OAuthClientResult input, {
    bool sharedDevice = false,
    bool allowRegistration = true,
  }) async {
    final path = switch (input.provider) {
      OAuthProvider.apple => ApiEndpoints.oauthApple,
      OAuthProvider.google => ApiEndpoints.oauthGoogle,
      OAuthProvider.microsoft => ApiEndpoints.oauthMicrosoft,
    };

    final body = <String, dynamic>{
      'shared_device': sharedDevice,
      'allow_registration': allowRegistration,
    };

    if (input.provider == OAuthProvider.apple) {
      body['identity_token'] = input.idToken;
      if (input.authorizationCode != null) {
        body['authorization_code'] = input.authorizationCode;
      }
      if (input.fullName != null) {
        body['user'] = {'name': input.fullName};
      }
    } else {
      body['id_token'] = input.idToken;
    }

    final response =
        await _api.post<Map<String, dynamic>>(path, data: body);

    if (!response.isSuccess || response.data == null) {
      // 409 is the backend refusing to register because we asked it not to —
      // a distinct outcome, not a failure the user should see as an error.
      if (response.statusCode == 409) {
        throw OAuthRegistrationRequiredException(
            response.error ?? 'Account does not exist yet');
      }
      throw OAuthExchangeException(response.error ?? 'OAuth exchange failed');
    }

    final d = response.data!;
    return OAuthExchangeResult(
      token: d['token'] as String,
      tokenType: (d['token_type'] as String?) ?? 'Bearer',
      expiresAt: d['expires_at'] as String?,
      sharedDevice: (d['shared_device'] as bool?) ?? sharedDevice,
      sessionStartedAt: d['session_started_at'] as String?,
      user: d['user'] as Map<String, dynamic>,
      isNewUser: (d['is_new_user'] as bool?) ?? false,
      profileSetupRequired: (d['profile_setup_required'] as bool?) ?? false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Riverpod provider
// ═══════════════════════════════════════════════════════════════════════════

final oauthRepositoryProvider = Provider<OauthRepository>((ref) {
  return OauthRepository(ref.watch(apiClientProvider));
});
