// Sidebar polish from the desktop-review feedback: the account block (name +
// XP) closes the sidebar — the settings/logout icon pair underneath it is
// gone, because the cog only reopened the profile the account block already
// opens, and logout lives at the bottom of that profile (BR-ATWZK8). A guest
// must also not read "Postup se uloží až po přihlášení." twice — once in the
// e-mail banner and again in the sidebar's register card right below it.
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/widgets/adaptive_shell.dart';
import 'package:eduai/widgets/nav_destinations.dart';
import 'package:eduai/widgets/shell_banners.dart';
import 'package:eduai/widgets/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The account block draws the user's own avatar (BR-D6W3CR), which reads the
/// catalog. Served from memory so the test does not stand up the repository
/// behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

void main() {
  Future<void> pumpShell(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
          userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
          avatarControllerProvider.overrideWith(_StubAvatarController.new),
        ],
        child: MaterialApp(
          home: AdaptiveShell(
            selectedIndex: 0,
            onItemTapped: (_) {},
            title: 'Titulek',
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the account block closes the sidebar, with nothing beneath it',
      (tester) async {
    await pumpShell(tester, 1440);

    final accountY =
        tester.getTopLeft(find.text(AppStrings.defaultUserName)).dy;
    final lastNavY = tester
        .getTopLeft(find.text(navDestinations.last.label()).first)
        .dy;

    expect(accountY, greaterThan(lastNavY),
        reason: 'identity sits below the navigation list');
    // The settings cog and the logout button are gone: the cog only reopened
    // the profile that the account block opens, and logout is at the bottom
    // of that profile.
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.byIcon(Icons.logout_rounded), findsNothing);
    expect(find.bySemanticsLabel(AppStrings.profileSectionSettings),
        findsNothing);
    expect(find.bySemanticsLabel(AppStrings.profileLogout), findsNothing);
    // What is left has to read as a control, so it keeps a chevron and the
    // "My account" label rather than being a bare avatar.
    // The block merges into one node, so its label carries the name and the XP
    // line after "My account" — match the prefix rather than the whole string.
    expect(find.bySemanticsLabel(RegExp(AppStrings.profileTitle)),
        findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.chevron_right_rounded)).dy,
      closeTo(accountY + 8, 12),
      reason: 'the chevron belongs on the account row itself',
    );
  });

  testWidgets('the tablet rail drops the actions too', (tester) async {
    await pumpShell(tester, 700);

    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.byIcon(Icons.logout_rounded), findsNothing);
  });

  group('guest register banner', () {
    Future<void> pumpBanners(WidgetTester tester, double width) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // A guest: no active user row at all.
            activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
            showEmailValidationBannerProvider.overrideWithValue(true),
            minorModeProvider
                .overrideWith((ref) => MinorModeNotifier()..state = false),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShellBanners(onLogout: () {})),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('is suppressed on desktop, where the sidebar card carries it',
        (tester) async {
      await pumpBanners(tester, 1440);

      expect(find.text(AppStrings.bannerGuestMessage), findsNothing);
    });

    testWidgets('stays on a phone, which has no sidebar card', (tester) async {
      await pumpBanners(tester, 390);

      expect(find.text(AppStrings.bannerGuestMessage), findsOneWidget);
    });
  });

  // The sidebar's bottom stack (notices, guest card, account block) used to be
  // fixed-height, so every pixel it wanted came out of the destination list —
  // on a 802px-tall browser window with the shared-device strip showing, the
  // last destination fell below the fold (BR-3APJQC). The guest card is the
  // one piece there that can afford to give way.
  group('guest card gives way to the destinations', () {
    /// Pumps the sidebar alone at [height], with a stand-in for the notices
    /// the shell hands it — 48px is the two-line shared-device strip.
    Future<void> pumpSideNav(
      WidgetTester tester,
      double height, {
      bool withNotices = true,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(1460, height);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
            userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
            avatarControllerProvider.overrideWith(_StubAvatarController.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SideNav(
                    selectedIndex: 0,
                    onItemTapped: (_) {},
                    isGuest: true,
                    notices: withNotices
                        ? Container(height: 48, color: Colors.orange)
                        : null,
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
      );
      // The measured heights land on the next frame.
      await tester.pump();
      await tester.pump();
    }

    double navOverflow(WidgetTester tester) {
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
      return scrollable.controller?.position.maxScrollExtent ?? 0;
    }

    testWidgets('every destination stays in view on a laptop window',
        (tester) async {
      // 1460x802 is the viewport the bug was reported from.
      await pumpSideNav(tester, 802);

      expect(navOverflow(tester), 0,
          reason: 'the destination list must not need scrolling');
      expect(find.text(navDestinations.last.label()), findsOneWidget);
    });

    testWidgets('keeps the full illustration when there is room',
        (tester) async {
      await pumpSideNav(tester, 1000);

      expect(navOverflow(tester), 0);
      expect(tester.getSize(find.byType(Image).first).height, 88,
          reason: 'a tall window pays for the full card');
    });

    testWidgets('drops the illustration rather than the destinations',
        (tester) async {
      await pumpSideNav(tester, 700);

      expect(navOverflow(tester), 0);
      expect(find.text(AppStrings.shellGuestCtaButton), findsOneWidget,
          reason: 'the card shrinks but never loses its call to action');
    });

    testWidgets('gives the illustration back when the notice clears',
        (tester) async {
      await pumpSideNav(tester, 802);
      final withNotice = tester.getSize(find.byType(Image).first).height;

      // "This is my device" clears the shared-device strip.
      await pumpSideNav(tester, 802, withNotices: false);
      final withoutNotice = tester.getSize(find.byType(Image).first).height;

      expect(withoutNotice, greaterThan(withNotice),
          reason: 'the freed height goes back into the card');
    });

    testWidgets('survives a window too short for everything', (tester) async {
      await pumpSideNav(tester, 420);

      expect(tester.takeException(), isNull,
          reason: 'the list scrolls instead of overflowing');
      expect(find.text(AppStrings.shellGuestCtaButton), findsOneWidget);
    });
  });
}
