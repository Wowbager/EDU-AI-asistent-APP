/// Whether a login that just completed must stop at the profile onboarding
/// (nickname + color profile + avatar vibe) before the app opens.
///
/// The onboarding is a sign-up step, not a greeting: an account whose profile
/// is already set up lands straight on the dashboard, on every login, on every
/// device and in every browser (BR-D27TFA). It used to be gated on a
/// device-local flag as well — the API had no "onboarded" column, so "first
/// login into the account" was approximated as "first login on this device" —
/// which meant a returning student was asked to customise a profile they
/// already had every time they signed in from a new device, and on the web
/// every time the browser's storage was cleared.
///
/// [profileSetupRequired] is the server's verdict, and it wins. It is now one
/// fact of the account — `users.onboarded_at`, set once when the student
/// finishes and read back by every login path (BR-YXVMKY). Before that each
/// path guessed at it and two guessed wrong in opposite directions: SSO asked
/// whether the account had `selected_subjects`, which nothing on that path
/// ever writes, so every SSO login re-onboarded; a student login code said
/// "no" flatly, so a student never onboarded at all — even though a code is
/// exactly how a student enters the app for the very first time.
///
/// Guests are never onboarded: a guest is not "the account as such", and the
/// course PIN they came with should land them in the course, not in a profile
/// form. Minors count as accounts despite their empty email.
///
/// [activeUserName] catches the accounts no flag covers — an offline sign-up,
/// or a student login code that resolved without a name: no nickname yet means
/// the onboarding still gets asked once.
bool loginNeedsProfileSetup({
  required bool profileSetupRequired,
  required String activeUserEmail,
  required String activeUserName,
  required bool isMinor,
}) {
  if (profileSetupRequired) return true;
  final isGuest = activeUserEmail.trim().isEmpty && !isMinor;
  if (isGuest) return false;
  return activeUserName.trim().isEmpty;
}
