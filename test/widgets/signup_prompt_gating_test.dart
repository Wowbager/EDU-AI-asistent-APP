// Who may be told "Postup se uloží až po přihlášení." (BR-7CDXBR).
//
// The prompt appears in three places — the sidebar card, the e-mail-validation
// banner and the profile page's Log In/Log Out button — and each used to
// decide for itself with a bare `email.isEmpty`. That is wrong for two kinds
// of account that have no e-mail on purpose: a minor from a self-service
// "Samoobsluha" classroom, and any student signed in with a login code. Both
// already hold a real server-side account, so the prompt is a dead end.
//
// The first group was fixed once (BR-8FDF37) but only on the main tabs; every
// pushed page draws its sidebar through DetailShell, which kept the old test
// and kept showing the card. These pin down the shared predicate and both
// shells, so a fourth call site cannot quietly reintroduce the bug.
//
//   flutter test test/widgets/signup_prompt_gating_test.dart
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/widgets/detail_shell.dart';
import 'package:eduai/widgets/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UsersTableData _user({
  required String email,
  required bool isEmailValidated,
  String name = 'Veselý mrož',
}) {
  final now = DateTime(2026, 1, 1);
  return UsersTableData(
    id: 'u1',
    email: email,
    name: name,
    avatarIndex: 0,
    selectedSubjects: '[0]',
    isEmailValidated: isEmailValidated,
    isActive: true,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// An anonymous guest — `createGuestUser()` writes an empty e-mail and leaves
/// the validated flag false.
final _guest = _user(email: '', isEmailValidated: false);

/// A student signed in with a login code. No e-mail (the API mints classroom
/// accounts without one), but `auth_page` marks the row validated to record
/// that the server authenticated it.
final _codeStudent = _user(email: '', isEmailValidated: true);

/// Registered, e-mail not confirmed yet. Must keep every prompt.
final _unverified = _user(email: 'michal@example.com', isEmailValidated: false);

/// The sidebar's account block draws the user's own avatar (BR-D6W3CR), which
/// reads the catalog. Served from memory so the test does not stand up the
/// repository behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

void main() {
  group('canOfferSignupProvider', () {
    Future<bool> resolve({UsersTableData? user, bool isMinor = false}) async {
      final container = ProviderContainer(
        overrides: [
          activeUserStreamProvider.overrideWith((ref) => Stream.value(user)),
          minorModeProvider
              .overrideWith((ref) => MinorModeNotifier()..state = isMinor),
        ],
      );
      addTearDown(container.dispose);

      // `Stream.value` emits on the next microtask, so without this the
      // provider would still see the loading null rather than the row.
      await container.read(activeUserStreamProvider.future);
      return container.read(canOfferSignupProvider);
    }

    test('an anonymous guest is offered the sign-up prompt', () async {
      expect(await resolve(user: _guest), isTrue);
    });

    test('no local row at all counts as a guest', () async {
      expect(await resolve(user: null), isTrue);
    });

    test('a code-login student is not — they already have an account',
        () async {
      expect(await resolve(user: _codeStudent), isFalse);
    });

    test('a minor is not, whatever their local row says', () async {
      expect(await resolve(user: _guest, isMinor: true), isFalse);
      expect(await resolve(user: _codeStudent, isMinor: true), isFalse);
    });

    test('a registered but unverified user is not', () async {
      // They have an account already; their prompt is "verify your e-mail",
      // which `showEmailValidationBannerProvider` owns. This predicate is
      // only about offering *sign-up*, so it must not swallow them — the
      // banner stays because it is gated on that other provider, not this
      // one.
      expect(await resolve(user: _unverified), isFalse);
    });
  });

  group('the sidebar sign-up card', () {
    /// `AdaptiveShell` takes `isGuest` from its caller (MainScreen), so the
    /// widget that decides on its own — and the one that got it wrong — is
    /// `DetailShell`.
    Future<void> pumpDetailShell(
      WidgetTester tester, {
      required UsersTableData? user,
      bool isMinor = false,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.reset);

      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('overflowed')) return;
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeUserStreamProvider.overrideWith((ref) => Stream.value(user)),
            userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
            minorModeProvider
                .overrideWith((ref) => MinorModeNotifier()..state = isMinor),
            showEmailValidationBannerProvider.overrideWithValue(false),
            avatarControllerProvider.overrideWith(_StubAvatarController.new),
          ],
          child: MaterialApp(
            home: DetailShell(
              backLabel: AppStrings.libraryTitle,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    bool cardShown(WidgetTester tester) =>
        tester.widget<SideNav>(find.byType(SideNav)).isGuest;

    testWidgets('shows for a guest on a pushed page', (tester) async {
      await pumpDetailShell(tester, user: _guest);

      expect(cardShown(tester), isTrue);
      expect(find.text(AppStrings.shellGuestCtaButton), findsOneWidget);
    });

    testWidgets('is hidden for a code-login student on a pushed page',
        (tester) async {
      await pumpDetailShell(tester, user: _codeStudent);

      expect(cardShown(tester), isFalse);
      expect(find.text(AppStrings.shellGuestCtaButton), findsNothing);
    });

    testWidgets('is hidden for a minor on a pushed page', (tester) async {
      // The reported case: a child from a "Samoobsluha" classroom opening the
      // library from Kurzy still saw the card, because only the main tabs had
      // the guard (BR-7CDXBR).
      await pumpDetailShell(tester, user: _codeStudent, isMinor: true);

      expect(cardShown(tester), isFalse);
      expect(find.text(AppStrings.shellGuestCtaTitle), findsNothing);
    });

    testWidgets('a registered unverified user never sees it', (tester) async {
      // The card is guest-only; their prompt is the "verify your e-mail"
      // banner, which ShellBanners keeps.
      await pumpDetailShell(tester, user: _unverified);

      expect(cardShown(tester), isFalse);
    });
  });
}
