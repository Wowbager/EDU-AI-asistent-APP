import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/strings/locale_manager.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/pages/profile_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The language picker used to size itself to the intrinsic width of its
// content, so Material's 280px floor was the only thing holding it open. The
// selected row also loses 24px of title width to the check icon, which was
// enough to break "Čeština" mid-word ("Češti / na"). BR-TDNPTY.
// ─────────────────────────────────────────────────────────────────────────────

/// The profile header draws the user's own avatar (BR-D6W3CR), which reads the
/// catalog. Served from memory so the test does not stand up the repository
/// behind it.
class _StubAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

Future<void> _openPicker(WidgetTester tester, {required Size physicalSize}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // The profile header draws the user's own avatar now (BR-D6W3CR), so the
      // page needs a scope even though the picker itself reads nothing.
      overrides: [
        avatarControllerProvider.overrideWith(_StubAvatarController.new),
      ],
      child: const MaterialApp(
        home: ProfilePage(userName: 'Tester', userEmail: 'tester@example.com'),
      ),
    ),
  );

  // The settings list scrolls; drag the "Jazyk" row into view before tapping.
  final languageRow = find.text(AppStrings.profileLanguage);
  await tester.scrollUntilVisible(languageRow, 200);
  await tester.tap(languageRow);
  await tester.pumpAndSettle();
}

/// The "Čeština" label also appears on the settings row behind the dialog, so
/// scope the finder to the dialog's own option row.
final Finder _czechRow = find.descendant(
  of: find.byType(Dialog),
  matching: find.text(AppLocale.cs.displayName),
);

double _dialogWidth(WidgetTester tester) => tester
    .getSize(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first,
    )
    .width;

void main() {
  testWidgets('language dialog is wide enough for the language name', (tester) async {
    // 1080x2400 @2.0 → 540x1200 logical.
    await _openPicker(tester, physicalSize: const Size(1080, 2400));

    expect(_dialogWidth(tester), 320.0);

    // "Čeština" is the selected row (Czech is the default locale), so it is
    // the one that has to share its row with the check icon.
    expect(LocaleManager.current, AppLocale.cs);
    final title = tester.widget<Text>(_czechRow);
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);

    // Fits on that single line — no wrap, and no ellipsis either.
    final para = tester.renderObject<RenderParagraph>(
      _czechRow,
    );
    expect(para.didExceedMaxLines, isFalse);
  });

  testWidgets('language dialog shrinks to fit a narrow screen', (tester) async {
    // 600x1600 @2.0 → 300x800 logical; 300 - 80 inset padding = 220.
    await _openPicker(tester, physicalSize: const Size(600, 1600));

    expect(_dialogWidth(tester), 220.0);
  });
}
