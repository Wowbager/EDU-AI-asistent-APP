// What the start-up /api/user check may do to the local "real account" flag
// (users.is_email_validated). AuthWrapper itself cannot be pumped in a widget
// test (see root_navigator_minor_test.dart's header), so the rule lives in
// shouldMarkEmailValidated and is pinned here.
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/routing/account_verification.dart';

void main() {
  group('shouldMarkEmailValidated', () {
    test('heals a login-code student the onboarding turned into a guest '
        '(BR-7U6V36)', () {
      expect(
        shouldMarkEmailValidated(
          isEmailValidated: false,
          email: '',
          serverUser: {'is_guest': false, 'email': null},
        ),
        isTrue,
      );
    });

    test('leaves a real guest a guest', () {
      expect(
        shouldMarkEmailValidated(
          isEmailValidated: false,
          email: '',
          serverUser: {'is_guest': true, 'email': null},
        ),
        isFalse,
      );
    });

    test('does nothing when the server does not say', () {
      expect(
        shouldMarkEmailValidated(
          isEmailValidated: false,
          email: '',
          serverUser: const {},
        ),
        isFalse,
      );
    });

    test('keeps the verify banner for a registered, unverified e-mail', () {
      // Such an account is no guest either — is_guest alone must not clear
      // a flag that is about the e-mail.
      expect(
        shouldMarkEmailValidated(
          isEmailValidated: false,
          email: 'student@example.com',
          serverUser: {'is_guest': false, 'email_verified_at': null},
        ),
        isFalse,
      );
    });

    test('mirrors a server-verified e-mail (BR-3XVWV7)', () {
      expect(
        shouldMarkEmailValidated(
          isEmailValidated: false,
          email: 'student@example.com',
          serverUser: {
            'is_guest': false,
            'email_verified_at': '2026-08-24T10:00:00.000000Z',
          },
        ),
        isTrue,
      );
    });

    test('never writes a flag that is already set', () {
      expect(
        shouldMarkEmailValidated(
          isEmailValidated: true,
          email: '',
          serverUser: {'is_guest': false},
        ),
        isFalse,
      );
    });
  });
}
