// Sign-up onboarding on ProfileSetupPage.
//
// The page runs for two kinds of visitors: sign-ups (the legacy
// create-and-migrate path) and accounts the server still reports as having
// no profile. For the latter it must edit the active row in place — never
// create a second local user. Which logins reach the page at all is decided
// by loginNeedsProfileSetup (test/routing/login_destination_test.dart): a
// returning account skips it entirely (BR-D27TFA).
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/pages/profile_setup_page.dart';
import 'package:eduai/widgets/auth_hero_scaffold.dart';

const _tileSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 270.93 270.93">'
    '<rect x="100" y="100" width="70" height="40" fill="#333"/></svg>';

AvatarItem _catalogItem(String code, AvatarSlot slot, int layer,
    {bool isDefault = false, bool owned = false}) {
  return AvatarItem(
    code: code,
    name: code,
    slot: slot,
    layer: layer,
    url: 'https://r2.test/$code.svg',
    rarity: AvatarRarity.common,
    price: 0,
    isDefault: isDefault,
    owned: owned,
    svgSource: _tileSvg,
  );
}

/// Serves the vibe step a canned catalog so the tiles and the preview render
/// without any network or local avatar rows.
class _FakeAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState(
        catalog: [
          _catalogItem('torso_base', AvatarSlot.torso, 20,
              isDefault: true, owned: true),
          // The four starter accessories the vibe step is meant to offer …
          _catalogItem('face_modre_bryle', AvatarSlot.face, 32),
          _catalogItem('face_maska_skraboska', AvatarSlot.face, 32),
          _catalogItem('head_zimni_cepice', AvatarSlot.head, 40),
          _catalogItem('head_sluchatka', AvatarSlot.head, 40),
          // … and a free catalog item that must NOT leak into onboarding.
          _catalogItem('face_bryle', AvatarSlot.face, 32),
        ],
        equipped: const {AvatarSlot.torso: 'torso_base'},
      );
}

/// In-memory token so the commit path's API client never touches the
/// FlutterSecureStorage platform channel (unavailable in `flutter test`).
class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({required super.prefs});

  @override
  String? get token => 'token';
  @override
  bool get isAuthenticated => true;
  @override
  Future<void> load() async {}
}

const _userId = 'account-1';
const _email = 'student@example.com';
const _originalName = 'Původní jméno';

