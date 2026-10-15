import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import '../core/theme/app_theme.dart';
import '../core/util/markdown_link_handler.dart';
import '../core/util/markdown_table_column_width.dart';
import 'lesson_image.dart';

/// Fallback body size, matching [AppTextStyles.body].
const double _kDefaultBodyFontSize = 15.0;

/// How much bigger a displayed formula is than the surrounding body.
const double _kDisplayMathStep = 3.0;

/// A widget that renders Markdown content with inline LaTeX support.
///
/// Uses a single MarkdownBody with custom inline syntax so that block-level
/// markdown (headers, tables, lists) and inline LaTeX ($...$, $$...$$)
/// coexist without breaking each other.
class MarkdownLatexWidget extends ConsumerWidget {
  final String content;

  /// The paragraph style, when the caller needs something other than the
  /// default 15px body — e.g. a card whose other sections are meta-sized
  /// (BR-PM7XQ3). Everything that hangs off the body size (bold, italics,
  /// links, list bullets, tables, inline and display maths) is scaled to
  /// match, so a smaller base does not leave 15px islands behind. The colour
  /// still comes from [textColor]: two ways to set the same thing would only
  /// fight each other.
  final TextStyle? textStyle;

  final Color? textColor;
  /// Whether text is user-selectable. Set to false when widget sits inside
  /// a tappable button so SelectableText doesn't eat the tap and show the
  /// text-cursor over LaTeX regions.
  final bool selectable;

  /// Overrides what a tapped link does. Defaults to [handleMarkdownLink],
  /// which routes our own URLs in-app and everything else to the browser.
  final void Function(String href)? onTapLink;

  /// Colour for links. Defaults to [AppColors.quizPurple]; the blockquote
  /// builder overrides it because purple-on-purple is unreadable.
  final Color? linkColor;

