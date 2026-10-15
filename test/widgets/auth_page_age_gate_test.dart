import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/network/oauth_api_port.dart';
import 'package:eduai/core/oauth/oauth_clients.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/oauth_repository.dart';
import 'package:eduai/features/email_validation/data/email_validation_repository.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/pages/auth_page.dart';
import 'package:eduai/pages/consent/age_gate_page.dart';

// ─────────────────────────────────────────────────────────────────────────
// AgeGatePage's own behavior (country confirmation, threshold display) is
// covered in isolation by test/consent/age_gate_test.dart. This file pins
// *where* AuthPage puts that gate.
//
// It used to sit in front of the whole form: opening login/sign-up from the
// PIN screen showed it, so a returning user was asked where they live and
// whether they are over 15 every single time they signed in (BR-N9Y48J). The
// form is login and registration at once, so the gate moved onto the branch
// that actually creates an account.
//
// For OAuth that branch is not visible from the client: the exchange is
// find-or-create, so moving the gate in front of it only narrowed the bug —
// every social sign-in still asked (BR-VTNTMQ). The sign-in now asks the
// backend not to register (`allow_registration: false`); an unknown e-mail
// comes back 409 with nothing created, and only that opens the gate. The
// magic-link half lives in test/consent/registration_age_gate_test.dart.
//
// The e-mail path asked only after the code had been sent and typed in, so a
// new address went straight to the code screen like any sign-in (BR-J2WJEQ).
// It now asks the server whether the address has an account first, and an
// unknown one meets the gate before anything is sent.
// ─────────────────────────────────────────────────────────────────────────

/// The exchange endpoint. [accountExists] is the server-side fact the client
/// is trying to discover without creating anything: a sign-in-only request for
/// an unknown e-mail is refused with 409, exactly as `OAuthController` does.
class _FakeApi implements OAuthApiPort {
  _FakeApi({required this.accountExists});

  bool accountExists;
  Map<String, dynamic>? capturedBody;

  /// Every `allow_registration` value sent, in order. A `true` in here is the
  /// backend having been asked to create the account — "the gate stopped the
  /// sign-up" is only true while this holds none.
  final List<bool> registrationFlags = [];

  bool get registered => registrationFlags.contains(true);

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    capturedBody = data as Map<String, dynamic>?;
    final allowRegistration = capturedBody!['allow_registration'] as bool;
    registrationFlags.add(allowRegistration);

    if (!accountExists && !allowRegistration) {
      return ApiResult<T>.failure('Tento účet zatím neexistuje.',
          statusCode: 409);
    }
    accountExists = true;

    return ApiResult.success(<String, dynamic>{
      'token': 'sanctum-token',
      'user': {'id': 1, 'name': 'Host', 'email': 'host@edu.ai'},
    } as T);
  }
}

/// `POST /api/email/check` — the same "does this account exist" fact for the
/// e-mail form. AuthPage itself never sends a code (the verification page it
/// hands off to does), so a send here would be a bug in its own right.
class _FakeEmailRepo extends Fake implements EmailValidationRepository {
  _FakeEmailRepo({required this.accountExists});

  final bool accountExists;
  final List<String> checked = [];
  int codesSent = 0;

  @override
  Future<ApiResult<bool>> checkEmailExists(String email) async {
    checked.add(email);
    return ApiResult.success(accountExists);
  }

  @override
  Future<ApiResult<SendCodeResponse>> sendVerificationCode(String email) async {
    codesSent++;
    return ApiResult.success(const SendCodeResponse(sent: true, expiresIn: 600));
  }
}

class _FakeGoogleClient extends GoogleOAuthClient {
  _FakeGoogleClient() : super(webClientId: '');

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<OAuthClientResult?> signIn() async => OAuthClientResult(
        provider: OAuthProvider.google,
        idToken: 'google-id-token',
      );
}

Future<_FakeApi> _pumpAuthPage(
  WidgetTester tester, {
  bool startInLoginMode = false,
  bool accountExists = false,
  ValueChanged<String?>? onNeedsParentalConsent,
  ValueChanged<OAuthExchangeResult>? onOAuthSuccess,
  ValueChanged<String>? onEmailSubmit,
  _FakeEmailRepo? emailRepo,
}) async {
  // Tall viewport so bottom-of-scroll content (and the gate's own layout)
  // renders without needing to scroll it into view first.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  // The test-only Ahem font is wider than the real font and overflows some
  // of AuthPage's fixed-width buttons. Cosmetic and test-only — ignore.
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeApi = _FakeApi(accountExists: accountExists);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authTokenStorageProvider
            .overrideWithValue(AuthTokenStorage(prefs: prefs)),
        googleOAuthClientProvider.overrideWithValue(_FakeGoogleClient()),
        oauthRepositoryProvider.overrideWithValue(OauthRepository(fakeApi)),
        emailValidationRepositoryProvider.overrideWithValue(
          emailRepo ?? _FakeEmailRepo(accountExists: accountExists),
        ),
      ],
      child: MaterialApp(
        home: AuthPage(
          onEmailSubmit: onEmailSubmit ?? (_) {},
          startInLoginMode: startInLoginMode,
          onNeedsParentalConsent: onNeedsParentalConsent,
          onOAuthSuccess: onOAuthSuccess ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));

  return fakeApi;
}

