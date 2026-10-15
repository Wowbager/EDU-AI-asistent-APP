import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/widgets/adaptive_shell.dart';
import 'package:eduai/widgets/custom_bottom_nav.dart';
import 'package:eduai/widgets/desktop_top_bar.dart';
import 'package:eduai/widgets/side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/layout/breakpoints.dart';

/// The sidebar's account block draws the user's own avatar (BR-D6W3CR), which
/// reads the catalog. Served from memory so the test does not stand up the
/// repository behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

/// The shell picks the navigation chrome purely from viewport width, so these
/// assert the three branches directly — a regression here silently ships a
/// phone layout to desktop (or the reverse) and nothing else would catch it.
void main() {
  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Both read the local DB, which a widget test has no business
          // opening. The shell only needs them to resolve to "no user".
          activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
          userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
          avatarControllerProvider.overrideWith(_StubAvatarController.new),
        ],
        child: MaterialApp(
          home: AdaptiveShell(
            selectedIndex: 0,
            onItemTapped: (_) {},
            title: 'Přehled',
            subtitle: 'Podtitulek',
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('phone width keeps the bottom nav and no sidebar',
      (tester) async {
    await pumpAt(tester, kCompactMaxWidth - 1);

    expect(find.byType(CustomBottomNav), findsOneWidget);
    expect(find.byType(SideNav), findsNothing);
    expect(find.byType(DesktopTopBar), findsNothing);
  });

  testWidgets('tablet width swaps the bottom nav for a collapsed rail',
      (tester) async {
    await pumpAt(tester, kCompactMaxWidth);

    expect(find.byType(CustomBottomNav), findsNothing);
    expect(find.byType(SideNav), findsOneWidget);
    // No top bar at this width — it costs more vertical room than it gives.
    expect(find.byType(DesktopTopBar), findsNothing);
    expect(tester.widget<SideNav>(find.byType(SideNav)).expanded, isFalse);
  });

  testWidgets('desktop width expands the sidebar and adds the top bar',
      (tester) async {
    await pumpAt(tester, 1440);

    expect(find.byType(CustomBottomNav), findsNothing);
    expect(tester.widget<SideNav>(find.byType(SideNav)).expanded, isTrue);
    expect(find.byType(DesktopTopBar), findsOneWidget);
    expect(find.text('Přehled'), findsOneWidget);
    expect(find.text('Podtitulek'), findsOneWidget);
  });

  test('grid columns grow with the available width, not the screen', () {
    expect(gridColumns(400), 1);
    expect(gridColumns(700), 2);
    expect(gridColumns(1000), 3);
    expect(gridColumns(1300), 4);
  });
}