  const MarkdownLatexWidget({
    super.key,
    required this.content,
    this.textStyle,
    this.textColor,
    this.selectable = true,
    this.onTapLink,
    this.linkColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveTextColor = textColor ?? AppColors.primaryDark88;
    final effectiveLinkColor = linkColor ?? AppColors.quizPurple;

    // Everything below is sized off the body. When the caller supplied a style
    // its size becomes the new body size, and `sized` pulls the rest along.
    final baseStyle = textStyle?.copyWith(color: effectiveTextColor) ??
        AppTextStyles.body(color: effectiveTextColor, height: 1.5);
    final baseFontSize = baseStyle.fontSize ?? _kDefaultBodyFontSize;
    TextStyle sized(TextStyle style) => style.copyWith(fontSize: baseFontSize);

    // Pre-process: promote $\begin{...}...\end{...}$ → $$...$$ so that
    // multi-line LaTeX environments render as display math even with single $
    final promoted = _promoteBlockEnvironments(content);

    // Pre-process: any $$...$$ block alone on its own line gets isolated as
    // its own paragraph (blank lines before/after) so consecutive display
    // formulas render stacked instead of inline-flowing in one paragraph.
    final isolated = _isolateBlockMath(promoted);

    // Add hard line breaks (trailing spaces) for single newlines,
    // but skip table rows (lines starting with |) and separator rows (---)
    final processed = _addHardLineBreaks(isolated);

    return MarkdownBody(
      data: processed,
      shrinkWrap: true,
      selectable: selectable,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      // Without this, flutter_markdown still attaches a tap recognizer to every
      // link but its callback is a no-op, so taps are swallowed and nothing at
      // all happens — which is exactly how BR-QJJXPN was reported.
      onTapLink: (text, href, title) {
        if (href == null || href.trim().isEmpty) return;
        final override = onTapLink;
        if (override != null) {
          override(href);
          return;
        }
        handleMarkdownLink(context, ref, href);
      },
      // Pictures go through the offline lesson image cache (BR-BX9AA4); the
      // default builder's error state is an empty box, so offline they vanished.
      sizedImageBuilder: lessonMarkdownImageBuilder(),
      blockSyntaxes: const [
        // Takes over `> quote` from the built-in BlockquoteSyntax; custom
        // block syntaxes are matched first (markdown Document constructor).
        _AppQuoteSyntax(),
      ],
      inlineSyntaxes: [
        _DisplayLatexSyntax(), // $$...$$ must come before $...$
        _InlineLatexSyntax(),
      ],
      builders: {
        'latex': _LatexElementBuilder(
          textColor: textColor ?? AppColors.primaryDark,
          baseFontSize: baseFontSize,
        ),
        'appquote': _AppQuoteBuilder(
          selectable: selectable,
          onTapLink: onTapLink,
          textStyle: textStyle,
        ),
      },
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        strong: sized(AppTextStyles.bodyBold(color: textColor ?? AppColors.primaryDark)),
        em: sized(AppTextStyles.bodyItalic(color: effectiveTextColor)),
        // Links inherited the paragraph style before, so they were tappable but
        // looked like plain text. Matches the legal pages.
        a: sized(AppTextStyles.body(color: effectiveLinkColor)).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: effectiveLinkColor,
        ),
        h1: AppTextStyles.heading3(color: textColor ?? AppColors.primaryDark),
        h2: AppTextStyles.cardTitle(color: textColor ?? AppColors.primaryDark),
        h3: AppTextStyles.subtitle(color: textColor ?? AppColors.primaryDark),
        listBullet: sized(AppTextStyles.body(color: effectiveTextColor)),
        // Unreachable in practice: _AppQuoteSyntax claims every `> quote`
        // before the built-in BlockquoteSyntax sees it, so quotes render via
        // _AppQuoteBuilder instead. Kept as a light-background fallback in
        // case some other syntax ever emits a <blockquote> — the solid
        // primary fill of the real style would be unreadable here, because
        // flutter_markdown lets the `p` style override `blockquote`'s colour
        // (builder.dart: `styleSheet.blockquote!.merge(_inlines.last.style)`)
        // and the text would stay dark.
        blockquote: AppTextStyles.bodyItalic(color: AppColors.primaryDark80),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            left: BorderSide(color: AppColors.primary, width: 4),
          ),
          borderRadius: AppDecorations.radiusXS,
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        code: AppTextStyles.codeBlock(color: AppColors.primaryDark).copyWith(
          backgroundColor: AppColors.background,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppDecorations.radiusXS,
        ),
        tableHead: sized(AppTextStyles.bodyBold(color: textColor ?? AppColors.primaryDark)),
        tableBody: sized(AppTextStyles.body(color: effectiveTextColor)),
        tableBorder: TableBorder.all(
          color: AppColors.primaryDark24,
          width: 1,
        ),
        // Wide tables scroll sideways instead of being squeezed into the
        // viewport (BR-9AHW8R) — see markdown_table_column_width.dart.
        tableColumnWidth: kMarkdownTableColumnWidth,
        // Only painted when the table actually overflows — ScrollbarPainter
        // bails out when maxScrollExtent == minScrollExtent — so narrow tables
        // don't get a stray bar underneath, and wide ones advertise the scroll.
        tableScrollbarThumbVisibility: true,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  /// Promote $\begin{env}...\end{env}$ → $$\begin{env}...\end{env}$$
  /// so multi-line LaTeX environments (aligned, cases, matrix, etc.)
  /// are rendered as display math even when wrapped in single $.
  String _promoteBlockEnvironments(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?<!\$)\$(?!\$)(\s*\\begin\{[\s\S]*?\\end\{[^}]+\}\s*)\$(?!\$)'),
      (m) => '\$\$${m[1]}\$\$',
    );
  }

  /// Ensure any line that consists solely of a $$…$$ block has blank lines
  /// before and after it, so the markdown parser treats each one as its own
  /// paragraph. Without this, consecutive `$$…$$` lines collapse into a
  /// single paragraph and render as inline-flowing widgets on one line.
  String _isolateBlockMath(String text) {
    final lines = text.split('\n');
    final blockMath = RegExp(r'^[ \t]*\$\$.*?\$\$[ \t]*$');
    final result = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isBlock = blockMath.hasMatch(line);
      if (isBlock) {
        final prevBlank = result.isEmpty || result.last.trim().isEmpty;
        if (!prevBlank) result.add('');
        result.add(line);
        final nextBlank = i + 1 >= lines.length || lines[i + 1].trim().isEmpty;
        if (!nextBlank) result.add('');
      } else {
        result.add(line);
      }
    }
    return result.join('\n');
  }

  /// Add trailing spaces for hard line breaks, but preserve table rows.
  String _addHardLineBreaks(String text) {
    final lines = text.split('\n');
    final result = <String>[];

    bool inTable = false;
    for (final line in lines) {
      final trimmed = line.trimLeft();
      // Detect table rows: start with | or are separator rows like |---|---|
      if (trimmed.startsWith('|') || (inTable && trimmed.startsWith('---'))) {
        inTable = true;
        result.add(line);
      } else {
        if (inTable && trimmed.isEmpty) {
          inTable = false; // table ended
        }
        // Add trailing spaces for hard line break (skip empty lines)
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          result.add('$line  ');
        } else {
          result.add(line);
        }
      }
    }

    return result.join('\n');
  }
}

