import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/navigation_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/util/markdown_link_handler.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/widgets/detail_shell.dart';
import 'package:eduai/widgets/nav_destinations.dart';
import 'package:eduai/widgets/side_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-48B7DY: opening a course through a /pin deep link left the sidebar
// highlighting "Přehled". A pushed page draws its own sidebar and reads
// [mainTabIndexProvider], which no deep-link path ever set — so the shell
// pointed at the dashboard while a course filled the screen, and the top bar's
// "Zpět na všechny kurzy" popped back to the dashboard too.
//
// Not covered here: the enroll success path itself, which needs the course
// repository, the local DB and an R2 download. Verified by hand on stage with
// /pin/<code>; the pieces below pin down the wiring around it.
// ─────────────────────────────────────────────────────────────────────────────

/// The sidebar's account block draws the user's own avatar (BR-D6W3CR), which
/// reads the catalog. Served from memory so the test does not stand up the
/// repository behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

Future<void> _pumpDetailShell(WidgetTester tester, {required int tab}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.reset);

  // The test-only Ahem font is far wider than the real one, so sidebar labels
  // overflow their rows. Cosmetic and test-only — same suppression the auth
  // breakpoint tests use.
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
        // The shell only needs these to resolve to "no user" — a widget test
        // has no business opening the local DB.
        activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        mainTabIndexProvider.overrideWith((ref) => tab),
        avatarControllerProvider.overrideWith(_StubAvatarController.new),
      ],
      child: MaterialApp(
        home: DetailShell(
          backLabel: AppStrings.courseBackToAll,
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the pushed-page sidebar highlights the Kurzy tab when selected',
      (tester) async {
    await _pumpDetailShell(tester, tab: kKurzyTabIndex);

    expect(
      tester.widget<SideNav>(find.byType(SideNav)).selectedIndex,
      kKurzyTabIndex,
    );
  });

  // The bug, stated as a test: the default tab is what the deep link used to
  // leave behind, and it is not Kurzy.
  testWidgets('a course opened with the tab untouched shows the dashboard',
      (tester) async {
    await _pumpDetailShell(tester, tab: 0);

    expect(tester.widget<SideNav>(find.byType(SideNav)).selectedIndex, 0);
  });

  // kKurzyTabIndex indexes MainScreen.pages; navDestinations carries the same
  // contract for the nav bars. If one moves without the other, the deep link
  // starts landing on whatever tab drifted into slot 3.
  test('kKurzyTabIndex is the index of the Kurzy destination', () {
    final kurzy = navDestinations
        .firstWhere((d) => d.label() == AppStrings.navKurzy);

    expect(kKurzyTabIndex, kurzy.index);
  });

  // A code that never resolves must leave the user where they were: the tab is
  // only moved after the enroll succeeds, so a mistyped PIN cannot yank the
  // shell over to Kurzy behind the error message.
  testWidgets('a failed enroll leaves the tab alone', (tester) async {
    late WidgetRef capturedRef;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    // Too short to be a join code — fails before anything touches the network.
    await openCourseByCode(
      capturedContext,
      capturedRef,
      '123',
      selectCoursesTab: true,
    );
    await tester.pump();

    expect(capturedRef.read(mainTabIndexProvider), 0);
  });
}
