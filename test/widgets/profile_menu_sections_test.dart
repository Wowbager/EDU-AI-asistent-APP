import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/pages/profile_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Účet" is the section for what the user owns: the profile, the avatar and
// the privacy settings. Doplňky is a place to go, not an account setting, so
// it belongs at the bottom under "Další" — and the avatar editor, previously
// only reachable two taps deep inside Doplňky, belongs here. BR-KB7XSJ.
// ─────────────────────────────────────────────────────────────────────────────

/// The profile header draws the user's own avatar, which reads the catalog.
/// Served from memory so the test does not stand up the repository behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  VoidCallback? onAvatarTap,
}) async {
  // Phone width, so the page renders on its own rather than inside
  // `DetailShell`'s sidebar layout; tall enough that the whole settings list
  // fits on screen, since a tap needs its row hit-testable.
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        avatarControllerProvider.overrideWith(_StubAvatarController.new),
      ],
      child: MaterialApp(
        home: ProfilePage(
          userName: 'Tester',
          userEmail: 'tester@example.com',
          onAvatarTap: onAvatarTap,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Vertical position of a row's label, which is what "above" and "below" mean
/// on this page.
double _y(WidgetTester tester, String label) =>
    tester.getTopLeft(find.text(label).first).dy;

void main() {
  testWidgets('Účet lists profile, avatar and privacy in that order',
      (tester) async {
    await _pumpProfile(tester);

    final account = _y(tester, AppStrings.profileSectionAccount);
    final editProfile = _y(tester, AppStrings.profileEditProfile);
    final editAvatar = _y(tester, AppStrings.profileEditAvatar);
    final privacy = _y(tester, AppStrings.profilePrivacy);
    final settings = _y(tester, AppStrings.profileSectionSettings);

    expect(account, lessThan(editProfile));
    expect(editProfile, lessThan(editAvatar));
    expect(editAvatar, lessThan(privacy));
    // All three sit inside Účet, i.e. above the next section's header.
    expect(privacy, lessThan(settings));
  });

  testWidgets('Doplňky moved out of Účet down into Další', (tester) async {
    await _pumpProfile(tester);

    final more = _y(tester, AppStrings.profileSectionMore);
    final doplnky = _y(tester, AppStrings.doplnkyTitle);
    final about = _y(tester, AppStrings.profileAbout);

    expect(more, lessThan(doplnky), reason: 'Doplňky must be under Další');
    expect(doplnky, lessThan(about));
  });

  testWidgets('avatar row opens the avatar editor', (tester) async {
    var taps = 0;
    await _pumpProfile(tester, onAvatarTap: () => taps++);

    await tester.tap(find.text(AppStrings.profileEditAvatar));
    await tester.pump();

    expect(taps, 1);
  });
}