// ─── Custom Block Syntax for Blockquotes ─────────────────────

/// Claims `> quote` blocks and hands their body back as *raw markdown*
/// instead of a parsed `<blockquote>` tree.
///
/// Why not just style flutter_markdown's own blockquote? Because its text
/// colour is unsettable: the renderer merges the paragraph style *over* the
/// blockquote style (`styleSheet.blockquote!.merge(_inlines.last.style)` in
/// builder.dart), and `p` always carries an explicit colour. Bold and inline
/// maths inside the quote carry their own colours on top of that. Re-rendering
/// the body through a nested [MarkdownLatexWidget] is what lets a single
/// `textColor` reach every one of them.
///
/// [md.Element.text] wraps the body in a plain [md.Text] node, which the
/// inline parser leaves alone — same trick the LaTeX builders rely on. The
/// extra `p` wrapper keeps `_blocks.last.tag` a known block tag so the
/// renderer can look up a parent style for the custom element.
class _AppQuoteSyntax extends md.BlockquoteSyntax {
  const _AppQuoteSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    // parseChildLines is inherited: it strips the `>` markers per CommonMark
    // and follows lazy continuation lines, so quotes keep parsing exactly as
    // they did before — only the rendering changes.
    final body = parseChildLines(parser).map((line) => line.content).join('\n');
    return md.Element('p', [md.Element.text('appquote', body)]);
  }
}

// ─── Custom Element Builder for Blockquotes ──────────────────

/// Renders a quote as a filled card in the active palette — solid [
/// AppColors.primary] with white text, matching a selected chip/button.
class _AppQuoteBuilder extends MarkdownElementBuilder {
  final bool selectable;
  final void Function(String href)? onTapLink;

  /// Handed down so a quote inside smaller-set markdown does not snap back to
  /// the default body size — the quote body is its own MarkdownLatexWidget.
  final TextStyle? textStyle;

  _AppQuoteBuilder({
    required this.selectable,
    this.onTapLink,
    this.textStyle,
  });

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppDecorations.radiusM,
      ),
      child: MarkdownLatexWidget(
        content: element.textContent,
        textStyle: textStyle,
        textColor: Colors.white,
        linkColor: Colors.white,
        selectable: selectable,
        onTapLink: onTapLink,
      ),
    );
  }
}

// ─── Custom Inline Syntax for LaTeX ──────────────────────────

/// Matches display math: $$...$$ (rendered centered, larger)
class _DisplayLatexSyntax extends md.InlineSyntax {
  // Match $$...$$ — non-greedy, can span content but not empty
  _DisplayLatexSyntax() : super(r'\$\$([^\$]+?)\$\$', startCharacter: 0x24);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final latex = match[1]!.trim();
    final el = md.Element.text('latex', latex);
    el.attributes['displayMode'] = 'true';
    parser.addNode(el);
    return true;
  }
}

