import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/utils/content_embeds.dart';

void main() {
  group('parseContentEmbeds', () {
    test('text only -> single TextPart', () {
      final parts = parseContentEmbeds('hello **world**');
      expect(parts.length, 1);
      expect(parts.first, isA<TextPart>());
      expect((parts.first as TextPart).text, 'hello **world**');
    });

    test('markdown image + nested <source> video (real onboarding case)', () {
      const content =
          'Intro text\n\n![Yes!](https://cdn/ico.webp)\n'
          '<video controls width="640" autoplay muted loop playsinline>\n'
          '  <source src="https://cdn/e-intro.mp4" type="video/mp4">\n'
          '  Your browser does not support the video tag.\n'
          '</video>';
      final parts = parseContentEmbeds(content);
      expect(parts.whereType<VideoPart>().length, 1);
      expect((parts.whereType<VideoPart>().first).url, 'https://cdn/e-intro.mp4');
      // Text before the video (with markdown image) is preserved.
      expect(parts.first, isA<TextPart>());
      expect((parts.first as TextPart).text, contains('![Yes!]'));
    });

    test('src directly on <video> element', () {
      final parts = parseContentEmbeds('<video src="https://cdn/a.mp4"></video>');
      expect(parts.whereType<VideoPart>().single.url, 'https://cdn/a.mp4');
    });

    test('multiple videos with interleaved text, order preserved', () {
      const content =
          'A<video><source src="https://cdn/1.mp4"></video>'
          'B<video><source src="https://cdn/2.mp4"></video>C';
      final parts = parseContentEmbeds(content);
      expect(parts.length, 5);
      expect((parts[0] as TextPart).text, 'A');
      expect((parts[1] as VideoPart).url, 'https://cdn/1.mp4');
      expect((parts[2] as TextPart).text, 'B');
      expect((parts[3] as VideoPart).url, 'https://cdn/2.mp4');
      expect((parts[4] as TextPart).text, 'C');
    });

    test('video tag without a src is dropped, surrounding text kept', () {
      final parts = parseContentEmbeds('before<video></video>after');
      expect(parts.whereType<VideoPart>(), isEmpty);
      expect(parts.whereType<TextPart>().map((t) => t.text), ['before', 'after']);
    });

    test('hasVideoEmbed detects presence', () {
      expect(hasVideoEmbed('x <video></video>'), isTrue);
      expect(hasVideoEmbed('no media here'), isFalse);
    });
  });

  group('parseContentEmbeds — markdown video syntax', () {
    test('markdown image pointing at an mp4 becomes a VideoPart', () {
      final parts = parseContentEmbeds('![](https://cdn/clip.mp4)');
      expect(parts.whereType<VideoPart>().single.url, 'https://cdn/clip.mp4');
      expect(parts.whereType<TextPart>(), isEmpty);
    });

    test('surrounding text is preserved around a markdown video', () {
      final parts = parseContentEmbeds(
        'Před\n\n![Ukázka](https://cdn/clip.mov)\n\nPo',
      );
      expect(parts.length, 3);
      expect((parts[0] as TextPart).text.trim(), 'Před');
      expect((parts[1] as VideoPart).url, 'https://cdn/clip.mov');
      expect((parts[2] as TextPart).text.trim(), 'Po');
    });

    test('markdown image pointing at a picture stays text', () {
      const content = '![Yes!](https://cdn/ico.webp)';
      final parts = parseContentEmbeds(content);
      expect(parts.whereType<VideoPart>(), isEmpty);
      expect((parts.single as TextPart).text, content);
    });

    test('video url with a query string is matched', () {
      final parts =
          parseContentEmbeds('![](https://cdn/clip.mp4?v=2&sig=abc)');
      expect(
        parts.whereType<VideoPart>().single.url,
        'https://cdn/clip.mp4?v=2&sig=abc',
      );
    });

    test('markdown title after the url is not part of the video url', () {
      final parts =
          parseContentEmbeds('![alt](https://cdn/clip.mp4 "Popisek")');
      expect(parts.whereType<VideoPart>().single.url, 'https://cdn/clip.mp4');
    });

    test('plain link (no bang) to an mp4 is left as text', () {
      const content = '[stáhnout](https://cdn/clip.mp4)';
      final parts = parseContentEmbeds(content);
      expect(parts.whereType<VideoPart>(), isEmpty);
      expect((parts.single as TextPart).text, content);
    });

    test('markdown and tag videos keep document order', () {
      const content = 'A\n\n![](https://cdn/1.mp4)\n\nB'
          '<video src="https://cdn/2.mp4"></video>C';
      final parts = parseContentEmbeds(content);
      expect(parts.whereType<VideoPart>().map((v) => v.url),
          ['https://cdn/1.mp4', 'https://cdn/2.mp4']);
      expect(parts.map((p) => p is VideoPart ? 'V' : 'T').join(), 'TVTVT');
    });

    test('uppercase extension is matched', () {
      final parts = parseContentEmbeds('![](https://cdn/CLIP.MP4)');
      expect(parts.whereType<VideoPart>().single.url, 'https://cdn/CLIP.MP4');
    });

    test('hasVideoEmbed detects markdown video syntax', () {
      expect(hasVideoEmbed('![](https://cdn/clip.mp4)'), isTrue);
      expect(hasVideoEmbed('![](https://cdn/pic.png)'), isFalse);
    });
  });
}
