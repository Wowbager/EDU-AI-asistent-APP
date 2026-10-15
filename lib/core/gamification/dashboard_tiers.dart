import '../strings/app_strings.dart';

/// XP thresholds that reshape the dashboard as the learner progresses
/// (BR-ERUJBY).
///
/// One place on purpose: the greeting subtitle is rendered twice — the phone
/// welcome card and the desktop shell's top bar — and the two used to be
/// separate constants that drifted apart. Everything here is a pure function
/// of `xpPoints`, so the tiers are unit-testable without a widget tree.
///
/// The bounds are exclusive (`xp > threshold`), matching how the product spec
/// is written ("XP>50 …", "XP>100 …").
class DashboardTiers {
  const DashboardTiers._();

  /// Above this the "Začněte s návodem" challenge becomes "Procvičování".
  static const int practiceInsteadOfGuide = 30;

  /// Above this the streak/trophy panels drop their encouragement line
  /// ("Skvělá práce!…", "Sbírej trofeje…") and shrink (BR-Q7FFF3). Same rung as
  /// [practiceInsteadOfGuide] by coincidence of the spec, not by definition.
  static const int statEncouragement = 30;

  /// Greeting subtitle steps.
  static const int greetingKeepGoing = 50;
  static const int greetingProud = 100;
  static const int greetingCheering = 200;

  /// Above this the Knihovna banner advertises the mini-game reward.
  static const int promoReward = 70;

  /// Above this the trophy half-tile becomes the shop, and the entrance-exam
  /// banner points at the Cermatík chat instead of the intro course.
  static const int shopInsteadOfTrophies = 100;
  static const int cermatikInsteadOfJpz = 100;

  /// Subtitle under "Ahoj, {jméno}! 👋".
  static String greetingSubtitle(int xp) {
    if (xp > greetingCheering) return AppStrings.dashGreetingCheering;
    if (xp > greetingProud) return AppStrings.dashGreetingProud;
    if (xp > greetingKeepGoing) return AppStrings.dashGreetingKeepGoing;
    return AppStrings.dashGreetingWelcome;
  }

  /// The learner has done enough that the onboarding course is no longer the
  /// thing to put in front of them; practice takes the slot.
  static bool showsPractice(int xp) => xp > practiceInsteadOfGuide;

  /// The caption under the streak/trophy value. It is onboarding scaffolding —
  /// past the first rung it is just two lines of height on a tile whose number
  /// already says everything.
  static bool showsStatEncouragement(int xp) => xp <= statEncouragement;

  /// Knihovna banner copy: the plain invitation, or the one that names the
  /// mini-game waiting in Doplňky.
  static bool showsPromoReward(int xp) => xp > promoReward;

  /// The second half-tile: trophies for newcomers, the avatar shop later —
  /// trophies stay reachable by tapping the streak tile or the XP badge.
  static bool showsShop(int xp) => xp > shopInsteadOfTrophies;

  /// The entrance-exam banner: intro course first, Cermatík once the learner
  /// is invested enough for a conversation to beat a course.
  static bool showsCermatik(int xp) => xp > cermatikInsteadOfJpz;
}