/// Matches inline math: $...$ (rendered inline, smaller)
class _InlineLatexSyntax extends md.InlineSyntax {
  // Match $...$ — non-greedy, no newlines, not empty, not preceded by $
  _InlineLatexSyntax() : super(r'\$([^\$\n]+?)\$', startCharacter: 0x24);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final latex = match[1]!.trim();
    final el = md.Element.text('latex', latex);
    el.attributes['displayMode'] = 'false';
    parser.addNode(el);
    return true;
  }
}

// ─── Custom Element Builder for LaTeX ────────────────────────

class _LatexElementBuilder extends MarkdownElementBuilder {
  final Color textColor;

  /// The paragraph size this markdown is set in. Inline maths matches it, so a
  /// formula never towers over the sentence it sits in.
  final double baseFontSize;

  _LatexElementBuilder({
    required this.textColor,
    this.baseFontSize = _kDefaultBodyFontSize,
  });

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Strip trailing whitespace per line — _addHardLineBreaks may have added
    // trailing "  " to lines inside $$...$$ which confuses flutter_math_fork.
    final rawLatex = element.textContent;
    final latex = rawLatex
        .split('\n')
        .map((l) => l.trimRight())
        .join('\n')
        .trim();
    final isDisplay = element.attributes['displayMode'] == 'true';

    // A displayed formula has always been one step up from the body.
    final fontSize = isDisplay ? baseFontSize + _kDisplayMathStep : baseFontSize;
    final mathStyle = isDisplay ? MathStyle.display : MathStyle.text;

    Widget buildMath(String tex) => Math.tex(
      tex,
      textStyle: TextStyle(fontSize: fontSize, color: textColor),
      mathStyle: mathStyle,
      onErrorFallback: (error) => Text(
        '\$$tex\$',
        style: AppTextStyles.codeInline(color: AppColors.orange),
      ),
    );

    if (isDisplay) {
      // Don't split at = signs when the LaTeX content is structured math
      // (alignment environments, line breaks, alignment markers). Splitting
      // there shreds \begin{aligned}…\end{aligned} into invalid pieces.
      final hasEnv = latex.contains(r'\begin{') ||
          latex.contains(r'\end{') ||
          latex.contains(r'\\') || // LaTeX line break
          latex.contains('&'); // alignment marker

      if (!hasEnv) {
        final parts = _splitAtTopLevelEquals(latex);

        if (parts.length > 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: parts.map((p) => buildMath(p)).toList(),
            ),
          );
        }
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: buildMath(latex)),
      );
    }

    // Inline math — render as a single inline element.
    // Wrap in RichText+WidgetSpan so flutter_markdown's _mergeInlineChildren
    // recognises it as text and merges it into the paragraph's TextSpan tree
    // instead of treating it as a standalone block widget (which causes a
    // line break before and after the formula).
    return RichText(
      text: WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: buildMath(latex),
      ),
    );
  }

  /// Split LaTeX at top-level `=` signs (not inside parentheses/braces).
  /// The `=` is kept at the end of the left part for readability.
  static List<String> _splitAtTopLevelEquals(String latex) {
    final parts = <String>[];
    int depth = 0;
    int lastSplit = 0;

    for (int i = 0; i < latex.length; i++) {
      final c = latex[i];
      if (c == '(' || c == '{' || c == '[') {
        depth++;
      } else if (c == ')' || c == '}' || c == ']') {
        depth = (depth - 1).clamp(0, 999);
      } else if (depth == 0 && c == '=') {
        // Include the = at the end of the left part
        final part = latex.substring(lastSplit, i + 1).trim();
        if (part.isNotEmpty) parts.add(part);
        lastSplit = i + 1;
      }
    }

    final remaining = latex.substring(lastSplit).trim();
    if (remaining.isNotEmpty) parts.add(remaining);

    return parts;
  }
}
