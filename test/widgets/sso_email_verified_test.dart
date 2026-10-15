// Characterisation tests around BR-3XVWV7: after signing up or signing in via
// SSO the app still showed the "Ověř svůj e-mail pro plný přístup" banner.
//
// The backend was never wrong — OAuthController::loginByEmail sets
// email_verified_at for both a freshly created user and a previously
// unverified one. The banner reads a *local* Drift column
// (showEmailValidationBannerProvider -> users.is_email_validated), and nothing
// in the OAuth path kept that column in sync with the server.
//
// READ THIS BEFORE TRUSTING THIS FILE: none of these tests fail against the
// pre-fix code, so none of them would have caught the original bug. All three
// gaps lived in AuthWrapper — _handleOAuthSuccess not setting
// _isEmailValidated, _persistOAuthUser missing a branch, and the /api/user
// sync ignoring email_verified_at — and AuthWrapper cannot be pumped in a
// widget test: its build() wraps every state in InactivityWatcher, whose real
// Timer.periodic and dispose()-time ref.read() deadlock flutter_test's
// teardown. See root_navigator_minor_test.dart's header for the full write-up
// of that constraint. The real defect is therefore still only covered by
// manual testing on stage.
//
// What these tests are actually worth:
//
//   - The ProfileSetupPage pair pins the contract the fix depends on: that the
//     page writes users.is_email_validated straight from its widget flag, in
//     both directions. ProfileSetupPage already behaved this way; the bug was
//     that AuthWrapper handed it `false`. If someone later hardcodes this
//     write, or drops the parameter, the fix upstream goes silently dead and
//     these catch it.
//
//   - _runVerificationMirror is a copy of the mirror step added to
//     _checkExistingAuth, not a call into it, so it cannot detect that step
//     being deleted. It does exercise the real markEmailValidated against a
//     real Drift DB and pins the intended semantics — in particular that the
//     flag only ever moves false -> true and only on server say-so, which is
//     the property that keeps the fix from hiding the banner from people who
//     genuinely have not verified.
//
// Closing the real gap means making AuthWrapper mountable (or extracting the
// boot sequence out of it); that is a bigger change than this fix warranted.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/pages/profile_setup_page.dart';

/// In-memory token, so tests never touch the real FlutterSecureStorage
/// platform channel (unavailable in `flutter test`).
class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs});

  String? _fakeToken = 'device-token';

  @override
  String? get token => _fakeToken;

  @override
  bool get isAuthenticated => (_fakeToken ?? '').isNotEmpty;

  @override
  Future<void> setToken(String value) async => _fakeToken = value;

  @override
  Future<void> clearToken() async => _fakeToken = null;

  @override
  Future<void> load() async {}
}

/// Serves a canned /api/user body; every other call fails, which is what the
/// ProfileSetupPage tests want — a failed server sync is non-fatal there by
/// design, and the local row this test asserts on is written before it.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.tokens);

  Map<String, dynamic> userData = const {};

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    if (path == '/api/user') {
      return ApiResult.success(userData as T, statusCode: 200);
    }
    return ApiResult.failure('not mocked in test: $path', statusCode: 404);
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Duration? receiveTimeout,
  }) async {
    return ApiResult.failure('offline in test', statusCode: 503);
  }
}

/// Mirrors the email-verification mirror step this fix added to
/// AuthWrapper._checkExistingAuth's 200 branch (root_navigator.dart), calling
/// the real AppDatabase.markEmailValidated against the real (in-memory) DB.
/// Returns the flag the boot sequence would hand to ProfileSetupPage.
Future<bool> _runVerificationMirror(
  AppDatabase db,
  UsersTableData activeUser,
  Map<String, dynamic> userData,
) async {
  var isEmailValidated = activeUser.isEmailValidated;
  if (!isEmailValidated && userData['email_verified_at'] != null) {
    await db.markEmailValidated(activeUser.id);
    isEmailValidated = true;
  }
  return isEmailValidated;
}

