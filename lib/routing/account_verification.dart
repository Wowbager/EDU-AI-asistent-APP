/// Whether the start-up `/api/user` check has to flag the local row as a
/// verified account (`users.is_email_validated`).
///
/// The server owns that fact; the local column is a mirror. It only ever
/// moves false → true, and only on the server's say-so — so the "verify your
/// e-mail" banner and the guest sign-up prompt never disappear for someone
/// who genuinely still needs them.
///
/// [serverUser] is the `/api/user` payload. A row written unverified (SSO
/// sign-up, verification skipped offline) converges once the server reports
/// `email_verified_at` (BR-3XVWV7).
///
/// An e-mail-less row is the other case: a student who signs in with a login
/// code has no e-mail by design, and the flag is all that tells them apart
/// from a guest (see `canOfferSignupProvider`). The onboarding used to
/// re-create such a row without it, leaving a signed-in student with the
/// guest prompt (BR-7U6V36); `is_guest: false` from the server restores it
/// on the next start. A row that has an e-mail is left to the rule above —
/// not being a guest says nothing about whether the e-mail is verified.
bool shouldMarkEmailValidated({
  required bool isEmailValidated,
  required String email,
  required Map<String, dynamic> serverUser,
}) {
  if (isEmailValidated) return false;
  if (serverUser['email_verified_at'] != null) return true;
  return email.trim().isEmpty && serverUser['is_guest'] == false;
}
