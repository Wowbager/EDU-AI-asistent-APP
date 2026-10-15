import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';

/// BR-KYBZ7H — legacy display steps sniffed HTML with a bare `contains('<')`,
/// so plain prose containing a comparison was parsed into the HTML slot and
/// later stripped by the tag remover.
void main() {
  BlockStep parse(String output, {String format = 'plain_text'}) {
    return BlockStep.fromJsonWithId('s1', {
      'type': 'display',
      'expected_output_format': format,
      'modes': {
        'static': {'output': output},
      },
    });
  }

  test('plain prose with a comparison stays plain text', () {
    final step = parse('Platí 5 < 10 a 20 > 15.');

    expect(step.hasHtmlContent, isFalse);
    expect(step.displayText, 'Platí 5 < 10 a 20 > 15.');
  });

  test('a blockquote containing a comparison stays plain text', () {
    final step = parse('> Platí, že 5 < 10.');

    expect(step.hasHtmlContent, isFalse);
    expect(step.displayText, '> Platí, že 5 < 10.');
  });

  test('real tags in plain_text output are still treated as HTML', () {
    final step = parse('<p>Odstavec</p>');

    expect(step.hasHtmlContent, isTrue);
  });

  test('an explicit html_text format is still treated as HTML', () {
    final step = parse('Bez tagů', format: 'html_text');

    expect(step.hasHtmlContent, isTrue);
  });
}
