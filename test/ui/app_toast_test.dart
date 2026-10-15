import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/core/ui/app_toast.dart';

/// BR-8H9WTT — "Nejprve vyber odpověď" was a full-width strip pinned to the
/// bottom of the *window*, outside the content pane, because the desktop shells
/// nest the page's `Scaffold` inside their own and Flutter only renders a
/// `SnackBar` in the root one.
///
/// These tests pin down the two halves of the fix: a corner toast on wide
/// viewports, and a width-capped snack bar for every call site still using
/// `ScaffoldMessenger` directly.
///
/// BR-PFXDYD then found the cost of hosting that corner toast outside the
/// Navigator: with no `Material` above it, the message picked up Flutter's
/// yellow-double-underline fallback style.
void main() {
  const message = 'Nejprve vyber odpověď';

  /// Mirrors the wiring in `MyApp.build` — the toast host and the responsive
  /// snack bar theme both live in `MaterialApp.builder`, above the Navigator.
  ///
  /// Set [nested] to reproduce the shape that caused the bug: the desktop
  /// shells put the page's own `Scaffold` inside a window-level one, which is
  /// what pushed the snack bar out of the content pane.
  Widget harness({bool nested = false}) {
    final page = Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showAppToast(context, message),
            child: const Text('confirm'),
          ),
        ),
      ),
    );

    return MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          snackBarTheme: AppTheme.snackBarThemeFor(context),
        ),
        child: ToastHost(child: child ?? const SizedBox.shrink()),
      ),
      home: nested
          ? Scaffold(
              body: Row(
                children: [
                  const SizedBox(width: 240), // stands in for SideNav
                  Expanded(child: page),
                ],
              ),
            )
          : page,
    );
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The styled card wrapping the toast text.
  Finder toastCard() => find
      .ancestor(of: find.text(message), matching: find.byType(Container))
      .first;

  group('wide viewport', () {
    testWidgets('renders a capped-width toast in the top-right corner',
        (tester) async {
      setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(harness());

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      // The old behaviour: a SnackBar spanning the window. Must be gone.
      expect(find.byType(SnackBar), findsNothing);

      final rect = tester.getRect(toastCard());
      expect(rect.width, lessThanOrEqualTo(kToastMaxWidth));
      // Anchored to the top-right, not the bottom edge of the window.
      expect(rect.right, greaterThan(1440 - 40));
      expect(rect.top, lessThan(60));
    });

    testWidgets('stays in the corner even with the shell nesting that broke it',
        (tester) async {
      setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(harness(nested: true));

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();

      final rect = tester.getRect(toastCard());
      // The regression: a SnackBar here rendered in the *outer* Scaffold, so it
      // sat at the very bottom of the window spanning its full width.
      expect(rect.width, lessThanOrEqualTo(kToastMaxWidth));
      expect(rect.top, lessThan(60));
      expect(rect.bottom, lessThan(900 / 2));
    });

    testWidgets('repeating the same message does not stack copies',
        (tester) async {
      setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(harness());

      await tester.tap(find.text('confirm'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
    });

    testWidgets('auto-dismisses', (tester) async {
      setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(harness());

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });

    testWidgets('tapping the toast closes it early', (tester) async {
      setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(harness());

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(message));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });

    /// BR-PFXDYD — the stack is a sibling of the Navigator, so nothing above it
    /// supplied a `Material` and the text fell back to `WidgetsApp`'s
    /// `_errorTextStyle`. `AppTextStyles.body` overrides its colour, size,
    /// family and weight but not `decoration`, so the one part that survived was
    /// a yellow double underline.
    testWidgets('draws the message without the Material fallback decoration',
        (tester) async {
      setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(harness());

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();

      final toastText = find.text(message);

      // The cause: something above the toast has to set a `DefaultTextStyle`.
      expect(
        find.ancestor(of: toastText, matching: find.byType(Material)),
        findsAtLeastNWidgets(1),
      );

      // The symptom: whatever it inherits, the message must come out undecorated.
      final style = DefaultTextStyle.of(tester.element(toastText))
          .style
          .merge(tester.widget<Text>(toastText).style);
      expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
    });
  });

  group('compact viewport', () {
    testWidgets('keeps the bottom snack bar — phones were never broken',
        (tester) async {
      setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(harness());

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      final rect = tester.getRect(find.byType(SnackBar));
      // Bottom half of the screen, i.e. where a phone expects it.
      expect(rect.center.dy, greaterThan(844 / 2));
    });
  });

  group('snackBarThemeFor', () {
    Future<SnackBarThemeData> resolve(WidgetTester tester, Size size) async {
      setViewport(tester, size);
      late SnackBarThemeData theme;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              theme = AppTheme.snackBarThemeFor(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return theme;
    }

    testWidgets('caps the width once there is room to cap', (tester) async {
      final theme = await resolve(tester, const Size(1440, 900));
      expect(theme.behavior, SnackBarBehavior.floating);
      expect(theme.width, AppTheme.snackBarMaxWidth);
    });

    testWidgets('leaves phones on the default full-width bar', (tester) async {
      final theme = await resolve(tester, const Size(390, 844));
      expect(theme.width, isNull);
    });
  });
}
