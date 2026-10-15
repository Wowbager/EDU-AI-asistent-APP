import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/widgets/markdown_media_widget.dart';
import 'package:eduai/widgets/markdown_latex_widget.dart';
import 'package:eduai/widgets/video_embed.dart';

// Regression test for BR-8JA266: a video linked from a news body with markdown
// image syntax used to fall through to flutter_markdown's default image
// builder, which tried to decode the mp4 as a picture and rendered a broken
// image. The body must be split so videos render as native players.

Widget _host(String content) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownMediaWidget(content: content),
        ),
      ),
    );

void main() {
  testWidgets('markdown video link renders a player, not an image',
      (tester) async {
    await tester.pumpWidget(_host(
      'Nová lekce je venku!\n\n![](https://cdn/clip.mp4)',
    ));
    await tester.pump();

    expect(find.byType(AppVideoEmbed), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    // Surrounding text still renders as markdown.
    expect(find.byType(MarkdownLatexWidget), findsOneWidget);
  });

  testWidgets('<video> tag in the body renders a player', (tester) async {
    await tester.pumpWidget(_host(
      'Před\n<video controls><source src="https://cdn/a.mp4"></video>',
    ));
    await tester.pump();

    expect(find.byType(AppVideoEmbed), findsOneWidget);
  });

  testWidgets('body without video renders a single markdown widget',
      (tester) async {
    await tester.pumpWidget(_host(r'Jen **text** a $x^2$ vzorec.'));
    await tester.pump();

    expect(find.byType(AppVideoEmbed), findsNothing);
    expect(find.byType(MarkdownLatexWidget), findsOneWidget);
  });

  testWidgets('two videos both render players', (tester) async {
    await tester.pumpWidget(_host(
      '![](https://cdn/1.mp4)\n\nmezitext\n\n![](https://cdn/2.mp4)',
    ));
    await tester.pump();

    expect(find.byType(AppVideoEmbed), findsNWidgets(2));
  });
}
