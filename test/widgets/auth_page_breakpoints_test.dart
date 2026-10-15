import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/layout/breakpoints.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/consent_repository.dart';
import 'package:eduai/pages/auth_page.dart';
import 'package:eduai/pages/consent/age_gate_page.dart';
import 'package:eduai/pages/consent/consent_request_page.dart';
import 'package:eduai/widgets/auth_hero_scaffold.dart';
import 'package:eduai/widgets/language_switcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-UWJD4M removed the global 640px clamp and gave the login screen a
// split-pane layout on wide windows. These assert the layout actually switches
// at the breakpoint, and that phones are left alone.
//
// Structural assertions rather than goldens: golden files drift with font
// rendering across machines and CI, and the repo has no golden infrastructure.
// ─────────────────────────────────────────────────────────────────────────────

/// Pumps the auth page at a given *logical* viewport size.
///
/// [topPadding] is the logical status-bar inset. It defaults to 0 — only the
/// compact-hero tests care, since that is the edge the composition must not
/// slide under.
Future<void> _pumpAt(
  WidgetTester tester,
  Size logicalSize, {
  double topPadding = 0,
  bool startInLoginMode = false,
}) async {
  const dpr = 2.0;
  tester.view.physicalSize = logicalSize * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(top: topPadding * dpr);
  addTearDown(tester.view.reset);

  // The test-only Ahem font is far wider than the real one, so labels overflow
  // their caps. Cosmetic and test-only — same suppression as the legal-links test.
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
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: AuthPage(
          // The flag is only read in initState, and pumping twice in one test
          // reuses the State — key it so a second pump really restarts.
          key: ValueKey(startInLoginMode),
          onEmailSubmit: (_) {},
          startInLoginMode: startInLoginMode,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Finder for any raster logo. The sheet layout dropped the character logo in
/// BR-W5HNHB and BR-HN5YU4 retired the asset itself, so branding here is vector
/// only — catching an `Image` at all now means a raster mark crept back in.
final Finder _rasterLogo = find.byWidgetPredicate(
  (w) => w is Image && w.image is AssetImage,
);

void main() {
  group('authPanelWidth', () {
    test('matches the 48% design ratio at the 1440px artboard', () {
      expect(authPanelWidth(1440), closeTo(691.2, 0.01));
    });

    test('is clamped so a wide monitor does not outgrow the design', () {
      expect(authPanelWidth(1920), 720);
      expect(authPanelWidth(3360), 720);
    });

    test('keeps the hero pane usable at the expanded threshold', () {
      // 900 × 0.48 = 432, above the 420 floor, leaving 468 for the hero.
      expect(authPanelWidth(900), 432);
      expect(authPanelWidth(600), 420);
    });
  });

  group('WidthClass', () {
    Future<WidthClass> classAt(WidgetTester tester, double width) async {
      late WidthClass result;
      tester.view.physicalSize = Size(width * 2, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = context.widthClass;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('phone width is compact', (tester) async {
      expect(await classAt(tester, 390), WidthClass.compact);
      expect(await classAt(tester, 599), WidthClass.compact);
    });

    testWidgets('portrait tablet is medium, not split-pane', (tester) async {
      expect(await classAt(tester, 600), WidthClass.medium);
      expect(await classAt(tester, 834), WidthClass.medium);
      expect(await classAt(tester, 899), WidthClass.medium);
    });

    testWidgets('landscape tablet and desktop are expanded', (tester) async {
      expect(await classAt(tester, 900), WidthClass.expanded);
      expect(await classAt(tester, 1440), WidthClass.expanded);
    });
  });

  group('AuthPage layout', () {
    testWidgets('phone keeps the bottom-sheet layout', (tester) async {
      await _pumpAt(tester, const Size(390, 955));

      expect(find.byKey(sheetKey), findsOneWidget);
      expect(find.byKey(splitPaneKey), findsNothing);
    });

    testWidgets('portrait tablet keeps the bottom-sheet layout', (tester) async {
      await _pumpAt(tester, const Size(834, 1194));

      expect(find.byKey(sheetKey), findsOneWidget);
      expect(find.byKey(splitPaneKey), findsNothing);
    });

    testWidgets('desktop switches to the split-pane layout', (tester) async {
      await _pumpAt(tester, const Size(1440, 810));

      expect(find.byKey(splitPaneKey), findsOneWidget);
      expect(find.byKey(sheetKey), findsNothing);
      expect(find.text(AppStrings.authHeroTaglineExpanded), findsOneWidget);
    });

    testWidgets('language switcher survives in the split-pane layout',
        (tester) async {
      // It lives inside the sheet layout's Stack (BR-U75N5Y), so the desktop
      // branch has to place its own or the feature vanishes on wide windows.
      await _pumpAt(tester, const Size(1440, 810));

      expect(find.byType(LanguageSwitcher), findsOneWidget);
    });

    testWidgets('wave spans the full window width on desktop', (tester) async {
      await _pumpAt(tester, const Size(1440, 810));

      final wave = tester.getSize(find.byKey(waveKey));
      expect(wave.width, 1440);
      // 1440 × 250/1440 — the asset's own ratio, so it cannot distort.
      expect(wave.height, closeTo(250, 0.01));
    });

    testWidgets('wave is zoomed past the viewport on a phone', (tester) async {
      await _pumpAt(tester, const Size(390, 955));

      final wave = tester.getSize(find.byKey(waveKey));
      // Wider than the 390 viewport so the curve keeps its designed height
      // instead of flattening to a ~68px strip.
      expect(wave.width, closeTo(585, 0.01));
      expect(wave.height, closeTo(101.6, 0.5));
    });

    testWidgets('hero scene layers render 1:1 at the design artboard size',
        (tester) async {
      await _pumpAt(tester, const Size(1440, 810));

      // The cave and the props scene are both authored on the 1440×810
      // artboard, so at exactly that window they render unscaled.
      expect(tester.getSize(find.byKey(caveKey)), const Size(1440, 810));
      expect(tester.getSize(find.byKey(sceneKey)), const Size(1440, 810));
    });

    testWidgets('props follow the wave, cave still reaches the ground on the '
        'taller iPad-landscape ratio', (tester) async {
      await _pumpAt(tester, const Size(1180, 820));

      // Props share the wave's width-based scale so the mascot keeps
      // standing where the ground curves.
      final scene = tester.getSize(find.byKey(sceneKey));
      expect(scene.width, closeTo(1180, 0.01));
      expect(scene.height, closeTo(1180 * 810 / 1440, 0.5));

      // The cave hangs from the top edge; with width scaling alone it would
      // stop ~70px short of the hills on this ratio, so it scales by height
      // here instead.
      final cave = tester.getSize(find.byKey(caveKey));
      expect(cave.height, closeTo(820, 0.01));
    });

    testWidgets('hero scene layers stay out of the phone layout',
        (tester) async {
      await _pumpAt(tester, const Size(390, 955));

      expect(find.byKey(caveKey), findsNothing);
      expect(find.byKey(sceneKey), findsNothing);
    });

    testWidgets('form controls stay capped on a very wide window',
        (tester) async {
      await _pumpAt(tester, const Size(3360, 1890));

      // The continue button must not stretch across the monitor — it lives in
      // the 340px form column inside the capped panel.
      final button = find.widgetWithText(ElevatedButton, AppStrings.authContinue);
      expect(button, findsOneWidget);
      expect(tester.getSize(button).width, lessThanOrEqualTo(340));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // BR-W5HNHB: the sheet layout used to show only the character logo, leaving a
  // band of empty gradient above it, while the wide layout already had the full
  // illustrated scene. The phone now gets the same artwork, cropped to the
  // props and scaled to whatever room is left above the wave.
  // ───────────────────────────────────────────────────────────────────────────
  group('compact hero (phone sheet)', () {
    /// Distance from the top of the window to the top of the composition.
    double heroTop(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(compactWordmarkKey)).dy;

    testWidgets('phone shows the props and wordmark, with no raster logo',
        (tester) async {
      await _pumpAt(tester, const Size(390, 844), topPadding: 47);

      expect(find.byKey(compactSceneKey), findsOneWidget);
      expect(find.byKey(compactWordmarkKey), findsOneWidget);
      expect(_rasterLogo, findsNothing);
    });

    testWidgets('portrait tablet gets it too', (tester) async {
      await _pumpAt(tester, const Size(834, 1194), topPadding: 24);

      expect(find.byKey(compactSceneKey), findsOneWidget);
      expect(_rasterLogo, findsNothing);
    });

    testWidgets('split-pane layout draws the full scene instead', (tester) async {
      await _pumpAt(tester, const Size(1440, 810));

      expect(find.byKey(sceneKey), findsOneWidget);
      expect(find.byKey(compactSceneKey), findsNothing);
      expect(find.byKey(compactWordmarkKey), findsNothing);
    });

    testWidgets('props stand on the wave rather than floating above it',
        (tester) async {
      await _pumpAt(tester, const Size(390, 844), topPadding: 47);

      final props = tester.getRect(find.byKey(compactSceneKey));
      final wave = tester.getRect(find.byKey(waveKey));

      // Overlapping the wave is the point — the mascot has to look planted.
      expect(props.bottom, greaterThan(wave.top));
      // ...but not so far that the lower props vanish behind the sheet.
      expect(props.bottom, lessThan(wave.bottom));
    });

    // The sheet grows from 52% to 72% of the screen in sign-up mode and the
    // keyboard shrinks the body further, so a fixed-size composition would
    // slide under the status bar — the same failure BR-PXB3N3 fixed for the
    // card itself.
    for (final device in const [
      (name: 'iPhone 14', size: Size(390, 844), inset: 47.0),
      (name: 'iPhone SE', size: Size(375, 667), inset: 20.0),
      (name: 'portrait tablet', size: Size(834, 1194), inset: 24.0),
    ]) {
      for (final signUp in const [false, true]) {
        testWidgets(
            'clears the status bar on ${device.name}'
            '${signUp ? ' in sign-up mode' : ''}', (tester) async {
          await _pumpAt(
            tester,
            device.size,
            topPadding: device.inset,
            startInLoginMode: signUp,
          );

          expect(heroTop(tester), greaterThanOrEqualTo(device.inset));
        });
      }
    }

    testWidgets('composition shrinks when the sheet takes the room',
        (tester) async {
      await _pumpAt(tester, const Size(390, 844), topPadding: 47);
      final login = tester.getSize(find.byKey(compactSceneKey)).width;

      await _pumpAt(tester, const Size(390, 844),
          topPadding: 47, startInLoginMode: true);
      final signUp = tester.getSize(find.byKey(compactSceneKey)).width;

      expect(signUp, lessThan(login));
    });

    testWidgets('never outgrows the design width', (tester) async {
      // 390 × 0.88 = 343.2, under the 400 cap.
      await _pumpAt(tester, const Size(390, 1400), topPadding: 47);
      expect(
        tester.getSize(find.byKey(compactSceneKey)).width,
        closeTo(343.2, 0.5),
      );

      // 834 × 0.88 = 734 — capped, or the artwork would dwarf the 340px form
      // column underneath it.
      await _pumpAt(tester, const Size(834, 1194), topPadding: 24);
      expect(
        tester.getSize(find.byKey(compactSceneKey)).width,
        lessThanOrEqualTo(400),
      );
    });
  });

  // The child onboarding steps (age gate, guardian consent request) are stops
  // on the same auth journey — on wide windows they keep the illustrated hero
  // scene and swap only the right-hand panel's content.
  group('child onboarding layout', () {
    Future<void> pumpAt(WidgetTester tester, Size logicalSize, Widget page) async {
      tester.view.physicalSize = logicalSize * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Widget ageGate() => AgeGatePage(
          initialCountry: 'CZ',
          onOldEnough: () {},
          onNeedsConsent: (_) {},
          onBack: () {},
        );

    Widget consentRequest() => ConsentRequestPage(
          onSubmit: (_) async => const ConsentActionResult.success(),
          onEnterCode: () {},
          onBack: () {},
        );

    testWidgets('age gate keeps the hero scene on desktop', (tester) async {
      await pumpAt(tester, const Size(1440, 810), ageGate());

      expect(find.byKey(splitPaneKey), findsOneWidget);
      expect(find.byKey(sceneKey), findsOneWidget);
      // The step content moved into the panel, back arrow included.
      expect(find.text('CZ'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('age gate keeps its plain layout on a phone', (tester) async {
      await pumpAt(tester, const Size(390, 955), ageGate());

      expect(find.byKey(splitPaneKey), findsNothing);
      expect(find.byKey(sceneKey), findsNothing);
      expect(find.text('CZ'), findsOneWidget);
    });

    testWidgets('consent request keeps the hero scene on desktop',
        (tester) async {
      await pumpAt(tester, const Size(1440, 810), consentRequest());

      expect(find.byKey(splitPaneKey), findsOneWidget);
      expect(find.byKey(sceneKey), findsOneWidget);
      expect(find.text(AppStrings.consentIntroTitle), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('consent request keeps its plain layout on a phone',
        (tester) async {
      await pumpAt(tester, const Size(390, 955), consentRequest());

      expect(find.byKey(splitPaneKey), findsNothing);
      expect(find.text(AppStrings.consentIntroTitle), findsOneWidget);
    });

    testWidgets('consent request form stays capped inside the panel',
        (tester) async {
      await pumpAt(tester, const Size(3360, 1890), consentRequest());

      final button =
          find.widgetWithText(FilledButton, AppStrings.consentSend);
      expect(button, findsOneWidget);
      expect(tester.getSize(button).width, lessThanOrEqualTo(340));
    });
  });
}
