// BR-D27TFA: signing in as an existing user (by e-mail code or by student
// login code) ran the profile onboarding again instead of opening the
// dashboard. The onboarding was gated on a device-local SharedPreferences
// flag, so every new device — and, on the web, every cleared browser profile
// — counted as a "first login" for an account that had been set up long ago.
//
// AuthWrapper itself cannot be pumped in a widget test (its build() wraps
// every state in InactivityWatcher, whose real Timer.periodic and
// dispose()-time ref.read() deadlock flutter_test's teardown — see
// test/widgets/root_navigator_minor_test.dart's header for the write-up), so
// the decision lives in loginNeedsProfileSetup() and the three handlers
// (_handleOAuthSuccess, _handleVerificationComplete, _handlePinLoginComplete)
// call it through _needsProfileSetup(). These tests exercise the real rule.
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/routing/login_destination.dart';

void main() {
  group('loginNeedsProfileSetup', () {
    test('a returning account goes straight to the app', () {
      // The bug: no device-local flag on this browser, yet the account has a
      // nickname and the server does not ask for setup.
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: false,
          activeUserEmail: 'student@example.com',
          activeUserName: 'Marco Polo 2.',
          isMinor: false,
        ),
        isFalse,
      );
    });

    test('a student login code into an onboarded account skips the onboarding',
        () {
      // The code path now passes the server's verdict; for a student who
      // signs in every morning that is false, and auth_page has just written
      // the resolved name onto the local row.
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: false,
          activeUserEmail: 'student@example.com',
          activeUserName: 'Jana N.',
          isMinor: false,
        ),
        isFalse,
      );
    });

    test("a student's first code login is onboarded despite having a name",
        () {
      // BR-YXVMKY: the teacher created this account, so the local row is
      // already complete — a name, a real e-mail — and every local signal
      // says "returning user". Only the server knows the student has never
      // opened the app, and that verdict has to win.
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: true,
          activeUserEmail: 'jana@skola.cz',
          activeUserName: 'Jana Nováková',
          isMinor: false,
        ),
        isTrue,
      );
    });

    test("a minor's first code login is onboarded too", () {
      // A minor's row has no e-mail, the shape the guest branch matches on —
      // so the guest short-circuit must not swallow the server's verdict.
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: true,
          activeUserEmail: '',
          activeUserName: 'Stydlivý delfín',
          isMinor: true,
        ),
        isTrue,
      );
    });

    test('the server asking for setup wins over the local row', () {
      // A sign-up still has the guest's row (empty e-mail) at this point —
      // ProfileSetupPage is what creates the account's own row — so the
      // guest rule must not short-circuit it.
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: true,
          activeUserEmail: '',
          activeUserName: 'Host',
          isMinor: false,
        ),
        isTrue,
      );
    });

    test('a guest is never onboarded', () {
      // A course PIN created this row; the course is what they came for.
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: false,
          activeUserEmail: '',
          activeUserName: 'Host',
          isMinor: false,
        ),
        isFalse,
      );
    });

    test('an account with no nickname yet is still asked once', () {
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: false,
          activeUserEmail: 'student@example.com',
          activeUserName: '   ',
          isMinor: false,
        ),
        isTrue,
      );
    });

    test('a minor counts as an account despite the empty e-mail', () {
      // Minors have no e-mail on their local row (BR-8FDF37 keeps them out of
      // the server sync), so they must not fall into the guest branch — but a
      // set-up minor still skips the onboarding.
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: false,
          activeUserEmail: '',
          activeUserName: '',
          isMinor: true,
        ),
        isTrue,
      );
      expect(
        loginNeedsProfileSetup(
          profileSetupRequired: false,
          activeUserEmail: '',
          activeUserName: 'Školní jméno',
          isMinor: true,
        ),
        isFalse,
      );
    });
  });
}
