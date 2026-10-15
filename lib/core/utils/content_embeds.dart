// Parses inline media embeds out of step content so they can render as native
// widgets instead of being dropped by the markdown/HTML renderers.
//
// Handles <video> tags (with nested <source src> or a src attribute on the
// <video> element itself) and markdown image syntax pointing at a video file
// (![alt](https://…/clip.mp4)) — the latter is what editors type in the news
// body, and the markdown renderer would otherwise try to decode it as an image.
// The surrounding text is preserved in document order so a player can be
// interleaved between markdown/HTML segments.

/// One ordered piece of step content: either text (markdown/HTML) or a video.
sealed class ContentPart {
  const ContentPart();
}

/// A run of text (markdown or HTML) between embeds.
class TextPart extends ContentPart {
  final String text;
  const TextPart(this.text);
}

/// A video embed extracted from a <video> tag.
class VideoPart extends ContentPart {
  final String url;
  const VideoPart(this.url);
}

final RegExp _videoTagRe =
    RegExp(r'<video[^>]*>[\s\S]*?</video>', caseSensitive: false);
// Self-closing or attribute-only: <video ... src="..." />  (no closing tag)
final RegExp _videoSelfRe =
    RegExp(r'<video[^>]*/>', caseSensitive: false);
final RegExp _srcRe =
    RegExp(r'''src\s*=\s*["']([^"']+)["']''', caseSensitive: false);

/// Video file extensions we treat as playable when they appear in a markdown
/// image link. Kept to what video_player handles on both iOS and Android.
const String _videoExt = r'(?:mp4|m4v|mov|webm)';

/// Markdown image syntax whose target is a video file:
/// `![alt](https://cdn/clip.mp4 "optional title")`, optional <> around the URL.
final RegExp _videoMarkdownRe = RegExp(
  r'!\[[^\]]*\]\(\s*<?(\S+?\.' + _videoExt + r'(?:\?[^)\s]*)?)>?(?:\s+"[^"]*")?\s*\)',
  caseSensitive: false,
);

/// True when [content] contains a video embed worth extracting.
bool hasVideoEmbed(String content) =>
    content.contains('<video') || _videoMarkdownRe.hasMatch(content);

/// Split [content] into ordered text and video parts.
///
/// Falls back to a single [TextPart] when no video tag is present.
List<ContentPart> parseContentEmbeds(String content) {
  if (!hasVideoEmbed(content)) return [TextPart(content)];

  // Collect every embed candidate — <video>...</video>, self-closing <video/>
  // and markdown ![](…mp4) — with its resolved URL, sorted by position.
  final matches = <({int start, int end, String? url})>[
    for (final m in _videoTagRe.allMatches(content))
      (start: m.start, end: m.end, url: _extractVideoSrc(m.group(0)!)),
    for (final m in _videoSelfRe.allMatches(content))
      (start: m.start, end: m.end, url: _extractVideoSrc(m.group(0)!)),
    for (final m in _videoMarkdownRe.allMatches(content))
      (start: m.start, end: m.end, url: m.group(1)),
  ]..sort((a, b) => a.start.compareTo(b.start));

  // Drop self-closing matches that overlap a full-tag match (the full tag wins).
  final ranges = <({int start, int end, String? url})>[];
  int guard = -1;
  for (final m in matches) {
    if (m.start < guard) continue;
    ranges.add(m);
    guard = m.end;
  }

  final parts = <ContentPart>[];
  int last = 0;
  for (final m in ranges) {
    final before = content.substring(last, m.start);
    if (before.trim().isNotEmpty) parts.add(TextPart(before));

    final url = m.url;
    if (url != null && url.isNotEmpty) parts.add(VideoPart(url));

    last = m.end;
  }
  final rest = content.substring(last);
  if (rest.trim().isNotEmpty) parts.add(TextPart(rest));

  if (parts.isEmpty) parts.add(TextPart(content));
  return parts;
}

/// Pull the first src="..." out of a <video> tag (covers nested <source> too).
String? _extractVideoSrc(String tag) => _srcRe.firstMatch(tag)?.group(1);
