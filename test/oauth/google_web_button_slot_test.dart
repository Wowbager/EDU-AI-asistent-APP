import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/oauth/oauth_sign_in_buttons.dart';
import 'package:eduai/widgets/auth_hero_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// On web the Google button is drawn by GIS at a fixed pixel width, inside a
// platform view that google_sign_in_web sizes to the slot, centres the button
// in and clips with `overflow: hidden`. The button always asked for 400px,
// but the auth form column is only 340px wide, so 30px were cut off each
// side — and the logo with them (BR-N3MXDH). The button must be asked for the
// width its slot actually has, never more than the 400px GIS allows.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  /// Pumps the slot [slotWidth] wide and returns the width the GIS button was
  /// asked to render at (null when it was not built at all).
  Future<double?> askedWidth(
    WidgetTester tester,
    double slotWidth, {
    bool ready = true,
  }) async {
    double? asked;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: slotWidth,
          child: GoogleWebButtonSlot(
            ready: ready,
            buttonBuilder: ({required double width}) {
              asked = width;
              return SizedBox(width: width, height: 40);
            },
          ),
        ),
      ),
    ));
    return asked;
  }

  testWidgets('fits the auth form column instead of overflowing it',
      (tester) async {
    expect(await askedWidth(tester, kAuthFormColumnWidth), kAuthFormColumnWidth);
  });

  testWidgets('stays at the 400px GIS maximum in a wider slot', (tester) async {
    expect(await askedWidth(tester, 448), 400);
  });

  testWidgets('floors a fractional slot so it never rounds past the edge',
      (tester) async {
    expect(await askedWidth(tester, 326.4), 326);
  });

  testWidgets('shows a spinner, not the button, until the SDK is ready',
      (tester) async {
    expect(await askedWidth(tester, kAuthFormColumnWidth, ready: false), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
