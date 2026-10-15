// BR-YS6VC5 — the dashboard greeting card ran its copy across the full card
// width and at a fixed 32px, so a long greeting did both of the things the
// client reported: the right half slid under the mascot that is painted on top
// of the card, and the third line spilled out of the fixed 148px box.
//
// The copy now stops before the artwork and steps its size down until it fits.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/widgets/welcome_card.dart';

/// The longest greeting the dashboard can show (`dashGreetingKeepGoing`).
const _longGreeting = 'Pokračuj v učení a zlepšíš se každý den.';

/// A phone-width card: 390px viewport minus the dashboard's 16px page padding.
const _cardWidth = 358.0;

Future<void> _pumpCard(WidgetTester tester, String description) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _cardWidth,
            child: WelcomeCard(
              title: 'Odvazny Orel',
              description: description,
              // The asset would need a real image binding; the layout under
              // test is the text side, and the mascot's footprint is a
              // constant either way.
              illustrationPath: null,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('long greeting fits the card instead of overflowing it',
      (tester) async {
    await _pumpCard(tester, _longGreeting);

    expect(tester.takeException(), isNull);

    final style = tester.widget<Text>(find.text(_longGreeting)).style!;
    expect(style.fontSize, lessThan(32),
        reason: 'the greeting has to step down to fit the 148px card');

    final size = tester.getSize(find.text(_longGreeting));
    // 148 card − 24/32 padding − the 20px title and its 4px gap.
    expect(size.height, lessThanOrEqualTo(68));
  });

  testWidgets('the greeting stops before the mascot', (tester) async {
    await _pumpCard(tester, _longGreeting);

    // Inside the card's padding the artwork claims everything to its right.
    final expected = WelcomeCard.textWidthFor(_cardWidth - 32);
    expect(expected, lessThan(_cardWidth - 32));
    expect(tester.getSize(find.text(_longGreeting)).width,
        lessThanOrEqualTo(expected));
  });

  testWidgets('short greeting keeps the design size', (tester) async {
    const short = 'Ahoj!';
    await _pumpCard(tester, short);

    expect(tester.widget<Text>(find.text(short)).style!.fontSize, 32);
  });

  testWidgets('a long user name does not push the greeting out',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _cardWidth,
              child: WelcomeCard(
                title: 'Odvazny Orel s velmi dlouhou přezdívkou navíc',
                description: _longGreeting,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text(_longGreeting)).style!.fontSize,
        lessThan(32));
  });
}