/// Picks [country] on the gate's country step, confirms it, then answers the
/// age question. AuthPage never passes AgeGatePage an `initialCountry` — it
/// falls back to the real `AgeThreshold.detectCountry()`, which reads the
/// actual host/CI locale and is not guaranteed to resolve to a country the
/// gate even offers (e.g. a `en_US` test runner). So these tests must always
/// pick a country explicitly rather than rely on whatever got pre-selected,
/// exactly like a real user would when the guess is wrong or unrecognised.
Future<void> _confirmCountryAndAnswer(
  WidgetTester tester, {
  required String country,
  required String answer,
}) async {
  await tester.tap(find.text(country));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.authContinue));
  await tester.pumpAndSettle();
  await tester.tap(find.text(answer));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening login/sign-up asks nothing — signing in is not '
      'registering (BR-N9Y48J)', (tester) async {
    await _pumpAuthPage(tester, onNeedsParentalConsent: (_) {});

    expect(find.byType(AgeGatePage), findsNothing);

    await tester.ensureVisible(find.text(AppStrings.authLoginSignUp));
    await tester.tap(find.text(AppStrings.authLoginSignUp));
    await tester.pumpAndSettle();

    // Straight to the real form: the e-mail field, no questions in front of
    // it. The magic-link code is what tells login from registration apart,
    // and it has not even been sent yet at this point.
    expect(find.byType(AgeGatePage), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('signing back in with a provider asks nothing (BR-VTNTMQ)',
      (tester) async {
    OAuthExchangeResult? signedIn;
    final fakeApi = await _pumpAuthPage(
      tester,
      startInLoginMode: true,
      accountExists: true,
      onNeedsParentalConsent: (_) {},
      onOAuthSuccess: (r) => signedIn = r,
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();

    expect(find.byType(AgeGatePage), findsNothing,
        reason: 'this account passed the gate when it was made');
    expect(signedIn?.token, 'sanctum-token');
    // A single request, and it asked not to register — its refusal is the
    // only thing that would have opened the gate.
    expect(fakeApi.registrationFlags, [false]);
  });

  testWidgets('the gate runs before the account is created', (tester) async {
    final fakeApi = await _pumpAuthPage(
      tester,
      startInLoginMode: true,
      onNeedsParentalConsent: (_) {},
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();

    expect(find.byType(AgeGatePage), findsOneWidget);
    // The sign-in attempt was refused rather than turned into an account, so
    // nothing exists yet while the gate is unanswered.
    expect(fakeApi.registered, isFalse);
    expect(fakeApi.accountExists, isFalse);
  });

  testWidgets('"yes" lets the exchange through', (tester) async {
    OAuthExchangeResult? signedIn;
    final fakeApi = await _pumpAuthPage(
      tester,
      startInLoginMode: true,
      onNeedsParentalConsent: (_) {},
      onOAuthSuccess: (r) => signedIn = r,
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();
    await _confirmCountryAndAnswer(
      tester,
      country: 'CZ',
      answer: AppStrings.ageGateYes,
    );

    expect(find.byType(AgeGatePage), findsNothing);
    // Refused sign-in, then the exchange that actually creates the account.
    expect(fakeApi.registrationFlags, [false, true]);
    expect(signedIn?.token, 'sanctum-token');
  });

  testWidgets('"no" hands off to the consent flow and creates no account',
      (tester) async {
    String? consentCountry;
    OAuthExchangeResult? signedIn;
    final fakeApi = await _pumpAuthPage(
      tester,
      startInLoginMode: true,
      onNeedsParentalConsent: (c) => consentCountry = c,
      onOAuthSuccess: (r) => signedIn = r,
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();
    await _confirmCountryAndAnswer(
      tester,
      country: 'SK',
      answer: AppStrings.ageGateNo,
    );

    expect(consentCountry, 'SK');
    expect(fakeApi.registered, isFalse);
    expect(fakeApi.accountExists, isFalse);
    expect(signedIn, isNull);
    expect(find.byType(AgeGatePage), findsNothing);
  });

  testWidgets('backing out of the gate abandons the sign-in', (tester) async {
    final fakeApi = await _pumpAuthPage(
      tester,
      startInLoginMode: true,
      onNeedsParentalConsent: (_) {},
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();
    expect(find.byType(AgeGatePage), findsOneWidget);

    // The gate's own back arrow, on its first (country) step.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(AgeGatePage), findsNothing);
    expect(fakeApi.registered, isFalse);
    // Back on the form, free to try again — and a second attempt asks again,
    // since the gate's answer is never persisted.
    expect(find.text(AppStrings.authGoogleLogin), findsOneWidget);
    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();
    expect(find.byType(AgeGatePage), findsOneWidget);
    expect(find.text(AppStrings.authContinue), findsOneWidget); // country step
    expect(find.text(AppStrings.ageGateYes), findsNothing); // not the age step
  });

  testWidgets('a caller with no consent flow registers without a dead-end gate',
      (tester) async {
    OAuthExchangeResult? signedIn;
    // onNeedsParentalConsent null: nothing to hand a minor off to, so
    // _ageGateBeforeOAuth waves the registration through rather than showing a
    // gate whose "no" answer would go nowhere.
    final fakeApi = await _pumpAuthPage(
      tester,
      startInLoginMode: true,
      onOAuthSuccess: (r) => signedIn = r,
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();

    expect(find.byType(AgeGatePage), findsNothing);
    expect(signedIn?.token, 'sanctum-token');
    expect(fakeApi.registrationFlags, [false, true]);
  });

  group('e-mail (BR-J2WJEQ)', () {
    Future<void> submitEmail(WidgetTester tester, String email) async {
      await tester.enterText(find.byType(TextField), email);
      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.authLogin));
      await tester.pumpAndSettle();
    }

    testWidgets('a new e-mail is asked for age before any code is sent',
        (tester) async {
      String? submitted;
      final emailRepo = _FakeEmailRepo(accountExists: false);
      await _pumpAuthPage(
        tester,
        startInLoginMode: true,
        onNeedsParentalConsent: (_) {},
        onEmailSubmit: (e) => submitted = e,
        emailRepo: emailRepo,
      );

      await submitEmail(tester, 'novy@edu.ai');

      expect(emailRepo.checked, ['novy@edu.ai']);
      expect(find.byType(AgeGatePage), findsOneWidget);
      // Not handed on to the verification page, which is what sends the code.
      expect(submitted, isNull);
      expect(emailRepo.codesSent, 0);
    });

    testWidgets('"yes" goes on to the code', (tester) async {
      String? submitted;
      await _pumpAuthPage(
        tester,
        startInLoginMode: true,
        onNeedsParentalConsent: (_) {},
        onEmailSubmit: (e) => submitted = e,
      );

      await submitEmail(tester, 'novy@edu.ai');
      await _confirmCountryAndAnswer(
        tester,
        country: 'CZ',
        answer: AppStrings.ageGateYes,
      );

      expect(find.byType(AgeGatePage), findsNothing);
      expect(submitted, 'novy@edu.ai');
    });

    testWidgets('"no" hands off to the consent flow and sends nothing',
        (tester) async {
      String? submitted;
      String? consentCountry;
      await _pumpAuthPage(
        tester,
        startInLoginMode: true,
        onNeedsParentalConsent: (c) => consentCountry = c,
        onEmailSubmit: (e) => submitted = e,
      );

      await submitEmail(tester, 'dite@edu.ai');
      await _confirmCountryAndAnswer(
        tester,
        country: 'SK',
        answer: AppStrings.ageGateNo,
      );

      expect(consentCountry, 'SK');
      expect(submitted, isNull);
    });

    testWidgets('backing out of the gate stays on the form, nothing sent',
        (tester) async {
      String? submitted;
      await _pumpAuthPage(
        tester,
        startInLoginMode: true,
        onNeedsParentalConsent: (_) {},
        onEmailSubmit: (e) => submitted = e,
      );

      await submitEmail(tester, 'novy@edu.ai');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(AgeGatePage), findsNothing);
      expect(submitted, isNull);
      expect(find.widgetWithText(ElevatedButton, AppStrings.authLogin),
          findsOneWidget);
    });

    testWidgets('an e-mail with an account goes straight to its code',
        (tester) async {
      String? submitted;
      await _pumpAuthPage(
        tester,
        startInLoginMode: true,
        accountExists: true,
        onNeedsParentalConsent: (_) {},
        onEmailSubmit: (e) => submitted = e,
      );

      await submitEmail(tester, 'zpet@edu.ai');

      expect(find.byType(AgeGatePage), findsNothing,
          reason: 'this account passed the gate when it was made');
      expect(submitted, 'zpet@edu.ai');
    });
  });
}
