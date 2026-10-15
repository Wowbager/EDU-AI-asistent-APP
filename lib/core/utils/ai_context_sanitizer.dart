/// Strips media links out of text that is about to be sent to the AI mentor.
///
/// Course content is Block V2 markdown, so a step's text can carry an image
/// embed like `![náměstí](https://pub-….r2.dev/…)`. The "Zeptat se AI" context
/// is assembled verbatim from that text, so the raw URL landed both in the
/// student's own message bubble and in the prompt (BR-KFHPAR). Three reasons
/// that is wrong: the model cannot open links (the system prompt says so), the
/// URL is noise in the chat, and ~90 characters of it eat into the
/// 400-character task-content budget, truncating the actual assignment.
///
/// Media collapses to a short label — `[Obrázek: náměstí]` — so the model still
/// knows something visual is there without getting a link it can't follow.
/// Links keep their label text, and anything left that is only a URL is
/// dropped.
library;

import '../strings/app_strings.dart';

/// `![alt](url)` — must run before [_mdLink] so the `!` form is consumed first.
final _mdImage = RegExp(r'!\[([^\]]*)\]\([^)]*\)');

/// `[text](url)` — the label survives, the target does not.
final _mdLink = RegExp(r'\[([^\]]*)\]\([^)]*\)');

final _htmlImg = RegExp(r'<img\b[^>]*>', caseSensitive: false);
final _htmlAlt = RegExp(r'''\balt\s*=\s*["']([^"']*)["']''', caseSensitive: false);

/// Paired `<video>…</video>` / `<audio>…</audio>` / `<iframe>…</iframe>` and
/// their self-closing or unpaired forms (including a bare `<source>`).
final _htmlMedia = RegExp(
  r'<(video|audio|iframe)\b[^>]*>[\s\S]*?</\1\s*>|<(video|audio|iframe|source)\b[^>]*/?>',
  caseSensitive: false,
);

/// Whatever URL survived the markup rules — a bare paste, a reference-style
/// link definition, an autolink in angle brackets.
final _bareUrl = RegExp(r'<?\bhttps?://[^\s<>()\[\]"]+>?', caseSensitive: false);

final _leadingWs = RegExp(r'^[ \t]*');
final _innerRun = RegExp(r'[ \t]{2,}');
final _blankLines = RegExp(r'\n{3,}');

String _label(String kind, String? description) {
  final text = (description ?? '').trim();
  return text.isEmpty ? '[$kind]' : '[$kind: $text]';
}

/// Rewrite [input] so no media URL reaches the AI mentor.
///
/// Safe on plain prose and on LaTeX (`$x^2$`, `$$\frac{a}{b}$$`) — none of the
/// rules match a `$…$` span.
String sanitizeAiContext(String input) {
  if (input.isEmpty) return input;

  var out = input.replaceAllMapped(
    _mdImage,
    (m) => _label(AppStrings.blockDisplayTitleImage, m.group(1)),
  );
  out = out.replaceAllMapped(_mdLink, (m) => (m.group(1) ?? '').trim());
  out = out.replaceAllMapped(
    _htmlImg,
    (m) => _label(
      AppStrings.blockDisplayTitleImage,
      _htmlAlt.firstMatch(m.group(0)!)?.group(1),
    ),
  );
  out = out.replaceAllMapped(_htmlMedia, (m) {
    final tag = (m.group(1) ?? m.group(2) ?? '').toLowerCase();
    return tag == 'audio'
        ? '[${AppStrings.blockDisplayTitleAudio}]'
        : '[${AppStrings.blockDisplayTitleVideo}]';
  });
  out = out.replaceAll(_bareUrl, '');

  return _tidy(out);
}

/// Close the gaps left by the removals without reflowing the text: leading
/// indentation stays (nested lists keep their shape), runs of spaces inside a
/// line collapse, and lines emptied by a removal do not pile up as blank space.
String _tidy(String text) {
  final lines = text.split('\n').map((line) {
    final indent = _leadingWs.firstMatch(line)!.group(0)!;
    final body =
        line.substring(indent.length).replaceAll(_innerRun, ' ').trimRight();
    return body.isEmpty ? '' : '$indent$body';
  });
  return lines.join('\n').replaceAll(_blankLines, '\n\n').trim();
}
