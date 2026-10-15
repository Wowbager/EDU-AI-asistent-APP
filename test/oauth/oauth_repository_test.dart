import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/network/oauth_api_port.dart';
import 'package:eduai/core/oauth/oauth_payload.dart';
import 'package:eduai/core/oauth/oauth_provider.dart';
import 'package:eduai/data/repositories/oauth_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake — implements the thin OAuthApiPort interface; no real Dio needed.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeApi implements OAuthApiPort {
  String? capturedPath;
  Map<String, dynamic>? capturedBody;

  /// Response to return from [post].
  ApiResult<Map<String, dynamic>> nextResult = ApiResult.success({
    'token': 'test-sanctum-token',
    'token_type': 'Bearer',
    'expires_at': null,
    'shared_device': false,
    'session_started_at': null,
    'user': {'id': 1, 'name': 'Test User', 'email': 'test@example.com', 'role': 'student'},
    'is_new_user': true,
    'profile_setup_required': false,
  });

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    capturedPath = path;
    capturedBody = data as Map<String, dynamic>?;
    // Cast: our test only calls post<Map<String,dynamic>>, so T == Map<String,dynamic>.
    return nextResult as ApiResult<T>;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late _FakeApi fakeApi;
  late OauthRepository repo;

  setUp(() {
    fakeApi = _FakeApi();
    repo = OauthRepository(fakeApi);
  });

  // ── Apple ──────────────────────────────────────────────────────────────────

  test('Apple: POSTs to /api/auth/apple with identity_token', () async {
    final input = OAuthClientResult(
      provider: OAuthProvider.apple,
      idToken: 'apple-id-token-123',
    );

    await repo.exchange(input);

    expect(fakeApi.capturedPath, '/api/auth/apple');
    expect(fakeApi.capturedBody!['identity_token'], 'apple-id-token-123');
    expect(fakeApi.capturedBody!.containsKey('id_token'), isFalse);
    expect(fakeApi.capturedBody!['shared_device'], false);
  });

  test('Apple: includes authorization_code and user.name when provided', () async {
    final input = OAuthClientResult(
      provider: OAuthProvider.apple,
      idToken: 'apple-id-token-456',
      authorizationCode: 'auth-code-abc',
      fullName: 'Jane Doe',
    );

    await repo.exchange(input);

    expect(fakeApi.capturedBody!['authorization_code'], 'auth-code-abc');
    expect(fakeApi.capturedBody!['user'], {'name': 'Jane Doe'});
  });

  test('Apple: omits authorization_code and user when null', () async {
    final input = OAuthClientResult(
      provider: OAuthProvider.apple,
      idToken: 'apple-id-token-789',
    );

    await repo.exchange(input);

    expect(fakeApi.capturedBody!.containsKey('authorization_code'), isFalse);
    expect(fakeApi.capturedBody!.containsKey('user'), isFalse);
  });

  // ── Google ─────────────────────────────────────────────────────────────────

  test('Google: POSTs to /api/auth/google with id_token', () async {
    final input = OAuthClientResult(
      provider: OAuthProvider.google,
      idToken: 'google-id-token-xyz',
    );

    await repo.exchange(input);

    expect(fakeApi.capturedPath, '/api/auth/google');
    expect(fakeApi.capturedBody!['id_token'], 'google-id-token-xyz');
    expect(fakeApi.capturedBody!.containsKey('identity_token'), isFalse);
    expect(fakeApi.capturedBody!['shared_device'], false);
  });

  // ── Microsoft ──────────────────────────────────────────────────────────────

  test('Microsoft: POSTs to /api/auth/microsoft with id_token', () async {
    final input = OAuthClientResult(
      provider: OAuthProvider.microsoft,
      idToken: 'ms-id-token-abc',
    );

    await repo.exchange(input);

    expect(fakeApi.capturedPath, '/api/auth/microsoft');
    expect(fakeApi.capturedBody!['id_token'], 'ms-id-token-abc');
    expect(fakeApi.capturedBody!['shared_device'], false);
  });

  // ── shared_device flag ─────────────────────────────────────────────────────

  test('shared_device=true is sent in body', () async {
    final input = OAuthClientResult(
      provider: OAuthProvider.google,
      idToken: 'google-token',
    );

    await repo.exchange(input, sharedDevice: true);

    expect(fakeApi.capturedBody!['shared_device'], true);
  });

  // ── Response parsing ───────────────────────────────────────────────────────

  test('Response is parsed into OAuthExchangeResult correctly', () async {
    fakeApi.nextResult = ApiResult.success({
      'token': 'sanctum-abc',
      'token_type': 'Bearer',
      'expires_at': '2026-07-01T00:00:00Z',
      'shared_device': true,
      'session_started_at': '2026-06-01T10:00:00Z',
      'user': {'id': 42, 'name': 'Alice', 'email': 'alice@edu.ai', 'role': 'teacher'},
      'is_new_user': false,
      'profile_setup_required': true,
    });

    final input = OAuthClientResult(
      provider: OAuthProvider.apple,
      idToken: 'apple-token',
    );

    final result = await repo.exchange(input);

    expect(result.token, 'sanctum-abc');
    expect(result.tokenType, 'Bearer');
    expect(result.expiresAt, '2026-07-01T00:00:00Z');
    expect(result.sharedDevice, true);
    expect(result.sessionStartedAt, '2026-06-01T10:00:00Z');
    expect(result.user['id'], 42);
    expect(result.user['email'], 'alice@edu.ai');
    expect(result.isNewUser, false);
    expect(result.profileSetupRequired, true);
  });

  test('Minimal response (null optional fields) is parsed without error', () async {
    fakeApi.nextResult = ApiResult.success({
      'token': 'minimal-token',
      'user': {'id': 1, 'name': 'Bob', 'email': 'bob@edu.ai', 'role': 'student'},
    });

    final input = OAuthClientResult(
      provider: OAuthProvider.google,
      idToken: 'google-minimal',
    );

    final result = await repo.exchange(input);

    expect(result.token, 'minimal-token');
    expect(result.tokenType, 'Bearer'); // default
    expect(result.expiresAt, isNull);
    expect(result.sharedDevice, false); // default (sharedDevice arg was false)
    expect(result.isNewUser, false);
    expect(result.profileSetupRequired, false);
  });

  // ── allow_registration ─────────────────────────────────────────────────────

  test('allow_registration defaults to true in the body', () async {
    await repo.exchange(
      OAuthClientResult(provider: OAuthProvider.google, idToken: 'g'),
    );

    expect(fakeApi.capturedBody!['allow_registration'], true);
  });

  test('allow_registration=false is sent in body', () async {
    await repo.exchange(
      OAuthClientResult(provider: OAuthProvider.google, idToken: 'g'),
      allowRegistration: false,
    );

    expect(fakeApi.capturedBody!['allow_registration'], false);
  });

  test('409 becomes OAuthRegistrationRequiredException, not a plain failure',
      () async {
    fakeApi.nextResult =
        ApiResult.failure('Tento účet zatím neexistuje.', statusCode: 409);

    expect(
      () => repo.exchange(
        OAuthClientResult(provider: OAuthProvider.google, idToken: 'g'),
        allowRegistration: false,
      ),
      throwsA(isA<OAuthRegistrationRequiredException>()),
    );
  });

  // ── Error path ─────────────────────────────────────────────────────────────

  test('Throws OAuthExchangeException on API failure', () async {
    fakeApi.nextResult = ApiResult.failure('Unauthorized');

    final input = OAuthClientResult(
      provider: OAuthProvider.apple,
      idToken: 'bad-token',
    );

    expect(
      () => repo.exchange(input),
      throwsA(isA<OAuthExchangeException>()),
    );
  });
}
