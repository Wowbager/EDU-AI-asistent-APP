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
import 'package:eduai/data/repositories/consent_repository.dart';
import 'package:eduai/pages/auth_page.dart';
import 'package:eduai/pages/consent/age_gate_page.dart';
import 'package:eduai/pages/consent/consent_request_page.dart';

// ─────────────────────────────────────────────────────────────────────────
// test/widgets/auth_page_age_gate_test.dart already proves AuthPage calls
// onNeedsParentalConsent(country) with a stub closure. That is not the same
// claim as "the age gate is reachable in the running app": Task 14's whole
// point is wiring real call sites (root_navigator.dart, main_screen.dart) so
// something real happens after the callback fires — before this task neither
// call site passed onNeedsParentalConsent at all, so the gate could never
// actually be answered "no" and lead anywhere.
//
// root_navigator.dart's AuthWrapper is too heavy to pump directly in a
// widget test (DB bootstrap, connectivity checks, session restore all run in
// initState before it settles on AppState.auth). _AuthOrConsent below
// reproduces the exact shape of its two relevant switch cases —
// AppState.auth swapped for AppState.consentRequest — using the real
// AuthPage and real ConsentRequestPage widgets, then drives an actual
// country-confirm-then-"no" answer through it end to end.
//
// The gate is driven through the OAuth sign-in, which is where AuthPage now
// runs it: on the branch that would create the account, rather than in front
// of the login form (BR-N9Y48J) or in front of every social sign-in
// (BR-VTNTMQ). The sign-in asks the backend not to register first; the 409
// that comes back for an unknown e-mail is what opens the gate.
// ─────────────────────────────────────────────────────────────────────────

/// Answers the sign-in-only attempt the way the backend does for an e-mail
/// with no account behind it: 409, nothing created. [registered] records an
/// exchange that asked to create one — answering "no" must never reach that.
class _SignInOnlyApi implements OAuthApiPort {
  bool registered = false;

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    if ((data as Map<String, dynamic>)['allow_registration'] as bool) {
      registered = true;
      return ApiResult<T>.failure('the account must not be created');
    }
    return ApiResult<T>.failure('Tento účet zatím neexistuje.',
        statusCode: 409);
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

class _AuthOrConsent extends StatefulWidget {
  const _AuthOrConsent();

  @override
  State<_AuthOrConsent> createState() => _AuthOrConsentState();
}

class _AuthOrConsentState extends State<_AuthOrConsent> {
  bool _showConsent = false;
  String? _consentCountry;

  @override
  Widget build(BuildContext context) {
    if (_showConsent) {
      return ConsentRequestPage(
        country: _consentCountry,
        onSubmit: (_) async => const ConsentActionResult.success(),
        onEnterCode: () => setState(() => _showConsent = false),
        onBack: () => setState(() => _showConsent = false),
      );
    }

    return AuthPage(
      onEmailSubmit: (_) {},
      startInLoginMode: true,
      onOAuthSuccess: (_) {},
      onNeedsParentalConsent: (country) => setState(() {
        _consentCountry = country;
        _showConsent = true;
      }),
    );
  }
}

void main() {
  testWidgets('a real "no" answer on the age gate reaches a real ConsentRequestPage, '
      'not a stub', (tester) async {
    // Tall viewport so AuthPage/AgeGatePage render without needing scroll.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // The test-only Ahem font is wider than the real font and overflows some
    // of AuthPage's fixed-width buttons. Cosmetic and test-only — ignore,
    // mirroring test/widgets/auth_page_age_gate_test.dart.
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _SignInOnlyApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authTokenStorageProvider
              .overrideWithValue(AuthTokenStorage(prefs: prefs)),
          googleOAuthClientProvider.overrideWithValue(_FakeGoogleClient()),
          oauthRepositoryProvider.overrideWithValue(OauthRepository(api)),
        ],
        child: const MaterialApp(home: _AuthOrConsent()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Starting point: the login form, nothing consent-related mounted yet.
    expect(find.byType(AgeGatePage), findsNothing);
    expect(find.byType(ConsentRequestPage), findsNothing);

    await tester.ensureVisible(find.text(AppStrings.authGoogleLogin));
    await tester.tap(find.text(AppStrings.authGoogleLogin));
    await tester.pumpAndSettle();
    expect(find.byType(AgeGatePage), findsOneWidget);

    // Confirm SK on the country step, then answer "no" on the age step.
    await tester.tap(find.text('SK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.authContinue));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.ageGateNo));
    await tester.pumpAndSettle();

    // A real transition happened — AuthPage/AgeGatePage are fully gone and a
    // real ConsentRequestPage (its actual intro copy, not a placeholder) is
    // now on screen, carrying the confirmed country through.
    expect(find.byType(AuthPage), findsNothing);
    expect(find.byType(AgeGatePage), findsNothing);
    expect(find.byType(ConsentRequestPage), findsOneWidget);
    expect(find.text(AppStrings.consentIntroTitle), findsOneWidget);
    // …and no account was created on the way there.
    expect(api.registered, isFalse);
  });
}
