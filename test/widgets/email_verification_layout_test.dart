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
import 'package:eduai/features/email_validation/data/email_validation_repository.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/pages/email_verification_page.dart';
import 'package:eduai/widgets/auth_hero_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-V4YWYF: the email-verification step still used the retired raster
// `login_bg.png` + bare wordmark while the login screen had moved to the shared
// hero scene. These pin it to the same scaffold the login screen uses — the
// compact hero + vector wave on phones, the split-pane on wide windows — so the
// two graphics cannot drift apart again.
//
// Structural assertions rather than goldens, matching auth_page_breakpoints_test.
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

/// Nothing here reaches the network — the code send is faked at the repo.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.tokens);

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

/// `POST /api/email/verify` sends the code straight to "sent", so the page
/// settles into its code-entry state without a network call or the offline
/// dialog.
class _FakeEmailRepo extends EmailValidationRepository {
  _FakeEmailRepo({required super.apiClient, required super.database});

  @override
  Future<ApiResult<SendCodeResponse>> sendVerificationCode(String email) async =>
      ApiResult.success(const SendCodeResponse(sent: true, expiresIn: 600));
}

/// Reports "online" without touching the connectivity_plus platform channel,
/// which is absent under `flutter test`.
class _FakeConnectivity extends ConnectivityService {
  @override
  Future<ConnectivityState> get currentState async => ConnectivityState.wifi;

  @override
  Future<bool> get isOnline async => true;
}

Future<void> _pumpAt(WidgetTester tester, Size logicalSize) async {
  const dpr = 2.0;
  tester.view.physicalSize = logicalSize * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = const FakeViewPadding(top: 47 * dpr);
  addTearDown(tester.view.reset);

  // The test-only Ahem font overflows caps; cosmetic, same suppression the
  // auth-layout test uses.
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final tokens = _FakeAuthTokenStorage(prefs: prefs);
  final api = _FakeApiClient(tokens);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        authTokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(api),
        connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
        emailValidationRepositoryProvider.overrideWithValue(
          _FakeEmailRepo(apiClient: api, database: db),
        ),
      ],
      child: MaterialApp(
        home: EmailVerificationPage(
          email: 'student@example.com',
          onVerified: (_, _) {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Any raster logo/background. The auth journey is vector-only now, so catching
/// an `Image` at all means the old `login_bg.png` (or a raster mark) crept back.
final Finder _rasterAsset = find.byWidgetPredicate(
  (w) => w is Image && w.image is AssetImage,
);

void main() {
  testWidgets('phone shows the compact hero, wave and no raster background',
      (tester) async {
    await _pumpAt(tester, const Size(390, 844));

    expect(find.byKey(compactSceneKey), findsOneWidget);
    expect(find.byKey(compactWordmarkKey), findsOneWidget);
    expect(find.byKey(waveKey), findsOneWidget);
    expect(_rasterAsset, findsNothing);
    // Sheet layout, not the split-pane, on a phone.
    expect(find.byKey(splitPaneKey), findsNothing);
  });

  testWidgets('desktop switches to the split-pane hero scene', (tester) async {
    await _pumpAt(tester, const Size(1440, 810));

    expect(find.byKey(splitPaneKey), findsOneWidget);
    expect(find.byKey(sceneKey), findsOneWidget);
    expect(_rasterAsset, findsNothing);
    // The phone-only compact hero must stay out of the wide layout.
    expect(find.byKey(compactSceneKey), findsNothing);
  });
}
