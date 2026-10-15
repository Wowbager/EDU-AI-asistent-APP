import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/network/oauth_api_port.dart';
import 'package:eduai/core/oauth/google_oauth_client.dart';
import 'package:eduai/core/oauth/oauth_clients.dart';
import 'package:eduai/core/oauth/oauth_payload.dart';
import 'package:eduai/core/oauth/oauth_provider.dart';
import 'package:eduai/core/oauth/oauth_sign_in_buttons.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/oauth_repository.dart';
import 'package:eduai/features/email_validation/data/email_validation_repository.dart';
import 'package:eduai/features/email_validation/presentation/email_verification_dialog.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/pages/consent/age_gate_page.dart';
import 'package:eduai/pages/consent/consent_request_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The registration dialog reached from the "sign up for full access" banner
// only offered email + PIN. It must offer the same SSO providers as the auth
// screen, and it must ask for the *live* session mode — not the pending
// preference, whose `true` default makes the backend skip absorbGuest and
// silently drop the guest's progress (BR-79QSEV).
//
// It also registers guests, and used to do so without ever asking their age —
// by e-mail or by provider. An unknown e-mail or provider account now meets
// the age gate before a code is sent or an account created (BR-J2WJEQ).
// ─────────────────────────────────────────────────────────────────────────────

class _FakeApi implements OAuthApiPort {
  _FakeApi({this.accountExists = true});

  /// A sign-in-only exchange for an unknown account is refused with 409,
  /// exactly as `OAuthController` does.
  final bool accountExists;
  Map<String, dynamic>? capturedBody;
  final List<bool> registrationFlags = [];

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    capturedBody = data as Map<String, dynamic>?;
    final allowRegistration =
        capturedBody!['allow_registration'] as bool? ?? true;
    registrationFlags.add(allowRegistration);
    if (!accountExists && !allowRegistration) {
      return ApiResult<T>.failure('Tento účet zatím neexistuje.',
          statusCode: 409);
    }
    return ApiResult.success(<String, dynamic>{
      'token': 'sanctum-token',
      'user': {'id': 1, 'name': 'Host', 'email': 'host@edu.ai'},
    }) as ApiResult<T>;
  }
}

/// `POST /api/email/check` and `/send-code`.
class _FakeEmailRepo extends Fake implements EmailValidationRepository {
  _FakeEmailRepo({required this.accountExists});

  final bool accountExists;
  final List<String> codesSentTo = [];

  @override
  Future<ApiResult<bool>> checkEmailExists(String email) async =>
      ApiResult.success(accountExists);

