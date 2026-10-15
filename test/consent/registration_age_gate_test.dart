// The age gate used to sit in front of the whole login form, so every
// returning user was asked where they live and whether they are over 15
// before they could type their e-mail (BR-N9Y48J). The form is login and
// registration at once — the magic-link code is what tells the two apart — so
// the gate belongs on the branch that actually creates an account.
//
// These tests pin that branch inside EmailVerificationNotifier.verifyCode:
// the `onNewAccount` hook is consulted when, and only when, the verified
// e-mail has no account behind it, and answering "no" leaves nothing created.
//
// Asking only after the code, though, meant a new e-mail went straight to the
// code screen like any sign-in, with no age question in sight (BR-J2WJEQ).
// screenNewAccount now asks the server first, before anything is sent, and
// verifyCode's hook is left as the fallback for when that check fails.
//
// AuthWrapper itself cannot be pumped in a widget test (its InactivityWatcher
// deadlocks flutter_test's teardown — see root_navigator_minor_test.dart), so
// the navigator's own wiring of this hook to the gate route is not covered
// here. The decision this file guards is the one that used to be wrong.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/features/email_validation/data/email_validation_repository.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';

/// In-memory token storage — the real one talks to FlutterSecureStorage,
/// which has no platform channel under `flutter test`.
class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs});

  String? _fakeToken;

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

