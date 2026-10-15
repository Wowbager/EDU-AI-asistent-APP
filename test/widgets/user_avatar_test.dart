// The user's own avatar shows up next to their name (BR-D6W3CR).
//
// The dress-up avatar (BR-7JRBCN) was only ever drawn where it is *authored* —
// the shop and the onboarding picker. Every surface that prints the user's
// name kept drawing the legacy `avatarIndex` emoji, which nothing in the app
// lets the user pick, so the figure they had assembled appeared nowhere near
// their name.
//
// These pin the three surfaces the report named — the sidebar's account block,
// the profile header, and the edit-profile form — plus the fallback, because a
// circle that renders empty while the catalog resolves would be a regression of
// its own.
//
//   flutter test test/widgets/user_avatar_test.dart
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/pages/edit_profile_page.dart';
import 'package:eduai/pages/profile_page.dart';
import 'package:eduai/widgets/adaptive_shell.dart';
import 'package:eduai/widgets/avatar_view.dart';
import 'package:eduai/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal but renderable layer — [AvatarView] draws whatever `svgSource`
/// holds.
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 270.93 270.93">'
    '<rect width="270.93" height="270.93" fill="#c792ea"/></svg>';

const _torso = AvatarItem(
  code: 'torso_base',
  name: 'torso_base',
  slot: AvatarSlot.torso,
  layer: 20,
  url: 'https://r2.test/torso_base.svg',
  rarity: AvatarRarity.common,
  price: 0,
  isDefault: true,
  owned: true,
  svgSource: _svg,
);

/// Wearing something, so there is a composed figure to draw.
const _dressed = AvatarState(
  catalog: [_torso],
  equipped: {AvatarSlot.torso: 'torso_base'},
);

/// A fresh account: the catalog is known, nothing is worn.
const _bare = AvatarState(catalog: [_torso], equipped: {});

/// Serves a fixed outfit — the widget only reads, so nothing else is needed.
class _FakeAvatarController extends AvatarController {
  _FakeAvatarController(this._value);

  final AvatarState _value;

  @override
  Future<AvatarState> build() async => _value;
}

/// `avatarIndex: 3` is the frog — the slot the reporter's account sits in, and
/// the emoji that was being drawn instead of their avatar.
UsersTableData _user() {
  final now = DateTime(2026, 1, 1);
  return UsersTableData(
    id: 'u1',
    email: 'marek@example.com',
    name: 'Marek',
    avatarIndex: 3,
    selectedSubjects: '[0]',
    isEmailValidated: true,
    isActive: true,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// 1440x900 logical — wide enough for the sidebar's expanded account block.
const Size _desktop = Size(1440, 900);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  AvatarState avatar = const AvatarState(catalog: [], equipped: {}),
  Size size = const Size(390, 844),
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
        avatarControllerProvider
            .overrideWith(() => _FakeAvatarController(avatar)),
      ],
      child: MaterialApp(home: page),
    ),
  );
  // Two frames: the overridden async notifier resolves on the first.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('UserAvatar', () {
    testWidgets('draws the composed avatar once an outfit resolves',
        (tester) async {
      await _pump(
        tester,
        const Center(child: UserAvatar(size: 72, avatarIndex: 3)),
        avatar: _dressed,
      );

      expect(find.byType(AvatarView), findsOneWidget);
      // The emoji is the fallback, not a second avatar drawn alongside it.
      expect(find.text('\u{1F438}'), findsNothing);
    });

    testWidgets('falls back to the legacy emoji with nothing worn',
        (tester) async {
      await _pump(
        tester,
        const Center(child: UserAvatar(size: 72, avatarIndex: 3)),
        avatar: _bare,
      );

      expect(find.byType(AvatarView), findsNothing);
      expect(find.text('\u{1F438}'), findsOneWidget);
    });

    testWidgets('keeps the circle filled while the catalog is still loading',
        (tester) async {
      await _pump(
        tester,
        const Center(child: UserAvatar(size: 72, avatarIndex: 3)),
      );

      expect(find.text('\u{1F438}'), findsOneWidget);
    });
  });

  group('the surfaces that print the name', () {
    testWidgets('the sidebar account block draws it', (tester) async {
      await _pump(
        tester,
        AdaptiveShell(
          selectedIndex: 0,
          onItemTapped: (_) {},
          title: 'Titulek',
          child: const SizedBox.shrink(),
        ),
        avatar: _dressed,
        size: _desktop,
      );

      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.byType(AvatarView), findsOneWidget);
    });

    testWidgets('the profile header draws it', (tester) async {
      await _pump(
        tester,
        const ProfilePage(
          userName: 'Marek',
          userEmail: 'marek@example.com',
          avatarIndex: 3,
        ),
        avatar: _dressed,
      );

      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.byType(AvatarView), findsOneWidget);
    });

    testWidgets('the edit-profile form draws it', (tester) async {
      await _pump(
        tester,
        const EditProfilePage(
          userName: 'Marek',
          userEmail: 'marek@example.com',
        ),
        avatar: _dressed,
      );

      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.byType(AvatarView), findsOneWidget);
    });
  });
}