  @override
  Future<ApiResult<SendCodeResponse>> sendVerificationCode(String email) async {
    codesSentTo.add(email);
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

Future<_FakeApi> _pumpGuestDialog(
  WidgetTester tester, {
  ValueChanged<OAuthExchangeResult>? onOAuthSuccess,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  // The test-only Ahem font is much wider than the real font, so the social
  // button labels overflow the dialog's content box. Cosmetic and test-only —
  // same suppression as auth_page_legal_links_test.
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);

  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();

  final fakeApi = _FakeApi();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authTokenStorageProvider
            .overrideWithValue(AuthTokenStorage(prefs: preferences)),
        googleOAuthClientProvider.overrideWithValue(_FakeGoogleClient()),
        oauthRepositoryProvider.overrideWithValue(OauthRepository(fakeApi)),
      ],
      child: MaterialApp(
        home: Scaffold(
          // email: '' → the guest registration variant of the dialog.
          body: EmailVerificationDialog(
            email: '',
            onOAuthSuccess: onOAuthSuccess ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return fakeApi;
}

void main() {
  testWidgets('guest registration dialog offers SSO buttons', (tester) async {
    await _pumpGuestDialog(tester);
    await tester.pumpAndSettle();

    expect(find.byType(OAuthSignInButtons), findsOneWidget);
    expect(find.text(AppStrings.authGoogleLogin), findsOneWidget);
    expect(find.text(AppStrings.authMicrosoftLogin), findsOneWidget);
  });

  testWidgets(
      'dialog exchanges with the live session mode, not the pending preference',
      (tester) async {
    // Defaults in the wild: no session flag written yet (live = false) while
    // the pending preference defaults to true. The dialog must send false, or
    // the backend skips absorbGuest and the guest's courses are orphaned.
    final fakeApi = await _pumpGuestDialog(
      tester,
      prefs: const {'session_pending_shared_device': true},
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();

    expect(fakeApi.capturedBody, isNotNull);
    expect(fakeApi.capturedBody!['shared_device'], isFalse);
  });

  testWidgets('dialog reports the exchanged session to its caller',
      (tester) async {
    OAuthExchangeResult? received;
    await _pumpGuestDialog(tester, onOAuthSuccess: (r) => received = r);

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.token, 'sanctum-token');
  });

  testWidgets('dialog leaves the pending session preference untouched',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      const {'session_pending_shared_device': true},
    );
    await _pumpGuestDialog(
      tester,
      prefs: const {'session_pending_shared_device': true},
    );

    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('session_pending_shared_device'), isTrue);
  });

  group('age gate (BR-J2WJEQ)', () {
    /// Opens the guest dialog the way the banner does — as a real dialog
    /// route, which a minor's answer has to close.
    Future<void> openGuestDialog(
      WidgetTester tester, {
      required _FakeEmailRepo emailRepo,
      _FakeApi? oauthApi,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('overflowed')) return;
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authTokenStorageProvider
                .overrideWithValue(AuthTokenStorage(prefs: preferences)),
            googleOAuthClientProvider.overrideWithValue(_FakeGoogleClient()),
            oauthRepositoryProvider
                .overrideWithValue(OauthRepository(oauthApi ?? _FakeApi())),
            emailValidationRepositoryProvider.overrideWithValue(emailRepo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => EmailVerificationDialog(
                      email: '',
                      onOAuthSuccess: (_) {},
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> submitEmail(WidgetTester tester, String email) async {
      await tester.enterText(find.byType(TextField), email);
      await tester.pump();
      await tester.tap(find.text(AppStrings.actionContinue));
      await tester.pumpAndSettle();
    }

    Future<void> answer(
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

    testWidgets('a new e-mail is asked for age before a code is sent',
        (tester) async {
      final emailRepo = _FakeEmailRepo(accountExists: false);
      await openGuestDialog(tester, emailRepo: emailRepo);

      await submitEmail(tester, 'novy@edu.ai');

      expect(find.byType(AgeGatePage), findsOneWidget);
      expect(emailRepo.codesSentTo, isEmpty);

      await answer(tester, country: 'CZ', answer: AppStrings.ageGateYes);

      expect(find.byType(AgeGatePage), findsNothing);
      expect(emailRepo.codesSentTo, ['novy@edu.ai']);
    });

    testWidgets('"no" closes the dialog for the consent request, nothing sent',
        (tester) async {
      final emailRepo = _FakeEmailRepo(accountExists: false);
      await openGuestDialog(tester, emailRepo: emailRepo);

      await submitEmail(tester, 'dite@edu.ai');
      await answer(tester, country: 'SK', answer: AppStrings.ageGateNo);

      expect(find.byType(ConsentRequestPage), findsOneWidget);
      expect(find.byType(EmailVerificationDialog, skipOffstage: false),
          findsNothing);
      expect(emailRepo.codesSentTo, isEmpty);
    });

    testWidgets('an e-mail with an account gets its code, asked nothing',
        (tester) async {
      final emailRepo = _FakeEmailRepo(accountExists: true);
      await openGuestDialog(tester, emailRepo: emailRepo);

      await submitEmail(tester, 'zpet@edu.ai');

      expect(find.byType(AgeGatePage), findsNothing);
      expect(emailRepo.codesSentTo, ['zpet@edu.ai']);
    });

    testWidgets('a provider account that does not exist yet is asked first',
        (tester) async {
      final oauthApi = _FakeApi(accountExists: false);
      await openGuestDialog(
        tester,
        emailRepo: _FakeEmailRepo(accountExists: false),
        oauthApi: oauthApi,
      );

      await tester.tap(find.text(AppStrings.authGoogleLogin));
      await tester.pumpAndSettle();

      expect(find.byType(AgeGatePage), findsOneWidget);
      // Refused as a sign-in, never sent as a registration.
      expect(oauthApi.registrationFlags, [false]);
    });
  });
}
