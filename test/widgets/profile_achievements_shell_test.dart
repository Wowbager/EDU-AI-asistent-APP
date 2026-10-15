// "Můj účet" and "Úspěchy" keep the sidebar on a wide viewport (BR-5JSXBV).
//
// Both pages are pushed above `MainScreen`, and both used to render bare —
// `ContentWidth` clamped them to phone width and nothing redrew the navigation,
// so a tablet/desktop user landed on a floating column whose only way out was
// the back button, while every other pushed page (Doplňky, Obchod, Knihovna,
// kurz, lekce, chat) carried a copy of the sidebar.
//
// These pin the two halves of the fix: the chrome appears beside the content on
// a wide viewport, the page's own `PageHeader` steps aside so the heading is not
// printed twice, and the phone layout is left exactly as it was.
//
//   flutter test test/widgets/profile_achievements_shell_test.dart
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/pages/achievements_page.dart';
import 'package:eduai/pages/profile_page.dart';
import 'package:eduai/widgets/page_header.dart';
import 'package:eduai/widgets/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A registered, verified account — the plain case. Guest handling on pushed
/// pages has its own suite (`signup_prompt_gating_test.dart`).
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

/// The sidebar and the profile header both draw the user's own avatar
/// (BR-D6W3CR), which reads the catalog. Served from memory so the test does
/// not stand up the repository behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

/// 1440x900 logical — the desktop artboard, well past `kMediumMaxWidth`.
const Size _desktop = Size(1440, 900);

/// 390x844 logical — the phone artboard, under `kCompactMaxWidth`.
const Size _phone = Size(390, 844);

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  // The test-only Ahem font is far wider than the real one, so labels overflow
  // their rows. Cosmetic and test-only — same suppression the other shell tests
  // use.
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
        activeUserStreamProvider.overrideWith((ref) => Stream.value(_user())),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
        minorModeProvider.overrideWith((ref) => MinorModeNotifier()),
        showEmailValidationBannerProvider.overrideWithValue(false),
        avatarControllerProvider.overrideWith(_StubAvatarController.new),
      ],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump();
}

void main() {
  group('ProfilePage', () {
    testWidgets('draws the sidebar on a wide viewport', (tester) async {
      await _pumpPage(
        tester,
        const ProfilePage(userName: 'Michal', userEmail: 'michal@example.com'),
        size: _desktop,
      );

      expect(find.byType(SideNav), findsOneWidget);
      // DetailShell's top bar carries the title now, so the page's own header
      // (back button + "Můj účet") would be a second copy of it.
      expect(find.byType(PageHeader), findsNothing);
    });

    testWidgets('lights the account block rather than the tab underneath',
        (tester) async {
      await _pumpPage(
        tester,
        const ProfilePage(userName: 'Michal', userEmail: 'michal@example.com'),
        size: _desktop,
      );

      // The profile is the one destination that is not a row in the list, so
      // without this the sidebar would highlight whatever tab the user left.
      expect(tester.widget<SideNav>(find.byType(SideNav)).accountActive, isTrue);
    });

    testWidgets('is unchanged on a phone', (tester) async {
      await _pumpPage(
        tester,
        const ProfilePage(userName: 'Michal', userEmail: 'michal@example.com'),
        size: _phone,
      );

      expect(find.byType(SideNav), findsNothing);
      expect(find.byType(PageHeader), findsOneWidget);
    });
  });

  group('AchievementsPage', () {
    testWidgets('draws the sidebar on a wide viewport', (tester) async {
      await _pumpPage(tester, const AchievementsPage(), size: _desktop);

      expect(find.byType(SideNav), findsOneWidget);
      expect(find.byType(PageHeader), findsNothing);
    });

    testWidgets('leaves the account block alone — it is not the profile',
        (tester) async {
      await _pumpPage(tester, const AchievementsPage(), size: _desktop);

      expect(
        tester.widget<SideNav>(find.byType(SideNav)).accountActive,
        isFalse,
      );
    });

    testWidgets('is unchanged on a phone', (tester) async {
      await _pumpPage(tester, const AchievementsPage(), size: _phone);

      expect(find.byType(SideNav), findsNothing);
      expect(find.byType(PageHeader), findsOneWidget);
    });
  });
}
