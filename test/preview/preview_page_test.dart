import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/preview/preview_channel.dart';
import 'package:eduai/preview/preview_page.dart';

// What the editor's browser suite reads from the player instead of pixels:
// `inspected`, the reply to `inspect`, and the names the accessibility layer gives
// the card's own buttons. Both only report; neither may change what is drawn.

class _FakeChannel implements PreviewChannel {
  void Function(Map<String, dynamic> message)? _onMessage;
  final sent = <Map<String, dynamic>>[];

  @override
  void listen(void Function(Map<String, dynamic> message) onMessage) => _onMessage = onMessage;

  @override
  void send(Map<String, dynamic> message) => sent.add(message);

  @override
  void dispose() {}

  void post(Map<String, dynamic> message) => _onMessage!(message);

  Map<String, dynamic> lastOf(String type) => sent.lastWhere((m) => m['type'] == type);
}

Map<String, dynamic> _block(String id, List<String> steps, {String? hint}) => {
      'block_id': id,
      'type': 'display',
      if (hint != null) 'hint': hint,
      'steps': [
        for (var i = 0; i < steps.length; i++)
          {'id': 's${i + 1}', 'type': 'text', 'order': i + 1, 'content': steps[i]},
      ],
    };

void main() {
  Future<_FakeChannel> open(WidgetTester tester) async {
    final channel = _FakeChannel();
    await tester.pumpWidget(MaterialApp(home: PreviewPage(channel: channel)));
    await tester.pump();
    return channel;
  }

  Future<Map<String, dynamic>> inspect(WidgetTester tester, _FakeChannel channel, int id) async {
    channel.post({'type': 'inspect', 'id': id});
    await tester.pumpAndSettle();
    final reply = channel.lastOf('inspected');
    expect(reply['id'], id, reason: 'the reply names the request it answers');
    return reply;
  }

  testWidgets('before any content, it says there is none', (tester) async {
    final channel = await open(tester);
    expect(channel.sent.first, {'type': 'ready'});
    final reply = await inspect(tester, channel, 1);
    expect(reply['content'], 'none');
  });

  testWidgets('Náhled: the card sent, every step, and the focused one', (tester) async {
    final channel = await open(tester);
    channel.post({
      'type': 'setBlock',
      'block': _block('B1', ['První', 'Druhý']),
      'exportMode': 'course_v2',
      'view': 'expanded',
      'stepId': 's2',
    });
    await tester.pumpAndSettle();
    final reply = await inspect(tester, channel, 2);
    expect(reply, containsPair('content', 'block'));
    expect(reply, containsPair('view', 'expanded'));
    expect(reply, containsPair('blockId', 'B1'));
    expect(reply, containsPair('stepId', 's2'));
    expect(reply['shownStepIds'], ['s1', 's2']);
    expect(channel.sent.where((m) => m['type'] == 'stepChanged'), isEmpty,
        reason: 'inspect reports; it is not a move');
  });

  testWidgets('Náhled: a card made of several blocks shows them all, in order', (tester) async {
    final channel = await open(tester);
    channel.post({
      'type': 'setBlock',
      'block': [
        _block('B1', ['První']),
        {..._block('B1_2', ['Druhý']), 'steps': [
          {'id': 's2', 'type': 'text', 'order': 1, 'content': 'Druhý'},
        ]},
      ],
      'exportMode': 'course_v2',
      'view': 'expanded',
      'stepId': 's2',
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('První'), findsOneWidget);
    expect(find.textContaining('Druhý'), findsOneWidget);
    final reply = await inspect(tester, channel, 5);
    expect(reply['blockIds'], ['B1', 'B1_2']);
    expect(reply['shownStepIds'], ['s1', 's2']);
    expect(reply['stepId'], 's2');
  });

  testWidgets('Vyzkoušet: where the pupil is, as stepChanged said', (tester) async {
    final channel = await open(tester);
    channel.post({
      'type': 'setLesson',
      'course': {
        'course_id': 'C1',
        'lessons': [
          {
            'lesson_id': 'L1',
            'blocks': [
              {'block_id': 'B1', 'order': 1},
              {'block_id': 'B2', 'order': 2},
            ],
          },
        ],
        'blocks': [_block('B1', ['a', 'b']), _block('B2', ['c'])],
      },
      'lessonId': 'L1',
      'exportMode': 'course_v2',
      'view': 'play',
    });
    await tester.pumpAndSettle();
    final moved = channel.lastOf('stepChanged');
    final reply = await inspect(tester, channel, 3);
    expect(reply, containsPair('content', 'lesson'));
    expect(reply, containsPair('lessonId', 'L1'));
    expect(reply['blockId'], moved['blockId']);
    expect(reply['stepId'], moved['stepId']);
    expect(reply['shownStepIds'], moved['shownStepIds']);
    expect(reply['canGoBack'], false);
  });

  testWidgets('a broken draft is reported as an error, not a crash', (tester) async {
    final channel = await open(tester);
    channel.post({'type': 'setBlock', 'block': 'not a block', 'view': 'expanded'});
    await tester.pumpAndSettle();
    final reply = await inspect(tester, channel, 4);
    expect(reply['content'], 'error');
    expect(reply['error'], isNotEmpty);
  });

  testWidgets('the card\'s own buttons have names', (tester) async {
    final semantics = tester.ensureSemantics();
    final channel = await open(tester);
    channel.post({
      'type': 'setBlock',
      'block': _block('B1', ['První'], hint: 'Zkus to'),
      'exportMode': 'course_v2',
      'view': 'play',
    });
    await tester.pumpAndSettle();
    for (final name in ['Uložit do záložek', 'Líbí se mi', 'Nelíbí se mi', 'Nápověda']) {
      expect(find.bySemanticsLabel(name), findsOneWidget, reason: name);
    }
    expect(find.bySemanticsLabel(RegExp('^(Pokračovat|Hotovo)\$')), findsWidgets);
    semantics.dispose();
  });
}