Future<void> _seedAccount(AppDatabase db) async {
  await db.createAndActivateUser(
    UsersTableCompanion(
      id: const Value(_userId),
      email: const Value(_email),
      name: const Value(_originalName),
      isEmailValidated: const Value(true),
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

  Future<void> pumpPage(
    WidgetTester tester, {
    required String email,
    required void Function() onComplete,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: ProfileSetupPage(email: email, onComplete: onComplete),
        ),
      ),
    );
    // Let initState's async active-user lookup land (mode + name pre-fill).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.actionContinue));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('onboarding keeps the hero scene on desktop', (tester) async {
    tester.view.physicalSize = const Size(2880, 1620);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await _seedAccount(db);
    await pumpPage(tester, email: _email, onComplete: () {});

    // The onboarding is a stop on the auth journey — same split-pane hero
    // scene, its content in the right-hand panel.
    expect(find.byKey(splitPaneKey), findsOneWidget);
    expect(find.text(AppStrings.profileSetupTitle), findsOneWidget);

    // Step 2 keeps the scene too.
    await tapContinue(tester);
    expect(find.byKey(splitPaneKey), findsOneWidget);
    expect(find.text(AppStrings.profileSetupVibeTitle), findsOneWidget);
  });

  testWidgets('onboarding keeps its plain layout on phones', (tester) async {
    tester.view.physicalSize = const Size(780, 1910);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await _seedAccount(db);
    await pumpPage(tester, email: _email, onComplete: () {});

    expect(find.byKey(splitPaneKey), findsNothing);
    expect(find.text(AppStrings.profileSetupTitle), findsOneWidget);
  });

  testWidgets('the onboarding pre-fills the nickname and walks two steps',
      (tester) async {
    await _seedAccount(db);
    await pumpPage(tester, email: _email, onComplete: () {});

    // Step 1: nickname pre-filled from the account, color profile offered.
    expect(find.text(AppStrings.profileSetupTitle), findsOneWidget);
    expect(find.text(_originalName), findsOneWidget);
    expect(find.text(AppStrings.profileSetupColorLabel), findsOneWidget);

    await tapContinue(tester);

    // Step 2: the vibe step.
    expect(find.text(AppStrings.profileSetupVibeTitle), findsOneWidget);
    expect(find.text(AppStrings.profileSetupTitle), findsNothing);
  });

  testWidgets('completing the onboarding edits the active row in place',
      (tester) async {
    await _seedAccount(db);
    var completed = false;
    await pumpPage(tester, email: _email, onComplete: () => completed = true);

    await tester.enterText(find.byType(TextField), 'Nová přezdívka');
    await tapContinue(tester); // → vibe step
    await tapContinue(tester); // → commit
    await tester.pump(const Duration(milliseconds: 200));

    expect(completed, isTrue);

    final users = await db.select(db.usersTable).get();
    expect(users, hasLength(1),
        reason: 'the onboarding must never create a second local user');
    expect(users.single.id, _userId);
    expect(users.single.name, 'Nová přezdívka');
  });

  testWidgets('finishing the onboarding queues it onto the account',
      (tester) async {
    // BR-YXVMKY: "already onboarded" is a fact of the account, not of the
    // device — otherwise the next phone, or the next cleared browser, runs
    // the whole flow again. The completion rides the sync queue so finishing
    // it offline still reaches the server, and it merges with the nickname
    // write rather than replacing it.
    await _seedAccount(db);
    await pumpPage(tester, email: _email, onComplete: () {});

    await tester.enterText(find.byType(TextField), 'Nová přezdívka');
    await tapContinue(tester); // → vibe step
    await tapContinue(tester); // → commit
    await tester.pump(const Duration(milliseconds: 200));

    final queued = await db.select(db.syncQueueTable).get();
    final users = queued.where((e) => e.tableName_ == 'users').toList();
    expect(users, hasLength(1),
        reason: 'one pending users entry, not one per field');
    final payload = jsonDecode(users.single.payload) as Map<String, dynamic>;
    expect(payload['onboarding_completed'], isTrue);
    expect(payload['name'], 'Nová přezdívka');
  });

  testWidgets(
      'vibe step offers only the four starter accessories, not the whole '
      'free catalog (BR-ZHVC94)', (tester) async {
    await _seedAccount(db);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = _FakeAuthTokenStorage(prefs: prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          authTokenStorageProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(ApiClient(tokens)),
          avatarControllerProvider.overrideWith(_FakeAvatarController.new),
        ],
        child: MaterialApp(
          home: ProfileSetupPage(email: _email, onComplete: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tapContinue(tester); // → vibe step

    // Exactly the four starters are offered, alongside the "no accessory"
    // tile — nothing else from the (all-free) catalog.
    expect(find.bySemanticsLabel(AppStrings.profileSetupVibeNone),
        findsOneWidget);
    for (final code in const [
      'face_modre_bryle',
      'face_maska_skraboska',
      'head_zimni_cepice',
      'head_sluchatka',
    ]) {
      expect(find.bySemanticsLabel(code), findsOneWidget,
          reason: '$code is a starter accessory and must be offered');
    }
    expect(find.bySemanticsLabel('face_bryle'), findsNothing,
        reason: 'a non-starter free item must not leak into onboarding');
  });

  testWidgets(
      'vibe step lists free accessories, and a purchase that cannot reach '
      'the server never blocks finishing', (tester) async {
    await _seedAccount(db);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = _FakeAuthTokenStorage(prefs: prefs);
    var completed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          authTokenStorageProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(ApiClient(tokens)),
          avatarControllerProvider.overrideWith(_FakeAvatarController.new),
        ],
        child: MaterialApp(
          home: ProfileSetupPage(
            email: _email,
            onComplete: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tapContinue(tester); // → vibe step

    // A starter accessory is offered next to the "no accessory" tile.
    expect(find.bySemanticsLabel(AppStrings.profileSetupVibeNone),
        findsOneWidget);
    final glasses = find.bySemanticsLabel('face_modre_bryle');
    expect(glasses, findsOneWidget);

    await tester.tap(glasses);
    await tester.pump();

    // Finishing tries to claim the item through the real repository, whose
    // network is blocked in tests — the failure must surface as a snackbar,
    // not stop the onboarding.
    await tapContinue(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(completed, isTrue,
        reason: 'an unreachable avatar server must never trap the user in '
            'the onboarding');
  });

  testWidgets('a login with no email handed over still updates in place',
      (tester) async {
    await _seedAccount(db);
    var completed = false;
    await pumpPage(tester, email: '', onComplete: () => completed = true);

    expect(find.text(_originalName), findsOneWidget,
        reason: 'the account\'s current name is the starting value');

    await tapContinue(tester);
    await tapContinue(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(completed, isTrue);
    final users = await db.select(db.usersTable).get();
    expect(users, hasLength(1));
    expect(users.single.id, _userId);
  });

  testWidgets(
      'a student signed in with a login code and no e-mail keeps their '
      'account through the onboarding (BR-7U6V36)', (tester) async {
    // Teacher-created student accounts carry no e-mail; auth_page marks the
    // row they log in to as a real account via isEmailValidated. The
    // onboarding used to see only the empty e-mail, re-create the row as an
    // unverified e-mail-less one — the exact shape of a guest — and so put
    // the "progress is saved only after you sign in" prompt in front of a
    // signed-in student.
    await db.createAndActivateUser(
      UsersTableCompanion(
        id: const Value(_userId),
        email: const Value(''),
        name: const Value('Jan Novák'),
        isEmailValidated: const Value(true),
        isActive: const Value(true),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    var completed = false;
    await pumpPage(tester, email: '', onComplete: () => completed = true);

    expect(find.text('Jan Novák'), findsOneWidget,
        reason: 'the account\'s current name is the starting value');

    await tester.enterText(find.byType(TextField), 'Honza');
    await tapContinue(tester); // → vibe step
    await tapContinue(tester); // → commit
    await tester.pump(const Duration(milliseconds: 200));

    expect(completed, isTrue);

    final users = await db.select(db.usersTable).get();
    expect(users, hasLength(1),
        reason: 'the onboarding must never create a second local user');
    final user = users.single;
    expect(user.id, _userId);
    expect(user.name, 'Honza');
    // Exactly what canOfferSignupProvider reads: an e-mail-less row is a
    // guest unless it is flagged as a real account.
    expect(user.email, isEmpty);
    expect(user.isEmailValidated, isTrue,
        reason: 'a login-code student must not turn into a guest');

    // The nickname travels the regular profile write with the onboarding
    // flag — not a registration with an empty e-mail the server rejects.
    final queued = await db.select(db.syncQueueTable).get();
    final userEntries = queued.where((e) => e.tableName_ == 'users').toList();
    expect(userEntries, hasLength(1));
    expect(userEntries.single.recordId, _userId);
    final payload =
        jsonDecode(userEntries.single.payload) as Map<String, dynamic>;
    expect(payload['name'], 'Honza');
    expect(payload['onboarding_completed'], isTrue);
    expect(find.text(AppStrings.profileSetupSyncWarning), findsNothing);
  });
}
