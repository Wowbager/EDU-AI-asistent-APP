import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/theme/app_text_styles.dart';
import 'package:eduai/widgets/markdown_latex_widget.dart';

/// BR-PM7XQ3 — [MarkdownLatexWidget.textStyle] was declared and then never
/// read, so every caller that asked for a smaller body got the default 15px
/// anyway. Honouring it is what lets the feedback card render the model answer
/// at the size of its own sections.
void main() {
  Future<void> pump(
    WidgetTester tester,
    String markdown, {
    TextStyle? textStyle,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownLatexWidget(content: markdown, textStyle: textStyle),
      ),
    ));
  }

  MarkdownStyleSheet sheet(WidgetTester tester) =>
      tester.widget<MarkdownBody>(find.byType(MarkdownBody).first).styleSheet!;

  testWidgets('a caller-supplied style drives the paragraph type',
      (tester) async {
    await pump(tester, 'Bezny odstavec.', textStyle: AppTextStyles.meta());

    expect(sheet(tester).p!.fontSize, AppTextStyles.meta().fontSize);
    expect(sheet(tester).listBullet!.fontSize, AppTextStyles.meta().fontSize);
  });

  testWidgets('inline math follows the caller-supplied size', (tester) async {
    await pump(tester, r'Hodnota $a$ je ctyri.',
        textStyle: AppTextStyles.meta());

    final math = tester.widget<Math>(find.byType(Math));
    expect(math.textStyle!.fontSize, AppTextStyles.meta().fontSize);
  });

  testWidgets('without a style the body keeps the default size', (tester) async {
    await pump(tester, 'Bezny odstavec.');

    expect(sheet(tester).p!.fontSize, AppTextStyles.body().fontSize);
  });

  testWidgets('without a style inline math keeps the default size',
      (tester) async {
    await pump(tester, r'Hodnota $a$ je ctyri.');

    final math = tester.widget<Math>(find.byType(Math));
    expect(math.textStyle!.fontSize, AppTextStyles.body().fontSize);
  });

  testWidgets('display math stays a step larger than the body', (tester) async {
    await pump(tester, r'$$a = 4$$', textStyle: AppTextStyles.meta());

    // A display formula is split at the top-level `=`, so it renders as more
    // than one Math widget; they all carry the same size.
    final math = tester.widget<Math>(find.byType(Math).first);
    expect(math.textStyle!.fontSize,
        greaterThan(AppTextStyles.meta().fontSize!));
  });
}
