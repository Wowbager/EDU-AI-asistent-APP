import 'package:flutter/material.dart';
import '../core/utils/content_embeds.dart';
import 'markdown_latex_widget.dart';
import 'video_embed.dart';

/// Markdown + LaTeX content whose inline video embeds render as native players.
///
/// Videos are split out of the text *before* it reaches the markdown parser:
/// flutter_markdown places image widgets inside a `Wrap`, which hands its
/// children unbounded width, so a full-width player cannot live there. Each
/// video therefore becomes a sibling of the surrounding text segments instead.
///
/// Recognises both `![alt](https://…/clip.mp4)` and `<video src="…">` — see
/// [parseContentEmbeds].
class MarkdownMediaWidget extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final Color? textColor;
  final bool selectable;

  /// Forwarded to each text segment. Left null, links route themselves — see
  /// [MarkdownLatexWidget.onTapLink].
  final void Function(String href)? onTapLink;

  const MarkdownMediaWidget({
    super.key,
    required this.content,
    this.textStyle,
    this.textColor,
    this.selectable = true,
    this.onTapLink,
  });

  Widget _text(String value) => MarkdownLatexWidget(
        content: value,
        textStyle: textStyle,
        textColor: textColor,
        selectable: selectable,
        onTapLink: onTapLink,
      );

  @override
  Widget build(BuildContext context) {
    if (!hasVideoEmbed(content)) return _text(content);

    final children = <Widget>[];
    for (final part in parseContentEmbeds(content)) {
      final child = switch (part) {
        VideoPart(:final url) => AppVideoEmbed(videoUrl: url),
        // Trim so the blank lines that surrounded the embed don't leave an
        // empty paragraph above or below the player.
        TextPart(:final text) => _text(text.trim()),
      };
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(child);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
