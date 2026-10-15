// A pushed page's sidebar has to reach `MainScreen` even when there is no
// `MainScreen` yet (BR-CMP2PX).
//
// The reported case: a fresh guest resolves a course PIN, and `AuthPage`
// pushes the course detail page itself — the app is still in its auth state,
// so nothing is mounted underneath the sidebar that page draws. Tapping
// "Registrovat se" bumped `requestGuestLoginProvider`, which only `MainScreen`
// listens to, so it did nothing at all; tapping the account block popped the
// course (which finishes the login and finally mounts `MainScreen`, on the
// Kurzy tab the PIN selected) and then dropped the intent, because
// `ref.listen` had missed the change that happened before it existed.
//
// Both taps now record a `ShellIntent`, and the slot is read-and-cleared —
// so an intent recorded before the shell mounts survives to be acted on.
//
//   flutter test test/widgets/pushed_shell_intent_test.dart
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/navigation_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/features/email_validation/providers/email_validation_providers.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/widgets/detail_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An anonymous guest — `createGuestUser()` writes an empty e-mail and leaves
/// the validated flag false. The only account the register card is shown to.
UsersTableData _guest() {
  final now = DateTime(2026, 1, 1);
  return UsersTableData(
    id: 'u1',
    email: '',
    name: 'Veselý mrož',
    avatarIndex: 0,
    selectedSubjects: '[0]',
    isEmailValidated: false,
    isActive: true,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// The sidebar's account block draws the user's own avatar (BR-D6W3CR), which
/// reads the catalog. Served from memory so the test does not stand up the
/// repository behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

void main() {
  late ProviderContainer container;

  /// Everything the sidebar and its banners read, with no user row of note
  /// beyond "an anonymous guest".
  Future<void> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeUserStreamProvider.overrideWith((ref) => Stream.value(_guest())),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
        minorModeProvider
            .overrideWith((ref) => MinorModeNotifier()..state = false),
        showEmailValidationBannerProvider.overrideWithValue(false),
        avatarControllerProvider.overrideWith(_StubAvatarController.new),
        // The PIN flow points the shell at Kurzy before the course opens
        // (BR-48B7DY) — the tab the reporter was left staring at.
        mainTabIndexProvider.overrideWith((ref) => kKurzyTabIndex),
      ],
    );
    addTearDown(container.dispose);
  }

  /// The course detail page as the PIN flow leaves it: a `DetailShell` pushed
  /// on top of a route that is *not* `MainScreen`.
  Future<void> pumpPushedDetailPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1322, 807);
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
              // Stands in for the AuthPage the PIN flow is still sitting on.
              return const Scaffold(body: Text('auth'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    Navigator.of(navContext).push(
      MaterialPageRoute(
        builder: (_) => DetailShell(
          backLabel: AppStrings.courseBackToAll,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the register card records an intent and pops to the shell',
      (tester) async {
    await buildContainer();
    await pumpPushedDetailPage(tester);

    await tester.tap(find.text(AppStrings.shellGuestCtaButton));
    await tester.pumpAndSettle();

    // Popping back is what completes the PIN login and mounts MainScreen; the
    // intent has to be waiting for it when it gets there.
    expect(find.text('auth'), findsOneWidget);
    expect(
      container.read(pendingShellIntentProvider),
      ShellIntent.openGuestLogin,
    );
    // The old channel is a bump nobody hears from here.
    expect(container.read(requestGuestLoginProvider), 0);
  });

  testWidgets('the account block records the profile intent', (tester) async {
    await buildContainer();
    await pumpPushedDetailPage(tester);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.text('auth'), findsOneWidget);
    expect(
      container.read(pendingShellIntentProvider),
      ShellIntent.openProfile,
    );
  });

  group('takePendingShellIntent', () {
    late WidgetRef ref;

    Future<void> pumpConsumer(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('hands over an intent recorded before the shell existed',
        (tester) async {
      await buildContainer();
      // Exactly the gap the bug fell into: the slot is written while nothing
      // is listening, and the reader arrives afterwards.
      container.read(pendingShellIntentProvider.notifier).state =
          ShellIntent.openProfile;
      await pumpConsumer(tester);

      expect(takePendingShellIntent(ref), ShellIntent.openProfile);
    });

    testWidgets('empties the slot, so it is acted on once', (tester) async {
      await buildContainer();
      container.read(pendingShellIntentProvider.notifier).state =
          ShellIntent.openGuestLogin;
      await pumpConsumer(tester);

      expect(takePendingShellIntent(ref), ShellIntent.openGuestLogin);
      expect(container.read(pendingShellIntentProvider), isNull);
      expect(takePendingShellIntent(ref), isNull);
    });
  });
}
