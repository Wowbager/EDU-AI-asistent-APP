// Desktop chat header (BR-7VMQ2U).
//
// On a wide window the shell drew a top bar saying "Chat" above *both* panes
// of the two-pane chat layout. That left the "new chat" button a row below the
// heading it belongs next to, and pushed the open conversation down by the
// bar's height instead of letting it start at the top edge.
//
// The fix is a `showTopBar` opt-out on the shell plus the page taking its
// heading back. These pin down both halves.
//
//   flutter test test/widgets/chat_desktop_header_test.dart
import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/pages/chaty_page.dart';
import 'package:eduai/widgets/adaptive_shell.dart';
import 'package:eduai/widgets/desktop_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _desktop = Size(1440, 900);
const Size _phone = Size(390, 844);

/// The test-only Ahem font is far wider than the real one, so labels overflow
/// their rows. Cosmetic and test-only — same suppression the other shell tests
/// use.
void _ignoreOverflow() {
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

void _sizeTo(WidgetTester tester, Size logicalSize) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.reset);
}

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

/// Key on the shell's content slot, so the tests can measure where a page
/// actually begins rather than inferring it from the bar's presence.
const _contentKey = ValueKey('shell-content');

Future<void> _pumpShell(
  WidgetTester tester, {
  required bool showTopBar,
  Size size = _desktop,
}) async {
  _sizeTo(tester, size);
  _ignoreOverflow();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeUserStreamProvider.overrideWith((ref) => Stream.value(_user())),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        home: AdaptiveShell(
          selectedIndex: 1,
          onItemTapped: (_) {},
          title: AppStrings.navChat,
          showTopBar: showTopBar,
          child: const ColoredBox(
            key: _contentKey,
            color: Color(0xFFEEEEEE),
            child: SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpChatyPage(WidgetTester tester, Size size) async {
  _sizeTo(tester, size);
  _ignoreOverflow();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatSessionsStreamProvider.overrideWith(
          (ref) => Stream.value(const <ChatSessionsTableData>[]),
        ),
        connectivityStateProvider.overrideWith(
          (ref) => Stream.value(ConnectivityState.wifi),
        ),
      ],
      child: const MaterialApp(home: ChatyPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AdaptiveShell.showTopBar', () {
    testWidgets('desktop draws the top bar by default', (tester) async {
      await _pumpShell(tester, showTopBar: true);

      expect(find.byType(DesktopTopBar), findsOneWidget);
    });

    testWidgets('a page can opt out of the top bar', (tester) async {
      await _pumpShell(tester, showTopBar: false);

      expect(find.byType(DesktopTopBar), findsNothing);
    });

    // The half of the ticket about the conversation: with the bar gone the
    // content has to actually reach the top edge, not merely lose a heading.
    testWidgets('opting out lets the content start at the top edge',
        (tester) async {
      await _pumpShell(tester, showTopBar: false);

      expect(tester.getTopLeft(find.byKey(_contentKey)).dy, 0);
    });

    testWidgets('the bar costs the content vertical space when it is on',
        (tester) async {
      await _pumpShell(tester, showTopBar: true);

      expect(tester.getTopLeft(find.byKey(_contentKey)).dy, greaterThan(0));
    });

    testWidgets('the flag is a no-op on a phone, which has no top bar anyway',
        (tester) async {
      await _pumpShell(tester, showTopBar: true, size: _phone);

      expect(find.byType(DesktopTopBar), findsNothing);
    });
  });

  group('ChatyPage header', () {
    // Previously dropped on `expanded` on the grounds that the shell's bar
    // already said "Chat". It no longer does, so losing this would leave the
    // page unlabelled.
    testWidgets('the heading is present on desktop', (tester) async {
      await _pumpChatyPage(tester, _desktop);

      expect(find.text(AppStrings.chatyTitle), findsOneWidget);
    });

    testWidgets('the new-chat button sits level with the heading on desktop',
        (tester) async {
      await _pumpChatyPage(tester, _desktop);

      final heading = find.text(AppStrings.chatyTitle);
      final button = find.widgetWithText(
        GestureDetector,
        AppStrings.chatyNewChat,
      );
      expect(heading, findsOneWidget);
      expect(button, findsOneWidget);

      // Same row, so the same vertical centre. The bug put the button ~60px
      // lower, in the column below a heading that lived in the shell's bar.
      expect(
        tester.getCenter(button).dy,
        closeTo(tester.getCenter(heading).dy, 1.0),
        reason: 'the button belongs beside the heading, not under it',
      );

      // Heading left, button right — the `Spacer` between them.
      expect(
        tester.getCenter(heading).dx,
        lessThan(tester.getCenter(button).dx),
      );
    });

    testWidgets('the phone layout keeps heading and button level too',
        (tester) async {
      await _pumpChatyPage(tester, _phone);

      final heading = find.text(AppStrings.chatyTitle);
      final button = find.widgetWithText(
        GestureDetector,
        AppStrings.chatyNewChat,
      );

      expect(
        tester.getCenter(button).dy,
        closeTo(tester.getCenter(heading).dy, 1.0),
      );
    });

    // Sweeps the widths either side of both breakpoints (600 compact→medium,
    // 900 medium→expanded). The heading used to vanish at exactly 900; nothing
    // about the header should move at either boundary now.
    for (final width in <double>[390, 599, 600, 899, 900, 1024, 1440]) {
      testWidgets('header holds together at ${width.toInt()}px',
          (tester) async {
        await _pumpChatyPage(tester, Size(width, 900));

        final heading = find.text(AppStrings.chatyTitle);
        final button = find.widgetWithText(
          GestureDetector,
          AppStrings.chatyNewChat,
        );
        expect(heading, findsOneWidget);
        expect(button, findsOneWidget);
        expect(
          tester.getCenter(button).dy,
          closeTo(tester.getCenter(heading).dy, 1.0),
        );

        // Heading flush to the column's left padding, button to its right.
        // Deliberately not asserting the button's right edge: the test-only
        // Ahem font is far wider than the real one, so the row overflows the
        // 360px column here and any width bound would be measuring the font.
        expect(tester.getTopLeft(heading).dx, closeTo(16, 0.5));
        expect(
          tester.getCenter(heading).dx,
          lessThan(tester.getCenter(button).dx),
        );
      });
    }
  });
}
