import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/utils/ai_context_sanitizer.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/lesson_detail_page.dart';

/// BR-KFHPAR — the "Zeptat se AI" context was assembled verbatim from Block V2
/// markdown, so a step's image embed (`![náměstí](https://pub-….r2.dev/…)`) put
/// a raw URL into the student's message bubble and into the prompt. The model
/// cannot open links, and ~90 characters of URL ate into the 400-character
/// task-content budget that the assignment itself needs.
void main() {
  group('sanitizeAiContext', () {
    test('markdown image collapses to its alt text', () {
      expect(
        sanitizeAiContext(
            'Obsah úlohy: ![náměstí](https://pub-7a82.r2.dev/img/x.png)'),
        'Obsah úlohy: [Obrázek: náměstí]',
      );
    });

    test('image without alt keeps a bare label', () {
      expect(sanitizeAiContext('![](https://pub-7a82.r2.dev/x.png)'), '[Obrázek]');
    });

    test('link keeps its label and loses the target', () {
      expect(
        sanitizeAiContext(
            'Podívej se na [CERMAT](https://prijimacky.cermat.cz) a pokračuj.'),
        'Podívej se na CERMAT a pokračuj.',
      );
    });

    test('bare url is dropped', () {
      expect(
        sanitizeAiContext('Zdroj: https://example.com/a/b?c=d a dál'),
        'Zdroj: a dál',
      );
    });

    test('html media collapses to labels', () {
      expect(
        sanitizeAiContext('<img src="https://x.dev/g.png" alt="graf"> '
            '<video src="https://x.dev/v.mp4"></video> '
            '<audio src="https://x.dev/a.mp3"></audio>'),
        '[Obrázek: graf] [Video] [Audio]',
      );
    });

    test('latex and prose are left alone', () {
      const input = 'Vyřeš \$x^2 + 1 = 0\$ a pak \$\$\\frac{a}{b}\$\$.\n'
          '- první\n- druhý';

      expect(sanitizeAiContext(input), input);
    });

    test('a line emptied by a removal does not leave a hole', () {
      expect(
        sanitizeAiContext(
            'Zadání:\n\nhttps://pub-7a82.r2.dev/x.png\n\nHotovo'),
        'Zadání:\n\nHotovo',
      );
    });

    test('nested list indentation survives', () {
      expect(
        sanitizeAiContext('- první\n  - ![mapa](https://pub-7a82.r2.dev/m.png)'),
        '- první\n  - [Obrázek: mapa]',
      );
    });

    test('empty input is returned untouched', () {
      expect(sanitizeAiContext(''), '');
    });
  });

  group('buildLessonChatContext', () {
    // The exact shape from the report: a statistics step whose markdown body
    // ends with an R2 image embed.
    ContentBlock statisticsBlock() => ContentBlock(
          blockId: 'b1',
          type: BlockType.question,
          steps: const [
            BlockStep(
              stepId: 's1',
              type: StepType.evaluation,
              content: StepContent(
                text: 'Těmto informacím říkáme DATA.\n'
                    '![náměstí](https://pub-7a82ccbfca9a4f4aa1e25276ad59c86a.r2.dev/x.png)',
              ),
              hint: 'Statistika je důležitá',
              help: 'Podívej se na [zdroj](https://example.com/statistika)',
              evaluationConfig: EvaluationConfig(type: 'open'),
            ),
          ],
        );

    test('no media url reaches the AI context', () {
      final context = buildLessonChatContext(
        block: statisticsBlock(),
        courseName: 'Statistika pro ZŠ',
        lessonName: 'Statistika - Data a základní pojmy',
        liveStepIndex: 0,
      );

      expect(context, isNot(contains('http')));
      expect(context, isNot(contains('r2.dev')));

      // The task text and the image's description both survive.
      expect(context, contains('Těmto informacím říkáme DATA.'));
      expect(context, contains('[Obrázek: náměstí]'));

      // Hint and help are sanitised too — the link label stays, the URL goes.
      expect(context, contains('Statistika je důležitá'));
      expect(context, contains('Podívej se na zdroj'));
    });
  });
}
