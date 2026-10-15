import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/data/repositories/consent_repository.dart';
import 'package:eduai/pages/consent/consent_confirm_web_page.dart';
import 'package:eduai/pages/consent/consent_manage_web_page.dart';

/// These two pages are the only public, unauthenticated routes a *parent*
/// opens (from an emailed link), never the child. Every result type here is
/// [ConsentActionResult]/[ConsentConfirmResult]/[ConsentManageResult]/
/// [ConsentCodeResult] — never a bare bool — precisely so these tests can
/// pin down "the server said no" vs "the request never arrived" (Task 11
/// note B) and "confirmed, but the mail failed" (Task 11 note C).
void main() {
  group('ConsentConfirmWebPage', () {
    Future<void> pump(WidgetTester tester, Widget page) async {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
    }

    testWidgets('normalises and submits the code, reports success when the mail went out',
        (tester) async {
      String? sentCode;

      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          onConfirm: (code) async {
            sentCode = code;
            return const ConsentConfirmResult.success(totalChildren: 3, mailSent: true);
          },
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ab12cd');
      await tester.tap(find.text('Potvrdit souhlas'));
      await tester.pumpAndSettle();

      expect(sentCode, 'AB12CD', reason: 'the code must be normalised before it is sent');
      expect(find.textContaining('Souhlas potvrzen'), findsOneWidget);
      // The confirmed-but-no-mail copy must not also appear.
      expect(find.textContaining('nepodařilo odeslat'), findsNothing);
    });

    testWidgets('prefills the code from the link, normalised, and submits it unchanged',
        (tester) async {
      String? sentCode;

      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          initialCode: ' ab12cd ',
          onConfirm: (code) async {
            sentCode = code;
            return const ConsentConfirmResult.success(totalChildren: 3, mailSent: true);
          },
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      // BR-FBD2E9: the whole point is that the parent types nothing. The
      // field must already hold the code the same email printed above the
      // link, normalised exactly as _submit() would have normalised it.
      expect(find.widgetWithText(TextField, 'AB12CD'), findsOneWidget);

      await tester.tap(find.text('Potvrdit souhlas'));
      await tester.pumpAndSettle();

      expect(sentCode, 'AB12CD');
      expect(find.textContaining('Souhlas potvrzen'), findsOneWidget);
    });

    testWidgets('a prefilled code is never submitted without an explicit tap',
        (tester) async {
      var confirmCalls = 0;

      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          initialCode: 'AB12CD',
          onConfirm: (_) async {
            confirmCalls++;
            return const ConsentConfirmResult.success(totalChildren: 3, mailSent: true);
          },
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      // Mail link-scanners (SafeLinks & co.) fetch every URL in an incoming
      // message. If merely rendering this page confirmed, one of them would
      // burn a ConsentCode attempt — or grant a legally load-bearing parental
      // consent no human ever saw. Rendering must stay side-effect free.
      expect(confirmCalls, 0);
      expect(find.text('Potvrdit souhlas'), findsOneWidget);
    });

    testWidgets('a link with no code keeps the field empty, as before',
        (tester) async {
      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          onConfirm: (_) async =>
              const ConsentConfirmResult.success(totalChildren: 3, mailSent: true),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, '');
    });

    testWidgets('never claims the inbox was reached when mail_sent is false, and offers recovery',
        (tester) async {
      String? requestedEmail;

      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          onConfirm: (_) async =>
              const ConsentConfirmResult.success(totalChildren: 3, mailSent: false),
          onRequestManageLink: (email) async {
            requestedEmail = email;
            return const ConsentActionResult.success();
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'ab12cd');
      await tester.tap(find.text('Potvrdit souhlas'));
      await tester.pumpAndSettle();

      // Must not say "we emailed you the codes" — that would be a lie.
      expect(find.textContaining('Přihlašovací kódy jsme vám poslali e-mailem'), findsNothing);
      expect(find.textContaining('3'), findsOneWidget);
      expect(find.textContaining('nepodařilo odeslat'), findsOneWidget);

      // The recovery path: "send me the link again", reached from right here.
      expect(find.text('Poslat odkaz znovu'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'rodic@example.com');
      await tester.tap(find.text('Poslat odkaz znovu'));
      await tester.pumpAndSettle();

      expect(requestedEmail, 'rodic@example.com');
      expect(find.textContaining('Pokud e-mail známe'), findsOneWidget);
    });

    testWidgets(
        'a network failure resending the link does not claim success, and the form stays usable',
        (tester) async {
      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          onConfirm: (_) async =>
              const ConsentConfirmResult.success(totalChildren: 3, mailSent: false),
          onRequestManageLink: (_) async =>
              const ConsentActionResult.failure(ConsentFailure.network),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ab12cd');
      await tester.tap(find.text('Potvrdit souhlas'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'rodic@example.com');
      await tester.tap(find.text('Poslat odkaz znovu'));
      await tester.pumpAndSettle();

      // Nothing was actually sent — must not show the neutral "on its way"
      // copy, and the retry action must still be there.
      expect(find.textContaining('Pokud e-mail známe'), findsNothing);
      expect(find.textContaining('zkontroluj připojení k internetu'), findsOneWidget);
      expect(find.text('Poslat odkaz znovu'), findsOneWidget);
    });

    testWidgets('shows the rejected-code copy, not the network copy, when the server said no',
        (tester) async {
      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          onConfirm: (_) async => const ConsentConfirmResult.failure(ConsentFailure.rejected),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.tap(find.text('Potvrdit souhlas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('neplatný nebo vypršel'), findsOneWidget);
      expect(find.textContaining('zkontroluj připojení k internetu'), findsNothing);
    });

    testWidgets('shows the network copy, not the rejected-code copy, when the request never arrived',
        (tester) async {
      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: 'abc-123',
          onConfirm: (_) async => const ConsentConfirmResult.failure(ConsentFailure.network),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'AB12CD');
      await tester.tap(find.text('Potvrdit souhlas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('zkontroluj připojení k internetu'), findsOneWidget);
      expect(find.textContaining('neplatný nebo vypršel'), findsNothing);
    });

    testWidgets('a missing id shows a comprehensible message and never calls onConfirm',
        (tester) async {
      var called = false;

      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: null,
          onConfirm: (_) async {
            called = true;
            return const ConsentConfirmResult.failure(ConsentFailure.rejected);
          },
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      // Only the resend-link form's email field remains — not the 6-char
      // code field, and not a way to reach onConfirm.
      expect(called, isFalse);
      expect(find.text('Potvrdit souhlas'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('an empty id string is treated the same as a missing one', (tester) async {
      var called = false;

      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: '   ',
          onConfirm: (_) async {
            called = true;
            return const ConsentConfirmResult.failure(ConsentFailure.rejected);
          },
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      expect(called, isFalse);
      expect(find.text('Potvrdit souhlas'), findsNothing);
    });

    testWidgets('a missing id still offers the resend-link recovery, not a dead end',
        (tester) async {
      String? requestedEmail;

      await pump(
        tester,
        ConsentConfirmWebPage(
          publicId: null,
          onConfirm: (_) async => const ConsentConfirmResult.failure(ConsentFailure.rejected),
          onRequestManageLink: (email) async {
            requestedEmail = email;
            return const ConsentActionResult.success();
          },
        ),
      );

      expect(find.text('Poslat odkaz znovu'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'rodic@example.com');
      await tester.tap(find.text('Poslat odkaz znovu'));
      await tester.pumpAndSettle();

      expect(requestedEmail, 'rodic@example.com');
      expect(find.textContaining('Pokud e-mail známe'), findsOneWidget);
    });
  });

  group('ConsentManageWebPage', () {
    Future<void> pump(WidgetTester tester, Widget page) async {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
    }

    testWidgets('lists children and shows a regenerated code once', (tester) async {
      await pump(
        tester,
        ConsentManageWebPage(
          token: 'tok',
          loadState: () async => const ConsentManageResult.success(ConsentManageState(
            status: 'confirmed',
            children: [ConsentChild(id: 1, name: 'Stydlivý delfín')],
          )),
          onRegenerate: (_) async => const ConsentCodeResult.success('NEW123'),
          onRevoke: () async => const ConsentActionResult.success(),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      expect(find.text('Stydlivý delfín'), findsOneWidget);
      expect(find.text('NEW123'), findsNothing);

      await tester.tap(find.text('Nový kód'));
      await tester.pumpAndSettle();

      expect(find.text('NEW123'), findsOneWidget);
      expect(find.textContaining('Zapište si ho'), findsOneWidget);
    });

    testWidgets('regenerating twice for one child replaces the shown code, not appends it',
        (tester) async {
      var callCount = 0;

      await pump(
        tester,
        ConsentManageWebPage(
          token: 'tok',
          loadState: () async => const ConsentManageResult.success(ConsentManageState(
            status: 'confirmed',
            children: [ConsentChild(id: 1, name: 'Stydlivý delfín')],
          )),
          onRegenerate: (_) async {
            callCount++;
            return ConsentCodeResult.success(callCount == 1 ? 'FIRST1' : 'SECOND2');
          },
          onRevoke: () async => const ConsentActionResult.success(),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.tap(find.text('Nový kód'));
      await tester.pumpAndSettle();
      expect(find.text('FIRST1'), findsOneWidget);

      await tester.tap(find.text('Nový kód'));
      await tester.pumpAndSettle();

      expect(find.text('FIRST1'), findsNothing);
      expect(find.text('SECOND2'), findsOneWidget);
      expect(callCount, 2);
    });

    testWidgets('double-tapping regenerate before the response lands fires only one request',
        (tester) async {
      var callCount = 0;
      final completer = Completer<ConsentCodeResult>();

      await pump(
        tester,
        ConsentManageWebPage(
          token: 'tok',
          loadState: () async => const ConsentManageResult.success(ConsentManageState(
            status: 'confirmed',
            children: [ConsentChild(id: 1, name: 'Stydlivý delfín')],
          )),
          onRegenerate: (_) async {
            callCount++;
            return completer.future;
          },
          onRevoke: () async => const ConsentActionResult.success(),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.tap(find.text('Nový kód'));
      await tester.pump();
      // Second tap while the first request is still in flight — the button
      // must already be disabled, so this must not fire a second request.
      await tester.tap(find.text('Nový kód'));
      await tester.pump();

      completer.complete(const ConsentCodeResult.success('NEW123'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(find.text('NEW123'), findsOneWidget);
    });

    testWidgets('shows the expired state (with recovery) when the token is dead, not a network error',
        (tester) async {
      await pump(
        tester,
        ConsentManageWebPage(
          token: 'dead-token',
          loadState: () async => const ConsentManageResult.failure(ConsentFailure.rejected),
          onRegenerate: (_) async => const ConsentCodeResult.failure(ConsentFailure.network),
          onRevoke: () async => const ConsentActionResult.success(),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      expect(find.textContaining('Odkaz vypršel'), findsOneWidget);
      expect(find.text('Poslat odkaz znovu'), findsOneWidget);
      expect(find.textContaining('zkontroluj připojení k internetu'), findsNothing);
    });

    testWidgets(
        'a network failure resending the link on the expired-link screen does not claim success',
        (tester) async {
      await pump(
        tester,
        ConsentManageWebPage(
          token: 'dead-token',
          loadState: () async => const ConsentManageResult.failure(ConsentFailure.rejected),
          onRegenerate: (_) async => const ConsentCodeResult.failure(ConsentFailure.network),
          onRevoke: () async => const ConsentActionResult.success(),
          onRequestManageLink: (_) async =>
              const ConsentActionResult.failure(ConsentFailure.network),
        ),
      );

      await tester.enterText(find.byType(TextField), 'rodic@example.com');
      await tester.tap(find.text('Poslat odkaz znovu'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pokud e-mail známe'), findsNothing);
      expect(find.textContaining('zkontroluj připojení k internetu'), findsOneWidget);
      expect(find.text('Poslat odkaz znovu'), findsOneWidget);
    });

    testWidgets('a network failure loading the page is not confused with an expired link',
        (tester) async {
      await pump(
        tester,
        ConsentManageWebPage(
          token: 'tok',
          loadState: () async => const ConsentManageResult.failure(ConsentFailure.network),
          onRegenerate: (_) async => const ConsentCodeResult.failure(ConsentFailure.network),
          onRevoke: () async => const ConsentActionResult.success(),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      // Honest wording: this is a connectivity problem, not a dead/expired link.
      expect(find.textContaining('Odkaz vypršel'), findsNothing);
      expect(find.textContaining('Nepodařilo se načíst'), findsOneWidget);
    });

    testWidgets('a confirmed revoke shows the revoked state', (tester) async {
      await pump(
        tester,
        ConsentManageWebPage(
          token: 'tok',
          loadState: () async => const ConsentManageResult.success(ConsentManageState(
            status: 'confirmed',
            children: [ConsentChild(id: 1, name: 'Stydlivý delfín')],
          )),
          onRegenerate: (_) async => const ConsentCodeResult.success('NEW123'),
          onRevoke: () async => const ConsentActionResult.success(),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.tap(find.text('Odvolat souhlas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Odvolat souhlas'));
      await tester.pumpAndSettle();

      expect(find.text('Souhlas byl odvolán.'), findsOneWidget);
      // The confirmation dialog explained the timeline before the parent
      // committed — the terminal screen must restate it, since the manage
      // link stays usable for 24h and a parent can land back here later.
      expect(find.textContaining('smažeme do 30 dní'), findsOneWidget);
    });

    testWidgets('cancelling the revoke confirmation leaves onRevoke uncalled', (tester) async {
      var revokeCalled = false;

      await pump(
        tester,
        ConsentManageWebPage(
          token: 'tok',
          loadState: () async => const ConsentManageResult.success(ConsentManageState(
            status: 'confirmed',
            children: [ConsentChild(id: 1, name: 'Stydlivý delfín')],
          )),
          onRegenerate: (_) async => const ConsentCodeResult.success('NEW123'),
          onRevoke: () async {
            revokeCalled = true;
            return const ConsentActionResult.success();
          },
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.tap(find.text('Odvolat souhlas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ne'));
      await tester.pumpAndSettle();

      expect(revokeCalled, isFalse);
      expect(find.text('Souhlas byl odvolán.'), findsNothing);
      // Still on the normal manage screen — the revoke button is there to
      // try again, not stuck on a dialog or an error state.
      expect(find.text('Odvolat souhlas'), findsOneWidget);
    });

    testWidgets('a network failure mid-revoke does not claim the consent was revoked',
        (tester) async {
      await pump(
        tester,
        ConsentManageWebPage(
          token: 'tok',
          loadState: () async => const ConsentManageResult.success(ConsentManageState(
            status: 'confirmed',
            children: [ConsentChild(id: 1, name: 'Stydlivý delfín')],
          )),
          onRegenerate: (_) async => const ConsentCodeResult.success('NEW123'),
          onRevoke: () async => const ConsentActionResult.failure(ConsentFailure.network),
          onRequestManageLink: (_) async => const ConsentActionResult.success(),
        ),
      );

      await tester.tap(find.text('Odvolat souhlas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Odvolat souhlas'));
      await tester.pumpAndSettle();

      expect(find.text('Souhlas byl odvolán.'), findsNothing);
      expect(find.textContaining('zkontroluj připojení k internetu'), findsOneWidget);
      // The retry action must still be there — the wifi could come back.
      expect(find.text('Odvolat souhlas'), findsOneWidget);
    });
  });
}
