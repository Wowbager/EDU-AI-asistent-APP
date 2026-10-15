// The tablet/desktop sidebar owns the whole navigation (BR-KN9XUT).
//
// The top bar used to carry the XP pill, a profile chip and a row of circular
// actions next to a sidebar that listed a different set of destinations. This
// pins down what replaced it: one list, identity and XP in the sidebar, and
// Doplňky (games, avatar editor, themes) reachable without a second piece of
// chrome.
//
//   flutter test test/widgets/side_nav_destinations_test.dart
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/sync/sync_status.dart';
import 'package:eduai/data/repositories/user_stats_repository.dart';
import 'package:eduai/widgets/nav_destinations.dart';
import 'package:eduai/widgets/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UsersTableData _user({String name = 'Michal', int avatarIndex = 0}) {
  final now = DateTime(2026, 1, 1);
  return UsersTableData(
    id: 'u1',
    email: 'michal@example.com',
    name: name,
    avatarIndex: avatarIndex,
    selectedSubjects: '[0]',
    isEmailValidated: true,
    isActive: true,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpSideNav(
  WidgetTester tester, {
  int selectedIndex = 0,
  ValueChanged<int>? onItemTapped,
  ValueChanged<NavPush>? onPushTapped,
  NavPush? activePush,
  UserStats? stats,
  int unread = 0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.reset);

  // The test-only Ahem font is far wider than the real one, so sidebar labels
  // overflow their rows. Cosmetic and test-only — same suppression the other
  // shell tests use.
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeUserStreamProvider.overrideWith((ref) => Stream.value(_user())),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(stats)),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            if (unread > 0) {
              ref.read(unreadNewsCountProvider.notifier).set(unread);
            }
            return Scaffold(
              body: SideNav(
                selectedIndex: selectedIndex,
                onItemTapped: onItemTapped ?? (_) {},
                onPushTapped: onPushTapped,
                activePush: activePush,
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the row carrying [label] is drawn as the selected destination.
///
/// Selection is a filled `Material` behind the row and unselected rows are
/// transparent, so this reads the highlight the user actually sees rather than
/// a flag the widget keeps to itself. The nearest `Material` above the label is
/// the row's own — the one `InkWell` ripples into.
bool _isRowSelected(WidgetTester tester, String label) {
  final material = tester.widget<Material>(
    find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
  );

  return material.color != Colors.transparent;
}

void main() {
  test('every destination either selects a tab or pushes a page', () {
    for (final destination in navDestinations) {
      expect(
        (destination.index == null) != (destination.push == null),
        isTrue,
        reason: '${destination.label()} must do exactly one of the two',
      );
    }
  });

  // Games, the avatar editor and themes are folded into one Doplňky page, and
  // the sidebar must reach it as a destination, not a top-bar button.
  test('doplňky is a destination, not a top-bar button', () {
    final pushes = navDestinations.map((d) => d.push).whereType<NavPush>();

    expect(pushes, contains(NavPush.doplnky));
  });

  // "Notifications" in the design is Novinky — there is no separate feed, so
  // the badge must ride the destination flag rather than a hard-coded slot.
  test('exactly one destination carries the news badge', () {
    expect(navDestinations.where((d) => d.showsNewsBadge), hasLength(1));
    expect(
      navDestinations.firstWhere((d) => d.showsNewsBadge).label(),
      AppStrings.navNovinky,
    );
  });

  testWidgets('the sidebar lists doplňky', (tester) async {
    await _pumpSideNav(tester);

    expect(find.text(AppStrings.doplnkyTitle), findsOneWidget);
  });

  testWidgets('a push destination does not move the selected tab',
      (tester) async {
    final tabs = <int>[];
    final pushes = <NavPush>[];

    await _pumpSideNav(
      tester,
      onItemTapped: tabs.add,
      onPushTapped: pushes.add,
    );

    await tester.tap(find.text(AppStrings.doplnkyTitle));
    await tester.pumpAndSettle();

    expect(pushes, [NavPush.doplnky]);
    expect(
      tabs,
      isEmpty,
      reason: 'doplňky is a route; moving the tab would strand the shell on a '
          'page that is not one',
    );
  });

  // A pushed page redraws this sidebar (`DetailShell`) while the tab
  // underneath stays where the user left it. The highlight has to follow the
  // page on screen, not that leftover tab (BR-WB6EUH).
  testWidgets('an open push destination takes the highlight', (tester) async {
    await _pumpSideNav(tester, selectedIndex: 1, activePush: NavPush.doplnky);

    expect(_isRowSelected(tester, AppStrings.doplnkyTitle), isTrue);
    expect(
      _isRowSelected(tester, AppStrings.navChat),
      isFalse,
      reason: 'lighting the tab underneath as well would put the user in two '
          'places at once',
    );
  });

  testWidgets('with no push open the selected tab keeps the highlight',
      (tester) async {
    await _pumpSideNav(tester, selectedIndex: 1);

    expect(_isRowSelected(tester, AppStrings.navChat), isTrue);
    expect(_isRowSelected(tester, AppStrings.doplnkyTitle), isFalse);
  });

  testWidgets('a tab destination still selects its tab', (tester) async {
    final tabs = <int>[];

    await _pumpSideNav(tester, onItemTapped: tabs.add);

    await tester.tap(find.text(AppStrings.navKurzy));
    await tester.pumpAndSettle();

    expect(tabs, [3]);
  });

  // Name on top, XP underneath — the block the top bar's profile chip and XP
  // pill were folded into.
  testWidgets('the account block shows the name and the XP', (tester) async {
    await _pumpSideNav(
      tester,
      stats: UserStats(
        id: 's1',
        userId: 'u1',
        xpPoints: 1240,
        level: 5,
        streakDays: 3,
        coursesCount: 2,
        achievementsCount: 1,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    expect(find.text('Michal'), findsOneWidget);
    expect(find.text('1240 XP'), findsOneWidget);
    expect(find.text('5'), findsOneWidget, reason: 'level badge');
  });

  testWidgets('the account block falls back to a default name', (tester) async {
    await _pumpSideNav(tester, stats: null);

    expect(find.text('Michal'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
  });
}
