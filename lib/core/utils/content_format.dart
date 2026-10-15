/// Shared "what format is this text?" sniffing.
///
/// Course content arrives as a plain string with no reliable format flag, so
/// every renderer has to guess whether to hand it to the markdown widget, the
/// HTML widget, or a plain [Text]. Keeping the guess in one place stops the
/// per-call-site copies from drifting apart (BR-KYBZ7H: blockquotes rendered
/// as literal `>` because only some of the copies knew about block markers).
///
/// Always test HTML first — an HTML snippet can easily contain a `-` or `*`
/// and would otherwise be misread as markdown and printed with its tags.
library;

/// Block-level markers only count at the start of a line and need whitespace
/// after them, so `Teplota > 30` and `out-of-the-box` stay plain prose.
/// Up to 3 leading spaces are allowed, same as CommonMark.
final _mdBlockMarkers = RegExp(
  r'^[ \t]{0,3}(>[ \t]?\S|#{1,6}[ \t]|[-*+][ \t]|\d+\.[ \t]|\|)',
  multiLine: true,
);

/// Inline markers can appear anywhere. `$` covers the LaTeX support that
/// [MarkdownLatexWidget] layers on top of markdown.
final _mdInlineMarkers = RegExp(r'(\*\*|__|`|!\[|\[[^\]\n]+\]\(|\$|(?<!\w)\*\S)');

/// A real tag — name required — so `5 < 10 a 20 > 15` is not mistaken for HTML.
final _htmlTag = RegExp(r'<\s*/?\s*[a-zA-Z][a-zA-Z0-9-]*(\s[^<>]*)?/?>');

bool looksLikeMarkdown(String text) =>
    _mdBlockMarkers.hasMatch(text) || _mdInlineMarkers.hasMatch(text);

bool looksLikeHtml(String text) => _htmlTag.hasMatch(text);
