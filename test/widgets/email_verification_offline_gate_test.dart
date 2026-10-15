import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/features/email_validation/data/email_validation_repository.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/pages/email_verification_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Offline, the verification page offers "continue without verification", which
// goes on to profile setup and creates the account on the device. Nothing could
// tell whether the address already had an account (AuthPage's check could not
// reach the server either), so that is a registration as far as the app knows,
// and it skipped the age gate — going offline was a way round the gate and the
// guardian consent flow behind it (BR-J2WJEQ).
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory token storage — the real one talks to FlutterSecureStorage, which
/// has no platform channel under `flutter test`.
class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs});

  @override
  String? get token => null;

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> load() async {}
}

class _OfflineApiClient extends ApiClient {
  _OfflineApiClient(super.tokens);

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Duration? receiveTimeout,
  }) async =>
      ApiResult.failure('offline in test', statusCode: 503);
}

/// The account check answers "no account" — only reachable in these tests
/// through an explicit [EmailVerificationNotifier.screenNewAccount] call, to
/// stand for AuthPage having asked before it went offline.
class _FakeEmailRepo extends EmailValidationRepository {
  _FakeEmailRepo({required super.apiClient, required super.database});

  int codesSent = 0;

  @override
  Future<ApiResult<bool>> checkEmailExists(String email) async =>
      ApiResult.success(false);

  @override
  Future<ApiResult<SendCodeResponse>> sendVerificationCode(String email) async {
    codesSent++;
    return ApiResult.success(const SendCodeResponse(sent: true, expiresIn: 600));
  }
}

/// Reports "offline" without touching the connectivity_plus platform channel.
class _OfflineConnectivity extends ConnectivityService {
  @override
  Future<ConnectivityState> get currentState async => ConnectivityState.offline;

  @override
  Future<bool> get isOnline async => false;
}

/// Pumps the page offline, so it opens straight onto its offline dialog.
/// Every call to the page's two callbacks is recorded in [events], in order.
Future<({List<String> events, _FakeEmailRepo repo})> _pumpOffline(
  WidgetTester tester, {
  required bool gateAnswer,
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
  final prefs = await SharedPreferences.getInstance();
  final tokens = _FakeAuthTokenStorage(prefs: prefs);
  final api = _OfflineApiClient(tokens);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = _FakeEmailRepo(apiClient: api, database: db);

  final events = <String>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        authTokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(api),
        connectivityServiceProvider.overrideWithValue(_OfflineConnectivity()),
        emailValidationRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: EmailVerificationPage(
          email: 'novy@edu.ai',
          onVerified: (needsSetup, validated) =>
              events.add('verified($needsSetup, $validated)'),
          onNewAccount: () async {
            events.add('gate');
            return gateAnswer;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (events: events, repo: repo);
}

void main() {
  testWidgets('continuing offline asks for age first', (tester) async {
    final r = await _pumpOffline(tester, gateAnswer: true);

    expect(find.text(AppStrings.emailVerificationOfflineTitle), findsOneWidget);
    await tester.tap(find.text(AppStrings.actionContinue));
    await tester.pumpAndSettle();

    expect(r.events, ['gate', 'verified(true, false)']);
    expect(r.repo.codesSent, 0);
  });

  testWidgets('a "no" (or a back-out) goes no further — no account is made',
      (tester) async {
    final r = await _pumpOffline(tester, gateAnswer: false);

    await tester.tap(find.text(AppStrings.actionContinue));
    await tester.pumpAndSettle();

    // The caller has already taken over (consent request, back to login);
    // the page must not also go on to profile setup.
    expect(r.events, ['gate']);
  });

  testWidgets('an address already asked about before going offline is not '
      'asked again', (tester) async {
    final r = await _pumpOffline(tester, gateAnswer: true);

    // AuthPage's check got through and the gate said yes, then the
    // connection dropped before the code could go out.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmailVerificationPage)),
    );
    await container
        .read(emailVerificationProvider.notifier)
        .screenNewAccount('novy@edu.ai', onNewAccount: () async => true);

    await tester.tap(find.text(AppStrings.actionContinue));
    await tester.pumpAndSettle();

    expect(r.events, ['verified(true, false)']);
  });
}
