import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/util/markdown_link_handler.dart';
import 'package:eduai/widgets/markdown_latex_widget.dart';
import 'package:eduai/widgets/markdown_media_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BR-QJJXPN: a link inside a news item did nothing when tapped. MarkdownBody
// attaches a tap recognizer to every link regardless, but its callback is a
// no-op unless onTapLink is supplied — which MarkdownLatexWidget never did, so
// the tap was swallowed and the deep link never ran.
//
// Two things are covered here: that a tap reaches the callback at all (the
// regression), and that the href is routed to the right place (the rules).
// ─────────────────────────────────────────────────────────────────────────────

/// Tap the middle of [linkText].
///
/// `tester.tapOnText` only collects RenderParagraphs, and the widget's default
/// `selectable: true` renders paragraphs as SelectableText (a RenderEditable),
/// so the substring finder comes up empty there. That is a limitation of the
/// finder, not of the widget — for the selectable case we locate the glyph
/// ourselves and tap the raw coordinates instead.
Future<void> _tapText(WidgetTester tester, String linkText) async {
  final editables = find.byType(EditableText);
  if (editables.evaluate().isEmpty) {
    await tester.tapOnText(find.textRange.ofSubstring(linkText));
    return;
  }

  // Content split across several paragraphs (or around a video embed) renders
  // as several SelectableTexts, so find the one actually holding the link.
  for (final element in editables.evaluate()) {
    final renderEditable =
        (element as StatefulElement).state as EditableTextState;
    final render = renderEditable.renderEditable;
    final plain = render.text!.toPlainText(includeSemanticsLabels: false);
    final start = plain.indexOf(linkText);
    if (start < 0) continue;

    final caret = render.getLocalRectForCaret(
      TextPosition(offset: start + linkText.length ~/ 2),
    );
    await tester.tapAt(render.localToGlobal(caret.center));
    return;
  }
  fail('link text "$linkText" not rendered in any EditableText');
}

Future<List<String>> _tapLink(
  WidgetTester tester,
  String markdown,
  String linkText, {
  bool selectable = true,
}) async {
  final tapped = <String>[];

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MarkdownLatexWidget(
            content: markdown,
            selectable: selectable,
            onTapLink: tapped.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await _tapText(tester, linkText);
  await tester.pump();

  return tapped;
}

void main() {
  group('MarkdownLatexWidget link taps', () {
    testWidgets('a tapped link reaches the handler', (tester) async {
      final tapped = await _tapLink(
        tester,
        'Tady je [seznamovací kurz](https://app.edu-ai.eu/pin/uslov1) pro tebe.',
        'seznamovací kurz',
      );

      expect(tapped, ['https://app.edu-ai.eu/pin/uslov1']);
    });

    // The widget defaults to selectable: true, which renders the paragraph as a
    // SelectableText.rich instead of a Text.rich. Span recognizers have to
    // survive that swap (they do — RenderEditable hit-tests spans the same way
    // RenderParagraph does), so both modes are covered.
    testWidgets('taps work in the non-selectable mode too', (tester) async {
      final tapped = await _tapLink(
        tester,
        'Otevři [kurz](/pin/uslov1).',
        'kurz',
        selectable: false,
      );

      expect(tapped, ['/pin/uslov1']);
    });

    testWidgets('links inside a list item are tappable', (tester) async {
      final tapped = await _tapLink(
        tester,
        '- Nejdřív [kurz](/course/abc123)\n- Potom něco jiného',
        'kurz',
      );

      expect(tapped, ['/course/abc123']);
    });
  });

  // News bodies go through MarkdownMediaWidget, which splits video embeds out
  // and renders the remaining text segments as MarkdownLatexWidgets. A link
  // sitting next to a video must still work.
  testWidgets('links survive the video-embed split', (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MarkdownMediaWidget(
              content: 'Mrkni na video:\n\n'
                  '<video src="https://cdn.example.com/clip.mp4"></video>\n\n'
                  'A pak si dej [seznamovací kurz](/pin/uslov1).',
              onTapLink: tapped.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await _tapText(tester, 'seznamovací kurz');
    await tester.pump();

    expect(tapped, ['/pin/uslov1']);
  });

  group('resolveMarkdownLink', () {
    test('routes /pin and /course deep links to the course code', () {
      for (final href in [
        '/pin/uslov1',
        '/course/uslov1',
        'https://app.edu-ai.eu/pin/uslov1',
        'https://app.edu-ai.eu/course/uslov1',
      ]) {
        expect(
          resolveMarkdownLink(href),
          const MarkdownLinkTarget(MarkdownLinkAction.courseCode, 'uslov1'),
          reason: href,
        );
      }
    });

    test('keeps trailing slashes and whitespace out of the code', () {
      expect(
        resolveMarkdownLink('  https://app.edu-ai.eu/pin/uslov1/  '),
        const MarkdownLinkTarget(MarkdownLinkAction.courseCode, 'uslov1'),
      );
    });

    test('routes legal pages in-app, carrying the locale', () {
      expect(
        resolveMarkdownLink('/terms'),
        const MarkdownLinkTarget(
          MarkdownLinkAction.legalPage,
          'terms',
          locale: 'cs',
        ),
      );
      expect(
        resolveMarkdownLink('https://app.edu-ai.eu/privacy/en'),
        const MarkdownLinkTarget(
          MarkdownLinkAction.legalPage,
          'privacy',
          locale: 'en',
        ),
      );
    });

    test('a legal slug with an unexpected suffix is not a legal page', () {
      expect(
        resolveMarkdownLink('/terms/something-else').action,
        MarkdownLinkAction.external,
      );
    });

    // The marketing site is a different host and must open in the browser —
    // bundled course content already links to it.
    test('sends the marketing site to the browser', () {
      expect(
        resolveMarkdownLink('https://edu-ai.eu/o-nas'),
        const MarkdownLinkTarget(
          MarkdownLinkAction.external,
          'https://edu-ai.eu/o-nas',
        ),
      );
    });

    test('sends foreign hosts, mailto and tel to the browser', () {
      for (final href in [
        'https://example.com/pin/uslov1',
        'mailto:ahoj@edu-ai.eu',
        'tel:+420123456789',
      ]) {
        expect(
          resolveMarkdownLink(href).action,
          MarkdownLinkAction.external,
          reason: href,
        );
      }
    });

    // A path we have no route for must not be rewritten in-app, or the router's
    // errorBuilder would show "Stránka nenalezena" instead of the page.
    test('sends unknown paths on our own host to the browser', () {
      expect(
        resolveMarkdownLink('https://app.edu-ai.eu/nejaka-landing-page'),
        const MarkdownLinkTarget(
          MarkdownLinkAction.external,
          'https://app.edu-ai.eu/nejaka-landing-page',
        ),
      );
    });

    test('does not mistake a deeper pin path for a deep link', () {
      expect(
        resolveMarkdownLink('/pin/uslov1/extra').action,
        MarkdownLinkAction.external,
      );
    });
  });
}