/// Serves the /api/user profile the "existing account" branch fetches after
/// the code check hands it a token. Everything else fails, which is fine —
/// nothing else is reached here.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.tokens);

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    if (path == '/api/user') {
      return ApiResult.success(<String, dynamic>{
        'id': 7,
        'name': 'Vrátivší se',
        'email': 'zpet@edu.ai',
        'avatar_index': 0,
        'selected_subjects': <String>[],
      } as T, statusCode: 200);
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

/// Stands in for `POST /api/email/verify`. A token in the response is the
/// server saying "this e-mail already has an account"; its absence is
/// `user_exists: false`, i.e. continuing would register.
///
/// Also `POST /api/email/check`, the same fact asked before any code is sent.
class _FakeEmailRepo extends EmailValidationRepository {
  _FakeEmailRepo({required super.apiClient, required super.database});

  String? tokenToReturn;

  /// What the account check answers. Null fails the request, the way an
  /// offline or erroring server does.
  bool? accountExists = false;

  /// Every address a code was mailed to.
  final List<String> codesSentTo = [];

  @override
  Future<ApiResult<bool>> checkEmailExists(String email) async =>
      accountExists == null
          ? ApiResult.failure('offline in test', statusCode: 503)
          : ApiResult.success(accountExists!);

  @override
  Future<ApiResult<SendCodeResponse>> sendVerificationCode(String email) async {
    codesSentTo.add(email);
    return ApiResult.success(const SendCodeResponse(sent: true, expiresIn: 600));
  }

  @override
  Future<ApiResult<VerifyCodeResponse>> verifyCode(
    String email,
    String code, {
    bool sharedDevice = false,
  }) async =>
      ApiResult.success(VerifyCodeResponse(valid: true, token: tokenToReturn));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late _FakeEmailRepo repo;

  Future<void> build({String? token}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = _FakeAuthTokenStorage(prefs: prefs);
    final api = _FakeApiClient(tokens);

    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _FakeEmailRepo(apiClient: api, database: db)..tokenToReturn = token;

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      authTokenStorageProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(api),
      emailValidationRepositoryProvider.overrideWithValue(repo),
    ]);
  }

  tearDown(() async {
    // A successful verification kicks off post-login work (force sync, cache
    // refreshes) that outlives verifyCode. Let it settle before the container
    // and the database are torn out from under it.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container.dispose();
    await db.close();
  });

  test('signing into an existing account never reaches the gate', () async {
    await build(token: 'sanctum-token');
    final notifier = container.read(emailVerificationProvider.notifier);
    await notifier.sendCode('zpet@edu.ai');

    var asked = false;
    final ok = await notifier.verifyCode(
      '123456',
      onNewAccount: () async {
        asked = true;
        return true;
      },
    );

    expect(ok, isTrue);
    expect(asked, isFalse, reason: 'a returning user is not registering');
    expect(container.read(emailVerificationProvider),
        isA<EmailVerificationSuccess>());
  });

  test('a verified e-mail with no account behind it asks first', () async {
    await build(); // no token → user_exists: false
    final notifier = container.read(emailVerificationProvider.notifier);
    await notifier.sendCode('novy@edu.ai');

    var asked = 0;
    final ok = await notifier.verifyCode(
      '123456',
      onNewAccount: () async {
        asked++;
        return true;
      },
    );

    expect(asked, 1);
    expect(ok, isTrue);
    final state = container.read(emailVerificationProvider);
    expect(state, isA<EmailVerificationSuccess>());
    expect((state as EmailVerificationSuccess).isNewUser, isTrue);
  });

  test('answering "no" leaves no account behind', () async {
    await build(); // no token → registration
    final notifier = container.read(emailVerificationProvider.notifier);
    await notifier.sendCode('dite@edu.ai');

    final ok = await notifier.verifyCode(
      '123456',
      onNewAccount: () async => false,
    );

    expect(ok, isFalse);
    // Not a success state: the caller (guardian consent) took over, and the
    // verification screen must not fall through into profile setup.
    expect(container.read(emailVerificationProvider),
        isA<EmailVerificationInitial>());
    // And nothing was written locally — no half-made account to sign into.
    expect(await db.getActiveUser(), isNull);
  });

  test('the hook is optional — callers without a consent flow still register',
      () async {
    await build();
    final notifier = container.read(emailVerificationProvider.notifier);
    await notifier.sendCode('bezhooku@edu.ai');

    expect(await notifier.verifyCode('123456'), isTrue);
  });

  group('before the code is sent (BR-J2WJEQ)', () {
    test('an e-mail with an account goes on to its code, asked nothing',
        () async {
      await build(token: 'sanctum-token');
      repo.accountExists = true;
      final notifier = container.read(emailVerificationProvider.notifier);

      var asked = 0;
      final proceed = await notifier.screenNewAccount(
        'zpet@edu.ai',
        onNewAccount: () async {
          asked++;
          return true;
        },
      );

      expect(proceed, isTrue);
      expect(asked, 0, reason: 'signing in is not registering');
    });

    test('an unknown e-mail meets the gate before anything is sent', () async {
      await build();
      final notifier = container.read(emailVerificationProvider.notifier);

      int? codesWhenAsked;
      final proceed = await notifier.screenNewAccount(
        'dite@edu.ai',
        onNewAccount: () async {
          codesWhenAsked = repo.codesSentTo.length;
          return false; // under age — consent flow takes over
        },
      );

      expect(codesWhenAsked, 0, reason: 'the gate comes first');
      expect(proceed, isFalse);
      expect(repo.codesSentTo, isEmpty);
      expect(container.read(emailVerificationProvider),
          isA<EmailVerificationInitial>());
    });

    test('an e-mail screened before its code is not asked again after it',
        () async {
      await build(); // no token → registration
      final notifier = container.read(emailVerificationProvider.notifier);

      var asked = 0;
      Future<bool> gate() async {
        asked++;
        return true;
      }

      // Capitalised the way a phone keyboard likes to, then typed plainly —
      // still the same address.
      expect(await notifier.screenNewAccount('Novy@Edu.ai', onNewAccount: gate),
          isTrue);
      await notifier.sendCode('novy@edu.ai');
      expect(await notifier.verifyCode('123456', onNewAccount: gate), isTrue);

      expect(asked, 1);
      expect(repo.codesSentTo, ['novy@edu.ai']);
      final state = container.read(emailVerificationProvider);
      expect((state as EmailVerificationSuccess).isNewUser, isTrue);
    });

    test('a failed check lets the code through and asks after it instead',
        () async {
      await build();
      repo.accountExists = null;
      final notifier = container.read(emailVerificationProvider.notifier);

      var asked = 0;
      Future<bool> gate() async {
        asked++;
        return true;
      }

      expect(await notifier.screenNewAccount('novy@edu.ai', onNewAccount: gate),
          isTrue);
      expect(asked, 0, reason: 'nothing known yet to ask about');

      await notifier.sendCode('novy@edu.ai');
      await notifier.verifyCode('123456', onNewAccount: gate);
      expect(asked, 1, reason: 'the registration branch still gates');
    });

    test('screening one e-mail does not wave another one through', () async {
      await build();
      final notifier = container.read(emailVerificationProvider.notifier);

      var asked = 0;
      Future<bool> gate() async {
        asked++;
        return true;
      }

      await notifier.screenNewAccount('prvni@edu.ai', onNewAccount: gate);
      await notifier.sendCode('druhy@edu.ai');
      await notifier.verifyCode('123456', onNewAccount: gate);

      expect(asked, 2);
    });
  });
}
