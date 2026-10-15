import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/utils/content_format.dart';

void main() {
  group('looksLikeMarkdown — block markers', () {
    test('detects a blockquote line (BR-KYBZ7H)', () {
      const text = 'Jakému pojmu odpovídá tato definice?\n\n'
          '> „Text napsaný v přirozených větách a odstavcích (neveršovaný).“';
      expect(looksLikeMarkdown(text), isTrue);
    });

    test('detects a blockquote on the very first line', () {
      expect(looksLikeMarkdown('> citace'), isTrue);
    });

    test('detects an indented blockquote (up to 3 spaces)', () {
      expect(looksLikeMarkdown('   > citace'), isTrue);
    });

    test('detects ATX headings', () {
      expect(looksLikeMarkdown('# Nadpis'), isTrue);
      expect(looksLikeMarkdown('Text\n### Podnadpis'), isTrue);
    });

    test('detects dash and plus bullet lists', () {
      expect(looksLikeMarkdown('- první\n- druhá'), isTrue);
      expect(looksLikeMarkdown('+ první'), isTrue);
    });

    test('detects ordered lists', () {
      expect(looksLikeMarkdown('1. první\n2. druhá'), isTrue);
    });

    test('detects table rows', () {
      expect(looksLikeMarkdown('| a | b |\n|---|---|\n| 1 | 2 |'), isTrue);
    });
  });

  group('looksLikeMarkdown — inline markers', () {
    test('detects bold, italic and underscores', () {
      expect(looksLikeMarkdown('a **tučně** b'), isTrue);
      expect(looksLikeMarkdown('a *kurzíva* b'), isTrue);
      expect(looksLikeMarkdown('a __tučně__ b'), isTrue);
    });

    test('detects code, images, links and LaTeX', () {
      expect(looksLikeMarkdown('`kód`'), isTrue);
      expect(looksLikeMarkdown('![alt](x.png)'), isTrue);
      expect(looksLikeMarkdown('[odkaz](https://x.cz)'), isTrue);
      expect(looksLikeMarkdown(r'vzorec $a^2$'), isTrue);
    });
  });

  group('looksLikeMarkdown — must not fire', () {
    test('plain prose is not markdown', () {
      expect(looksLikeMarkdown('Toto je běžná věta bez formátování.'), isFalse);
    });

    test('a mid-sentence greater-than is not a blockquote', () {
      expect(looksLikeMarkdown('Teplota > 30 °C je vysoká.'), isFalse);
    });

    test('a hyphenated word is not a bullet list', () {
      expect(looksLikeMarkdown('Přidej e-mail nebo out-of-the-box řešení.'), isFalse);
    });

    test('a decimal number is not an ordered list', () {
      expect(looksLikeMarkdown('Výsledek je 3.14 metru.'), isFalse);
    });

    test('empty text is not markdown', () {
      expect(looksLikeMarkdown(''), isFalse);
    });
  });

  group('looksLikeHtml', () {
    test('detects real tags', () {
      expect(looksLikeHtml('<p>Ahoj</p>'), isTrue);
      expect(looksLikeHtml('řádek<br/>druhý'), isTrue);
      expect(looksLikeHtml('<img src="x.png">'), isTrue);
    });

    test('a comparison is not HTML', () {
      expect(looksLikeHtml('Platí 5 < 10 a 20 > 15.'), isFalse);
    });

    test('a blockquote is not HTML', () {
      expect(looksLikeHtml('> citace s < uvnitř'), isFalse);
    });

    test('plain prose is not HTML', () {
      expect(looksLikeHtml('Toto je běžná věta.'), isFalse);
    });
  });
}
