import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/consent/age_threshold.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/providers/core_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Result models
// ═══════════════════════════════════════════════════════════════════════════

/// Why a call to a public consent endpoint did not succeed. Screens branch
/// on this:
/// - [rejected] — the request reached the server, which said no (wrong or
///   expired code, a dead/expired magic link, bad input). Show the specific
///   in-flow error and let the guardian/child retry entering something.
/// - [network] — the request never reached the server at all (offline,
///   timeout, DNS). Offer a plain "try again", not a claim about the code.
///
/// Every write in [ConsentRepository] surfaces one of these on failure
/// instead of collapsing to a bare `false`, which would leave a screen no
/// way to tell "your code is wrong" apart from "you're offline".
enum ConsentFailure { rejected, network }

/// The API only ever sets a status code once a response actually came back
/// (see `ApiClient._handleError`): connection errors and timeouts leave it
/// null, a 4xx/5xx response sets it. That is exactly the rejected/network
/// split above.
ConsentFailure _failureFrom(ApiResult<dynamic> result) =>
    result.statusCode != null ? ConsentFailure.rejected : ConsentFailure.network;

/// Result of a plain accept/reject consent call (request consent, revoke,
/// resend a management link) where nothing beyond success/failure-and-why
/// is returned by the API.
class ConsentActionResult {
  final bool success;
  final ConsentFailure? failure;

  const ConsentActionResult.success()
      : success = true,
        failure = null;

  const ConsentActionResult.failure(ConsentFailure this.failure) : success = false;
}

/// Result of confirming a consent from the emailed code.
class ConsentConfirmResult {
  final bool confirmed;

  /// The guardian's total minor count after this call — not the number
  /// created by this call. On a repeat confirmation the API tops up rather
  /// than duplicates, so this can be unchanged from before.
  final int totalChildren;

  /// False when the account(s) were provisioned but the codes email failed
  /// to send. The caller must offer a resend instead of "check your inbox".
  final bool mailSent;

  final ConsentFailure? failure;

  const ConsentConfirmResult.success({required this.totalChildren, required this.mailSent})
      : confirmed = true,
        failure = null;

  const ConsentConfirmResult.failure(ConsentFailure this.failure)
      : confirmed = false,
        totalChildren = 0,
        mailSent = false;
}

/// One child account as shown on the guardian management page.
class ConsentChild {
  final int id;
  final String name;

  const ConsentChild({required this.id, required this.name});

  factory ConsentChild.fromJson(Map<String, dynamic> json) => ConsentChild(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );
}

/// State of a guardian's consent behind a magic link.
class ConsentManageState {
  final String status;
  final List<ConsentChild> children;

  const ConsentManageState({required this.status, required this.children});
}

/// Result of loading the guardian management page state.
class ConsentManageResult {
  final ConsentManageState? state;
  final ConsentFailure? failure;

  const ConsentManageResult.success(ConsentManageState this.state) : failure = null;

  const ConsentManageResult.failure(ConsentFailure this.failure) : state = null;

  bool get isSuccess => state != null;
}

/// Result of regenerating a child's login code.
class ConsentCodeResult {
  /// The new plaintext code, shown once and never stored. Null on failure.
  final String? code;
  final ConsentFailure? failure;

  const ConsentCodeResult.success(String this.code) : failure = null;

  const ConsentCodeResult.failure(ConsentFailure this.failure) : code = null;

  bool get isSuccess => code != null;
}

// ═══════════════════════════════════════════════════════════════════════════
// Repository
// ═══════════════════════════════════════════════════════════════════════════

/// Talks to the public consent endpoints (`routes/api.php`'s `consent`
/// group). None of these calls carry an auth token — the guardian has no
/// account, only a link from their inbox.
class ConsentRepository {
  final ApiClient _api;

  ConsentRepository(this._api);

  /// Refresh the bundled age thresholds from the server. Failures are silent:
  /// the gate keeps working on the bundled defaults.
  Future<void> loadConfig() async {
    final result = await _api.get<Map<String, dynamic>>(ApiEndpoints.consentConfig);
    if (!result.isSuccess || result.data == null) return;

    final raw = result.data!['age_thresholds'];
    if (raw is! Map) return;

    AgeThreshold.applyServerConfig(
      thresholds: raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      defaultThreshold: (result.data!['default_age_threshold'] as num?)?.toInt() ?? 15,
    );
  }

  /// Ask the guardian for consent. The response is intentionally constant, so
  /// success here means "we accepted the request", not "the email exists".
  Future<ConsentActionResult> requestConsent({
    required String email,
    required String locale,
    required String? country,
  }) async {
    final result = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.consentRequest,
      data: {
        'email': email.trim(),
        'locale': locale,
        if (country != null) 'country': country,
      },
    );

    if (result.isSuccess) return const ConsentActionResult.success();
    return ConsentActionResult.failure(_failureFrom(result));
  }

  /// Confirm a consent. Public web page only, never from the child's app.
  Future<ConsentConfirmResult> confirm({required String publicId, required String code}) async {
    final result = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.consentConfirm,
      data: {'id': publicId, 'code': code.trim().toUpperCase()},
    );

    if (!result.isSuccess || result.data?['confirmed'] != true) {
      return ConsentConfirmResult.failure(_failureFrom(result));
    }

    final data = result.data!;
    return ConsentConfirmResult.success(
      totalChildren: (data['children'] as num?)?.toInt() ?? 0,
      mailSent: data['mail_sent'] == true,
    );
  }

  /// Load the guardian management page state behind a magic-link token. The
  /// response carries `Cache-Control: no-store` server-side; nothing here
  /// caches it either — always fetched fresh.
  Future<ConsentManageResult> loadManageState(String token) async {
    final result = await _api.get<Map<String, dynamic>>(
      '${ApiEndpoints.consentManage}/$token',
    );

    if (!result.isSuccess || result.data == null) {
      return ConsentManageResult.failure(_failureFrom(result));
    }

    final data = result.data!;
    final children = (data['children'] as List? ?? const [])
        .map((e) => ConsentChild.fromJson(e as Map<String, dynamic>))
        .toList();

    return ConsentManageResult.success(ConsentManageState(
      status: data['status'] as String? ?? 'unknown',
      children: children,
    ));
  }

  /// Regenerate one child's login code. Returns the new plaintext code, shown
  /// once and never stored.
  Future<ConsentCodeResult> regenerateCode(String token, int childId) async {
    final result = await _api.post<Map<String, dynamic>>(
      '${ApiEndpoints.consentManage}/$token/regenerate',
      data: {'child_id': childId},
    );

    final code = result.isSuccess ? (result.data?['code'] as String?) : null;
    if (code == null) return ConsentCodeResult.failure(_failureFrom(result));
    return ConsentCodeResult.success(code);
  }

  Future<ConsentActionResult> revoke(String token) async {
    final result = await _api.post<Map<String, dynamic>>(
      '${ApiEndpoints.consentManage}/$token/revoke',
    );

    if (result.isSuccess) return const ConsentActionResult.success();
    return ConsentActionResult.failure(_failureFrom(result));
  }

  Future<ConsentActionResult> requestManageLink(String email) async {
    final result = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.consentManageRequestLink,
      data: {'email': email.trim()},
    );

    if (result.isSuccess) return const ConsentActionResult.success();
    return ConsentActionResult.failure(_failureFrom(result));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Riverpod provider
// ═══════════════════════════════════════════════════════════════════════════

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ConsentRepository(ref.watch(apiClientProvider));
});