const _userId = 'user-1';
const _email = 'student@example.com';

Future<void> _seedUser(AppDatabase db, {required bool isEmailValidated}) {
  return db.createAndActivateUser(
    UsersTableCompanion(
      id: const Value(_userId),
      email: const Value(_email),
      name: const Value('Student'),
      isEmailValidated: Value(isEmailValidated),
      isActive: const Value(true),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  // ══════════════════════════════════════════════════════════════════════════
  // (a) ProfileSetupPage must not downgrade an SSO-verified signup
  // ══════════════════════════════════════════════════════════════════════════

  /// Drives the real ProfileSetupPage through Continue and returns the user
  /// row it created.
  Future<UsersTableData> runProfileSetup(
    WidgetTester tester, {
    required bool isEmailValidated,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = _FakeAuthTokenStorage(prefs: prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          authTokenStorageProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(_FakeApiClient(tokens)),
          // Not a minor: minors are refused before any of this runs
          // (BR-8FDF37) and are covered by profile_setup_page_minor_test.dart.
          minorModeProvider.overrideWith((ref) => MinorModeNotifier()..state = false),
        ],
        child: MaterialApp(
          home: ProfileSetupPage(
            email: _email,
            isEmailValidated: isEmailValidated,
            onComplete: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField).first, 'Student');
    await tester.pump();

    // The onboarding has two steps (nickname + color profile, then the
    // avatar vibe); the row is only written on the second Continue.
    await tester.tap(find.text(AppStrings.actionContinue));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(AppStrings.actionContinue));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final user = await db.getActiveUser();
    expect(user, isNotNull, reason: 'Continue should have created a user row');
    return user!;
  }

  testWidgets(
    'ProfileSetupPage keeps the verified flag an SSO signup arrives with',
    (tester) async {
      final user = await runProfileSetup(tester, isEmailValidated: true);

      expect(
        user.isEmailValidated,
        isTrue,
        reason: 'an SSO signup is verified by the provider; writing false here '
            'is exactly what put the verify-email banner in front of SSO '
            'users (BR-3XVWV7)',
      );
    },
  );

  testWidgets(
    'ProfileSetupPage still records an unverified signup as unverified',
    (tester) async {
      final user = await runProfileSetup(tester, isEmailValidated: false);

      expect(
        user.isEmailValidated,
        isFalse,
        reason: 'the flag must be genuinely plumbed through, not hardcoded '
            'true — someone who skipped verification offline still needs the '
            'banner',
      );
    },
  );

  // ══════════════════════════════════════════════════════════════════════════
  // (c) The boot sync must converge a stale local flag
  // ══════════════════════════════════════════════════════════════════════════

  test('boot sync clears a stale unverified flag when the server says verified',
      () async {
    await _seedUser(db, isEmailValidated: false);
    final activeUser = (await db.getActiveUser())!;

    final flag = await _runVerificationMirror(db, activeUser, {
      'email_verified_at': '2026-08-24T10:00:00.000000Z',
    });

    expect(flag, isTrue, reason: 'the flag handed on to ProfileSetupPage must '
        'reflect the write, not the pre-write snapshot');
    expect(
      (await db.getActiveUser())!.isEmailValidated,
      isTrue,
      reason: 'without this an account that once went in unverified never '
          'converges and keeps the banner forever (BR-3XVWV7)',
    );
  });

  test('boot sync leaves the flag alone when the server says unverified',
      () async {
    await _seedUser(db, isEmailValidated: false);
    final activeUser = (await db.getActiveUser())!;

    final flag = await _runVerificationMirror(db, activeUser, {
      'email_verified_at': null,
    });

    expect(flag, isFalse);
    expect(
      (await db.getActiveUser())!.isEmailValidated,
      isFalse,
      reason: 'someone who genuinely has not verified must keep the banner — '
          'the flag only ever moves false -> true, and only on server say-so',
    );
  });
}
