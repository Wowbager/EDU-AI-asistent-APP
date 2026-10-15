// The sidebar's "Můj účet" block has to stay a button on the avatar editor
// (BR-NYNNM8).
//
// The reported case: on tablet/desktop the user opens Můj účet, taps "Upravit
// avatara" — which is the shop screen opened with `fromAccount` (BR-KB7XSJ) —
// and from there the account block does nothing at all, leaving the back
// button as the only way home.
//
// `DetailShell.accountActive` was doing two jobs: light the block, *and* stop
// it being a button because "this page is the profile". The avatar editor sets
// it for the highlight alone and inherited the dead tap. The two are separate
// flags now, so only `ProfilePage` — which really is that page — suppresses
// the tap.
//
//   flutter test test/widgets/account_block_from_shop_test.dart
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/navigation_providers.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/pages/profile_page.dart';
import 'package:eduai/pages/shop_page.dart';
import 'package:eduai/widgets/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A registered account — the plain case; the guest sign-up card has its own
/// suite (`pushed_shell_intent_test.dart`).
UsersTableData _user() {
  final now = DateTime(2026, 1, 1);
  return UsersTableData(
    id: 'u1',
    email: 'michal@example.com',
    name: 'Michal',
    avatarIndex: 0,
    selectedSubjects: '[0]',
    isEmailValidated: true,
    isActive: true,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// Both the sidebar's account block and the shop itself read the avatar
/// catalog. Served from memory so the test does not stand up the repository
/// behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

void main() {
  late ProviderContainer container;

  Future<void> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeUserStreamProvider.overrideWith((ref) => Stream.value(_user())),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
        minorModeProvider
            .overrideWith((ref) => MinorModeNotifier()..state = false),
        showEmailValidationBannerProvider.overrideWithValue(false),
        avatarControllerProvider.overrideWith(_StubAvatarController.new),
      ],
    );
    addTearDown(container.dispose);
  }

  /// The page as "Upravit avatara" pushes it: a route above the shell, on a
  /// desktop viewport where the sidebar is drawn at all.
  Future<void> pumpPushedPage(WidgetTester tester, Widget page) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    // The test-only Ahem font is far wider than the real one, so sidebar
    // labels overflow their rows. Cosmetic and test-only — the same
    // suppression the other sidebar suites use.
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    late BuildContext navContext;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              navContext = context;
              // Stands in for MainScreen, which is what an intent pops back to.
              return const Scaffold(body: Text('shell'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    Navigator.of(navContext).push(MaterialPageRoute(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  group('avatar editor opened from Můj účet', () {
    testWidgets('keeps the account block lit', (tester) async {
      await buildContainer();
      await pumpPushedPage(tester, const ShopPage(fromAccount: true));

      // BR-KB7XSJ: reached from the account, not from Doplňky, so the sidebar
      // says so instead of jumping to a destination the user never tapped.
      expect(tester.widget<SideNav>(find.byType(SideNav)).accountActive, isTrue);
    });

    testWidgets('leaves the account block tappable', (tester) async {
      await buildContainer();
      await pumpPushedPage(tester, const ShopPage(fromAccount: true));

      expect(
        tester.widget<SideNav>(find.byType(SideNav)).onProfileTap,
        isNotNull,
      );
    });

    testWidgets('tapping it pops back and asks for the profile',
        (tester) async {
      await buildContainer();
      await pumpPushedPage(tester, const ShopPage(fromAccount: true));

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      // MainScreen owns the profile push, so the editor pops and the intent
      // waits for the shell underneath.
      expect(find.text('shell'), findsOneWidget);
      expect(
        container.read(pendingShellIntentProvider),
        ShellIntent.openProfile,
      );
    });
  });

  group('the profile itself', () {
    testWidgets('is lit and not a button — it is already here', (tester) async {
      await buildContainer();
      await pumpPushedPage(
        tester,
        const ProfilePage(userName: 'Michal', userEmail: 'michal@example.com'),
      );

      final nav = tester.widget<SideNav>(find.byType(SideNav));
      expect(nav.accountActive, isTrue);
      expect(nav.onProfileTap, isNull);
    });
  });
}
