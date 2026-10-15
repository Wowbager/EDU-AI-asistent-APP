import 'package:flutter/foundation.dart';

import '../util/decimal_display.dart';
import 'locale_manager.dart';

/// Centralized user-facing strings for the EDU AI app.
///
/// Values are resolved at runtime against [LocaleManager.current], so the
/// entire UI follows the active locale. To change wording, edit the [_cz],
/// [_sk] and [_en] maps below. Technical strings (API keys, route names,
/// debug logs) are NOT included here.
///
/// All three maps must hold the same key set — `app_strings_test.dart`
/// enforces it. A missing key does not throw, it silently falls back, so
/// the test is the only thing that catches a forgotten translation.
///
/// **Important:** these are non-const getters. You cannot use
/// `const Text(AppStrings.x)` — drop the `const` keyword. The static
/// function entries (e.g. [genericError]) interpolate against the active
/// locale at call time.
class AppStrings {
  AppStrings._();

  /// The raw translation tables, keyed by locale.
  ///
  /// Exposed only so `app_strings_test.dart` can assert the three maps hold
  /// identical key sets — a missing key falls back silently at runtime, so
  /// nothing else would catch a forgotten translation.
  @visibleForTesting
  static Map<AppLocale, Map<String, String>> get translationTables => {
        AppLocale.cs: _cz,
        AppLocale.sk: _sk,
        AppLocale.en: _en,
      };

  // ── Internal lookup ───────────────────────────────────────────────────

  static String _t(String key) {
    final cz = _cz[key];
    final sk = _sk[key];
    final en = _en[key];
    switch (LocaleManager.current) {
      case AppLocale.cs:
        return cz ?? en ?? key;
      // Slovak falls back to Czech, not English — a missing key then shows
      // the closest language rather than switching the user to English.
      case AppLocale.sk:
        return sk ?? cz ?? en ?? key;
      case AppLocale.en:
        return en ?? cz ?? key;
    }
  }

  /// Locale-picks an interpolated string. Used by the entries below that
  /// splice a value into the sentence and therefore cannot live in the
  /// key maps. All three arguments are required so adding a locale breaks
  /// the build at every call site instead of silently falling back.
  static String _pick({
    required String cz,
    required String sk,
    required String en,
  }) {
    switch (LocaleManager.current) {
      case AppLocale.cs:
        return cz;
      case AppLocale.sk:
        return sk;
      case AppLocale.en:
        return en;
    }
  }

  // ── Navigation ──
  static String get navPrehled => _t('navPrehled');
  static String get navChat => _t('navChat');
  static String get navKurzy => _t('navKurzy');
  static String get navNovinky => _t('navNovinky');


  // ── Desktop / tablet shell ──
  static String get shellDashboardSubtitle => _t('shellDashboardSubtitle');
  static String get shellKurzySubtitle => _t('shellKurzySubtitle');
  static String get shellGuestCtaTitle => _t('shellGuestCtaTitle');
  static String get shellGuestCtaButton => _t('shellGuestCtaButton');
  static String get shellGames => _t('shellGames');
  static String get shellShop => _t('shellShop');

  // ── Dashboard: progress ring ──
  static String get progressCardTitle => _t('progressCardTitle');
  static String get progressCardCompleted => _t('progressCardCompleted');
  static String get progressCardDetail => _t('progressCardDetail');
  static String get progressCardHintStart => _t('progressCardHintStart');
  static String get progressCardHintGoing => _t('progressCardHintGoing');
  static String get progressCardHintDone => _t('progressCardHintDone');

  /// "4 z 16 lekcí" / "4 of 16 lessons"
  static String progressCardLessons(int done, int total) =>
      _t('progressCardLessons')
          .replaceAll('{done}', '$done')
          .replaceAll('{total}', '$total');

  // ── Dashboard: continue lesson ──
  static String get continueLessonTitle => _t('continueLessonTitle');
  static String get continueLessonBadge => _t('continueLessonBadge');
  static String get continueLessonButton => _t('continueLessonButton');
  static String get continueLessonEmpty => _t('continueLessonEmpty');
  static String get continueLessonAllDone => _t('continueLessonAllDone');
  static String get continueLessonQuizOnly => _t('continueLessonQuizOnly');
  static String get continueLessonOpenCourse =>
      _t('continueLessonOpenCourse');

  /// "2 z 4 kroků" / "2 of 4 steps"
  static String continueLessonSteps(int done, int total) =>
      _t('continueLessonSteps')
          .replaceAll('{done}', '$done')
          .replaceAll('{total}', '$total');

  // ── Dashboard: recent activity ──
  static String get recentActivityTitle => _t('recentActivityTitle');
  static String get recentActivityShowAll => _t('recentActivityShowAll');
  static String get recentActivityEmpty => _t('recentActivityEmpty');

  // ── Kurzy: wide layout ──
  static String get kurzySearchHint => _t('kurzySearchHint');
  static String get kurzyFilterButton => _t('kurzyFilterButton');
  static String get kurzySearchEmpty => _t('kurzySearchEmpty');
  static String get courseCardStart => _t('courseCardStart');
  static String get courseCardContinue => _t('courseCardContinue');
  static String get courseCardReview => _t('courseCardReview');

  // ── Course detail: wide layout ──
  static String get courseBackToAll => _t('courseBackToAll');
  static String get courseTabLessons => _t('courseTabLessons');
  static String get courseTabAbout => _t('courseTabAbout');
  static String get courseTabSkills => _t('courseTabSkills');
  static String get courseTabStats => _t('courseTabStats');
  static String get courseSaveButton => _t('courseSaveButton');
  static String get courseShowFewerLessons => _t('courseShowFewerLessons');
  static String get courseOpenLesson => _t('courseOpenLesson');
  static String get courseSkillsInCourse => _t('courseSkillsInCourse');
  static String get courseSkillsEmpty => _t('courseSkillsEmpty');
  static String get courseStatsPlaceholder => _t('courseStatsPlaceholder');
  static String get courseDetailedStats => _t('courseDetailedStats');
  static String get courseTrophyHint => _t('courseTrophyHint');

  // ── Lesson detail: wide layout ──
  static String get lessonAiHelpTitle => _t('lessonAiHelpTitle');
  static String get lessonAiHelpQuestion => _t('lessonAiHelpQuestion');
  static String get lessonAiHelpBody => _t('lessonAiHelpBody');
  static String get lessonAiHelpButton => _t('lessonAiHelpButton');

  /// "Zobrazit všechny lekce (8)"
  static String courseShowAllLessons(int count) =>
      _t('courseShowAllLessons').replaceAll('{count}', '$count');

  /// "Úroveň: Začátečník"
  static String courseLevelLabel(String level) =>
      _t('courseLevelLabel').replaceAll('{level}', level);

  /// "Úroveň 2"
  static String skillLevelLabel(int level) =>
      _t('skillLevelLabel').replaceAll('{level}', '$level');

  /// "8 kurzů" / "8 kurzov" / "8 courses"
  static String kurzyCount(int count) {
    switch (LocaleManager.current) {
      case AppLocale.cs:
        if (count == 1) return '1 kurz';
        if (count >= 2 && count <= 4) return '$count kurzy';
        return '$count kurzů';
      case AppLocale.sk:
        if (count == 1) return '1 kurz';
        if (count >= 2 && count <= 4) return '$count kurzy';
        return '$count kurzov';
      case AppLocale.en:
        return count == 1 ? '1 course' : '$count courses';
    }
  }

  // ── App ──
  static String get appTitle => _t('appTitle');
  static String get appName => _t('appName');

  // ── Welcome / Home ──
  static String get welcomeGreeting => _t('welcomeGreeting');
  static String get welcomeDescription => _t('welcomeDescription');
  static String get guideHeading => _t('guideHeading');
  static String get guideTitle => _t('guideTitle');
  static String get guideSubtitle => _t('guideSubtitle');
  static String get guideButton => _t('guideButton');
  static String get onboardingLoadError => _t('onboardingLoadError');
  static String get practiceTitle => _t('practiceTitle');
  static String get practiceStart => _t('practiceStart');
  static String get practiceEmpty => _t('practiceEmpty');
  static String get practiceDashSubtitle => _t('practiceDashSubtitle');
  static String get practiceBonusHint => _t('practiceBonusHint');
  static String get practiceBonusStart => _t('practiceBonusStart');
  static String get practiceScopeTitle => _t('practiceScopeTitle');
  static String get practiceScopeAllHint => _t('practiceScopeAllHint');
  static String get practiceScopeSelectAll => _t('practiceScopeSelectAll');
  static String get practiceScopeOther => _t('practiceScopeOther');
  static String get practiceScopeEmpty => _t('practiceScopeEmpty');
  static String get promoBadge => _t('promoBadge');
  static String get promoTitle => _t('promoTitle');
  static String get promoDescription => _t('promoDescription');
  static String get promoDescriptionReward => _t('promoDescriptionReward');

  // ── XP-tiered dashboard (BR-ERUJBY) ──
  static String get dashGreetingWelcome => _t('dashGreetingWelcome');
  static String get dashGreetingKeepGoing => _t('dashGreetingKeepGoing');
  static String get dashGreetingProud => _t('dashGreetingProud');
  static String get dashGreetingCheering => _t('dashGreetingCheering');
  static String get practiceNothingDue => _t('practiceNothingDue');
  static String get globalQuizHeading => _t('globalQuizHeading');
  static String get globalQuizTitle => _t('globalQuizTitle');
  static String get globalQuizSubtitle => _t('globalQuizSubtitle');
  static String get globalQuizStart => _t('globalQuizStart');
  static String get jpzBadge => _t('jpzBadge');
  static String get jpzTitle => _t('jpzTitle');
  static String get jpzDescription => _t('jpzDescription');
  static String get jpzCermatikDescription => _t('jpzCermatikDescription');
  static String get statShopSubtitle => _t('statShopSubtitle');
  static String get statShopAction => _t('statShopAction');
  static String get sectionQuickQuizzes => _t('sectionQuickQuizzes');
  static String get sectionContinue => _t('sectionContinue');
  static String get defaultUserName => _t('defaultUserName');

  // ── Age gate / parental consent (BR-8FDF37) ──
  static String get ageGateTitle => _t('ageGateTitle');
  static String ageGateQuestion(int age) =>
      _t('ageGateQuestion').replaceAll('{age}', '$age');
  static String get ageGateYes => _t('ageGateYes');
  static String get ageGateNo => _t('ageGateNo');
  static String get ageGateCountryLabel => _t('ageGateCountryLabel');
  static String get ageGateCountryQuestion => _t('ageGateCountryQuestion');
  static String get consentIntroTitle => _t('consentIntroTitle');
  static String get consentIntroBody => _t('consentIntroBody');
  static String get consentEmailLabel => _t('consentEmailLabel');
  static String get consentEmailInvalid => _t('consentEmailInvalid');
  static String get consentSend => _t('consentSend');
  static String get consentWaitingTitle => _t('consentWaitingTitle');
  static String get consentWaitingBody => _t('consentWaitingBody');
  static String get consentEnterCode => _t('consentEnterCode');
  static String get consentGenericError => _t('consentGenericError');
  static String get consentNetworkError => _t('consentNetworkError');
  static String get consentConfirmTitle => _t('consentConfirmTitle');
  static String get consentConfirmBody => _t('consentConfirmBody');
  static String get consentConfirmCta => _t('consentConfirmCta');
  static String get consentConfirmSuccess => _t('consentConfirmSuccess');
  static String get consentConfirmFailure => _t('consentConfirmFailure');
  static String get consentConfirmInvalidLink => _t('consentConfirmInvalidLink');
  static String consentConfirmSuccessNoMail(int totalChildren) =>
      _t('consentConfirmSuccessNoMail').replaceAll('{count}', '$totalChildren');
  static String get consentManageTitle => _t('consentManageTitle');
  static String get consentManageChildren => _t('consentManageChildren');
  static String get consentManageNewCode => _t('consentManageNewCode');
  static String get consentManageNewCodeHint => _t('consentManageNewCodeHint');
  static String get consentManageRevoke => _t('consentManageRevoke');
  static String get consentManageRevokeConfirm => _t('consentManageRevokeConfirm');
  static String get consentManageRevoked => _t('consentManageRevoked');
  static String get consentManageRevokedDetail => _t('consentManageRevokedDetail');
  static String get consentManageExpired => _t('consentManageExpired');
  static String get consentManageResend => _t('consentManageResend');
  static String get consentManageResendSent => _t('consentManageResendSent');
  static String get consentManageLoadError => _t('consentManageLoadError');
  static String get consentManageRetry => _t('consentManageRetry');
  static String get minorNameLocked => _t('minorNameLocked');

  // ── Chat placeholder ──
  static String get chatTitle => _t('chatTitle');
  static String get chatLockedMessage => _t('chatLockedMessage');

  // ── Add placeholder ──
  static String get addTitle => _t('addTitle');
  static String get contentComingSoon => _t('contentComingSoon');

  // ── News placeholder ──
  static String get novinkyTitle => _t('novinkyTitle');
  static String get novinkyEmpty => _t('novinkyEmpty');
  static String get novinkyError => _t('novinkyError');
  static String get novinkyLoading => _t('novinkyLoading');
  static String get novinkyRetry => _t('novinkyRetry');
  static String get novinkyPickArticle => _t('novinkyPickArticle');

  // ── Doplňky ──
  static String get doplnkyTitle => _t('doplnkyTitle');
  static String get doplnkySubtitle => _t('doplnkySubtitle');
  static String get doplnkyAvatarTitle => _t('doplnkyAvatarTitle');
  static String get doplnkyAvatarPerex => _t('doplnkyAvatarPerex');
  static String get doplnkyThemeTitle => _t('doplnkyThemeTitle');
  static String get doplnkyThemePerex => _t('doplnkyThemePerex');
  static String get doplnkyOpen => _t('doplnkyOpen');

  // ── Mini games ──
  static String get miniGamesTitle => _t('miniGamesTitle');
  static String get miniGamesSubtitle => _t('miniGamesSubtitle');
  static String get miniGamesEmpty => _t('miniGamesEmpty');
  static String get miniGamesError => _t('miniGamesError');
  static String get miniGamesRetry => _t('miniGamesRetry');
  static String get miniGamesPlay => _t('miniGamesPlay');
  static String get miniGamesComingSoon => _t('miniGamesComingSoon');
  static String get miniGamesOffline => _t('miniGamesOffline');
  static String get miniGamesSensorGyroscope => _t('miniGamesSensorGyroscope');
  static String get miniGamesLocked => _t('miniGamesLocked');
  static String get miniGamesStartFailed => _t('miniGamesStartFailed');

  // ── Mini games / in-game ──
  static String get gameTapToStart => _t('gameTapToStart');
  static String get gameReadyHeadline => _t('gameReadyHeadline');
  static String get gameRuleClimb => _t('gameRuleClimb');
  static String get gameRuleCoin => _t('gameRuleCoin');
  static String get gameRuleBoost => _t('gameRuleBoost');
  static String get gameRuleFall => _t('gameRuleFall');
  static String get gameHintTilt => _t('gameHintTilt');
  static String get gameHintKeys => _t('gameHintKeys');
  static String get gameHintButtons => _t('gameHintButtons');
  static String get gameSteerLeft => _t('gameSteerLeft');
  static String get gameSteerRight => _t('gameSteerRight');
  static String get gameScore => _t('gameScore');
  static String get gameOver => _t('gameOver');
  static String get gameCoinsCollected => _t('gameCoinsCollected');
  static String get gameBack => _t('gameBack');
  static String get gamePaused => _t('gamePaused');
  static String get gameResume => _t('gameResume');
  static String get gameQuit => _t('gameQuit');
  static String get gameQuitConfirm => _t('gameQuitConfirm');
  static String get gameExit => _t('gameExit');

  /// "4 minuty" / "4 minúty" / "4 minutes" — the game's expected run length.
  static String miniGamesDuration(int minutes) {
    switch (LocaleManager.current) {
      case AppLocale.cs:
        if (minutes == 1) return '$minutes minuta';
        if (minutes < 5) return '$minutes minuty';
        return '$minutes minut';
      case AppLocale.sk:
        if (minutes == 1) return '$minutes minúta';
        if (minutes < 5) return '$minutes minúty';
        return '$minutes minút';
      case AppLocale.en:
        return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }

  /// "4 pokusy" / "4 attempts" — plays left today.
  static String miniGamesAttempts(int attempts) {
    switch (LocaleManager.current) {
      case AppLocale.cs:
        if (attempts == 1) return '$attempts pokus';
        if (attempts < 5) return '$attempts pokusy';
        return '$attempts pokusů';
      case AppLocale.sk:
        if (attempts == 1) return '$attempts pokus';
        if (attempts < 5) return '$attempts pokusy';
        return '$attempts pokusov';
      case AppLocale.en:
        return '$attempts ${attempts == 1 ? 'attempt' : 'attempts'}';
    }
  }

  /// "Od 5 lvl" / "From lvl 5" — the level that unlocks the game.
  static String miniGamesMinLevel(int level) => _pick(
        cz: 'Od $level lvl',
        sk: 'Od $level lvl',
        en: 'From lvl $level',
      );

  /// "Pokus za 4 h" / "Pokus za 30 min" — when the next attempt lands.
  /// Rounds up so a lock never reads as "0".
  static String miniGamesUnlocksIn(Duration remaining) {
    final minutes = remaining.inSeconds <= 0
        ? 0
        : (remaining.inSeconds / 60).ceil();

    if (minutes < 60) {
      return _pick(
        cz: 'Pokus za $minutes min',
        sk: 'Pokus o $minutes min',
        en: 'Attempt in $minutes min',
      );
    }

    final hours = (minutes / 60).ceil();
    return _pick(
      cz: 'Pokus za $hours h',
      sk: 'Pokus o $hours h',
      en: 'Attempt in $hours h',
    );
  }

  // ── Courses tab ──
  static String get kurzyTitle => _t('kurzyTitle');
  static String get filterAll => _t('filterAll');
  static String get filterInProgress => _t('filterInProgress');
  static String get filterNotStarted => _t('filterNotStarted');
  static String get filterCompleted => _t('filterCompleted');
  static String get kurzyEmptyTitle => _t('kurzyEmptyTitle');
  static String get kurzyEmptySubtitle => _t('kurzyEmptySubtitle');
  static String get kurzyExploreLibrary => _t('kurzyExploreLibrary');
  static String get defaultCourseName => _t('defaultCourseName');

  // ── Auth ──

  /// Marketing headline on the welcome / login landing screens.
  static String get authHeadline => _t('authHeadline');

  /// Headline above the sign-in form itself. Separate from [authHeadline],
  /// which is still the marketing line on `welcome_page` and `login_page`.
  static String get authFormHeadline => _t('authFormHeadline');

  /// Tagline under the logo on the split-pane (desktop) login hero.
  static String get authHeroTaglineExpanded => _t('authHeroTaglineExpanded');

  static String get authCodeLabel => _t('authCodeLabel');
  static String get authVerifyingCode => _t('authVerifyingCode');
  static String get authContinue => _t('authContinue');
  static String get authOr => _t('authOr');
  static String get authLoginSignUp => _t('authLoginSignUp');
  static String get authTerms => _t('authTerms');
  static String get authPrivacy => _t('authPrivacy');
  static String get authEmailHint => _t('authEmailHint');
  static String get authLogin => _t('authLogin');
  static String get authOrCzech => _t('authOrCzech');
  static String get authGoogleLogin => _t('authGoogleLogin');
  static String get authMicrosoftLogin => _t('authMicrosoftLogin');
  static String get authAppleLogin => _t('authAppleLogin');
  static String get authTermsNotice => _t('authTermsNotice');
  static String get authTermsAndPrivacy => _t('authTermsAndPrivacy');
  static String get authTermsLink => _t('authTermsLink');
  static String get authTermsPrivacyJoiner => _t('authTermsPrivacyJoiner');
  static String get authPrivacyLink => _t('authPrivacyLink');
  static String get authEmptyEmailError => _t('authEmptyEmailError');
  static String get authInvalidEmailError => _t('authInvalidEmailError');
  static String codeNotFound(String pin) => _pick(
        cz: 'Kód "$pin" nebyl nalezen',
        sk: 'Kód "$pin" sa nenašiel',
        en: 'Code "$pin" was not found',
      );
  static String get authUserCreateError => _t('authUserCreateError');
  static String get authCourseLoadError => _t('authCourseLoadError');
  static String get authCourseDownloadError => _t('authCourseDownloadError');
  static String get authKeepLoggedInLabel => _t('authKeepLoggedInLabel');

  // ── Profile ──
  static String get profileTitle => _t('profileTitle');
  static String get profileSectionAccount => _t('profileSectionAccount');
  static String get profileEditProfile => _t('profileEditProfile');
  static String get profileEditAvatar => _t('profileEditAvatar');
  static String get profilePrivacy => _t('profilePrivacy');
  static String get profileSectionSettings => _t('profileSectionSettings');
  static String get profileTheme => _t('profileTheme');
  static String get profileNotifications => _t('profileNotifications');
  static String get profileLanguage => _t('profileLanguage');
  static String get profileComingSoon => _t('profileComingSoon');
  static String get profileSectionMore => _t('profileSectionMore');
  static String get profileAbout => _t('profileAbout');
  static String get profileTerms => _t('profileTerms');
  static String get profileLogout => _t('profileLogout');
  static String get profileLogin => _t('profileLogin');
  static String get profileStatCourses => _t('profileStatCourses');
  static String get profileStatStreak => _t('profileStatStreak');
  static String get profileStatAchievements => _t('profileStatAchievements');
  static String get profileQuickAchievements => _t('profileQuickAchievements');
  static String get profileQuickLibrary => _t('profileQuickLibrary');

  // ── Profile Setup ──
  static String get profileSetupTitle => _t('profileSetupTitle');
  static String get profileSetupSubtitle => _t('profileSetupSubtitle');
  static String get profileSetupNameLabel => _t('profileSetupNameLabel');
  static String get profileSetupNameHint => _t('profileSetupNameHint');
  static String get profileSetupColorLabel => _t('profileSetupColorLabel');
  static String get profileSetupVibeTitle => _t('profileSetupVibeTitle');
  static String get profileSetupVibeSubtitle => _t('profileSetupVibeSubtitle');
  static String get profileSetupVibeNone => _t('profileSetupVibeNone');
  static String get profileSetupAvatarLabel => _t('profileSetupAvatarLabel');
  static String get profileSetupSubjectsLabel => _t('profileSetupSubjectsLabel');
  static String get profileSetupNameError => _t('profileSetupNameError');
  static String get profileSetupSyncWarning => _t('profileSetupSyncWarning');
  static String profileSetupSaveError(String error) => _pick(
        cz: 'Chyba při ukládání: $error',
        sk: 'Chyba pri ukladaní: $error',
        en: 'Error while saving: $error',
      );

  // ── Edit Profile ──
  static String get editProfileTitle => _t('editProfileTitle');
  static String get editProfileNameLabel => _t('editProfileNameLabel');
  static String get editProfileEmailLabel => _t('editProfileEmailLabel');
  static String get editProfileNameHint => _t('editProfileNameHint');
  static String get editProfileEmailReadonly => _t('editProfileEmailReadonly');
  static String get editProfileEmptyNameError => _t('editProfileEmptyNameError');
  static String get editProfileSaveError => _t('editProfileSaveError');
  static String get editProfileSaveButton => _t('editProfileSaveButton');

  // ── Library ──
  static String get libraryTitle => _t('libraryTitle');
  static String get librarySubtitle => _t('librarySubtitle');
  static String get libraryCodeTitle => _t('libraryCodeTitle');
  static String get libraryCodeButton => _t('libraryCodeButton');
  static String get libraryCodeShort => _t('libraryCodeShort');

  // ── Classroom join (BR-3V2P22) ─────────────────────────────────────────
  static String get classroomJoinTitle => _t('classroomJoinTitle');
  static String get classroomJoinButton => _t('classroomJoinButton');
  static String get classroomJoinCodeHint => _t('classroomJoinCodeHint');
  static String get classroomJoinSearching => _t('classroomJoinSearching');
  static String get classroomJoinOffline => _t('classroomJoinOffline');
  static String get classroomJoinYes => _t('classroomJoinYes');
  static String get classroomJoinNo => _t('classroomJoinNo');
  // Class code (BR-TT6TD7): four characters the teacher set on the class.
  static String get classroomJoinSubmit => _t('classroomJoinSubmit');
  static String get classroomJoinClassCodeHint => _t('classroomJoinClassCodeHint');
  static String get classroomJoinUseStudentCode => _t('classroomJoinUseStudentCode');
  static String get classroomJoinUseClassCode => _t('classroomJoinUseClassCode');
  static String get classroomJoinClassCodeShort => _t('classroomJoinClassCodeShort');
  static String get classroomJoinCodeNotFound => _t('classroomJoinCodeNotFound');
  static String get classroomJoinLoginRequired => _t('classroomJoinLoginRequired');
  static String get classroomJoinNotAllowed => _t('classroomJoinNotAllowed');
  static String classroomJoinConfirm(String name) => _pick(
        cz: 'Chceš se připojit ke třídě „$name“?',
        sk: 'Chceš sa pripojiť k triede „$name“?',
        en: 'Do you want to join the class "$name"?',
      );
  static String classroomJoinSuccess(String name) => _pick(
        cz: 'Jsi ve třídě „$name“.',
        sk: 'Si v triede „$name“.',
        en: 'You joined "$name".',
      );
  static String get editProfileClassroomsLabel => _t('editProfileClassroomsLabel');
  static String get editProfileNoClassrooms => _t('editProfileNoClassrooms');
  static String libraryCodeNotFound(String code) => _pick(
        cz: 'Kurz s kódem "$code" nebyl nalezen',
        sk: 'Kurz s kódom "$code" sa nenašiel',
        en: 'Course with code "$code" was not found',
      );
  static String get libraryLoginRequired => _t('libraryLoginRequired');
  static String get libraryLoggedOnlyTitle => _t('libraryLoggedOnlyTitle');
  static String get libraryLoggedOnlyBody => _t('libraryLoggedOnlyBody');
  static String get libraryLoggedOnlyAction => _t('libraryLoggedOnlyAction');
  static String get libraryLinkOpenFailed => _t('libraryLinkOpenFailed');
  static String get libraryLoadError => _t('libraryLoadError');
  static String get librarySearchingCourse => _t('librarySearchingCourse');
  static String get libraryEmptyTitle => _t('libraryEmptyTitle');
  static String get libraryEmptySubtitle => _t('libraryEmptySubtitle');
  static String get libraryCoursesLoadError => _t('libraryCoursesLoadError');
  static String get libraryCourseAlreadyCompleted => _t('libraryCourseAlreadyCompleted');
  static String libraryCourseDownloadFailed(String name) => _pick(
        cz: 'Kurz "$name" se nepodařilo stáhnout. Zkuste to znovu.',
        sk: 'Kurz "$name" sa nepodarilo stiahnuť. Skúste to znova.',
        en: 'Failed to download course "$name". Please try again.',
      );
  static String libraryCourseAdded(String name) => _pick(
        cz: 'Kurz "$name" přidán do tvé knihovny',
        sk: 'Kurz "$name" pridaný do tvojej knižnice',
        en: 'Course "$name" added to your library',
      );
  static String libraryCourseDownloadError(String error) => _pick(
        cz: 'Nepodařilo se stáhnout kurz: $error',
        sk: 'Nepodarilo sa stiahnuť kurz: $error',
        en: 'Failed to download course: $error',
      );
  static String libraryCourseUpdated(String name) => _pick(
        cz: 'Kurz "$name" byl aktualizován',
        sk: 'Kurz "$name" bol aktualizovaný',
        en: 'Course "$name" has been updated',
      );
  static String libraryCourseUpdateError(String error) => _pick(
        cz: 'Nepodařilo se aktualizovat kurz: $error',
        sk: 'Nepodarilo sa aktualizovať kurz: $error',
        en: 'Failed to update course: $error',
      );
  static String get libraryUpdating => _t('libraryUpdating');
  static String get libraryDownloading => _t('libraryDownloading');
  static String get libraryUpdate => _t('libraryUpdate');
  static String get libraryLaunch => _t('libraryLaunch');
  static String get libraryDownload => _t('libraryDownload');
  static String lessonsCount(int count) => _pick(
        cz: '$count lekcí',
        sk: '$count lekcií',
        en: '$count lessons',
      );
  static String practiceDueCount(int count) => _pick(
        cz: '$count karet k procvičení',
        sk: '$count kariet na precvičenie',
        en: '$count cards to review',
      );

  /// Cards waiting today in one subject / area of the practice picker.
  static String practiceScopeDueCount(int count) => _pick(
        cz: 'dnes $count',
        sk: 'dnes $count',
        en: '$count today',
      );

  /// How many areas the student narrowed practice to.
  static String practiceScopeSelected(int count) => _pick(
        cz: 'Vybráno oblastí: $count',
        sk: 'Vybraných oblastí: $count',
        en: 'Areas selected: $count',
      );
  static String durationHours(int hours) => _pick(
        cz: '$hours hod',
        sk: '$hours hod',
        en: '${hours}h',
      );
  /// Smart duration: "45 min", "1 h", "1 h 20 min"
  static String durationSmart(int totalMinutes) {
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return durationHours(hours);
    return _pick(
      cz: '$hours hod $mins min',
      sk: '$hours hod $mins min',
      en: '${hours}h $mins min',
    );
  }

  // ── Course Detail ──
  static String get courseProgress => _t('courseProgress');
  static String get courseDescription => _t('courseDescription');
  static String get courseLessons => _t('courseLessons');
  static String get courseShowMore => _t('courseShowMore');
  static String get courseShowLess => _t('courseShowLess');
  static String courseShowMoreCount(int count) => _pick(
        cz: 'Zobrazit další ($count)',
        sk: 'Zobraziť ďalšie ($count)',
        en: 'Show more ($count)',
      );
  static String get courseQuizzes => _t('courseQuizzes');
  static String get courseShowAll => _t('courseShowAll');
  static String get courseContinueLesson => _t('courseContinueLesson');
  static String get courseExercise => _t('courseExercise');
  static String get courseQuiz => _t('courseQuiz');
  static String get courseCompleted => _t('courseCompleted');
  static String get courseCurrent => _t('courseCurrent');
  static String courseQuestionsCount(int count) => _pick(
        cz: '$count otázek',
        sk: '$count otázok',
        en: '$count questions',
      );
  static String get courseCorruptedTitle => _t('courseCorruptedTitle');
  static String get courseCorruptedMessage => _t('courseCorruptedMessage');
  static String get courseBack => _t('courseBack');
  static String get courseStartQuiz => _t('courseStartQuiz');
  static String get courseContinueQuiz => _t('courseContinueQuiz');
  static String get courseQuizUnlockHint => _t('courseQuizUnlockHint');
  static String get courseNoBookmarks => _t('courseNoBookmarks');
  static String get courseNoQuestions => _t('courseNoQuestions');
  static String get courseUpdateAvailable => _t('courseUpdateAvailable');
  static String get courseUpdateRequired => _t('courseUpdateRequired');
  static String get courseCardUpdate => _t('courseCardUpdate');
  static String get courseActionLessons => _t('courseActionLessons');

  // ── Lesson Detail ──
  static String lessonTitle(int index, String title) => _pick(
        cz: 'Lekce $index: $title',
        sk: 'Lekcia $index: $title',
        en: 'Lesson $index: $title',
      );
  static String get lessonEmptyTitle => _t('lessonEmptyTitle');
  static String get lessonEmptyMessage => _t('lessonEmptyMessage');
  static String get lessonFinishCourse => _t('lessonFinishCourse');
  static String get lessonNextLesson => _t('lessonNextLesson');
  static String get lessonBackToDetail => _t('lessonBackToDetail');
  static String get lessonCourseCompleted => _t('lessonCourseCompleted');
  static String get lessonSelectAnswerFirst => _t('lessonSelectAnswerFirst');
  static String get lessonExplanation => _t('lessonExplanation');
  static String lessonDetailedExplanation(String title) => _pick(
        cz: 'Podrobnější vysvětlení: $title',
        sk: 'Podrobnejšie vysvetlenie: $title',
        en: 'More detailed explanation: $title',
      );
  static String lessonExplanationTitle(String title) => _pick(
        cz: 'Vysvětlení: $title',
        sk: 'Vysvetlenie: $title',
        en: 'Explanation: $title',
      );
  static String get lessonFeedbackClear => _t('lessonFeedbackClear');
  static String get lessonFeedbackPractice => _t('lessonFeedbackPractice');
  static String get lessonFeedbackPracticeAdded => _t('lessonFeedbackPracticeAdded');
  static String get mentorSheetInputHint => _t('mentorSheetInputHint');
  static String get mentorSheetNoHelp => _t('mentorSheetNoHelp');
  static String get lessonFeedbackConfused => _t('lessonFeedbackConfused');
  static String get lessonFeedbackClarify => _t('lessonFeedbackClarify');
  static String get lessonFeedbackHint => _t('lessonFeedbackHint');
  static String lessonFeedbackCharCount(int count) => _pick(
        cz: '$count/500 znaků',
        sk: '$count/500 znakov',
        en: '$count/500 characters',
      );
  static String get lessonFeedbackThanks => _t('lessonFeedbackThanks');
  static String get lessonFeedbackSend => _t('lessonFeedbackSend');
  static String get lessonVideoError => _t('lessonVideoError');
  static String get lessonWriteAnswer => _t('lessonWriteAnswer');
  static String get lessonCheckAnswer => _t('lessonCheckAnswer');
  static String get lessonCorrect => _t('lessonCorrect');
  static String get lessonIncorrect => _t('lessonIncorrect');
  static String get lessonQuestionLabel => _t('lessonQuestionLabel');

  // ── Quiz ──
  static String get quizTitle => _t('quizTitle');
  static String get quizExerciseTitle => _t('quizExerciseTitle');
  static String quizCardProgress(int current, int total) => _pick(
        cz: 'Karta $current z $total',
        sk: 'Karta $current z $total',
        en: 'Card $current of $total',
      );
  static String quizCorrectCount(int correct, int total) => _pick(
        cz: '$correct/$total správně',
        sk: '$correct/$total správne',
        en: '$correct/$total correct',
      );
  static String get quizCompleted => _t('quizCompleted');
  static String get quizReviewCompleted => _t('quizReviewCompleted');
  static String quizCorrectResult(int correct, int total) => _pick(
        cz: '$correct z $total správně',
        sk: '$correct z $total správne',
        en: '$correct of $total correct',
      );
  static String quizCardsReviewed(int total) => _pick(
        cz: 'Prošel jsi $total karet',
        sk: 'Prešiel si $total kariet',
        en: 'You went through $total cards',
      );

  // ── End-of-quiz feedback popup (BR-JCUJVR) ──
  /// Title of the popup for a course with `quiz_evaluate` off — the quiz went
  /// through, but no score is disclosed.
  static String get quizSubmittedTitle => _pick(
        cz: 'Kvíz odeslán',
        sk: 'Kvíz odoslaný',
        en: 'Quiz submitted',
      );
  static String get quizSubmittedThanks => _pick(
        cz: 'Díky, tvoje odpovědi jsme uložili.',
        sk: 'Vďaka, tvoje odpovede sme uložili.',
        en: 'Thanks — your answers have been saved.',
      );
  static String get quizBreakdownHeading => _pick(
        cz: 'Přehled',
        sk: 'Prehľad',
        en: 'Overview',
      );
  static String get quizBreakdownCorrectNoHint => _pick(
        cz: 'Vyřešeno správně bez nápovědy',
        sk: 'Vyriešené správne bez nápovedy',
        en: 'Solved correctly without a hint',
      );
  static String get quizBreakdownCorrectWithHint => _pick(
        cz: 'Vyřešeno správně s nápovědou',
        sk: 'Vyriešené správne s nápovedou',
        en: 'Solved correctly with a hint',
      );
  static String get quizBreakdownWrong => _pick(
        cz: 'Vyřešeno špatně',
        sk: 'Vyriešené zle',
        en: 'Solved incorrectly',
      );
  static String get quizBreakdownUnanswered => _pick(
        cz: 'Nezodpovězeno',
        sk: 'Nezodpovedané',
        en: 'Not answered',
      );
  static String get quizEloHeading => _pick(
        cz: 'Změna úrovně podle oblastí',
        sk: 'Zmena úrovne podľa oblastí',
        en: 'Level change by domain',
      );
  static String get quizEloExplainer => _pick(
        cz: 'Průměrná změna tvé úrovně v oblastech, které jsi v tomhle kvízu procvičil.',
        sk: 'Priemerná zmena tvojej úrovne v oblastiach, ktoré si v tomto kvíze precvičil.',
        en: 'Average change in your level across the domains this quiz covered.',
      );
  /// Answers caught by the gaming filter — deliberately worded as guessing,
  /// not cheating; the AI comment carries the gentle explanation.
  static String get quizBreakdownGamed => _pick(
        cz: 'Tipováno',
        sk: 'Tipované',
        en: 'Guessed',
      );
  static String get quizAiCommentHeading => _pick(
        cz: 'Komentář k tvému řešení',
        sk: 'Komentár k tvojmu riešeniu',
        en: 'Feedback on your work',
      );
  static String get quizAiCommentLoading => _pick(
        cz: 'Připravuji komentář…',
        sk: 'Pripravujem komentár…',
        en: 'Preparing your feedback…',
      );

  // ── Global quiz entry dialog ──
  static String get globalQuizEntryTitle => _pick(
        cz: 'Z čeho si dáš kvíz?',
        sk: 'Z čoho si dáš kvíz?',
        en: 'What should your quiz cover?',
      );
  static String get globalQuizEntrySubtitle => _pick(
        cz: 'Vyber oblasti a kurzy, ze kterých ti sestavíme 10 úloh na míru.',
        sk: 'Vyber oblasti a kurzy, z ktorých ti zostavíme 10 úloh na mieru.',
        en: 'Pick the areas and courses to draw your 10 tailored questions from.',
      );
  static String get globalQuizEntryDomains => _pick(
        cz: 'Oblasti',
        sk: 'Oblasti',
        en: 'Areas',
      );
  static String get globalQuizEntryCourses => _pick(
        cz: 'Kurzy',
        sk: 'Kurzy',
        en: 'Courses',
      );
  static String get globalQuizEntryStart => _pick(
        cz: 'Spustit kvíz',
        sk: 'Spustiť kvíz',
        en: 'Start the quiz',
      );

  static String practiceSummarySuccess(int percent) => _pick(
        cz: 'Úspěšnost $percent %',
        sk: 'Úspešnosť $percent %',
        en: 'Success rate $percent%',
      );
  static String practiceSummaryXp(int xp) => _pick(
        cz: '+$xp XP získáno',
        sk: '+$xp XP získaných',
        en: '+$xp XP earned',
      );
  static String get practiceCompleted => _pick(
        cz: 'Procvičování dokončeno!',
        sk: 'Precvičovanie dokončené!',
        en: 'Practice complete!',
      );
  static String get practiceRatePrompt => _pick(
        cz: 'Jak dobře si to pamatuješ?',
        sk: 'Ako dobre si to pamätáš?',
        en: 'How well do you remember this?',
      );
  static String get practiceRateAgain =>
      _pick(cz: 'Nevím', sk: 'Neviem', en: "Don't know");
  static String get practiceRateHard =>
      _pick(cz: 'Připomeň', sk: 'Pripomeň', en: 'Remind me');
  static String get practiceRateGood =>
      _pick(cz: 'Jde to', sk: 'Ide to', en: 'Okay');
  static String get practiceRateEasy =>
      _pick(cz: 'Pamatuji', sk: 'Pamätám', en: 'I remember');
  static String get quizAllCorrect => _t('quizAllCorrect');
  static String get quizGreatJob => _t('quizGreatJob');
  static String get quizTryAgain => _t('quizTryAgain');
  static String get quizGreatReview => _t('quizGreatReview');
  static String get quizDone => _t('quizDone');
  static String get quizConfirmSubmit => _t('quizConfirmSubmit');
  static String get quizConfirmBack => _t('quizConfirmBack');
  static String get quizConfirmSend => _t('quizConfirmSend');
  static String get quizConfirmExitMessage => _t('quizConfirmExitMessage');
  static String get quizConfirmExitLeave => _t('quizConfirmExitLeave');
  static String get quizConfirmExitStay => _t('quizConfirmExitStay');
  static String get quizThankYou => _t('quizThankYou');
  static String get quizRetry => _t('quizRetry');
  static String get quizReview => _t('quizReview');
  static String get quizFinish => _t('quizFinish');
  static String get quizNext => _t('quizNext');
  static String get quizCheck => _t('quizCheck');
  static String get quizAnswerHint => _t('quizAnswerHint');
  static String get quizCorrectLabel => _t('quizCorrectLabel');
  static String get quizIncorrectLabel => _t('quizIncorrectLabel');
  static String get quizAskAi => _t('quizAskAi');
  static String get quizAnswersSaved => _t('quizAnswersSaved');

  // ── Chat-context prompts (shared by quiz + lesson detail) ──
  static String chatContextQuestionWithOptions(String text) => _pick(
        cz: 'Otázka s možnostmi:\n$text',
        sk: 'Otázka s možnosťami:\n$text',
        en: 'Question with options:\n$text',
      );
  static String chatContextHelpIntro(String courseName) => _pick(
        cz: 'Potřebuji pomoct s úlohou z kurzu "$courseName".',
        sk: 'Potrebujem pomôcť s úlohou z kurzu "$courseName".',
        en: 'I need help with a task from the course "$courseName".',
      );
  static String chatContextHelpIntroLesson(String courseName, String lessonName) => _pick(
        cz: 'Potřebuji pomoct s úlohou z kurzu "$courseName", lekce "$lessonName".',
        sk: 'Potrebujem pomôcť s úlohou z kurzu "$courseName", lekcia "$lessonName".',
        en: 'I need help with a task from the course "$courseName", lesson "$lessonName".',
      );
  static String chatContextHelpTaskContent(String text) => _pick(
        cz: 'Obsah úlohy: $text',
        sk: 'Obsah úlohy: $text',
        en: 'Task content: $text',
      );
  static String chatContextHelpHint(String hint) => _pick(
        cz: 'Nápověda říká: $hint',
        sk: 'Nápoveda hovorí: $hint',
        en: 'The hint says: $hint',
      );
  static String chatContextHelpDetail(String help) => _pick(
        cz: 'Podrobnější vysvětlení: $help',
        sk: 'Podrobnejšie vysvetlenie: $help',
        en: 'More detailed explanation: $help',
      );
  static String chatContextStudentQuery(String msg) => _pick(
        cz: 'Můj dotaz: $msg',
        sk: 'Moja otázka: $msg',
        en: 'My question: $msg',
      );
  static String get chatContextFallbackPrompt => _t('chatContextFallbackPrompt');

  /// The visible opening message of a chat started from a block's "ask the AI"
  /// action. The assembled task context travels hidden alongside it, so this is
  /// all the transcript shows for the student (BR-NAH3TR).
  static String get chatContextOpeningQuestion => _pick(
        cz: 'Můžeš mi pomoct s touto úlohou?',
        sk: 'Môžeš mi pomôcť s touto úlohou?',
        en: 'Can you help me with this task?',
      );

  // ── Exercise ──
  static String get exerciseSelectCorrect => _t('exerciseSelectCorrect');
  static String get exerciseSelectAll => _t('exerciseSelectAll');
  static String get exerciseWriteAnswer => _t('exerciseWriteAnswer');
  static String get exerciseAnswerHint => _t('exerciseAnswerHint');
  static String exerciseCharCount(int count) => _pick(
        cz: '$count/500 znaků',
        sk: '$count/500 znakov',
        en: '$count/500 characters',
      );
  static String get exerciseCorrect => _t('exerciseCorrect');
  static String get exerciseIncorrect => _t('exerciseIncorrect');
  // Buttons of a true/false question the author left unlabelled (BR-PJUUZZ).
  static String get trueFalseTrue => _t('trueFalseTrue');
  static String get trueFalseFalse => _t('trueFalseFalse');
  static String exerciseCorrectAnswer(String answer) => _pick(
        cz: 'Správná odpověď je: $answer',
        sk: 'Správna odpoveď je: $answer',
        en: 'Correct answer is: $answer',
      );
  static String get exerciseExplanationLabel => _t('exerciseExplanationLabel');

  // ── Achievements ──
  static String get achievementsTitle => _t('achievementsTitle');
  static String achievementsXpRemaining(int xp, int nextLevel) => _pick(
        cz: 'Zbývá $xp XP do lvl $nextLevel',
        sk: 'Zostáva $xp XP do lvl $nextLevel',
        en: '$xp XP to lvl $nextLevel',
      );
  static String achievementsDaysCount(int days) => _pick(
        cz: '$days ${days == 1 ? 'den' : 'dní'}',
        sk: '$days ${days == 1 ? 'deň' : 'dní'}',
        en: '$days ${days == 1 ? 'day' : 'days'}',
      );
  static String get achievementsTrophies => _t('achievementsTrophies');
  static String get achievementsCoins => _t('achievementsCoins');
  static String get achievementsEarnedTrophies => _t('achievementsEarnedTrophies');
  static String get achievementsChallenges => _t('achievementsChallenges');
  static String get achievementsSkills => _t('achievementsSkills');
  static String get achievementsSkillsPlaceholder => _t('achievementsSkillsPlaceholder');

  // Skill tab filters
  static String get skillTabAll => _t('skillTabAll');
  static String get skillTabBeginner => _t('skillTabBeginner');
  static String get skillTabIntermediate => _t('skillTabIntermediate');
  static String get skillTabExpert => _t('skillTabExpert');
  /// Always one decimal, so the label keeps a stable width as the level moves;
  /// [formatDecimal] supplies the locale's separator (BR-5DZ6JD).
  static String skillLevel(double level) {
    final formatted = formatDecimal(level, fractionDigits: 1);
    return _pick(
      cz: 'Úroveň: $formatted',
      sk: 'Úroveň: $formatted',
      en: 'Level: $formatted',
    );
  }
  static String skillConfidence(int low, int high) => _pick(
        cz: 'Interval jistoty: $low–$high',
        sk: 'Interval istoty: $low–$high',
        en: 'Confidence interval: $low–$high',
      );
  static String get achievementsGoals => _t('achievementsGoals');
  // Trophy strings (defaults / mock)
  static String get challengeMasterpiece => _t('challengeMasterpiece');
  static String get trophyBiologist => _t('trophyBiologist');
  static String get trophyBiologistDesc => _t('trophyBiologistDesc');
  static String get trophyWeekStreak => _t('trophyWeekStreak');
  static String get trophyWeekStreakDesc => _t('trophyWeekStreakDesc');
  // Goal strings (defaults / mock)
  static String get goalCompleteLessons => _t('goalCompleteLessons');
  static String get goalCompleteLessonsDesc => _t('goalCompleteLessonsDesc');
  static String get goalPerfectScores => _t('goalPerfectScores');
  static String get goalPerfectScoresDesc => _t('goalPerfectScoresDesc');
  // Time ago
  static String get timeYesterday => _t('timeYesterday');
  static String timeDaysAgo(int days) => _pick(
        cz: 'Před $days dny',
        sk: 'Pred $days dňami',
        en: '$days days ago',
      );
  static String timeHoursAgo(int hours) => _pick(
        cz: 'Před $hours hod',
        sk: 'Pred $hours hod',
        en: '${hours}h ago',
      );
  static String timeMinutesAgo(int minutes) => _pick(
        cz: 'Před $minutes min',
        sk: 'Pred $minutes min',
        en: '$minutes min ago',
      );
  static String get timeJustNow => _t('timeJustNow');
  static String timeDaysAgoShort(int days) => _pick(
        cz: 'před $days d',
        sk: 'pred $days d',
        en: '${days}d ago',
      );

  /// Coarse "how long ago" label for activity lists.
  ///
  /// Picks the largest unit that still reads naturally; anything past a week
  /// falls back to a plain date, because "před 43 dny" tells nobody anything.
  static String timeAgoFrom(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(when);
    if (diff.inMinutes < 1) return timeJustNow;
    if (diff.inMinutes < 60) return timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return timeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return timeYesterday;
    if (diff.inDays < 7) return timeDaysAgo(diff.inDays);
    return '${when.day}. ${when.month}. ${when.year}';
  }

  // ── Terms ──
  static String get termsTitle => _t('termsTitle');
  static String get termsLastUpdated => _t('termsLastUpdated');
  static String get termsSection1Title => _t('termsSection1Title');
  static String get termsSection1Body => _t('termsSection1Body');
  static String get termsSection2Title => _t('termsSection2Title');
  static String get termsSection2Body => _t('termsSection2Body');
  static String get termsSection3Title => _t('termsSection3Title');
  static String get termsSection3Body => _t('termsSection3Body');
  static String get termsSection4Title => _t('termsSection4Title');
  static String get termsSection4Body => _t('termsSection4Body');
  static String get termsSection5Title => _t('termsSection5Title');
  static String get termsSection5Body => _t('termsSection5Body');
  static String get termsSection6Title => _t('termsSection6Title');
  static String get termsSection6Body => _t('termsSection6Body');
  static String get termsSection7Title => _t('termsSection7Title');
  static String get termsSection7Body => _t('termsSection7Body');
  static String get termsSection8Title => _t('termsSection8Title');
  static String get termsSection8Body => _t('termsSection8Body');

  // ── Privacy ──
  static String get privacyTitle => _t('privacyTitle');
  static String get privacyComingSoon => _t('privacyComingSoon');
  static String get privacyComingSoonMessage => _t('privacyComingSoonMessage');

  // ── Bookmarks List ──
  static String get aboutSavedBookmarks => _t('aboutSavedBookmarks');
  static String get bookmarksListTitle => _t('bookmarksListTitle');
  static String get bookmarksListEmpty => _t('bookmarksListEmpty');
  static String get bookmarksListCourseNotDownloaded => _t('bookmarksListCourseNotDownloaded');

  // ── About / Debug ──
  static String get aboutTitle => _t('aboutTitle');
  static String get aboutSectionAppInfo => _t('aboutSectionAppInfo');
  static String get aboutAppName => _t('aboutAppName');
  static String get aboutLabelName => _t('aboutLabelName');
  static String get aboutLabelVersion => _t('aboutLabelVersion');
  static String get aboutLabelBuild => _t('aboutLabelBuild');
  static String get aboutBuildValue => _t('aboutBuildValue');
  static String get aboutLabelFlutter => _t('aboutLabelFlutter');
  static String get aboutFlutterValue => _t('aboutFlutterValue');
  static String get aboutVersionUnavailable => _t('aboutVersionUnavailable');
  static String get aboutSectionStatus => _t('aboutSectionStatus');
  static String get aboutDatabase => _t('aboutDatabase');
  static String get aboutDatabaseReady => _t('aboutDatabaseReady');
  static String get aboutDatabaseNotInit => _t('aboutDatabaseNotInit');
  static String get aboutUserLoggedIn => _t('aboutUserLoggedIn');
  static String get aboutGuestPin => _t('aboutGuestPin');
  static String get aboutYes => _t('aboutYes');
  static String get aboutNo => _t('aboutNo');
  static String get aboutApiAuth => _t('aboutApiAuth');
  static String get aboutConnection => _t('aboutConnection');
  static String get aboutConnectionChecking => _t('aboutConnectionChecking');
  static String get aboutConnectionError => _t('aboutConnectionError');
  static String get aboutSyncState => _t('aboutSyncState');
  static String get aboutSyncReady => _t('aboutSyncReady');
  static String get aboutSyncSyncing => _t('aboutSyncSyncing');
  static String get aboutSyncError => _t('aboutSyncError');
  static String get aboutLastSync => _t('aboutLastSync');
  static String get aboutNextSync => _t('aboutNextSync');
  static String get aboutSyncNever => _t('aboutSyncNever');
  static String get aboutSectionDbStats => _t('aboutSectionDbStats');
  static String get aboutCoursesCount => _t('aboutCoursesCount');
  static String get aboutPendingSync => _t('aboutPendingSync');
  static String get aboutSectionActions => _t('aboutSectionActions');
  static String get aboutForceSync => _t('aboutForceSync');
  static String get aboutClearSyncQueue => _t('aboutClearSyncQueue');
  static String get aboutRefreshStatus => _t('aboutRefreshStatus');
  static String get aboutClearAuthToken => _t('aboutClearAuthToken');
  static String get aboutClearCourses => _t('aboutClearCourses');
  static String get aboutFactoryReset => _t('aboutFactoryReset');
  static String get aboutSectionApiConfig => _t('aboutSectionApiConfig');
  static String get aboutBaseUrl => _t('aboutBaseUrl');
  static String get aboutAuth => _t('aboutAuth');
  static String get aboutAuthValue => _t('aboutAuthValue');
  static String get aboutConnWifi => _t('aboutConnWifi');
  static String get aboutConnMobile => _t('aboutConnMobile');
  static String get aboutConnEthernet => _t('aboutConnEthernet');
  static String get aboutConnOffline => _t('aboutConnOffline');
  static String aboutSyncQueueCleared(int count) => _pick(
        cz: 'Smazáno $count položek ze sync fronty',
        sk: 'Zmazaných $count položiek zo sync fronty',
        en: 'Cleared $count items from sync queue',
      );
  static String get aboutSyncCompleted => _t('aboutSyncCompleted');
  static String aboutSyncErrorMsg(String error) => _pick(
        cz: 'Chyba synchronizace: $error',
        sk: 'Chyba synchronizácie: $error',
        en: 'Sync error: $error',
      );
  static String get aboutClearTokenTitle => _t('aboutClearTokenTitle');
  static String get aboutClearTokenMessage => _t('aboutClearTokenMessage');
  static String get aboutTokenCleared => _t('aboutTokenCleared');
  static String get aboutClearCoursesTitle => _t('aboutClearCoursesTitle');
  static String get aboutClearCoursesMessage => _t('aboutClearCoursesMessage');
  static String aboutCoursesCleared(int count) => _pick(
        cz: 'Smazáno $count kurzů z knihovny',
        sk: 'Zmazaných $count kurzov z knižnice',
        en: 'Cleared $count courses from library',
      );
  static String get aboutNoUser => _t('aboutNoUser');
  static String get aboutFactoryResetTitle => _t('aboutFactoryResetTitle');
  static String get aboutFactoryResetMessage => _t('aboutFactoryResetMessage');
  static String get aboutDeleteAll => _t('aboutDeleteAll');
  static String aboutTimeJustNow() => _t('aboutTimeJustNow');
  static String aboutTimeSoon() => _t('aboutTimeSoon');
  static String aboutTimeMinutesAgo(int min, String time) => _pick(
        cz: 'před $min min ($time)',
        sk: 'pred $min min ($time)',
        en: '$min min ago ($time)',
      );
  static String aboutTimeInMinutes(int min, String time) => _pick(
        cz: 'za $min min ($time)',
        sk: 'o $min min ($time)',
        en: 'in $min min ($time)',
      );
  static String aboutTimeToday(String time) => _pick(
        cz: 'dnes $time',
        sk: 'dnes $time',
        en: 'today $time',
      );

  // ── Theme Selector ──
  static String get themeTitle => _t('themeTitle');
  static String get themeDefault => _t('themeDefault');
  static String get themeOcean => _t('themeOcean');
  static String get themeSunset => _t('themeSunset');
  static String get themeFire => _t('themeFire');
  static String get themeLight => _t('themeLight');
  static String get themeNeutral => _t('themeNeutral');
  static String get themeCustom => _t('themeCustom');
  static String get themeCreateNew => _t('themeCreateNew');
  static String get themeImportJson => _t('themeImportJson');
  static String get themeImportTitle => _t('themeImportTitle');
  static String get themeImportHint => _t('themeImportHint');
  static String get themeImportButton => _t('themeImportButton');
  static String get themeImportError => _t('themeImportError');
  static String get themeImportSuccess => _t('themeImportSuccess');
  static String get themeEditorTitle => _t('themeEditorTitle');
  static String get themeEditorName => _t('themeEditorName');
  static String get themeEditorNameHint => _t('themeEditorNameHint');
  static String get themeEditorSave => _t('themeEditorSave');
  static String get themeEditorExport => _t('themeEditorExport');
  static String get themeEditorExportCopied => _t('themeEditorExportCopied');
  static String get themeEditorDelete => _t('themeEditorDelete');
  static String get themeEditorDeleteConfirm => _t('themeEditorDeleteConfirm');
  static String get themeEditorDeleteYes => _t('themeEditorDeleteYes');
  static String get themeEditorCancel => _t('themeEditorCancel');
  static String get themeEditorConfirm => _t('themeEditorConfirm');
  static String get themeEditorNameEmpty => _t('themeEditorNameEmpty');
  static String get themeEditorGroupCoreBrand => _t('themeEditorGroupCoreBrand');
  static String get themeEditorGroupStatus => _t('themeEditorGroupStatus');
  static String get themeEditorGroupUi => _t('themeEditorGroupUi');
  static String get themeEditorGroupCards => _t('themeEditorGroupCards');
  static String get themeEditorGroupAvatars => _t('themeEditorGroupAvatars');
  static String get themeEditorGroupSubjects => _t('themeEditorGroupSubjects');
  static String get themeEditorGroupOther => _t('themeEditorGroupOther');
  static String get themeEditorPickColor => _t('themeEditorPickColor');
  static String get colorPickerHexLabel => _t('colorPickerHexLabel');

  // ── Email Verification ──
  static String get emailVerificationTitle => _t('emailVerificationTitle');
  static String get emailVerificationCodePrompt => _t('emailVerificationCodePrompt');
  static String get emailVerificationVerify => _t('emailVerificationVerify');
  static String get emailVerificationResend => _t('emailVerificationResend');
  static String get emailVerificationSending => _t('emailVerificationSending');
  static String get emailCheckingAccount => _t('emailCheckingAccount');
  static String get emailVerificationOfflineTitle => _t('emailVerificationOfflineTitle');
  static String get emailVerificationOfflineMessage => _t('emailVerificationOfflineMessage');
  static String get emailVerificationRetry => _t('emailVerificationRetry');
  static String get emailVerificationOfflineLabel => _t('emailVerificationOfflineLabel');
  static String get emailSendCodeError => _t('emailSendCodeError');
  static String get emailMissingError => _t('emailMissingError');
  static String get emailLoadingProfile => _t('emailLoadingProfile');
  static String get emailErrInvalidCode => _t('emailErrInvalidCode');
  static String get emailErrCodeExpired => _t('emailErrCodeExpired');
  static String get emailErrRateLimited => _t('emailErrRateLimited');
  static String get emailErrNetwork => _t('emailErrNetwork');
  static String get emailErrUnknown => _t('emailErrUnknown');

  // ── Email Validation Banner ──
  static String get bannerGuestMessage => _t('bannerGuestMessage');
  static String get bannerVerifyMessage => _t('bannerVerifyMessage');
  static String get bannerOfflineMessage => _t('bannerOfflineMessage');

  // ── Email Verification Dialog ──
  static String get dialogRegistration => _t('dialogRegistration');
  static String get dialogEmailVerification => _t('dialogEmailVerification');
  static String get dialogRegistrationSuccess => _t('dialogRegistrationSuccess');
  static String get dialogEmailVerified => _t('dialogEmailVerified');
  static String get dialogEmailInputPrompt => _t('dialogEmailInputPrompt');
  static String get dialogSendCodePrompt => _t('dialogSendCodePrompt');
  static String get dialogSendCode => _t('dialogSendCode');
  static String get dialogEnterCode => _t('dialogEnterCode');
  static String get dialogSendNewCode => _t('dialogSendNewCode');

  // ── Sync Banner ──
  static String get syncSyncing => _t('syncSyncing');
  static String get syncDone => _t('syncDone');
  static String get syncFailed => _t('syncFailed');

  // ── Common Actions ──
  static String get actionContinue => _t('actionContinue');
  static String get actionCancel => _t('actionCancel');
  static String get actionDelete => _t('actionDelete');
  static String get actionBack => _t('actionBack');

  // ── Welcome Page ──
  static String get welcomeAccessPin => _t('welcomeAccessPin');

  // ── Login Page ──
  static String get loginTitle => _t('loginTitle');
  static String get loginEmailPlaceholder => _t('loginEmailPlaceholder');

  // ── Auth (shared) ──
  static String get authLoginRequired => _t('authLoginRequired');
  static String get authDefaultStudentName => _t('authDefaultStudentName');

  // ── Profile (extra) ──
  static String get profileLanguageDefault => _t('profileLanguageDefault');
  static String profileLevelXp(int level, String xp) => 'Level $level • $xp XP';
  static String profileAppVersion(String version) => 'EDU-AI $version';

  // ── Profile Setup Subjects ──
  static String get subjectBiology => _t('subjectBiology');
  static String get subjectGrammar => _t('subjectGrammar');
  static String get subjectLiterature => _t('subjectLiterature');
  static String get subjectMath => _t('subjectMath');
  static String get subjectChemistry => _t('subjectChemistry');
  static String get subjectEnglish => _t('subjectEnglish');

  // ── Library (extra) ──
  static String get libraryLoginBadge => _t('libraryLoginBadge');

  // ── Course Detail (extra) ──
  static String courseDurationMin(int min) => '$min min';
  static String courseQuizPrefix(String title) => _pick(
        cz: 'KVÍZ: $title',
        sk: 'KVÍZ: $title',
        en: 'QUIZ: $title',
      );

  // ── Achievements (extra) ──
  static String achievementsLvl(int level) => 'Lvl $level';
  // Mock skill categories
  static String get skillMolecular => _t('skillMolecular');
  static String get skillEcological => _t('skillEcological');
  static String get skillEvolutionary => _t('skillEvolutionary');
  static String get skillCells => _t('skillCells');
  static String get skillDna => _t('skillDna');
  static String get skillProtein => _t('skillProtein');
  static String get skillEcosystems => _t('skillEcosystems');
  static String get skillProteins => _t('skillProteins');

  // ── Chaty Page ──
  static String get chatyTitle => _t('chatyTitle');
  static String get chatySubtitle => _t('chatySubtitle');
  static String get chatyInfoBanner => _t('chatyInfoBanner');
  static String get chatyEndedFilter => _t('chatyEndedFilter');
  static String get chatyOfflineBanner => _t('chatyOfflineBanner');
  static String get chatyNewChat => _t('chatyNewChat');
  static String get chatyTimeNow => _t('chatyTimeNow');
  // Mock chat data
  static String get chatMockAiTeacher => _t('chatMockAiTeacher');
  static String get chatMockAiTeacherMsg => _t('chatMockAiTeacherMsg');
  static String get chatMockMathMentor => _t('chatMockMathMentor');
  static String get chatMockMathMentorMsg => _t('chatMockMathMentorMsg');
  static String get chatMockTeacherJana => _t('chatMockTeacherJana');
  static String get chatMockTeacherJanaMsg => _t('chatMockTeacherJanaMsg');
  static String get chatMockYesterday => _t('chatMockYesterday');
  static String get chatMockStudyCoach => _t('chatMockStudyCoach');
  static String get chatMockStartConversation => _t('chatMockStartConversation');
  static String get chatMockTeacherPetr => _t('chatMockTeacherPetr');
  static String get chatMockTeacherPetrMsg => _t('chatMockTeacherPetrMsg');
  static String get chatMockThreeHoursAgo => _t('chatMockThreeHoursAgo');
  static String get chatMockLanguageMentor => _t('chatMockLanguageMentor');

  // ── Chat Detail Page ──
  static String get chatDetailToday => _t('chatDetailToday');
  static String get chatDetailOnline => _t('chatDetailOnline');
  static String get chatDetailOffline => _t('chatDetailOffline');
  static String get chatDetailInputHint => _t('chatDetailInputHint');
  static String get chatDetailHelperText => _t('chatDetailHelperText');
  static String get chatDetailMockAiGreeting => _t('chatDetailMockAiGreeting');
  static String get chatDetailMockUserMsg => _t('chatDetailMockUserMsg');
  static String get chatDetailOfflineBanner => _t('chatDetailOfflineBanner');
  // Feedback
  static String get chatFeedbackTitle => _t('chatFeedbackTitle');
  static String get chatFeedbackSubtitle => _t('chatFeedbackSubtitle');
  static String get chatFeedbackSelectReason => _t('chatFeedbackSelectReason');
  static String get chatFeedbackDetails => _t('chatFeedbackDetails');
  static String get chatFeedbackHint => _t('chatFeedbackHint');
  static String get chatFeedbackCancel => _t('chatFeedbackCancel');
  static String get chatFeedbackSubmit => _t('chatFeedbackSubmit');
  static String get chatFeedbackThanks => _t('chatFeedbackThanks');
  static String get chatFeedbackIncorrect => _t('chatFeedbackIncorrect');
  static String get chatFeedbackIncomplete => _t('chatFeedbackIncomplete');
  static String get chatFeedbackUnclear => _t('chatFeedbackUnclear');
  static String get chatFeedbackInappropriate => _t('chatFeedbackInappropriate');
  static String get chatFeedbackOther => _t('chatFeedbackOther');

  // ── Chat UI ──
  static String get chatNewConversation => _t('chatNewConversation');
  static String get chatSelectPersona => _t('chatSelectPersona');
  static String get courseMentor => _t('courseMentor');
  static String get chatyPickConversation => _t('chatyPickConversation');
  static String get chatEmptyState => _t('chatEmptyState');
  static String get chatRequiresInternet => _t('chatRequiresInternet');
  static String chatMentorNotFound(String slug) => _pick(
        cz: 'Mentor "$slug" nebyl nalezen',
        sk: 'Mentor "$slug" sa nenašiel',
        en: 'Mentor "$slug" was not found',
      );
  static String get chatStreamError => _t('chatStreamError');
  static String get chatSuggestionsTitle => _t('chatSuggestionsTitle');
  static String get chatRetry => _t('chatRetry');
  static String get chatDeleteConfirm => _t('chatDeleteConfirm');
  static String get chatDelete => _t('chatDelete');

  // ── Profile Drawer (extra) ──
  static String get drawerNavigation => _t('drawerNavigation');
  static String get drawerProfile => _t('drawerProfile');
  static String get drawerMore => _t('drawerMore');
  static String get drawerHelp => _t('drawerHelp');

  // ── Email Verification Dialog (extra) ──
  static String get dialogEmailHint => _t('dialogEmailHint');

  // ── Widgets: Step Content Renderer ──
  static String get stepWriteAnswer => _t('stepWriteAnswer');
  static String get stepExplanation => _t('stepExplanation');
  static String get stepAiFeedback => _t('stepAiFeedback');

  // Formative feedback on open answers (BR-P745Q8). Three fixed sections plus
  // an optional hint — never a grade, never a verdict.
  static String get openFeedbackTitle => _t('openFeedbackTitle');
  static String get openFeedbackStrengths => _t('openFeedbackStrengths');
  static String get openFeedbackImprovements => _t('openFeedbackImprovements');
  static String get openFeedbackNextStep => _t('openFeedbackNextStep');
  /// Heading for the authored explanation inside the feedback card. Its own
  /// key rather than [stepExplanation]: there it is a note on the question,
  /// here it is the answer the student was aiming for (BR-PM7XQ3).
  static String get openFeedbackSolution => _t('openFeedbackSolution');
  static String get openFeedbackEvaluating => _t('openFeedbackEvaluating');
  static String get openFeedbackQuizPending => _t('openFeedbackQuizPending');
  static String get openFeedbackFailed => _t('openFeedbackFailed');
  static String get openFeedbackNotEvaluable => _t('openFeedbackNotEvaluable');
  static String get openFeedbackOffline => _t('openFeedbackOffline');
  static String get openFeedbackRetry => _t('openFeedbackRetry');
  static String get openFeedbackRework => _t('openFeedbackRework');

  /// Attempts still standing between the student and the model answer on an
  /// AI-guided question (BR-V9TQA7).
  ///
  /// Names what actually appears — the authored model answer, headed
  /// "Vzorová odpověď" in the card — rather than "an explanation", which
  /// promised something the student never got (BR-XTCYD2).
  ///
  /// Built with [_pick] rather than a template because Czech and Slovak take
  /// three plural forms — "1 pokus", "2 pokusy", "5 pokusů" — and splicing a
  /// number into one fixed sentence gets two of the three wrong.
  static String openFeedbackAttemptsLeft(int count) => _pick(
        cz: count == 1
            ? 'Zbývá poslední pokus, pak ti ukážu vzorové řešení.'
            : count < 5
                ? 'Zbývají $count pokusy, pak ti ukážu vzorové řešení.'
                : 'Zbývá $count pokusů, pak ti ukážu vzorové řešení.',
        sk: count == 1
            ? 'Zostáva posledný pokus, potom ti ukážem vzorové riešenie.'
            : count < 5
                ? 'Zostávajú $count pokusy, potom ti ukážem vzorové riešenie.'
                : 'Zostáva $count pokusov, potom ti ukážem vzorové riešenie.',
        en: count == 1
            ? 'One attempt left, then I will show you the model answer.'
            : '$count attempts left, then I will show you the model answer.',
      );
  static String get openAnswerEmpty => _t('openAnswerEmpty');
  static String get openPhotoAdd => _t('openPhotoAdd');
  static String get openPhotoCamera => _t('openPhotoCamera');
  static String get openPhotoGallery => _t('openPhotoGallery');
  static String get openPhotoRemove => _t('openPhotoRemove');
  static String get openPhotoAttached => _t('openPhotoAttached');
  static String get openPhotoUploading => _t('openPhotoUploading');
  static String get openPhotoUploadFailed => _t('openPhotoUploadFailed');
  static String get openPhotoUnreadable => _t('openPhotoUnreadable');
  static String get openPhotoTooLarge => _t('openPhotoTooLarge');
  static String get stepAudioError => _t('stepAudioError');
  static String get stepNumericHint => _t('stepNumericHint');
  /// Both take a [num], not a preformatted string: the decimal separator is
  /// then locale-aware at the one place that builds the sentence, and no call
  /// site can leak a Dart-style dot into Czech content (BR-5DZ6JD).
  static String stepTolerance(num value) =>
      'Tolerance: ± ${formatDecimal(value)}';
  static String stepCorrectNumber(num value) {
    final formatted = formatDecimal(value);
    return _pick(
      cz: 'Správná odpověď: $formatted',
      sk: 'Správna odpoveď: $formatted',
      en: 'Correct answer: $formatted',
    );
  }
  static String get stepVideoError => _t('stepVideoError');

  // ── Widgets: Block Step Engine ──
  static String get engineCheck => _t('engineCheck');
  static String get engineNext => _t('engineNext');
  static String get engineContinue => _t('engineContinue');
  static String get engineSelectAnswer => _t('engineSelectAnswer');
  static String get engineAnswerAllQuestions => _t('engineAnswerAllQuestions');
  static String get engineTryAgain => _t('engineTryAgain');

  // ── Widgets: Stat Card ──
  static String get statStreak => _t('statStreak');
  static String get statStreakSubtitle => _t('statStreakSubtitle');
  static String get statTrophiesSubtitle => _t('statTrophiesSubtitle');
  static String get sectionMyCourses => _t('sectionMyCourses');
  static String get sectionShowAllCourses => _t('sectionShowAllCourses');
  static String get statDays => _t('statDays');
  static String statDaysPlural(int days) => _pick(
        cz: days == 1 ? 'den' : 'dní',
        sk: days == 1 ? 'deň' : 'dní',
        en: days == 1 ? 'day' : 'days',
      );
  static String get statTrophies => _t('statTrophies');

  // ── Widgets: Kurzy Course Card ──
  static String get courseCardCompleted => _t('courseCardCompleted');

  // ── Widgets: Promo Card ──
  static String get promoDefaultBadge => _t('promoDefaultBadge');

  // ── Debug Report ──
  static String get aboutSendDebugReport => _t('aboutSendDebugReport');
  static String get aboutDebugReportTitle => _t('aboutDebugReportTitle');
  static String get aboutDebugReportMessage => _t('aboutDebugReportMessage');
  static String get aboutDebugReportSend => _t('aboutDebugReportSend');
  static String get aboutDebugReportSending => _t('aboutDebugReportSending');
  static String get aboutDebugReportSuccess => _t('aboutDebugReportSuccess');
  static String get aboutDebugReportOffline => _t('aboutDebugReportOffline');
  static String aboutDebugReportError(String e) => _pick(
        cz: 'Nepodařilo se odeslat report: $e',
        sk: 'Nepodarilo sa odoslať report: $e',
        en: 'Failed to send report: $e',
      );

  // ── Errors ──
  static String genericError(String error) => _pick(
        cz: 'Chyba: $error',
        sk: 'Chyba: $error',
        en: 'Error: $error',
      );

  // ── Block / Step display titles ──
  static String get blockDisplayTitleContent => _t('blockDisplayTitleContent');
  static String get blockDisplayTitleQuestion => _t('blockDisplayTitleQuestion');
  static String get blockDisplayTitleHint => _t('blockDisplayTitleHint');
  static String get blockDisplayTitleSolution => _t('blockDisplayTitleSolution');
  static String get blockDisplayTitleTask => _t('blockDisplayTitleTask');
  static String get blockDisplayTitleImage => _t('blockDisplayTitleImage');
  static String get blockDisplayTitleVideo => _t('blockDisplayTitleVideo');
  static String get blockDisplayTitleAudio => _t('blockDisplayTitleAudio');
  static String get blockDisplayTitleLearning => _t('blockDisplayTitleLearning');
  static String get blockDisplayTitleExercise => _t('blockDisplayTitleExercise');
  static String lessonFallbackName(int oneBasedIndex) => _pick(
        cz: 'Lekce $oneBasedIndex',
        sk: 'Lekcia $oneBasedIndex',
        en: 'Lesson $oneBasedIndex',
      );

  // ── Chat Personas (defaults) ──
  static String get personaAiTeacherName => _t('personaAiTeacherName');
  static String get personaAiTeacherSubtitle => _t('personaAiTeacherSubtitle');
  static String get personaAiTeacherDesc => _t('personaAiTeacherDesc');
  static String get personaMathMentorName => _t('personaMathMentorName');
  static String get personaMathMentorSubtitle => _t('personaMathMentorSubtitle');
  static String get personaMathMentorDesc => _t('personaMathMentorDesc');
  static String get personaStudyCoachName => _t('personaStudyCoachName');
  static String get personaStudyCoachSubtitle => _t('personaStudyCoachSubtitle');
  static String get personaStudyCoachDesc => _t('personaStudyCoachDesc');
  static String get personaLanguageMentorName => _t('personaLanguageMentorName');
  static String get personaLanguageMentorSubtitle => _t('personaLanguageMentorSubtitle');
  static String get personaLanguageMentorDesc => _t('personaLanguageMentorDesc');
  static String get personaSkolnikName => _t('personaSkolnikName');
  static String get personaSkolnikSubtitle => _t('personaSkolnikSubtitle');
  static String get personaSkolnikDesc => _t('personaSkolnikDesc');
  static String get personaCermatikName => _t('personaCermatikName');
  static String get personaCermatikSubtitle => _t('personaCermatikSubtitle');
  static String get personaCermatikDesc => _t('personaCermatikDesc');

  // ── New chat / mentor cards ─────────────────────────────────
  static String get newChatSubtitle => _t('newChatSubtitle');
  static String get newChatNoMentors => _t('newChatNoMentors');
  static String get mentorAvailabilityOnline => _t('mentorAvailabilityOnline');
  static String get mentorAvailabilityCourseOnly =>
      _t('mentorAvailabilityCourseOnly');
  static String get mentorKindAi => _t('mentorKindAi');
  static String get mentorKindLibrary => _t('mentorKindLibrary');

  // ── Gamification defaults (level titles) ──
  static String get levelTitle1 => _t('levelTitle1');
  static String get levelTitle2 => _t('levelTitle2');
  static String get levelTitle3 => _t('levelTitle3');
  static String get levelTitle4 => _t('levelTitle4');
  static String get levelTitle5 => _t('levelTitle5');
  static String get levelTitle6 => _t('levelTitle6');
  static String get levelTitle7 => _t('levelTitle7');
  static String get levelTitle8 => _t('levelTitle8');
  static String get levelTitle9 => _t('levelTitle9');
  static String get levelTitle10 => _t('levelTitle10');

  // Gamification defaults (trophies)
  static String get trophyFirstLessonTitle => _t('trophyFirstLessonTitle');
  static String get trophyFirstLessonDesc => _t('trophyFirstLessonDesc');
  static String get trophyDiligentStudentTitle => _t('trophyDiligentStudentTitle');
  static String get trophyDiligentStudentDesc => _t('trophyDiligentStudentDesc');
  static String get trophyQuizNoviceTitle => _t('trophyQuizNoviceTitle');
  static String get trophyQuizNoviceDesc => _t('trophyQuizNoviceDesc');
  static String get trophyMasterpieceTitle => _t('trophyMasterpieceTitle');
  static String get trophyMasterpieceDesc => _t('trophyMasterpieceDesc');
  static String get trophyMonthStreakTitle => _t('trophyMonthStreakTitle');
  static String get trophyMonthStreakDesc => _t('trophyMonthStreakDesc');

  // Gamification defaults (goals)
  static String get goal100XpTitle => _t('goal100XpTitle');
  static String get goal500XpTitle => _t('goal500XpTitle');
  static String get goal1000XpTitle => _t('goal1000XpTitle');
  static String get goalXpDesc => _t('goalXpDesc');
  static String get goal3DayStreakTitle => _t('goal3DayStreakTitle');
  static String get goal14DayStreakTitle => _t('goal14DayStreakTitle');
  static String get goalDailyStreakDesc => _t('goalDailyStreakDesc');
  static String get goalLevel3Title => _t('goalLevel3Title');
  static String get goalLevelDesc => _t('goalLevelDesc');
  static String get goalComplete10LessonsTitle => _t('goalComplete10LessonsTitle');
  static String get goalPracticeDesc => _t('goalPracticeDesc');

  // Gamification defaults (challenges)
  static String get challenge5000XpTitle => _t('challenge5000XpTitle');
  static String get challenge5000XpDesc => _t('challenge5000XpDesc');
  static String get challenge3CoursesTitle => _t('challenge3CoursesTitle');
  static String get challenge3CoursesDesc => _t('challenge3CoursesDesc');
  static String get challenge60DayStreakTitle => _t('challenge60DayStreakTitle');
  static String get challenge60DayStreakDesc => _t('challenge60DayStreakDesc');

  // ── Shared Device Banner ──
  static String get sharedDeviceBannerLabel => _t('sharedDeviceBannerLabel');

  /// Live idle-logout countdown shown in the shared-device banner. [time] is a
  /// preformatted MM:SS string that ticks down and resets on user activity,
  /// e.g. "Sdílené zařízení — odhlášení za 14:32".
  static String sharedDeviceBannerCountdown(String time) => _pick(
        cz: 'Sdílené zařízení — odhlášení za $time',
        sk: 'Zdieľané zariadenie — odhlásenie o $time',
        en: 'Shared device — sign-out in $time',
      );
  static String get sharedDeviceDialogTitle => _t('sharedDeviceDialogTitle');
  static String get sharedDeviceDialogMessage => _t('sharedDeviceDialogMessage');
  static String get sharedDeviceDialogKeepLoggedIn => _t('sharedDeviceDialogKeepLoggedIn');
  static String get sharedDeviceConvertError => _t('sharedDeviceConvertError');

  // ── Shop ──
  static String get shopTitle => _t('shopTitle');
  static String get shopPermanentItems => _t('shopPermanentItems');
  static String get shopSlotHead => _t('shopSlotHead');
  static String get shopSlotEyes => _t('shopSlotEyes');
  static String get shopSlotMouth => _t('shopSlotMouth');
  static String get shopSlotArms => _t('shopSlotArms');
  static String get shopSlotLegs => _t('shopSlotLegs');
  static String get shopSlotTorso => _t('shopSlotTorso');
  static String get shopSlotFace => _t('shopSlotFace');
  static String get shopSlotNeck => _t('shopSlotNeck');
  static String get shopSlotHeld => _t('shopSlotHeld');
  static String get shopEquipped => _t('shopEquipped');
  static String get shopEquip => _t('shopEquip');
  static String get shopUnequip => _t('shopUnequip');
  static String get shopGetFree => _t('shopGetFree');
  static String get shopPurchaseFailed => _t('shopPurchaseFailed');
  static String get shopOfflineNotice => _t('shopOfflineNotice');
  static String get shopLoadFailed => _t('shopLoadFailed');
  static String get shopEmptySlot => _t('shopEmptySlot');
  static String get shopRetry => _t('shopRetry');

  // ── ELO / Confidence ──
  static String get eloInsufficientData => _t('eloInsufficientData');
  static String get confidenceHigher => _t('confidenceHigher');
  static String get confidenceMedium => _t('confidenceMedium');
  static String get confidenceLower => _t('confidenceLower');
  static String get confidenceVeryLow => _t('confidenceVeryLow');

  // ═════════════════════════════════════════════════════════════════════
  // Czech strings (default locale)
  // ═════════════════════════════════════════════════════════════════════
  static const Map<String, String> _cz = {
    'navPrehled': 'Prehled',
    'navChat': 'Chat',
    'navKurzy': 'Kurzy',
    'navNovinky': 'Novinky',
    'shellDashboardSubtitle': 'Pokračuj v učení a zlepšuj se každý den.',
    'shellKurzySubtitle': 'Vyber si kurz a začni se učit vlastním tempem.',
    'shellGuestCtaTitle': 'Postup se uloží\naž po přihlášení.',
    'shellGuestCtaButton': 'Registrovat se',
    'shellGames': 'Hry',
    'shellShop': 'Obchod',
    'progressCardTitle': 'Tvůj postup',
    'progressCardCompleted': 'Hotovo',
    'progressCardDetail': 'Zobrazit detail',
    'progressCardHintStart': 'Skvělý začátek!',
    'progressCardHintGoing': 'Jde ti to skvěle!',
    'progressCardHintDone': 'Máš hotovo. Paráda!',
    'progressCardLessons': '{done} z {total} lekcí',
    'continueLessonTitle': 'Pokračuj v lekci',
    'continueLessonBadge': 'AKTUÁLNÍ',
    'continueLessonButton': 'Pokračovat v lekci',
    'continueLessonEmpty': 'Zatím jsi nezačal žádnou lekci.',
    'continueLessonAllDone': 'Všechny lekce máš hotové.',
    'continueLessonQuizOnly': 'Otevři kurz a pusť se do kvízu.',
    'continueLessonOpenCourse': 'Otevřít kurz',
    'continueLessonSteps': '{done} z {total} kroků',
    'recentActivityTitle': 'Nedávná aktivita',
    'recentActivityShowAll': 'Zobrazit vše',
    'recentActivityEmpty': 'Zatím sbíráme data o tvé aktivitě.',
    'kurzySearchHint': 'Hledat kurz…',
    'kurzyFilterButton': 'Filtr',
    'kurzySearchEmpty': 'Žádný kurz neodpovídá hledání.',
    'courseCardStart': 'Začít kurz',
    'courseCardContinue': 'Pokračovat',
    'courseCardReview': 'Projít znovu',
    'courseBackToAll': 'Zpět na všechny kurzy',
    'courseTabLessons': 'Lekce',
    'courseTabAbout': 'O kurzu',
    'courseTabSkills': 'Dovednosti',
    'courseTabStats': 'Statistiky',
    'courseSaveButton': 'Uložit kurz',
    'courseShowAllLessons': 'Zobrazit všechny lekce ({count})',
    'courseShowFewerLessons': 'Zobrazit méně',
    'courseOpenLesson': 'Otevřít',
    'courseSkillsInCourse': 'Dovednosti v kurzu',
    'courseSkillsEmpty':
        'Dovednosti se objeví, až vyřešíš pár úloh.',
    'courseStatsPlaceholder': 'Statistiky kurzu teprve připravujeme.',
    'courseDetailedStats': 'Zobrazit detailní statistiky',
    'courseTrophyHint': 'Dokonči a získej trofej!',
    'lessonAiHelpTitle': 'AI nápověda',
    'lessonAiHelpQuestion': 'Potřebuješ pomoct?',
    'lessonAiHelpBody': 'Zeptej se AI asistenta na cokoli k této lekci.',
    'lessonAiHelpButton': 'Otevřít chat s AI',
    'courseLevelLabel': 'Úroveň: {level}',
    'skillLevelLabel': 'Úroveň {level}',
    'appTitle': 'Edu',
    'appName': 'EduAI',
    'welcomeGreeting': 'Ahoj',
    'welcomeDescription': 'Vítej ve své\nnové appce!',
    'guideHeading': 'Začněte s návodem',
    'guideTitle': 'Jak používat EDU AI',
    'guideSubtitle':
        'Rychlý úvod do aplikace EDU AI. '
        'Kde najdeš AI pomoc, jak fungují lekce '
        'a jak si ukládat věci k opakování.',
    'guideButton': 'Začít cvičení',
    'onboardingLoadError':
        'Úvodní kurz se nepodařilo připravit. Zkontroluj připojení a zkus to prosím znovu.',
    'practiceTitle': 'Procvičování',
    'practiceStart': 'Začít procvičování',
    'practiceEmpty': 'Teď nemáš nic k procvičení. Vrať se později!',
    'practiceDashSubtitle': 'Zopakuj si, co tě čeká dnes',
    'practiceBonusHint':
        'Na dnešek máš hotovo. Chceš pokračovat? Připravili jsme ti sadu navíc.',
    'practiceBonusStart': 'Procvičovat sadu navíc',
    'practiceScopeTitle': 'Co chceš procvičovat',
    'practiceScopeAllHint': 'Bez výběru se procvičuje vše.',
    'practiceScopeSelectAll': 'Vybrat vše',
    'practiceScopeOther': 'Ostatní',
    'practiceScopeEmpty':
        'Ve vybraných oblastech teď není nic k procvičení. Zkus vybrat další oblasti.',
    'promoBadge': 'KNIHOVNA',
    'promoTitle': 'Prozkoumej kurzy!',
    'promoDescription': 'V knihovně najdeš kurzy,\nkteré máš nyní k dispozici',
    'promoDescriptionReward': 'Studuj a čeká tě odměna:\nhra Oblaka 🤸',
    'dashGreetingWelcome': 'Vítej ve své nové appce!',
    'dashGreetingKeepGoing': 'Pokračuj v učení a zlepšíš se každý den.',
    'dashGreetingProud': 'Mám radost, co už jsme spolu dokázali.',
    'dashGreetingCheering': 'Jedeš bomby, fandím ti 👏',
    'practiceNothingDue':
        'Teď nemáš nic k opakování. Projdi lekci a karty se objeví.',
    'globalQuizHeading': 'Dej si kvíz',
    'globalQuizTitle': 'Otestuj se napříč kurzy',
    'globalQuizSubtitle': 'Náhodné otázky ze všech tvých kurzů',
    'globalQuizStart': 'Spustit kvíz',
    'jpzBadge': 'PŘIJÍMAČKY',
    'jpzTitle': 'Uvažuješ o přijímačkách?',
    'jpzDescription': 'Projdi si úvod k jednotné\npřijímací zkoušce',
    'jpzCermatikDescription': 'Zeptej se Cermatíka na cokoli\nkolem přijímaček',
    'statShopSubtitle': 'Vyber si nový vzhled\npro svou postavičku.',
    'statShopAction': 'Otevřít',
    'sectionQuickQuizzes': 'Rychlé kvízy',
    'sectionContinue': 'Pokračovat',
    'defaultUserName': 'Uživatel',
    'ageGateTitle': 'Než začneme',
    'ageGateQuestion': 'Je ti více než {age} let?',
    'ageGateYes': 'Ano',
    'ageGateNo': 'Ne',
    'ageGateCountryLabel': 'Země',
    'ageGateCountryQuestion': 'Ve které zemi bydlíš?',
    'consentIntroTitle': 'Potřebuješ souhlas rodiče',
    'consentIntroBody':
        'Napiš e-mail svého rodiče. Pošleme mu zprávu a on ti řekne kód, '
        'kterým se do aplikace přihlásíš.',
    'consentEmailLabel': 'E-mail rodiče',
    'consentEmailInvalid': 'Zkontroluj e-mail — něco tam chybí.',
    'consentSend': 'Odeslat rodiči',
    'consentWaitingTitle': 'Poslali jsme rodiči e-mail',
    'consentWaitingBody':
        'Požádej ho, ať ho otevře. Řekne ti kód pro vstup do aplikace.',
    'consentEnterCode': 'Zadat kód',
    'consentGenericError': 'Něco se nepovedlo. Zkus to prosím znovu.',
    'consentNetworkError':
        'Nepodařilo se to odeslat — zkontroluj připojení k internetu a zkus to znovu.',
    'consentConfirmTitle': 'Potvrzení souhlasu',
    'consentConfirmBody':
        'Zadejte šestiznakový kód z e-mailu. Tím potvrzujete souhlas '
        's používáním EDU-AI vaším dítětem.',
    'consentConfirmCta': 'Potvrdit souhlas',
    'consentConfirmSuccess':
        'Souhlas potvrzen. Přihlašovací kódy jsme vám poslali e-mailem.',
    'consentConfirmFailure': 'Kód je neplatný nebo vypršel. Požádejte o nový.',
    'consentConfirmInvalidLink':
        'Tento odkaz není platný. Zkontrolujte, jestli jste ho zkopírovali celý, '
        'nebo si nechte poslat nový e-mail.',
    'consentConfirmSuccessNoMail':
        'Souhlas byl potvrzen. Přihlašovací kódy se ale nepodařilo odeslat e-mailem '
        '(počet dětských účtů: {count}). Níže si nechte poslat odkaz pro správu '
        'souhlasu — tam kódy vygenerujete znovu.',
    'consentManageTitle': 'Správa souhlasu',
    'consentManageChildren': 'Účty dětí',
    'consentManageNewCode': 'Nový kód',
    'consentManageNewCodeHint':
        'Zapište si ho — znovu ho už nezobrazíme. Starý kód přestal platit.',
    'consentManageRevoke': 'Odvolat souhlas',
    'consentManageRevokeConfirm':
        'Opravdu odvolat? Účty se okamžitě zablokují a data smažeme do 30 dní.',
    'consentManageRevoked': 'Souhlas byl odvolán.',
    'consentManageRevokedDetail': 'Účty jsou zablokované. Data smažeme do 30 dní.',
    'consentManageExpired': 'Odkaz vypršel. Nechte si poslat nový.',
    'consentManageResend': 'Poslat odkaz znovu',
    'consentManageResendSent': 'Pokud e-mail známe, odkaz je na cestě.',
    'consentManageLoadError':
        'Nepodařilo se načíst — zkontrolujte připojení k internetu a zkuste to znovu.',
    'consentManageRetry': 'Zkusit znovu',
    'minorNameLocked': 'Přezdívku u dětského účtu měnit nelze.',
    'chatTitle': 'Chat',
    'chatLockedMessage': 'Chat se vám otevře po získání vyšší úrovně',
    'addTitle': 'Připojit / Přidat',
    'contentComingSoon': 'Tento obsah teprve připravujeme',
    'novinkyTitle': 'Novinky',
    'novinkyEmpty': 'Zatím žádné novinky',
    'novinkyError': 'Nepodařilo se načíst novinky',
    'novinkyLoading': 'Načítání novinek…',
    'novinkyRetry': 'Zkusit znovu',
    'novinkyPickArticle': 'Vyber novinku vlevo a přečti si ji tady.',
    'doplnkyTitle': 'Doplňky',
    'doplnkySubtitle': 'Minihry, úprava avatara a motivy aplikace na jednom místě.',
    'doplnkyAvatarTitle': 'Editor avatara',
    'doplnkyAvatarPerex': 'Obleč si svého maskota — vyber mu čepici, brýle a další doplňky.',
    'doplnkyThemeTitle': 'Editor motivů',
    'doplnkyThemePerex': 'Změň si barvy aplikace — vyber si z připravených motivů, nebo si vytvoř vlastní.',
    'doplnkyOpen': 'Otevřít',
    'miniGamesTitle': 'Minihry',
    'miniGamesSubtitle': 'Hraj hry a získávej odměny!',
    'miniGamesEmpty': 'Zatím žádné minihry',
    'miniGamesError': 'Nepodařilo se načíst minihry',
    'miniGamesRetry': 'Zkusit znovu',
    'miniGamesPlay': 'Hrát',
    'miniGamesComingSoon': 'Hru připravujeme',
    'miniGamesOffline': 'Potřebuješ připojení',
    'miniGamesSensorGyroscope': 'Gyroskop',
    'miniGamesLocked': 'Hra teď není dostupná',
    'miniGamesStartFailed': 'Hru se nepodařilo spustit',
    'gameTapToStart': 'Spustit hru',
    'gameReadyHeadline': 'Vyskákej se co nejvýš!',
    'gameRuleClimb': 'Skáčeš sám — ty jen řídíš, kam dopadneš',
    'gameRuleCoin': 'Sbírej Edux mince za body',
    'gameRuleBoost': 'Hvězda tě vystřelí raketou vzhůru',
    'gameRuleFall': 'Spadneš dolů = konec',
    'gameHintTilt': 'Nakláněj zařízení do stran',
    'gameHintKeys': 'Ovládej šipkami ← →',
    'gameHintButtons': 'Ovládej šipkami ← → dole na obrazovce',
    'gameSteerLeft': 'Doleva',
    'gameSteerRight': 'Doprava',
    'gameScore': 'Skóre',
    'gameOver': 'Konec hry',
    'gameCoinsCollected': 'Mince',
    'gameBack': 'Zpět na hry',
    'gamePaused': 'Pauza',
    'gameResume': 'Pokračovat',
    'gameQuit': 'Ukončit hru',
    'gameQuitConfirm': 'Ukončit hru? Pokus se ti nevrátí.',
    'gameExit': 'Zavřít hru',
    'kurzyTitle': 'Kurzy',
    'filterAll': 'Všechny',
    'filterInProgress': 'Probíhající',
    'filterNotStarted': 'Nezahájené',
    'filterCompleted': 'Dokončeno',
    'kurzyEmptyTitle': 'Zatím nemáš žádné kurzy',
    'kurzyEmptySubtitle': 'Prozkoumej knihovnu a vyber si kurzy, které tě zajímají',
    'kurzyExploreLibrary': 'Prozkoumat knihovnu',
    'defaultCourseName': 'Kurz',
    'authHeadline': 'Škola v kapse, AI na dosah',
    'authFormHeadline': 'Přihlásit se',
    'authHeroTaglineExpanded': 'Škola v kapse!',
    'authCodeLabel': 'Kód kurzu nebo přihlašovací kód',
    'authVerifyingCode': 'Ověřuji kód...',
    'authContinue': 'Pokračovat',
    'authOr': 'nebo',
    'authLoginSignUp': 'Přihlášení / Registrace',
    'authTerms': 'Podmínky',
    'authPrivacy': 'Soukromí',
    'authEmailHint': 'Tvůj e-mail',
    'authLogin': 'Přihlásit se',
    'authOrCzech': 'Nebo',
    'authGoogleLogin': 'Přihlásit pomocí Google',
    'authMicrosoftLogin': 'Přihlásit pomocí Microsoft',
    'authAppleLogin': 'Přihlásit pomocí Apple',
    'authTermsNotice': 'Registrací souhlasíš s našimi\n',
    'authTermsAndPrivacy': 'Podmínkami a Zásadami ochrany soukromí',
    'authTermsLink': 'Podmínkami',
    'authTermsPrivacyJoiner': ' a ',
    'authPrivacyLink': 'Zásadami ochrany soukromí',
    'authEmptyEmailError': 'Zadej prosím e-mailovou adresu',
    'authInvalidEmailError': 'Zadej platnou e-mailovou adresu',
    'authUserCreateError': 'Nepodařilo se vytvořit uživatele',
    'authCourseLoadError': 'Kurz se nepodařilo načíst',
    'authCourseDownloadError': 'Kurz se nepodařilo stáhnout. Zkontroluj připojení a zkus to znovu.',
    'authKeepLoggedInLabel': 'Zůstat trvale přihlášen — nejedná se o sdílené zařízení',
    'profileTitle': 'Můj účet',
    'profileSectionAccount': 'Účet',
    'profileEditProfile': 'Upravit profil',
    'profileEditAvatar': 'Upravit avatara',
    'profilePrivacy': 'Soukromí a zabezpečení',
    'profileSectionSettings': 'Nastavení',
    'profileTheme': 'Motiv',
    'profileNotifications': 'Oznámení',
    'profileLanguage': 'Jazyk',
    'profileComingSoon': 'Připravujeme',
    'profileSectionMore': 'Další',
    'profileAbout': 'O aplikaci',
    'profileTerms': 'Podmínky použití',
    'profileLogout': 'Odhlásit se',
    'profileLogin': 'Přihlásit se',
    'profileStatCourses': 'Kurzy',
    'profileStatStreak': 'Streak',
    'profileStatAchievements': 'Úspěchy',
    'profileQuickAchievements': 'Úspěchy',
    'profileQuickLibrary': 'Knihovna',
    'profileSetupTitle': 'Přizpůsob si svůj profil',
    'profileSetupSubtitle': 'Všechny úpravy můžeš později změnit v nastavení profilu',
    'profileSetupNameLabel': 'Přezdívka',
    'profileSetupNameHint': 'Jak tě vidí ostatní',
    'profileSetupColorLabel': 'Barevný profil',
    'profileSetupVibeTitle': 'Vyber si svůj vibe!',
    'profileSetupVibeSubtitle':
        'Vyber si vzhled svého avatara. Další doplňky získáš za svou aktivitu.',
    'profileSetupVibeNone': 'Bez doplňku',
    'profileSetupAvatarLabel': 'Vyber si avatara',
    'profileSetupSubjectsLabel': 'Vyber si prostředí',
    'profileSetupNameError': 'Zadej prosím svou přezdívku',
    'profileSetupSyncWarning': 'Profil uložen lokálně. Synchronizace proběhne později.',
    'editProfileTitle': 'Upravit profil',
    'editProfileNameLabel': 'Přezdívka',
    'editProfileEmailLabel': 'E-mail',
    'editProfileNameHint': 'Zadej přezdívku',
    'editProfileEmailReadonly': 'E-mail nelze změnit',
    'editProfileEmptyNameError': 'Přezdívka nemůže být prázdná',
    'editProfileSaveError': 'Nepodařilo se uložit změny',
    'editProfileSaveButton': 'Uložit změny',
    'libraryTitle': 'Knihovna',
    'librarySubtitle': 'Vyber si kurzy a stáhni si je',
    'libraryCodeTitle': 'Máš kód kurzu?',
    'libraryCodeButton': 'Zadat kód kurzu',
    'libraryCodeShort': 'Zadej 6místný kód',
    'classroomJoinTitle': 'Připojit se ke třídě',
    'classroomJoinButton': 'Zadat kód žáka',
    'classroomJoinCodeHint': 'Zadej 6místný kód žáka, který ti dal učitel',
    'classroomJoinSearching': 'Hledám třídu…',
    'classroomJoinOffline': 'Pro připojení ke třídě musíš být online',
    'classroomJoinYes': 'Ano',
    'classroomJoinNo': 'Ne',
    'classroomJoinSubmit': 'Připojit se',
    'classroomJoinClassCodeHint': 'Zadej 4místný kód třídy, který ti dal učitel',
    'classroomJoinUseStudentCode': 'Mám 6místný kód žáka',
    'classroomJoinUseClassCode': 'Mám 4místný kód třídy',
    'classroomJoinClassCodeShort': 'Zadej 4místný kód',
    'classroomJoinCodeNotFound': 'Kód třídy nebyl nalezen',
    'classroomJoinLoginRequired':
        'Pro připojení ke třídě se musíš přihlásit. Po přihlášení tě do třídy připojíme.',
    'classroomJoinNotAllowed': 'Tento účet se ke třídě připojit nemůže',
    'editProfileClassroomsLabel': 'Třídy',
    'editProfileNoClassrooms': 'Zatím nejsi v žádné třídě',
    'libraryLoginRequired': 'Pro stažení kurzu se musíš přihlásit',
    'libraryLoggedOnlyTitle': 'Kurz jen pro přihlášené',
    'libraryLoggedOnlyBody':
        'Tenhle kurz je dostupný jen přihlášeným uživatelům. Přihlas se a hned '
            'se ti otevře — o svůj dosavadní postup nepřijdeš.',
    'libraryLoggedOnlyAction': 'Přihlásit se',
    'libraryLinkOpenFailed': 'Odkaz se nepodařilo otevřít',
    'libraryLoadError': 'Kurz se nepodařilo načíst',
    'librarySearchingCourse': 'Hledám kurz...',
    'libraryEmptyTitle': 'Knihovna je prázdná',
    'libraryEmptySubtitle': 'Zatím tu nejsou žádné kurzy k dispozici',
    'libraryCoursesLoadError': 'Nepodařilo se načíst kurzy',
    'libraryCourseAlreadyCompleted': 'Tento kurz byl již dokončen.',
    'libraryUpdating': 'Aktualizuji...',
    'libraryDownloading': 'Stahuji...',
    'libraryUpdate': 'Aktualizovat',
    'libraryLaunch': 'Spustit',
    'libraryDownload': 'Stáhnout',
    'courseProgress': 'Postup',
    'courseDescription': 'Popis kurzu',
    'courseLessons': 'Lekce',
    'courseShowMore': 'Zobrazit více',
    'courseShowLess': 'Skrýt',
    'courseQuizzes': 'Kvízy',
    'courseShowAll': 'Zobrazit vše',
    'courseContinueLesson': 'Pokračovat v lekci',
    'courseExercise': 'Cvičení',
    'courseQuiz': 'Kvíz',
    'courseCompleted': 'DOKONČENO',
    'courseCurrent': 'AKTUÁLNÍ',
    'courseCorruptedTitle': 'Kurz se nepodařilo načíst',
    'courseCorruptedMessage': 'Data kurzu jsou neúplná nebo poškozená. Zkuste kurz stáhnout znovu v knihovně.',
    'courseBack': 'Zpět',
    'courseStartQuiz': 'Začít kvíz',
    'courseContinueQuiz': 'Pokračovat v kvízu',
    'courseQuizUnlockHint': 'Odpověz na otázky a odemkni lekce',
    'courseNoBookmarks': 'Zatím nemáš žádné uložené bloky k procvičování.\nPřidej je pomocí záložky v lekcích.',
    'courseNoQuestions': 'V tomto kurzu nejsou žádné otázky.',
    'courseUpdateAvailable': 'K dispozici je nová verze kurzu',
    'courseUpdateRequired': 'Aktualizujte kurz pro pokračování',
    'courseCardUpdate': 'Aktualizace',
    'courseActionLessons': 'Lekce',
    'lessonEmptyTitle': 'Obsah lekce se připravuje',
    'lessonEmptyMessage': 'Tato lekce zatím nemá žádný obsah.',
    'lessonFinishCourse': 'Dokončit kurz',
    'lessonNextLesson': 'Další lekce',
    'lessonBackToDetail': 'Zpět na detail kurzu',
    'lessonCourseCompleted': 'Gratulujeme! Dokončil jsi celý kurz.',
    'lessonSelectAnswerFirst': 'Nejprve vyber odpověď',
    'lessonExplanation': 'Vysvětlení',
    'lessonFeedbackClear': 'Už je to jasné',
    'lessonFeedbackPractice': 'Přidat k procvičování',
    'lessonFeedbackPracticeAdded': 'Přidáno k procvičování',
    'mentorSheetInputHint': 'Zeptej se AI mentora',
    'mentorSheetNoHelp': 'Zkus mi napsat vlastními slovy, čemu nerozumíš — vysvětlím ti to jinak.',
    'lessonFeedbackConfused': 'Nerozumím tomu',
    'lessonFeedbackClarify': 'Upřesni svůj dotaz',
    'lessonFeedbackHint': 'Napiš více o problému...',
    'lessonFeedbackThanks': 'Děkujeme za zpětnou vazbu!',
    'lessonFeedbackSend': 'Odeslat',
    'lessonVideoError': 'Nepodařilo se načíst video',
    'lessonWriteAnswer': 'Napiš odpověď...',
    'lessonCheckAnswer': 'Zkontrolovat',
    'lessonCorrect': 'Správně!',
    'lessonIncorrect': 'Zatím ne',
    'lessonQuestionLabel': 'Otázka',
    'quizTitle': 'Kvíz',
    'quizExerciseTitle': 'Cvičení',
    'quizCompleted': 'Kvíz dokončen!',
    'quizReviewCompleted': 'Opakování dokončeno!',
    'quizAllCorrect': 'Výborně! Všechno správně!',
    'quizGreatJob': 'Skvělá práce!',
    'quizTryAgain': 'Zkus to znovu!',
    'quizGreatReview': 'Skvělé opakování!',
    'quizDone': 'Hotovo',
    'quizConfirmSubmit': 'Opravdu chceš kvíz odeslat? Potom se k němu již nejde vrátit.',
    'quizConfirmBack': 'Zpět',
    'quizConfirmSend': 'Odeslat',
    'quizConfirmExitMessage': 'Opravdu chcete kvíz ukončit? Není možné se vrátit ani ho spustit znovu.',
    'quizConfirmExitLeave': 'Ukončit',
    'quizConfirmExitStay': 'Pokračovat',
    'quizThankYou': 'Skvělé, díky. Teď vím, jaké úlohy ti příště nabídnu.',
    'quizRetry': 'Zkusit znovu',
    'quizReview': 'Opakování',
    'quizFinish': 'Dokončit',
    'quizNext': 'Další',
    'quizCheck': 'Zkontrolovat',
    'quizAnswerHint': 'Zadej odpověď...',
    'quizCorrectLabel': 'Správně!',
    'quizIncorrectLabel': 'Špatně',
    'quizAskAi': 'Zeptat se AI',
    'quizAnswersSaved': 'Odpovědi byly uloženy, děkujeme',
    'chatContextFallbackPrompt': 'Můžeš mi to prosím vysvětlit jinak?',
    'exerciseSelectCorrect': 'Vyber správnou odpověď',
    'exerciseSelectAll': 'Vyber všechny správné odpovědi',
    'exerciseWriteAnswer': 'Napiš svou odpověď',
    'exerciseAnswerHint': 'Tvoje odpověď...',
    'exerciseCorrect': 'Správně',
    'exerciseIncorrect': 'Špatně',
    'trueFalseTrue': 'Ano',
    'trueFalseFalse': 'Ne',
    'exerciseExplanationLabel': 'Vysvětlení:',
    'achievementsTitle': 'Úspěchy',
    'achievementsTrophies': 'Trofeje',
    'achievementsCoins': 'Mince EDUX',
    'achievementsEarnedTrophies': 'Získané trofeje',
    'achievementsChallenges': 'Výzvy',
    'achievementsSkills': 'Dovednosti',
    'achievementsSkillsPlaceholder': 'Těším se, co společně zvládneme.',
    'skillTabAll': 'Všechny',
    'skillTabBeginner': 'Začátečník',
    'skillTabIntermediate': 'Pokročilý',
    'skillTabExpert': 'Expert',
    'achievementsGoals': 'Cíle',
    'challengeMasterpiece': 'Mistrovský kousek',
    'trophyBiologist': 'Mistrovský biolog',
    'trophyBiologistDesc': 'Získej 90% nebo více v kvízu',
    'trophyWeekStreak': 'Týdenní série',
    'trophyWeekStreakDesc': 'Uč se 7 dní v řadě',
    'goalCompleteLessons': 'Dokončit 10 lekcí',
    'goalCompleteLessonsDesc': '+100 XP po dokončení',
    'goalPerfectScores': 'Získat 5 perfektních skóre',
    'goalPerfectScoresDesc': '+150 XP po dokončení',
    'timeYesterday': 'Včera',
    'timeJustNow': 'Právě teď',
    'termsTitle': 'Podmínky použití',
    'termsLastUpdated': 'Poslední aktualizace: 19. ledna 2026',
    'termsSection1Title': '1. Úvodní ustanovení',
    'termsSection1Body':
        'Tyto podmínky použití upravují práva a povinnosti uživatelů '
        'aplikace EDU-AI. Používáním aplikace souhlasíte s těmito '
        'podmínkami. Aplikace je určena pro vzdělávací účely a je '
        'provozována společností EduAI s.r.o.',
    'termsSection2Title': '2. Uživatelský účet',
    'termsSection2Body':
        'Pro využívání plných funkcí aplikace je nutné vytvořit '
        'uživatelský účet. Uživatel je povinen poskytnout pravdivé '
        'údaje a chránit své přihlašovací údaje. Za veškeré aktivity '
        'provedené pod vaším účtem nesete odpovědnost.',
    'termsSection3Title': '3. Autorská práva',
    'termsSection3Body':
        'Veškerý obsah v aplikaci, včetně kurzů, textů, grafiky a '
        'softwarového kódu, je chráněn autorským právem. Uživatel '
        'získává pouze licenci k osobnímu nekomerčnímu využití obsahu. '
        'Kopírování, distribuce nebo komerční využití bez písemného '
        'souhlasu je zakázáno.',
    'termsSection4Title': '4. Pravidla používání',
    'termsSection4Body':
        'Uživatel se zavazuje používat aplikaci v souladu s právními '
        'předpisy a dobrými mravy. Je zakázáno šířit nevhodný obsah, '
        'pokoušet se o neoprávněný přístup k systémům, nebo jakýmkoli '
        'způsobem narušovat chod aplikace.',
    'termsSection5Title': '5. Ochrana osobních údajů',
    'termsSection5Body':
        'Zpracování osobních údajů se řídí Zásadami ochrany osobních '
        'údajů a nařízením GDPR. Shromažďujeme pouze údaje nezbytné '
        'pro poskytování služeb. Vaše údaje nikdy neprodáváme třetím '
        'stranám.',
    'termsSection6Title': '6. Omezení odpovědnosti',
    'termsSection6Body':
        'Aplikace je poskytována "tak jak je". Provozovatel nenese '
        'odpovědnost za případné škody vzniklé používáním aplikace, '
        'ztrátu dat nebo přerušení služby. Maximální odpovědnost je '
        'omezena na výši zaplacených poplatků.',
    'termsSection7Title': '7. Změny podmínek',
    'termsSection7Body':
        'Vyhrazujeme si právo tyto podmínky kdykoli změnit. O změnách '
        'budete informováni prostřednictvím aplikace nebo e-mailem. '
        'Pokračováním v používání aplikace po změně podmínek '
        'vyjadřujete souhlas s novým zněním.',
    'termsSection8Title': '8. Kontakt',
    'termsSection8Body':
        'V případě dotazů nebo připomínek nás můžete kontaktovat na '
        'e-mailové adrese podpora@eduai.cz nebo prostřednictvím '
        'kontaktního formuláře v aplikaci.',
    'privacyTitle': 'Soukromí a zabezpečení',
    'privacyComingSoon': 'Připravujeme',
    'privacyComingSoonMessage':
        'Na nastavení soukromí a zabezpečení právě pracujeme. Brzy zde najdete možnosti pro správu vašich dat a bezpečnostní nastavení.',
    'aboutSavedBookmarks': 'Uložené záložky',
    'bookmarksListTitle': 'Uložené záložky',
    'bookmarksListEmpty': 'Zatím nemáš žádné uložené záložky.\nPřidej je pomocí záložky v lekcích.',
    'bookmarksListCourseNotDownloaded': 'Kurz není stažen',
    'aboutTitle': 'O aplikaci',
    'aboutSectionAppInfo': 'Informace o aplikaci',
    'aboutAppName': 'EduAI',
    'aboutLabelName': 'Název',
    'aboutLabelVersion': 'Verze',
    'aboutLabelBuild': 'Build',
    'aboutBuildValue': 'Release',
    'aboutLabelFlutter': 'Flutter',
    'aboutFlutterValue': 'SDK 3.10+',
    'aboutVersionUnavailable': 'Nedostupná',
    'aboutSectionStatus': 'Stav systému',
    'aboutDatabase': 'Databáze',
    'aboutDatabaseReady': 'Připravena',
    'aboutDatabaseNotInit': 'Neinicializována',
    'aboutUserLoggedIn': 'Uživatel přihlášen',
    'aboutGuestPin': 'Host (PIN)',
    'aboutYes': 'Ano',
    'aboutNo': 'Ne',
    'aboutApiAuth': 'API autorizace',
    'aboutConnection': 'Připojení',
    'aboutConnectionChecking': 'Kontrola...',
    'aboutConnectionError': 'Chyba',
    'aboutSyncState': 'Sync stav',
    'aboutSyncReady': 'Připraveno',
    'aboutSyncSyncing': 'Synchronizace...',
    'aboutSyncError': 'Chyba',
    'aboutLastSync': 'Poslední sync',
    'aboutNextSync': 'Další sync',
    'aboutSyncNever': 'Zatím neproběhl',
    'aboutSectionDbStats': 'Statistiky databáze',
    'aboutCoursesCount': 'Počet kurzů',
    'aboutPendingSync': 'Čekající sync',
    'aboutSectionActions': 'Akce',
    'aboutForceSync': 'Vynutit synchronizaci',
    'aboutClearSyncQueue': 'Vymazat sync frontu',
    'aboutRefreshStatus': 'Obnovit stav',
    'aboutClearAuthToken': 'Vymazat auth token',
    'aboutClearCourses': 'Vymazat kurzy z knihovny',
    'aboutFactoryReset': 'Tovární reset (smazat vše)',
    'aboutSectionApiConfig': 'API konfigurace',
    'aboutBaseUrl': 'Base URL',
    'aboutAuth': 'Auth',
    'aboutAuthValue': 'Laravel Sanctum',
    'aboutConnWifi': 'WiFi',
    'aboutConnMobile': 'Mobilní data',
    'aboutConnEthernet': 'Ethernet',
    'aboutConnOffline': 'Offline',
    'aboutSyncCompleted': 'Synchronizace dokončena',
    'aboutClearTokenTitle': 'Vymazat token?',
    'aboutClearTokenMessage': 'Toto vás odhlásí z aplikace. Pokračovat?',
    'aboutTokenCleared': 'Token vymazán',
    'aboutClearCoursesTitle': 'Vymazat kurzy?',
    'aboutClearCoursesMessage':
        'Toto smaže všechny stažené kurzy z tvé lokální knihovny. '
        'Postup v kurzech bude ztracen. Pokračovat?',
    'aboutNoUser': 'Žádný přihlášený uživatel',
    'aboutFactoryResetTitle': 'Tovární reset?',
    'aboutFactoryResetMessage':
        'Toto smaže VŠECHNA lokální data: uživatele, kurzy, '
        'postup, záložky, auth token i sync frontu. '
        'Aplikace se vrátí do výchozího stavu jako po čisté instalaci.\n\n'
        'Opravdu pokračovat?',
    'aboutDeleteAll': 'Smazat vše',
    'aboutTimeJustNow': 'právě teď',
    'aboutTimeSoon': 'za chvíli',
    'themeTitle': 'Motiv',
    'themeDefault': 'Klasický fialový motiv',
    'themeOcean': 'Modrý motiv inspirovaný oceánem',
    'themeSunset': 'Teplý motiv v oranžových tónech',
    'themeFire': 'Hřejivý motiv v barvách ohně',
    'themeLight': 'Vzdušný světlý motiv',
    'themeNeutral': 'Klidný motiv v šedých tónech',
    'themeCustom': 'Vlastní motiv',
    'themeCreateNew': 'Vytvořit nový motiv',
    'themeImportJson': 'Importovat JSON',
    'themeImportTitle': 'Import motivu',
    'themeImportHint': 'Vlož JSON motivu…',
    'themeImportButton': 'Importovat',
    'themeImportError': 'Neplatný JSON motivu',
    'themeImportSuccess': 'Motiv úspěšně importován',
    'themeEditorTitle': 'Editor motivu',
    'themeEditorName': 'Název motivu',
    'themeEditorNameHint': 'Můj motiv',
    'themeEditorSave': 'Uložit motiv',
    'themeEditorExport': 'Exportovat JSON',
    'themeEditorExportCopied': 'JSON zkopírován do schránky',
    'themeEditorDelete': 'Smazat motiv',
    'themeEditorDeleteConfirm': 'Opravdu chceš smazat tento motiv?',
    'themeEditorDeleteYes': 'Smazat',
    'themeEditorCancel': 'Zrušit',
    'themeEditorConfirm': 'Potvrdit',
    'themeEditorNameEmpty': 'Zadej název motivu',
    'themeEditorGroupCoreBrand': 'Hlavní barvy',
    'themeEditorGroupStatus': 'Stavové barvy',
    'themeEditorGroupUi': 'UI prvky',
    'themeEditorGroupCards': 'Karty a pozadí',
    'themeEditorGroupAvatars': 'Avatary',
    'themeEditorGroupSubjects': 'Předměty',
    'themeEditorGroupOther': 'Další',
    'themeEditorPickColor': 'Vybrat barvu',
    'colorPickerHexLabel': 'Hex:',
    'emailVerificationTitle': 'Ověření e-mailu',
    'emailVerificationCodePrompt': 'Zadej 6místný kód z e-mailu',
    'emailVerificationVerify': 'Ověřit',
    'emailVerificationResend': 'Nepřišel kód? Odeslat znovu',
    'emailVerificationSending': 'Odesílám kód...',
    'emailCheckingAccount': 'Ověřuji e-mail...',
    'emailVerificationOfflineTitle': 'Jsi offline',
    'emailVerificationOfflineMessage':
        'Pro ověření e-mailu je potřeba připojení k internetu. Můžeš pokračovat bez ověření a ověřit e-mail později.',
    'emailVerificationRetry': 'Zkusit znovu',
    'emailVerificationOfflineLabel': 'Bez připojení',
    'emailSendCodeError': 'Nepodařilo se odeslat kód',
    'emailMissingError': 'E-mail nebyl zadán',
    'emailLoadingProfile': 'Načítám profil...',
    'emailErrInvalidCode': 'Neplatný kód',
    'emailErrCodeExpired': 'Kód vypršel',
    'emailErrRateLimited': 'Počkejte před dalším odesláním',
    'emailErrNetwork': 'Chyba připojení',
    'emailErrUnknown': 'Nastala neočekávaná chyba',
    'bannerGuestMessage': 'Postup se uloží až po přihlášení.',
    'bannerVerifyMessage': 'Ověř svůj e-mail pro plný přístup',
    'bannerOfflineMessage': 'Připojte se k internetu pro registraci',
    'dialogRegistration': 'Registrace',
    'dialogEmailVerification': 'Ověření e-mailu',
    'dialogRegistrationSuccess': 'Registrace proběhla úspěšně!',
    'dialogEmailVerified': 'E-mail byl úspěšně ověřen!',
    'dialogEmailInputPrompt': 'Zadejte svůj e-mail pro registraci a plný přístup k aplikaci.',
    'dialogSendCodePrompt': 'Na tento e-mail vám pošleme ověřovací kód.',
    'dialogSendCode': 'Odeslat kód',
    'dialogEnterCode': 'Zadejte 6místný kód z e-mailu',
    'dialogSendNewCode': 'Odeslat nový kód',
    'syncSyncing': 'Synchronizace...',
    'syncDone': 'Synchronizace dokončena',
    'syncFailed': 'Synchronizace selhala',
    'actionContinue': 'Pokračovat',
    'actionCancel': 'Zrušit',
    'actionDelete': 'Vymazat',
    'actionBack': 'Zpět',
    'welcomeAccessPin': 'Access Free Courses with PIN',
    'loginTitle': 'Přihlášení',
    'loginEmailPlaceholder': 'student@example.com',
    'authLoginRequired': 'Přidělil ti tento kurz učitel? Nejdříve se přihlas',
    'authDefaultStudentName': 'Student',
    'profileLanguageDefault': 'Čeština',
    'subjectBiology': 'Biologie',
    'subjectGrammar': 'Gramatika',
    'subjectLiterature': 'Literatura',
    'subjectMath': 'Matematika',
    'subjectChemistry': 'Chemie',
    'subjectEnglish': 'Angličtina',
    'libraryLoginBadge': 'Login',
    'skillMolecular': 'Molekulární',
    'skillEcological': 'Ekologická',
    'skillEvolutionary': 'Evoluční',
    'skillCells': 'Buňky',
    'skillDna': 'DNA',
    'skillProtein': 'Protein',
    'skillEcosystems': 'Ekosystémy',
    'skillProteins': 'Proteiny',
    'chatyTitle': 'Chaty',
    'chatySubtitle': 'Vyber si mentora nebo kouče pro konzultaci',
    'chatyInfoBanner': 'Všichni AI mentoři a AI učitelé jsou dostupní 24/7 pro pomoc s učením.',
    'chatyEndedFilter': 'Ukončené',
    'chatyOfflineBanner': 'Nejsi online',
    'chatyNewChat': 'Nový chat',
    'chatyTimeNow': 'teď',
    'chatMockAiTeacher': 'AI Učitel',
    'chatMockAiTeacherMsg': 'Dobrá práce na posledním kvízu!',
    'chatMockMathMentor': 'Mentor Matematika',
    'chatMockMathMentorMsg': 'Zkus si procvičit derivace',
    'chatMockTeacherJana': 'Mgr. Jana Nováková',
    'chatMockTeacherJanaMsg': 'Skvělý rozbor básně!',
    'chatMockYesterday': 'včera',
    'chatMockStudyCoach': 'Kouč Pro Studium',
    'chatMockStartConversation': 'Zahájit konverzaci',
    'chatMockTeacherPetr': 'Ing. Petr Svoboda',
    'chatMockTeacherPetrMsg': 'Ty: Potřebuji pomoc s fotosyntézou',
    'chatMockThreeHoursAgo': 'před 3 hod',
    'chatMockLanguageMentor': 'Mentor Cizí jazyky',
    'chatDetailToday': 'Dnes',
    'chatDetailOnline': 'Online',
    'chatDetailOffline': 'Offline',
    'chatDetailInputHint': 'Napiš mi...',
    'chatDetailHelperText': 'Napiš zprávu nebo polož otázku',
    'chatDetailMockAiGreeting': 'Ahoj! Jsem tvůj EDU-AI asistent. Jak ti dnes mohu pomoci?',
    'chatDetailMockUserMsg': 'Můžeš mi vysvětlit buněčné struktury?',
    'chatDetailOfflineBanner': 'Nejsi online — historie je dostupná, ale nové zprávy nelze odeslat',
    'chatFeedbackTitle': 'Co se ti nelíbilo?',
    'chatFeedbackSubtitle': 'Tvoje zpětná vazba nám pomůže zlepšit odpovědi',
    'chatFeedbackSelectReason': 'Vyber důvod',
    'chatFeedbackDetails': 'Další podrobnosti (volitelné)',
    'chatFeedbackHint': 'Napiš více o problému...',
    'chatFeedbackCancel': 'Zrušit',
    'chatFeedbackSubmit': 'Odeslat',
    'chatFeedbackThanks': 'Děkujeme za zpětnou vazbu!',
    'chatFeedbackIncorrect': 'Nesprávné informace',
    'chatFeedbackIncomplete': 'Neúplná odpověď',
    'chatFeedbackUnclear': 'Nesrozumitelné vysvětlení',
    'chatFeedbackInappropriate': 'Nevhodná odpověď',
    'chatFeedbackOther': 'Jiný důvod',
    'chatNewConversation': 'Nová konverzace',
    'chatSelectPersona': 'Vyber si mentora',
    'courseMentor': 'Mentor kurzu',
    'chatyPickConversation': 'Vyber konverzaci vlevo, nebo založ novou.',
    'chatEmptyState': 'Zatím žádné konverzace.\nZačni chatovat!',
    'chatRequiresInternet': 'Chat vyžaduje připojení k internetu',
    'chatStreamError': 'Chyba při generování odpovědi',
    'chatSuggestionsTitle': 'Mohlo by tě zajímat:',
    'chatRetry': 'Zkusit znovu',
    'chatDeleteConfirm': 'Opravdu chceš smazat tuto konverzaci?',
    'chatDelete': 'Smazat',
    'drawerNavigation': 'NAVIGACE',
    'drawerProfile': 'Profil',
    'drawerMore': 'DALŠÍ',
    'drawerHelp': 'Nápověda',
    'dialogEmailHint': 'vas@email.cz',
    'stepWriteAnswer': 'Napiš odpověď...',
    'stepExplanation': 'Vysvětlení',
    'stepAiFeedback': 'Hodnoceno AI',
    'openFeedbackTitle': 'Zpětná vazba',
    'openFeedbackStrengths': 'Co se povedlo',
    'openFeedbackImprovements': 'Co zlepšit',
    'openFeedbackNextStep': 'Co dál',
    'openFeedbackSolution': 'Vzorová odpověď',
    'openFeedbackEvaluating': 'Promýšlím tvou odpověď...',
    'openFeedbackQuizPending': 'Odpověď je odeslaná. Zpětnou vazbu uvidíš na konci kvízu.',
    'openFeedbackFailed': 'Zpětnou vazbu se teď nepodařilo připravit. Tvoje odpověď je uložená — zkus to prosím znovu.',
    'openFeedbackNotEvaluable': 'K téhle otázce ti zpětnou vazbu připravit nedokážu. Tvoje odpověď je uložená a učitel ji uvidí — klidně pokračuj dál.',
    'openFeedbackOffline': 'Teď nejsi připojený, takže zpětná vazba musí počkat. Odpověď máš uloženou.',
    'openFeedbackRetry': 'Zkusit znovu',
    'openFeedbackRework': 'Upravit odpověď',
    'openAnswerEmpty': 'Napiš prosím aspoň krátkou odpověď vlastními slovy, nebo přilož fotku řešení.',
    'openPhotoAdd': 'Přiložit fotku',
    'openPhotoCamera': 'Vyfotit',
    'openPhotoGallery': 'Vybrat z galerie',
    'openPhotoRemove': 'Odebrat fotku',
    'openPhotoAttached': 'Fotka je přiložená',
    'openPhotoUploading': 'Nahrávám fotku...',
    'openPhotoUploadFailed': 'Fotku se nepodařilo nahrát. Zkus to prosím znovu.',
    'openPhotoUnreadable': 'Z fotky se mi řešení nepodařilo přečíst. Zkus ji vyfotit znovu, nebo odpověz textem.',
    'openPhotoTooLarge': 'Fotka je moc velká. Zkus ji vyfotit znovu.',
    'stepAudioError': 'Nepodařilo se načíst audio',
    'stepNumericHint': 'Zadej číslo...',
    'stepVideoError': 'Nepodařilo se načíst video',
    'engineCheck': 'Zkontrolovat',
    'engineNext': 'Další',
    'engineContinue': 'Pokračovat',
    'engineSelectAnswer': 'Nejprve vyber odpověď',
    'engineAnswerAllQuestions': 'Nejprve odpověz na všechny otázky',
    'engineTryAgain': 'Zkusit znovu',
    'statStreak': 'Streak',
    'statStreakSubtitle': 'Skvělá práce!\nPokračuj v učení.',
    'statTrophiesSubtitle': 'Sbírej trofeje a odemykej\nnové odměny.',
    'sectionMyCourses': 'Moje kurzy',
    'sectionShowAllCourses': 'Zobrazit všechny',
    'statDays': 'dní',
    'statTrophies': 'Trofeje',
    'courseCardCompleted': 'DOKONČENO',
    'promoDefaultBadge': 'NOVÉ',
    'aboutSendDebugReport': 'Odeslat diagnostický report',
    'aboutDebugReportTitle': 'Odeslat report?',
    'aboutDebugReportMessage':
        'Shromáždí diagnostické informace o aplikaci '
        '(verze, stav databáze, sync fronta, statistiky) '
        'a odešle je vývojářům. Neobsahuje osobní data ani obsah kurzů.',
    'aboutDebugReportSend': 'Odeslat',
    'aboutDebugReportSending': 'Odesílám report...',
    'aboutDebugReportSuccess': 'Diagnostický report byl odeslán',
    'aboutDebugReportOffline': 'Pro odeslání reportu je potřeba připojení k internetu',
    'blockDisplayTitleContent': 'Obsah',
    'blockDisplayTitleQuestion': 'Otázka',
    'blockDisplayTitleHint': 'Nápověda',
    'blockDisplayTitleSolution': 'Řešení',
    'blockDisplayTitleTask': 'Úkol',
    'blockDisplayTitleImage': 'Obrázek',
    'blockDisplayTitleVideo': 'Video',
    'blockDisplayTitleAudio': 'Audio',
    'blockDisplayTitleLearning': 'Učivo',
    'blockDisplayTitleExercise': 'Cvičení',
    'personaAiTeacherName': 'Asistent učitele',
    'personaAiTeacherSubtitle': 'Obecný vzdělávací asistent',
    'personaAiTeacherDesc': 'AI asistent ti zodpoví otázky ke tvým kurzům a může předat dotaz učiteli.',
    'personaMathMentorName': 'Mentor kurzu',
    'personaMathMentorSubtitle': 'Specialista na matematiku',
    'personaMathMentorDesc': 'AI asistent ti vysvětlí pojmy a postupy řešení konkrétních úloh v kurzu.',
    'personaStudyCoachName': 'Studijní kouč',
    'personaStudyCoachSubtitle': 'Pomáhá s technikami učení',
    'personaStudyCoachDesc': 'AI asistent specializovaný na organizaci přípravy a well-being.',
    'personaLanguageMentorName': 'Poradce k přijímačkám',
    'personaLanguageMentorSubtitle': 'Zodpovídá dotazy k JPZ',
    'personaLanguageMentorDesc': 'Odpovědi z FAQ',
    'personaSkolnikName': 'Školník',
    'personaSkolnikSubtitle': 'Ví všechno o vaší škole',
    'personaSkolnikDesc': 'Digitální knihovník ti odpoví na otázky ze školního řádu a webu.',
    'personaCermatikName': 'Cermatík',
    'personaCermatikSubtitle': 'Průvodce přijímačkami',
    'personaCermatikDesc': 'Digitální knihovník ti najde informace o přijímacích zkouškách na střední.',
    'newChatSubtitle': 'Vyber si asistenta, mentora nebo knihovníka',
    'newChatNoMentors': 'Momentálně není dostupný žádný mentor.',
    'mentorAvailabilityOnline': 'online',
    'mentorAvailabilityCourseOnly': 'jen v kurzu',
    'mentorKindAi': 'AI',
    'mentorKindLibrary': 'knihovna',
    'levelTitle1': 'Začátečník',
    'levelTitle2': 'Učeň',
    'levelTitle3': 'Student',
    'levelTitle4': 'Pokročilý',
    'levelTitle5': 'Expert',
    'levelTitle6': 'Mistr',
    'levelTitle7': 'Guru',
    'levelTitle8': 'Legenda',
    'levelTitle9': 'Génius',
    'levelTitle10': 'Nedostižný',
    'trophyFirstLessonTitle': 'První lekce',
    'trophyFirstLessonDesc': 'Dokonči svou první lekci',
    'trophyDiligentStudentTitle': 'Pilný student',
    'trophyDiligentStudentDesc': 'Dokonči 5 lekcí',
    'trophyQuizNoviceTitle': 'Kvízový nováček',
    'trophyQuizNoviceDesc': 'Dokonči svůj první kvíz',
    'trophyMasterpieceTitle': 'Mistrovský kousek',
    'trophyMasterpieceDesc': 'Dokonči celý kurz',
    'trophyMonthStreakTitle': 'Měsíční série',
    'trophyMonthStreakDesc': 'Uč se 30 dní v řadě',
    'goal100XpTitle': 'Získat 100 XP',
    'goal500XpTitle': 'Získat 500 XP',
    'goal1000XpTitle': 'Získat 1000 XP',
    'goalXpDesc': 'Sbírej body za dokončené lekce a cvičení',
    'goal3DayStreakTitle': 'Série 3 dní',
    'goal14DayStreakTitle': 'Série 14 dní',
    'goalDailyStreakDesc': 'Uč se každý den po sobě',
    'goalLevel3Title': 'Dosáhnout úrovně 3',
    'goalLevelDesc': 'Každá úroveň = 500 XP',
    'goalComplete10LessonsTitle': 'Dokonči 10 lekcí',
    'goalPracticeDesc': 'Učení dělá mistra',
    'challenge5000XpTitle': 'Získat 5000 XP',
    'challenge5000XpDesc': 'Dokaž svou vytrvalost',
    'challenge3CoursesTitle': 'Dokonči 3 kurzy',
    'challenge3CoursesDesc': 'Prozkoumej různá témata',
    'challenge60DayStreakTitle': 'Série 60 dní',
    'challenge60DayStreakDesc': 'Opravdová disciplína',
    'sharedDeviceBannerLabel': 'Sdílené zařízení — odhlášení po 15 min nečinnosti',
    'sharedDeviceDialogTitle': 'Sdílené zařízení',
    'sharedDeviceDialogMessage': 'Toto zařízení je označené jako sdílené — po 15 minutách nečinnosti budete automaticky odhlášeni. Chcete se odhlásit nyní, nebo označit zařízení jako vlastní a zůstat přihlášeni?',
    'sharedDeviceDialogKeepLoggedIn': 'Toto je moje zařízení',
    'sharedDeviceConvertError': 'Zařízení se nepodařilo označit jako vlastní. Zkuste to prosím znovu.',
    'shopTitle': 'Obchod',
    'shopPermanentItems': 'Trvalé předměty',
    'shopSlotHead': 'Hlava',
    'shopSlotEyes': 'Oči',
    'shopSlotMouth': 'Pusa',
    'shopSlotArms': 'Ruce',
    'shopSlotLegs': 'Nohy',
    'shopSlotTorso': 'Trup',
    'shopSlotFace': 'Obličej',
    'shopSlotNeck': 'Krk',
    'shopSlotHeld': 'V ruce',
    'shopEquipped': 'Nasazeno',
    'shopEquip': 'Nasadit',
    'shopUnequip': 'Sundat',
    'shopGetFree': 'Získat zdarma',
    'shopPurchaseFailed': 'Předmět se nepodařilo získat. Zkontroluj připojení.',
    'shopOfflineNotice': 'Bez připojení — ukazujeme uloženou nabídku.',
    'shopLoadFailed': 'Obchod se nepodařilo načíst.',
    'shopEmptySlot': 'Zatím tu nic není.',
    'shopRetry': 'Zkusit znovu',
    'eloInsufficientData': 'Na odhad v této oblasti zatím nemáme dost údajů.',
    'confidenceHigher': 'vyšší',
    'confidenceMedium': 'střední',
    'confidenceLower': 'nižší',
    'confidenceVeryLow': 'velmi nízká',
  };

  // ═════════════════════════════════════════════════════════════════════
  // English strings
  // ═════════════════════════════════════════════════════════════════════
  static const Map<String, String> _en = {
    'navPrehled': 'Overview',
    'navChat': 'Chat',
    'navKurzy': 'Courses',
    'navNovinky': 'News',
    'shellDashboardSubtitle': 'Keep learning and get better every day.',
    'shellKurzySubtitle': 'Pick a course and learn at your own pace.',
    'shellGuestCtaTitle': 'Your progress is saved\nonce you sign in.',
    'shellGuestCtaButton': 'Sign up',
    'shellGames': 'Games',
    'shellShop': 'Shop',
    'progressCardTitle': 'Your progress',
    'progressCardCompleted': 'Done',
    'progressCardDetail': 'View details',
    'progressCardHintStart': 'Great start!',
    'progressCardHintGoing': "You're doing great!",
    'progressCardHintDone': 'All done. Nice!',
    'progressCardLessons': '{done} of {total} lessons',
    'continueLessonTitle': 'Continue lesson',
    'continueLessonBadge': 'CURRENT',
    'continueLessonButton': 'Continue lesson',
    'continueLessonEmpty': "You haven't started a lesson yet.",
    'continueLessonAllDone': 'You have finished every lesson.',
    'continueLessonQuizOnly': 'Open the course and take the quiz.',
    'continueLessonOpenCourse': 'Open course',
    'continueLessonSteps': '{done} of {total} steps',
    'recentActivityTitle': 'Recent activity',
    'recentActivityShowAll': 'Show all',
    'recentActivityEmpty': "We're still collecting your activity.",
    'kurzySearchHint': 'Search a course…',
    'kurzyFilterButton': 'Filter',
    'kurzySearchEmpty': 'No course matches your search.',
    'courseCardStart': 'Start course',
    'courseCardContinue': 'Continue',
    'courseCardReview': 'Review again',
    'courseBackToAll': 'Back to all courses',
    'courseTabLessons': 'Lessons',
    'courseTabAbout': 'About',
    'courseTabSkills': 'Skills',
    'courseTabStats': 'Stats',
    'courseSaveButton': 'Save course',
    'courseShowAllLessons': 'Show all lessons ({count})',
    'courseShowFewerLessons': 'Show fewer',
    'courseOpenLesson': 'Open',
    'courseSkillsInCourse': 'Skills in this course',
    'courseSkillsEmpty': 'Skills appear once you have solved a few tasks.',
    'courseStatsPlaceholder': 'Course stats are still in the works.',
    'courseDetailedStats': 'View detailed stats',
    'courseTrophyHint': 'Finish it and earn a trophy!',
    'lessonAiHelpTitle': 'AI help',
    'lessonAiHelpQuestion': 'Need a hand?',
    'lessonAiHelpBody': 'Ask the AI assistant anything about this lesson.',
    'lessonAiHelpButton': 'Open AI chat',
    'courseLevelLabel': 'Level: {level}',
    'skillLevelLabel': 'Level {level}',
    'appTitle': 'Edu',
    'appName': 'EduAI',
    'welcomeGreeting': 'Hi',
    'welcomeDescription': 'Welcome to your\nnew app!',
    'guideHeading': 'Start with the guide',
    'guideTitle': 'How to use EDU AI',
    'guideSubtitle':
        'A quick intro to the EDU AI app. '
        'Where to find AI help, how lessons work '
        'and how to save things to review.',
    'guideButton': 'Start exercise',
    'onboardingLoadError':
        'Could not prepare the intro course. Check your connection and try again.',
    'practiceTitle': 'Practice',
    'practiceStart': 'Start practice',
    'practiceEmpty': "Nothing to review right now. Check back later!",
    'practiceDashSubtitle': "Review what's due today",
    'practiceBonusHint':
        "You're done for today. Want to keep going? Here's a bonus set.",
    'practiceBonusStart': 'Practise a bonus set',
    'practiceScopeTitle': 'What to practise',
    'practiceScopeAllHint': 'With nothing selected, everything is practised.',
    'practiceScopeSelectAll': 'Select all',
    'practiceScopeOther': 'Other',
    'practiceScopeEmpty':
        'Nothing to review in the selected areas right now. Try selecting more.',
    'promoBadge': 'LIBRARY',
    'promoTitle': 'Explore courses!',
    'promoDescription': 'Find courses in the library\nthat are available to you now',
    'promoDescriptionReward': 'Keep studying — a reward awaits:\nthe Clouds game 🤸',
    'dashGreetingWelcome': 'Welcome to your new app!',
    'dashGreetingKeepGoing': 'Keep learning and you will improve every day.',
    'dashGreetingProud': 'I am glad about what we have achieved together.',
    'dashGreetingCheering': 'You are on fire, I am cheering for you 👏',
    'practiceNothingDue':
        'Nothing to review right now. Finish a lesson and cards will show up.',
    'globalQuizHeading': 'Take a quiz',
    'globalQuizTitle': 'Test yourself across courses',
    'globalQuizSubtitle': 'Random questions from all your courses',
    'globalQuizStart': 'Start the quiz',
    'jpzBadge': 'ENTRANCE EXAMS',
    'jpzTitle': 'Thinking about entrance exams?',
    'jpzDescription': 'Take the intro to the unified\nentrance exam',
    'jpzCermatikDescription': 'Ask Cermatík anything\nabout entrance exams',
    'statShopSubtitle': 'Pick a new look\nfor your character.',
    'statShopAction': 'Open',
    'sectionQuickQuizzes': 'Quick quizzes',
    'sectionContinue': 'Continue',
    'defaultUserName': 'User',
    'ageGateTitle': 'Before we start',
    'ageGateQuestion': 'Are you older than {age}?',
    'ageGateYes': 'Yes',
    'ageGateNo': 'No',
    'ageGateCountryLabel': 'Country',
    'ageGateCountryQuestion': 'Which country do you live in?',
    'consentIntroTitle': 'You need a parent\'s consent',
    'consentIntroBody':
        'Enter your parent\'s email. We will send them a message and they '
        'will give you the code you use to sign in.',
    'consentEmailLabel': 'Parent\'s email',
    'consentEmailInvalid': 'Check the email — something is missing.',
    'consentSend': 'Send to parent',
    'consentWaitingTitle': 'We emailed your parent',
    'consentWaitingBody':
        'Ask them to open it. They will tell you the code to get in.',
    'consentEnterCode': 'Enter code',
    'consentGenericError': 'Something went wrong. Please try again.',
    'consentNetworkError':
        'We could not send this — check your internet connection and try again.',
    'consentConfirmTitle': 'Confirm consent',
    'consentConfirmBody':
        'Enter the six-character code from the email. This confirms your '
        'consent to your child using EDU-AI.',
    'consentConfirmCta': 'Confirm consent',
    'consentConfirmSuccess':
        'Consent confirmed. We have emailed you the login codes.',
    'consentConfirmFailure': 'That code is invalid or expired. Request a new one.',
    'consentConfirmInvalidLink':
        'This link is not valid. Make sure you copied it in full, or have the '
        'email sent again.',
    'consentConfirmSuccessNoMail':
        'Consent confirmed. However, the login codes could not be emailed '
        '(child accounts created: {count}). Request the consent management '
        'link below to generate the codes there.',
    'consentManageTitle': 'Consent management',
    'consentManageChildren': 'Child accounts',
    'consentManageNewCode': 'New code',
    'consentManageNewCodeHint':
        'Write it down — we will not show it again. The old code no longer works.',
    'consentManageRevoke': 'Revoke consent',
    'consentManageRevokeConfirm':
        'Revoke? The accounts lock immediately and the data is erased within 30 days.',
    'consentManageRevoked': 'Consent revoked.',
    'consentManageRevokedDetail':
        'The accounts are blocked. The data will be erased within 30 days.',
    'consentManageExpired': 'This link expired. Request a new one.',
    'consentManageResend': 'Send the link again',
    'consentManageResendSent': 'If we know the email, the link is on its way.',
    'consentManageLoadError':
        'Could not load — check your internet connection and try again.',
    'consentManageRetry': 'Try again',
    'minorNameLocked': 'A child account\'s nickname cannot be changed.',
    'chatTitle': 'Chat',
    'chatLockedMessage': 'Chat will open after you reach a higher level',
    'addTitle': 'Connect / Add',
    'contentComingSoon': 'This content is still in preparation',
    'novinkyTitle': 'News',
    'novinkyEmpty': 'No news yet',
    'novinkyError': 'Could not load news',
    'novinkyLoading': 'Loading news…',
    'novinkyRetry': 'Try again',
    'novinkyPickArticle': 'Pick a story on the left to read it here.',
    'doplnkyTitle': 'Extras',
    'doplnkySubtitle': 'Mini games, avatar dress-up and app themes in one place.',
    'doplnkyAvatarTitle': 'Avatar editor',
    'doplnkyAvatarPerex': 'Dress up your mascot — pick a hat, glasses and more.',
    'doplnkyThemeTitle': 'Theme editor',
    'doplnkyThemePerex': 'Change the app colours — pick a ready-made theme or create your own.',
    'doplnkyOpen': 'Open',
    'miniGamesTitle': 'Mini games',
    'miniGamesSubtitle': 'Play games and earn rewards!',
    'miniGamesEmpty': 'No mini games yet',
    'miniGamesError': 'Could not load mini games',
    'miniGamesRetry': 'Try again',
    'miniGamesPlay': 'Play',
    'miniGamesComingSoon': 'Game coming soon',
    'miniGamesOffline': 'You need a connection',
    'miniGamesSensorGyroscope': 'Gyroscope',
    'miniGamesLocked': 'This game is not available right now',
    'miniGamesStartFailed': 'Could not start the game',
    'gameTapToStart': 'Start game',
    'gameReadyHeadline': 'Climb as high as you can!',
    'gameRuleClimb': 'You jump on your own — you just steer where you land',
    'gameRuleCoin': 'Collect Edux coins for points',
    'gameRuleBoost': 'A star rockets you upwards',
    'gameRuleFall': 'Fall off the bottom and the run ends',
    'gameHintTilt': 'Tilt your device sideways',
    'gameHintKeys': 'Steer with ← → keys',
    'gameHintButtons': 'Steer with the ← → buttons at the bottom',
    'gameSteerLeft': 'Left',
    'gameSteerRight': 'Right',
    'gameScore': 'Score',
    'gameOver': 'Game over',
    'gameCoinsCollected': 'Coins',
    'gameBack': 'Back to games',
    'gamePaused': 'Paused',
    'gameResume': 'Resume',
    'gameQuit': 'Quit game',
    'gameQuitConfirm': 'Quit the game? Your attempt will not be refunded.',
    'gameExit': 'Close game',
    'kurzyTitle': 'Courses',
    'filterAll': 'All',
    'filterInProgress': 'In progress',
    'filterNotStarted': 'Not started',
    'filterCompleted': 'Completed',
    'kurzyEmptyTitle': "You don't have any courses yet",
    'kurzyEmptySubtitle': "Browse the library and pick courses you're interested in",
    'kurzyExploreLibrary': 'Browse library',
    'defaultCourseName': 'Course',
    'authHeadline': 'Learn Smarter\nAnywhere',
    'authFormHeadline': 'Sign in',
    'authHeroTaglineExpanded': 'School in your pocket!',
    'authCodeLabel': 'Course code or login code',
    'authVerifyingCode': 'Verifying code...',
    'authContinue': 'Continue',
    'authOr': 'or',
    'authLoginSignUp': 'Log In / Sign Up',
    'authTerms': 'Terms',
    'authPrivacy': 'Privacy',
    'authEmailHint': 'Your email',
    'authLogin': 'Log in',
    'authOrCzech': 'Or',
    'authGoogleLogin': 'Sign in with Google',
    'authMicrosoftLogin': 'Sign in with Microsoft',
    'authAppleLogin': 'Sign in with Apple',
    'authTermsNotice': 'By signing up, you agree to our\n',
    'authTermsAndPrivacy': 'Terms and Privacy Policy',
    'authTermsLink': 'Terms',
    'authTermsPrivacyJoiner': ' and ',
    'authPrivacyLink': 'Privacy Policy',
    'authEmptyEmailError': 'Please enter an email address',
    'authInvalidEmailError': 'Please enter a valid email address',
    'authUserCreateError': 'Failed to create user',
    'authCourseLoadError': 'Failed to load course',
    'authCourseDownloadError': 'Failed to download the course. Check your connection and try again.',
    'authKeepLoggedInLabel': 'Stay logged in permanently — this is not a shared device',
    'profileTitle': 'My account',
    'profileSectionAccount': 'Account',
    'profileEditProfile': 'Edit profile',
    'profileEditAvatar': 'Edit avatar',
    'profilePrivacy': 'Privacy & security',
    'profileSectionSettings': 'Settings',
    'profileTheme': 'Theme',
    'profileNotifications': 'Notifications',
    'profileLanguage': 'Language',
    'profileComingSoon': 'Coming soon',
    'profileSectionMore': 'More',
    'profileAbout': 'About',
    'profileTerms': 'Terms of use',
    'profileLogout': 'Log out',
    'profileLogin': 'Log in',
    'profileStatCourses': 'Courses',
    'profileStatStreak': 'Streak',
    'profileStatAchievements': 'Achievements',
    'profileQuickAchievements': 'Achievements',
    'profileQuickLibrary': 'Library',
    'profileSetupTitle': 'Customize your profile',
    'profileSetupSubtitle': 'You can change everything later in your profile settings',
    'profileSetupNameLabel': 'Nickname',
    'profileSetupNameHint': 'How others see you',
    'profileSetupColorLabel': 'Color profile',
    'profileSetupVibeTitle': 'Pick your vibe!',
    'profileSetupVibeSubtitle':
        "Choose your avatar's look. You'll earn more accessories through your activity.",
    'profileSetupVibeNone': 'No accessory',
    'profileSetupAvatarLabel': 'Pick an avatar',
    'profileSetupSubjectsLabel': 'Pick a focus area',
    'profileSetupNameError': 'Please enter your nickname',
    'profileSetupSyncWarning': 'Profile saved locally. Sync will run later.',
    'editProfileTitle': 'Edit profile',
    'editProfileNameLabel': 'Nickname',
    'editProfileEmailLabel': 'Email',
    'editProfileNameHint': 'Enter a nickname',
    'editProfileEmailReadonly': 'Email cannot be changed',
    'editProfileEmptyNameError': 'Nickname cannot be empty',
    'editProfileSaveError': 'Failed to save changes',
    'editProfileSaveButton': 'Save changes',
    'libraryTitle': 'Library',
    'librarySubtitle': 'Pick courses and download them',
    'libraryCodeTitle': 'Have a course code?',
    'libraryCodeButton': 'Enter course code',
    'libraryCodeShort': 'Enter 6-digit code',
    'classroomJoinTitle': 'Join a class',
    'classroomJoinButton': 'Enter student code',
    'classroomJoinCodeHint': 'Enter the 6-character student code your teacher gave you',
    'classroomJoinSearching': 'Looking up the class…',
    'classroomJoinOffline': 'You need to be online to join a class',
    'classroomJoinYes': 'Yes',
    'classroomJoinNo': 'No',
    'classroomJoinSubmit': 'Join',
    'classroomJoinClassCodeHint': 'Enter the 4-character class code your teacher gave you',
    'classroomJoinUseStudentCode': 'I have a 6-character student code',
    'classroomJoinUseClassCode': 'I have a 4-character class code',
    'classroomJoinClassCodeShort': 'Enter 4-character code',
    'classroomJoinCodeNotFound': 'Class code not found',
    'classroomJoinLoginRequired':
        'You need to log in to join a class. We will add you to it once you are logged in.',
    'classroomJoinNotAllowed': 'This account cannot join a class',
    'editProfileClassroomsLabel': 'Classes',
    'editProfileNoClassrooms': 'You are not in any class yet',
    'libraryLoginRequired': 'You need to log in to download a course',
    'libraryLoggedOnlyTitle': 'Course for logged-in users',
    'libraryLoggedOnlyBody':
        'This course is only available to logged-in users. Log in and it will '
            'open right away — you will keep the progress you have made so far.',
    'libraryLoggedOnlyAction': 'Log in',
    'libraryLinkOpenFailed': 'Could not open the link',
    'libraryLoadError': 'Failed to load course',
    'librarySearchingCourse': 'Looking up course...',
    'libraryEmptyTitle': 'The library is empty',
    'libraryEmptySubtitle': 'No courses are available yet',
    'libraryCoursesLoadError': 'Failed to load courses',
    'libraryCourseAlreadyCompleted': 'This course has already been completed.',
    'libraryUpdating': 'Updating...',
    'libraryDownloading': 'Downloading...',
    'libraryUpdate': 'Update',
    'libraryLaunch': 'Launch',
    'libraryDownload': 'Download',
    'courseProgress': 'Progress',
    'courseDescription': 'Course description',
    'courseLessons': 'Lessons',
    'courseShowMore': 'Show more',
    'courseShowLess': 'Hide',
    'courseQuizzes': 'Quizzes',
    'courseShowAll': 'Show all',
    'courseContinueLesson': 'Continue lesson',
    'courseExercise': 'Exercise',
    'courseQuiz': 'Quiz',
    'courseCompleted': 'COMPLETED',
    'courseCurrent': 'CURRENT',
    'courseCorruptedTitle': 'Failed to load course',
    'courseCorruptedMessage': 'Course data is incomplete or corrupted. Try downloading the course again in the library.',
    'courseBack': 'Back',
    'courseStartQuiz': 'Start quiz',
    'courseContinueQuiz': 'Continue quiz',
    'courseQuizUnlockHint': 'Answer the questions to unlock lessons',
    'courseNoBookmarks': "You don't have any saved blocks to practice.\nAdd them using the bookmark in lessons.",
    'courseNoQuestions': 'This course has no questions.',
    'courseUpdateAvailable': 'A new version of the course is available',
    'courseUpdateRequired': 'Update the course to continue',
    'courseCardUpdate': 'Update',
    'courseActionLessons': 'Lessons',
    'lessonEmptyTitle': 'Lesson content is being prepared',
    'lessonEmptyMessage': "This lesson doesn't have any content yet.",
    'lessonFinishCourse': 'Finish course',
    'lessonNextLesson': 'Next lesson',
    'lessonBackToDetail': 'Back to course detail',
    'lessonCourseCompleted': 'Congratulations! You finished the whole course.',
    'lessonSelectAnswerFirst': 'Pick an answer first',
    'lessonExplanation': 'Explanation',
    'lessonFeedbackClear': "Now it's clear",
    'lessonFeedbackPractice': 'Add to practice',
    'lessonFeedbackPracticeAdded': 'Added to practice',
    'mentorSheetInputHint': 'Ask the AI mentor',
    'mentorSheetNoHelp': 'Tell me in your own words what is unclear — I will explain it differently.',
    'lessonFeedbackConfused': "I don't understand",
    'lessonFeedbackClarify': 'Refine your question',
    'lessonFeedbackHint': 'Write more about the problem...',
    'lessonFeedbackThanks': 'Thanks for your feedback!',
    'lessonFeedbackSend': 'Send',
    'lessonVideoError': 'Failed to load video',
    'lessonWriteAnswer': 'Write an answer...',
    'lessonCheckAnswer': 'Check',
    'lessonCorrect': 'Correct!',
    'lessonIncorrect': 'Not quite',
    'lessonQuestionLabel': 'Question',
    'quizTitle': 'Quiz',
    'quizExerciseTitle': 'Exercise',
    'quizCompleted': 'Quiz completed!',
    'quizReviewCompleted': 'Review completed!',
    'quizAllCorrect': 'Excellent! Everything correct!',
    'quizGreatJob': 'Great job!',
    'quizTryAgain': 'Try again!',
    'quizGreatReview': 'Great review!',
    'quizDone': 'Done',
    'quizConfirmSubmit': "Are you sure you want to submit the quiz? You won't be able to come back to it.",
    'quizConfirmBack': 'Back',
    'quizConfirmSend': 'Submit',
    'quizConfirmExitMessage': "Are you sure you want to leave the quiz? You can't return to it or start it again.",
    'quizConfirmExitLeave': 'Leave',
    'quizConfirmExitStay': 'Continue',
    'quizThankYou': 'Great, thanks. Now I know what tasks to offer you next time.',
    'quizRetry': 'Retry',
    'quizReview': 'Review',
    'quizFinish': 'Finish',
    'quizNext': 'Next',
    'quizCheck': 'Check',
    'quizAnswerHint': 'Type your answer...',
    'quizCorrectLabel': 'Correct!',
    'quizIncorrectLabel': 'Incorrect',
    'quizAskAi': 'Ask the AI',
    'quizAnswersSaved': 'Your answers were saved, thank you',
    'chatContextFallbackPrompt': 'Could you please explain it differently?',
    'exerciseSelectCorrect': 'Pick the correct answer',
    'exerciseSelectAll': 'Pick all correct answers',
    'exerciseWriteAnswer': 'Write your answer',
    'exerciseAnswerHint': 'Your answer...',
    'exerciseCorrect': 'Correct',
    'exerciseIncorrect': 'Incorrect',
    'trueFalseTrue': 'True',
    'trueFalseFalse': 'False',
    'exerciseExplanationLabel': 'Explanation:',
    'achievementsTitle': 'Achievements',
    'achievementsTrophies': 'Trophies',
    'achievementsCoins': 'EDUX coins',
    'achievementsEarnedTrophies': 'Earned trophies',
    'achievementsChallenges': 'Challenges',
    'achievementsSkills': 'Skills',
    'achievementsSkillsPlaceholder': "Looking forward to what we'll achieve together.",
    'skillTabAll': 'All',
    'skillTabBeginner': 'Beginner',
    'skillTabIntermediate': 'Intermediate',
    'skillTabExpert': 'Expert',
    'achievementsGoals': 'Goals',
    'challengeMasterpiece': 'Masterpiece',
    'trophyBiologist': 'Master biologist',
    'trophyBiologistDesc': 'Score 90% or more on a quiz',
    'trophyWeekStreak': 'Weekly streak',
    'trophyWeekStreakDesc': 'Study 7 days in a row',
    'goalCompleteLessons': 'Complete 10 lessons',
    'goalCompleteLessonsDesc': '+100 XP on completion',
    'goalPerfectScores': 'Get 5 perfect scores',
    'goalPerfectScoresDesc': '+150 XP on completion',
    'timeYesterday': 'Yesterday',
    'timeJustNow': 'Just now',
    'termsTitle': 'Terms of use',
    'termsLastUpdated': 'Last updated: January 19, 2026',
    'termsSection1Title': '1. Introductory provisions',
    'termsSection1Body':
        'These terms of use govern the rights and obligations of users '
        'of the EDU-AI application. By using the application you agree '
        'to these terms. The application is intended for educational '
        'purposes and is operated by EduAI s.r.o.',
    'termsSection2Title': '2. User account',
    'termsSection2Body':
        'A user account is required to access the full features of the '
        'application. Users must provide truthful information and protect '
        'their login credentials. You are responsible for all activity '
        'performed under your account.',
    'termsSection3Title': '3. Copyright',
    'termsSection3Body':
        'All content in the application — including courses, texts, '
        'graphics and software code — is protected by copyright. Users '
        'receive only a license for personal non-commercial use. Copying, '
        'distribution or commercial use without written consent is '
        'prohibited.',
    'termsSection4Title': '4. Usage rules',
    'termsSection4Body':
        'Users agree to use the application in accordance with applicable '
        'law and good morals. It is forbidden to spread inappropriate '
        'content, attempt unauthorised access to systems, or disrupt the '
        'operation of the application in any way.',
    'termsSection5Title': '5. Personal data protection',
    'termsSection5Body':
        'Processing of personal data is governed by the Privacy Policy '
        'and the GDPR regulation. We only collect data necessary to '
        'provide the service. We never sell your data to third parties.',
    'termsSection6Title': '6. Limitation of liability',
    'termsSection6Body':
        'The application is provided "as is". The operator is not liable '
        'for any damages caused by use of the application, data loss or '
        'service interruption. Maximum liability is limited to the amount '
        'of fees paid.',
    'termsSection7Title': '7. Changes to the terms',
    'termsSection7Body':
        'We reserve the right to change these terms at any time. You will '
        'be notified of changes through the application or by email. '
        'Continued use of the application after the change indicates your '
        'agreement with the new wording.',
    'termsSection8Title': '8. Contact',
    'termsSection8Body':
        'For questions or comments you can contact us at '
        'support@eduai.cz or via the contact form in the application.',
    'privacyTitle': 'Privacy & security',
    'privacyComingSoon': 'Coming soon',
    'privacyComingSoonMessage':
        "We're working on privacy and security settings. Options for managing your data and security settings will be here soon.",
    'aboutSavedBookmarks': 'Saved bookmarks',
    'bookmarksListTitle': 'Saved bookmarks',
    'bookmarksListEmpty': "You don't have any saved bookmarks yet.\nAdd them using the bookmark in lessons.",
    'bookmarksListCourseNotDownloaded': 'Course not downloaded',
    'aboutTitle': 'About',
    'aboutSectionAppInfo': 'App info',
    'aboutAppName': 'EduAI',
    'aboutLabelName': 'Name',
    'aboutLabelVersion': 'Version',
    'aboutLabelBuild': 'Build',
    'aboutBuildValue': 'Release',
    'aboutLabelFlutter': 'Flutter',
    'aboutFlutterValue': 'SDK 3.10+',
    'aboutVersionUnavailable': 'Unavailable',
    'aboutSectionStatus': 'System status',
    'aboutDatabase': 'Database',
    'aboutDatabaseReady': 'Ready',
    'aboutDatabaseNotInit': 'Not initialised',
    'aboutUserLoggedIn': 'User logged in',
    'aboutGuestPin': 'Guest (PIN)',
    'aboutYes': 'Yes',
    'aboutNo': 'No',
    'aboutApiAuth': 'API auth',
    'aboutConnection': 'Connection',
    'aboutConnectionChecking': 'Checking...',
    'aboutConnectionError': 'Error',
    'aboutSyncState': 'Sync state',
    'aboutSyncReady': 'Ready',
    'aboutSyncSyncing': 'Syncing...',
    'aboutSyncError': 'Error',
    'aboutLastSync': 'Last sync',
    'aboutNextSync': 'Next sync',
    'aboutSyncNever': 'Never',
    'aboutSectionDbStats': 'Database stats',
    'aboutCoursesCount': 'Course count',
    'aboutPendingSync': 'Pending sync',
    'aboutSectionActions': 'Actions',
    'aboutForceSync': 'Force sync',
    'aboutClearSyncQueue': 'Clear sync queue',
    'aboutRefreshStatus': 'Refresh status',
    'aboutClearAuthToken': 'Clear auth token',
    'aboutClearCourses': 'Clear courses from library',
    'aboutFactoryReset': 'Factory reset (delete everything)',
    'aboutSectionApiConfig': 'API configuration',
    'aboutBaseUrl': 'Base URL',
    'aboutAuth': 'Auth',
    'aboutAuthValue': 'Laravel Sanctum',
    'aboutConnWifi': 'WiFi',
    'aboutConnMobile': 'Mobile data',
    'aboutConnEthernet': 'Ethernet',
    'aboutConnOffline': 'Offline',
    'aboutSyncCompleted': 'Sync completed',
    'aboutClearTokenTitle': 'Clear token?',
    'aboutClearTokenMessage': 'This will log you out of the app. Continue?',
    'aboutTokenCleared': 'Token cleared',
    'aboutClearCoursesTitle': 'Clear courses?',
    'aboutClearCoursesMessage':
        'This will delete all downloaded courses from your local library. '
        'Course progress will be lost. Continue?',
    'aboutNoUser': 'No user logged in',
    'aboutFactoryResetTitle': 'Factory reset?',
    'aboutFactoryResetMessage':
        'This will delete ALL local data: user, courses, progress, '
        'bookmarks, auth token and sync queue. The app will return to '
        'default state as after a clean install.\n\n'
        'Really continue?',
    'aboutDeleteAll': 'Delete all',
    'aboutTimeJustNow': 'just now',
    'aboutTimeSoon': 'soon',
    'themeTitle': 'Theme',
    'themeDefault': 'Classic purple theme',
    'themeOcean': 'Blue theme inspired by the ocean',
    'themeSunset': 'Warm theme in orange tones',
    'themeFire': 'Cozy theme in fiery colors',
    'themeLight': 'Airy light theme',
    'themeNeutral': 'Calm theme in gray tones',
    'themeCustom': 'Custom theme',
    'themeCreateNew': 'Create new theme',
    'themeImportJson': 'Import JSON',
    'themeImportTitle': 'Import theme',
    'themeImportHint': 'Paste theme JSON…',
    'themeImportButton': 'Import',
    'themeImportError': 'Invalid theme JSON',
    'themeImportSuccess': 'Theme imported successfully',
    'themeEditorTitle': 'Theme editor',
    'themeEditorName': 'Theme name',
    'themeEditorNameHint': 'My theme',
    'themeEditorSave': 'Save theme',
    'themeEditorExport': 'Export JSON',
    'themeEditorExportCopied': 'JSON copied to clipboard',
    'themeEditorDelete': 'Delete theme',
    'themeEditorDeleteConfirm': 'Are you sure you want to delete this theme?',
    'themeEditorDeleteYes': 'Delete',
    'themeEditorCancel': 'Cancel',
    'themeEditorConfirm': 'Confirm',
    'themeEditorNameEmpty': 'Enter a theme name',
    'themeEditorGroupCoreBrand': 'Core brand colors',
    'themeEditorGroupStatus': 'Status colors',
    'themeEditorGroupUi': 'UI elements',
    'themeEditorGroupCards': 'Cards & backgrounds',
    'themeEditorGroupAvatars': 'Avatars',
    'themeEditorGroupSubjects': 'Subjects',
    'themeEditorGroupOther': 'Other',
    'themeEditorPickColor': 'Pick a color',
    'colorPickerHexLabel': 'Hex:',
    'emailVerificationTitle': 'Email verification',
    'emailVerificationCodePrompt': 'Enter the 6-digit code from your email',
    'emailVerificationVerify': 'Verify',
    'emailVerificationResend': "Didn't get the code? Send again",
    'emailVerificationSending': 'Sending code...',
    'emailCheckingAccount': 'Checking e-mail...',
    'emailVerificationOfflineTitle': "You're offline",
    'emailVerificationOfflineMessage':
        'An internet connection is required to verify your email. You can continue without verifying and verify your email later.',
    'emailVerificationRetry': 'Try again',
    'emailVerificationOfflineLabel': 'No connection',
    'emailSendCodeError': 'Failed to send code',
    'emailMissingError': 'Email was not provided',
    'emailLoadingProfile': 'Loading profile...',
    'emailErrInvalidCode': 'Invalid code',
    'emailErrCodeExpired': 'Code has expired',
    'emailErrRateLimited': 'Please wait before sending again',
    'emailErrNetwork': 'Connection error',
    'emailErrUnknown': 'An unexpected error occurred',
    'bannerGuestMessage': 'Your progress is saved once you sign in.',
    'bannerVerifyMessage': 'Verify your email for full access',
    'bannerOfflineMessage': 'Connect to the internet to sign up',
    'dialogRegistration': 'Sign up',
    'dialogEmailVerification': 'Email verification',
    'dialogRegistrationSuccess': 'Sign-up successful!',
    'dialogEmailVerified': 'Email successfully verified!',
    'dialogEmailInputPrompt': 'Enter your email to sign up and get full access to the app.',
    'dialogSendCodePrompt': "We'll send a verification code to this email.",
    'dialogSendCode': 'Send code',
    'dialogEnterCode': 'Enter the 6-digit code from your email',
    'dialogSendNewCode': 'Send new code',
    'syncSyncing': 'Syncing...',
    'syncDone': 'Sync completed',
    'syncFailed': 'Sync failed',
    'actionContinue': 'Continue',
    'actionCancel': 'Cancel',
    'actionDelete': 'Delete',
    'actionBack': 'Back',
    'welcomeAccessPin': 'Access Free Courses with PIN',
    'loginTitle': 'Log in',
    'loginEmailPlaceholder': 'student@example.com',
    'authLoginRequired': 'A teacher assigned you this course? Log in first',
    'authDefaultStudentName': 'Student',
    'profileLanguageDefault': 'English',
    'subjectBiology': 'Biology',
    'subjectGrammar': 'Grammar',
    'subjectLiterature': 'Literature',
    'subjectMath': 'Mathematics',
    'subjectChemistry': 'Chemistry',
    'subjectEnglish': 'English',
    'libraryLoginBadge': 'Login',
    'skillMolecular': 'Molecular',
    'skillEcological': 'Ecological',
    'skillEvolutionary': 'Evolutionary',
    'skillCells': 'Cells',
    'skillDna': 'DNA',
    'skillProtein': 'Protein',
    'skillEcosystems': 'Ecosystems',
    'skillProteins': 'Proteins',
    'chatyTitle': 'Chats',
    'chatySubtitle': 'Pick a mentor or coach to consult',
    'chatyInfoBanner': 'All AI mentors and AI teachers are available 24/7 for learning help.',
    'chatyEndedFilter': 'Ended',
    'chatyOfflineBanner': "You're offline",
    'chatyNewChat': 'New chat',
    'chatyTimeNow': 'now',
    'chatMockAiTeacher': 'AI Teacher',
    'chatMockAiTeacherMsg': 'Great job on your last quiz!',
    'chatMockMathMentor': 'Math Mentor',
    'chatMockMathMentorMsg': 'Try practising derivatives',
    'chatMockTeacherJana': 'Mrs. Jana Nováková',
    'chatMockTeacherJanaMsg': 'Excellent poem analysis!',
    'chatMockYesterday': 'yesterday',
    'chatMockStudyCoach': 'Study Coach',
    'chatMockStartConversation': 'Start a conversation',
    'chatMockTeacherPetr': 'Mr. Petr Svoboda',
    'chatMockTeacherPetrMsg': 'You: I need help with photosynthesis',
    'chatMockThreeHoursAgo': '3h ago',
    'chatMockLanguageMentor': 'Language Mentor',
    'chatDetailToday': 'Today',
    'chatDetailOnline': 'Online',
    'chatDetailOffline': 'Offline',
    'chatDetailInputHint': 'Write to me...',
    'chatDetailHelperText': 'Write a message or ask a question',
    'chatDetailMockAiGreeting': "Hi! I'm your EDU-AI assistant. How can I help you today?",
    'chatDetailMockUserMsg': 'Can you explain cell structures?',
    'chatDetailOfflineBanner': "You're offline — history is available, but new messages can't be sent",
    'chatFeedbackTitle': "What didn't you like?",
    'chatFeedbackSubtitle': 'Your feedback helps us improve answers',
    'chatFeedbackSelectReason': 'Pick a reason',
    'chatFeedbackDetails': 'More details (optional)',
    'chatFeedbackHint': 'Write more about the problem...',
    'chatFeedbackCancel': 'Cancel',
    'chatFeedbackSubmit': 'Send',
    'chatFeedbackThanks': 'Thanks for your feedback!',
    'chatFeedbackIncorrect': 'Incorrect information',
    'chatFeedbackIncomplete': 'Incomplete answer',
    'chatFeedbackUnclear': 'Unclear explanation',
    'chatFeedbackInappropriate': 'Inappropriate response',
    'chatFeedbackOther': 'Other reason',
    'chatNewConversation': 'New conversation',
    'chatSelectPersona': 'Pick a mentor',
    'courseMentor': 'Course mentor',
    'chatyPickConversation': 'Pick a conversation on the left, or start a new one.',
    'chatEmptyState': 'No conversations yet.\nStart chatting!',
    'chatRequiresInternet': 'Chat requires an internet connection',
    'chatStreamError': 'Error generating answer',
    'chatSuggestionsTitle': 'You might also ask:',
    'chatRetry': 'Try again',
    'chatDeleteConfirm': 'Are you sure you want to delete this conversation?',
    'chatDelete': 'Delete',
    'drawerNavigation': 'NAVIGATION',
    'drawerProfile': 'Profile',
    'drawerMore': 'MORE',
    'drawerHelp': 'Help',
    'dialogEmailHint': 'you@email.com',
    'stepWriteAnswer': 'Write an answer...',
    'stepExplanation': 'Explanation',
    'stepAiFeedback': 'Graded by AI',
    'openFeedbackTitle': 'Feedback',
    'openFeedbackStrengths': 'What went well',
    'openFeedbackImprovements': 'What to improve',
    'openFeedbackNextStep': 'What to do next',
    'openFeedbackSolution': 'Model answer',
    'openFeedbackEvaluating': 'Thinking about your answer...',
    'openFeedbackQuizPending': 'Your answer is in. You will see feedback at the end of the quiz.',
    'openFeedbackFailed': 'Feedback could not be prepared right now. Your answer is saved — please try again.',
    'openFeedbackNotEvaluable': 'I cannot prepare feedback for this question. Your answer is saved and your teacher will see it — feel free to move on.',
    'openFeedbackOffline': 'You are offline, so feedback has to wait. Your answer is saved.',
    'openFeedbackRetry': 'Try again',
    'openFeedbackRework': 'Revise answer',
    'openAnswerEmpty': 'Please write at least a short answer in your own words, or attach a photo of your solution.',
    'openPhotoAdd': 'Attach a photo',
    'openPhotoCamera': 'Take a photo',
    'openPhotoGallery': 'Choose from gallery',
    'openPhotoRemove': 'Remove photo',
    'openPhotoAttached': 'Photo attached',
    'openPhotoUploading': 'Uploading photo...',
    'openPhotoUploadFailed': 'The photo could not be uploaded. Please try again.',
    'openPhotoUnreadable': 'I could not read the solution from that photo. Try taking it again, or answer in text.',
    'openPhotoTooLarge': 'That photo is too large. Try taking it again.',
    'stepAudioError': 'Failed to load audio',
    'stepNumericHint': 'Enter a number...',
    'stepVideoError': 'Failed to load video',
    'engineCheck': 'Check',
    'engineNext': 'Next',
    'engineContinue': 'Continue',
    'engineSelectAnswer': 'Pick an answer first',
    'engineAnswerAllQuestions': 'Answer every question first',
    'engineTryAgain': 'Try again',
    'statStreak': 'Streak',
    'statStreakSubtitle': 'Great work!\nKeep learning.',
    'statTrophiesSubtitle': 'Collect trophies and unlock\nnew rewards.',
    'sectionMyCourses': 'My courses',
    'sectionShowAllCourses': 'Show all',
    'statDays': 'days',
    'statTrophies': 'Trophies',
    'courseCardCompleted': 'COMPLETED',
    'promoDefaultBadge': 'NEW',
    'aboutSendDebugReport': 'Send diagnostic report',
    'aboutDebugReportTitle': 'Send report?',
    'aboutDebugReportMessage':
        'Collects diagnostic information about the app '
        '(version, database state, sync queue, statistics) '
        'and sends it to developers. Does not contain personal data or course content.',
    'aboutDebugReportSend': 'Send',
    'aboutDebugReportSending': 'Sending report...',
    'aboutDebugReportSuccess': 'Diagnostic report sent',
    'aboutDebugReportOffline': 'An internet connection is required to send the report',
    'blockDisplayTitleContent': 'Content',
    'blockDisplayTitleQuestion': 'Question',
    'blockDisplayTitleHint': 'Hint',
    'blockDisplayTitleSolution': 'Solution',
    'blockDisplayTitleTask': 'Task',
    'blockDisplayTitleImage': 'Image',
    'blockDisplayTitleVideo': 'Video',
    'blockDisplayTitleAudio': 'Audio',
    'blockDisplayTitleLearning': 'Lesson content',
    'blockDisplayTitleExercise': 'Exercise',
    'personaAiTeacherName': 'Teacher Assistant',
    'personaAiTeacherSubtitle': 'General educational assistant',
    'personaAiTeacherDesc': 'An AI assistant answers questions about your courses and can pass them on to a teacher.',
    'personaMathMentorName': 'Course Mentor',
    'personaMathMentorSubtitle': 'Math specialist',
    'personaMathMentorDesc': 'An AI assistant explains the concepts and the steps behind the exercises in your course.',
    'personaStudyCoachName': 'Study Coach',
    'personaStudyCoachSubtitle': 'Helps with study techniques',
    'personaStudyCoachDesc': 'An AI assistant focused on planning your studies and your well-being.',
    'personaLanguageMentorName': 'Admissions Adviser',
    'personaLanguageMentorSubtitle': 'Answers admissions exam questions',
    'personaLanguageMentorDesc': 'FAQ-based answers',
    'personaSkolnikName': 'Caretaker',
    'personaSkolnikSubtitle': 'Knows everything about your school',
    'personaSkolnikDesc': 'A digital librarian answers questions from the school rules and website.',
    'personaCermatikName': 'Cermatík',
    'personaCermatikSubtitle': 'Admissions exam guide',
    'personaCermatikDesc': 'A digital librarian finds information about secondary school entrance exams.',
    'newChatSubtitle': 'Pick an assistant, a mentor or a librarian',
    'newChatNoMentors': 'No mentor is available right now.',
    'mentorAvailabilityOnline': 'online',
    'mentorAvailabilityCourseOnly': 'in course only',
    'mentorKindAi': 'AI',
    'mentorKindLibrary': 'library',
    'levelTitle1': 'Beginner',
    'levelTitle2': 'Apprentice',
    'levelTitle3': 'Student',
    'levelTitle4': 'Advanced',
    'levelTitle5': 'Expert',
    'levelTitle6': 'Master',
    'levelTitle7': 'Guru',
    'levelTitle8': 'Legend',
    'levelTitle9': 'Genius',
    'levelTitle10': 'Unreachable',
    'trophyFirstLessonTitle': 'First lesson',
    'trophyFirstLessonDesc': 'Finish your first lesson',
    'trophyDiligentStudentTitle': 'Diligent student',
    'trophyDiligentStudentDesc': 'Complete 5 lessons',
    'trophyQuizNoviceTitle': 'Quiz novice',
    'trophyQuizNoviceDesc': 'Pass your first quiz',
    'trophyMasterpieceTitle': 'Masterpiece',
    'trophyMasterpieceDesc': 'Score 100% on a quiz',
    'trophyMonthStreakTitle': 'Monthly streak',
    'trophyMonthStreakDesc': 'Study 30 days in a row',
    'goal100XpTitle': 'Earn 100 XP',
    'goal500XpTitle': 'Earn 500 XP',
    'goal1000XpTitle': 'Earn 1000 XP',
    'goalXpDesc': 'Collect points for completed lessons and exercises',
    'goal3DayStreakTitle': '3-day streak',
    'goal14DayStreakTitle': '14-day streak',
    'goalDailyStreakDesc': 'Study every day in a row',
    'goalLevel3Title': 'Reach level 3',
    'goalLevelDesc': 'Every level = 500 XP',
    'goalComplete10LessonsTitle': 'Complete 10 lessons',
    'goalPracticeDesc': 'Practice makes perfect',
    'challenge5000XpTitle': 'Earn 5000 XP',
    'challenge5000XpDesc': 'Prove your endurance',
    'challenge3CoursesTitle': 'Complete 3 courses',
    'challenge3CoursesDesc': 'Explore different topics',
    'challenge60DayStreakTitle': '60-day streak',
    'challenge60DayStreakDesc': 'True discipline',
    'sharedDeviceBannerLabel': 'Shared device — auto sign-out after 15 min of inactivity',
    'sharedDeviceDialogTitle': 'Shared device',
    'sharedDeviceDialogMessage': "This device is marked as shared — you'll be signed out automatically after 15 minutes of inactivity. Sign out now, or mark this device as your own and stay signed in?",
    'sharedDeviceDialogKeepLoggedIn': 'This is my device',
    'sharedDeviceConvertError': "Couldn't mark this device as your own. Please try again.",
    'shopTitle': 'Store',
    'shopPermanentItems': 'Permanent Items',
    'shopSlotHead': 'Head',
    'shopSlotEyes': 'Eyes',
    'shopSlotMouth': 'Mouth',
    'shopSlotArms': 'Arms',
    'shopSlotLegs': 'Legs',
    'shopSlotTorso': 'Torso',
    'shopSlotFace': 'Face',
    'shopSlotNeck': 'Neck',
    'shopSlotHeld': 'Held',
    'shopEquipped': 'Equipped',
    'shopEquip': 'Equip',
    'shopUnequip': 'Take off',
    'shopGetFree': 'Get for free',
    'shopPurchaseFailed': "Couldn't get the item. Check your connection.",
    'shopOfflineNotice': 'No connection — showing the saved catalog.',
    'shopLoadFailed': "Couldn't load the store.",
    'shopEmptySlot': 'Nothing here yet.',
    'shopRetry': 'Try again',
    'eloInsufficientData': 'Not enough data yet to estimate this area.',
    'confidenceHigher': 'higher',
    'confidenceMedium': 'medium',
    'confidenceLower': 'lower',
    'confidenceVeryLow': 'very low',
  };

  // ═════════════════════════════════════════════════════════════════════
  // Slovak strings
  //
  // The `terms*` keys below are deliberately left in Czech: they are the
  // remains of an in-app Terms screen that nothing renders any more (the
  // live legal texts are the markdown in `assets/legal/`), and legal
  // wording is not machine-translated. They stay here only so all three
  // maps keep the same key set.
  // ═════════════════════════════════════════════════════════════════════
  static const Map<String, String> _sk = {
    'navPrehled': 'Prehľad',
    'navChat': 'Chat',
    'navKurzy': 'Kurzy',
    'navNovinky': 'Novinky',
    'appTitle': 'Edu',
    'appName': 'EduAI',
    'welcomeGreeting': 'Ahoj',
    'welcomeDescription': 'Vitaj vo svojej\nnovej appke!',
    'guideHeading': 'Začnite s návodom',
    'guideTitle': 'Ako používať EDU AI',
    'guideSubtitle':
        'Rýchly úvod do aplikácie EDU AI. '
        'Kde nájdeš AI pomoc, ako fungujú lekcie '
        'a ako si ukladať veci na opakovanie.',
    'guideButton': 'Začať cvičenie',
    'onboardingLoadError':
        'Úvodný kurz sa nepodarilo pripraviť. Skontroluj pripojenie a skús to prosím znova.',
    'practiceTitle': 'Precvičovanie',
    'practiceStart': 'Začať precvičovanie',
    'practiceEmpty': 'Teraz nemáš nič na precvičenie. Vráť sa neskôr!',
    'practiceDashSubtitle': 'Zopakuj si, čo ťa čaká dnes',
    'practiceBonusHint':
        'Na dnešok máš hotovo. Chceš pokračovať? Pripravili sme ti sadu navyše.',
    'practiceBonusStart': 'Precvičovať sadu navyše',
    'practiceScopeTitle': 'Čo chceš precvičovať',
    'practiceScopeAllHint': 'Bez výberu sa precvičuje všetko.',
    'practiceScopeSelectAll': 'Vybrať všetko',
    'practiceScopeOther': 'Ostatné',
    'practiceScopeEmpty':
        'Vo vybraných oblastiach teraz nie je nič na precvičenie. Skús vybrať ďalšie oblasti.',
    'promoBadge': 'KNIŽNICA',
    'promoTitle': 'Preskúmaj kurzy!',
    'promoDescription': 'V knižnici nájdeš kurzy,\nktoré máš teraz k dispozícii',
    'promoDescriptionReward': 'Študuj a čaká ťa odmena:\nhra Oblaka 🤸',
    'dashGreetingWelcome': 'Vitaj vo svojej novej appke!',
    'dashGreetingKeepGoing': 'Pokračuj v učení a zlepšíš sa každý deň.',
    'dashGreetingProud': 'Mám radosť, čo sme spolu už dokázali.',
    'dashGreetingCheering': 'Ideš bomby, fandím ti 👏',
    'practiceNothingDue':
        'Teraz nemáš nič na opakovanie. Prejdi lekciu a kartičky sa objavia.',
    'globalQuizHeading': 'Daj si kvíz',
    'globalQuizTitle': 'Otestuj sa naprieč kurzami',
    'globalQuizSubtitle': 'Náhodné otázky zo všetkých tvojich kurzov',
    'globalQuizStart': 'Spustiť kvíz',
    'jpzBadge': 'PRIJÍMAČKY',
    'jpzTitle': 'Uvažuješ o prijímačkách?',
    'jpzDescription': 'Prejdi si úvod k jednotnej\nprijímacej skúške',
    'jpzCermatikDescription': 'Opýtaj sa Cermatíka na čokoľvek\nokolo prijímačiek',
    'statShopSubtitle': 'Vyber si nový vzhľad\npre svoju postavičku.',
    'statShopAction': 'Otvoriť',
    'sectionQuickQuizzes': 'Rýchle kvízy',
    'sectionContinue': 'Pokračovať',
    'defaultUserName': 'Používateľ',
    'chatTitle': 'Chat',
    'chatLockedMessage': 'Chat sa vám otvorí po získaní vyššej úrovne',
    'addTitle': 'Pripojiť / Pridať',
    'contentComingSoon': 'Tento obsah ešte pripravujeme',
    'novinkyTitle': 'Novinky',
    'novinkyEmpty': 'Zatiaľ žiadne novinky',
    'novinkyError': 'Nepodarilo sa načítať novinky',
    'novinkyLoading': 'Načítavam novinky…',
    'novinkyRetry': 'Skúsiť znova',
    'novinkyPickArticle': 'Vyber novinku vľavo a prečítaj si ju tu.',
    'kurzyTitle': 'Kurzy',
    'filterAll': 'Všetky',
    'filterInProgress': 'Prebiehajúce',
    'filterNotStarted': 'Nezačaté',
    'filterCompleted': 'Dokončené',
    'kurzyEmptyTitle': 'Zatiaľ nemáš žiadne kurzy',
    'kurzyEmptySubtitle': 'Preskúmaj knižnicu a vyber si kurzy, ktoré ťa zaujímajú',
    'kurzyExploreLibrary': 'Preskúmať knižnicu',
    'defaultCourseName': 'Kurz',
    'authHeadline': 'Škola vo vrecku, AI na dosah',
    'authCodeLabel': 'Kód kurzu alebo prihlasovací kód',
    'authVerifyingCode': 'Overujem kód...',
    'authContinue': 'Pokračovať',
    'authOr': 'alebo',
    'authLoginSignUp': 'Prihlásenie / Registrácia',
    'authTerms': 'Podmienky',
    'authPrivacy': 'Súkromie',
    'authEmailHint': 'Tvoj e-mail',
    'authLogin': 'Prihlásiť sa',
    'authOrCzech': 'Alebo',
    'authGoogleLogin': 'Prihlásiť pomocou Google',
    'authMicrosoftLogin': 'Prihlásiť pomocou Microsoft',
    'authAppleLogin': 'Prihlásiť pomocou Apple',
    'authTermsNotice': 'Registráciou súhlasíš s našimi\n',
    'authTermsAndPrivacy': 'Podmienkami a Zásadami ochrany súkromia',
    'authTermsLink': 'Podmienkami',
    'authTermsPrivacyJoiner': ' a ',
    'authPrivacyLink': 'Zásadami ochrany súkromia',
    'authEmptyEmailError': 'Zadaj prosím e-mailovú adresu',
    'authInvalidEmailError': 'Zadaj platnú e-mailovú adresu',
    'authUserCreateError': 'Nepodarilo sa vytvoriť používateľa',
    'authCourseLoadError': 'Kurz sa nepodarilo načítať',
    'authCourseDownloadError': 'Kurz sa nepodarilo stiahnuť. Skontroluj pripojenie a skús to znova.',
    'authKeepLoggedInLabel': 'Zostať trvalo prihlásený — nejde o zdieľané zariadenie',
    'profileTitle': 'Môj účet',
    'profileSectionAccount': 'Účet',
    'profileEditProfile': 'Upraviť profil',
    'profileEditAvatar': 'Upraviť avatara',
    'profilePrivacy': 'Súkromie a zabezpečenie',
    'profileSectionSettings': 'Nastavenia',
    'profileTheme': 'Motív',
    'profileNotifications': 'Oznámenia',
    'profileLanguage': 'Jazyk',
    'profileComingSoon': 'Pripravujeme',
    'profileSectionMore': 'Ďalšie',
    'profileAbout': 'O aplikácii',
    'profileTerms': 'Podmienky používania',
    'profileLogout': 'Odhlásiť sa',
    'profileLogin': 'Prihlásiť sa',
    'profileStatCourses': 'Kurzy',
    'profileStatStreak': 'Streak',
    'profileStatAchievements': 'Úspechy',
    'profileQuickAchievements': 'Úspechy',
    'profileQuickLibrary': 'Knižnica',
    'profileSetupTitle': 'Prispôsob si svoj profil',
    'profileSetupNameLabel': 'Prezývka',
    'profileSetupNameHint': 'Ako ťa vidia ostatní',
    'profileSetupAvatarLabel': 'Vyber si avatara',
    'profileSetupSubjectsLabel': 'Vyber si prostredie',
    'profileSetupNameError': 'Zadaj prosím svoju prezývku',
    'profileSetupSyncWarning': 'Profil uložený lokálne. Synchronizácia prebehne neskôr.',
    'editProfileTitle': 'Upraviť profil',
    'editProfileNameLabel': 'Prezývka',
    'editProfileEmailLabel': 'E-mail',
    'editProfileNameHint': 'Zadaj prezývku',
    'editProfileEmailReadonly': 'E-mail nie je možné zmeniť',
    'editProfileEmptyNameError': 'Prezývka nemôže byť prázdna',
    'editProfileSaveError': 'Nepodarilo sa uložiť zmeny',
    'editProfileSaveButton': 'Uložiť zmeny',
    'libraryTitle': 'Knižnica',
    'librarySubtitle': 'Vyber si kurzy a stiahni si ich',
    'libraryCodeTitle': 'Máš kód kurzu?',
    'libraryCodeShort': 'Zadaj 6-miestny kód',
    'classroomJoinTitle': 'Pripojiť sa k triede',
    'classroomJoinButton': 'Zadať kód žiaka',
    'classroomJoinCodeHint': 'Zadaj 6-miestny kód žiaka, ktorý ti dal učiteľ',
    'classroomJoinSearching': 'Hľadám triedu…',
    'classroomJoinOffline': 'Na pripojenie k triede musíš byť online',
    'classroomJoinYes': 'Áno',
    'classroomJoinNo': 'Nie',
    'classroomJoinSubmit': 'Pripojiť sa',
    'classroomJoinClassCodeHint': 'Zadaj 4-miestny kód triedy, ktorý ti dal učiteľ',
    'classroomJoinUseStudentCode': 'Mám 6-miestny kód žiaka',
    'classroomJoinUseClassCode': 'Mám 4-miestny kód triedy',
    'classroomJoinClassCodeShort': 'Zadaj 4-miestny kód',
    'classroomJoinCodeNotFound': 'Kód triedy sa nenašiel',
    'classroomJoinLoginRequired':
        'Na pripojenie k triede sa musíš prihlásiť. Po prihlásení ťa do triedy pripojíme.',
    'classroomJoinNotAllowed': 'Tento účet sa k triede pripojiť nemôže',
    'editProfileClassroomsLabel': 'Triedy',
    'editProfileNoClassrooms': 'Zatiaľ nie si v žiadnej triede',
    'libraryLoginRequired': 'Na stiahnutie kurzu sa musíš prihlásiť',
    'libraryLoadError': 'Kurz sa nepodarilo načítať',
    'librarySearchingCourse': 'Hľadám kurz...',
    'libraryEmptyTitle': 'Knižnica je prázdna',
    'libraryEmptySubtitle': 'Zatiaľ tu nie sú žiadne kurzy k dispozícii',
    'libraryCoursesLoadError': 'Nepodarilo sa načítať kurzy',
    'libraryCourseAlreadyCompleted': 'Tento kurz bol už dokončený.',
    'libraryUpdating': 'Aktualizujem...',
    'libraryDownloading': 'Sťahujem...',
    'libraryUpdate': 'Aktualizovať',
    'libraryLaunch': 'Spustiť',
    'libraryDownload': 'Stiahnuť',
    'courseProgress': 'Postup',
    'courseDescription': 'Popis kurzu',
    'courseLessons': 'Lekcie',
    'courseShowMore': 'Zobraziť viac',
    'courseShowLess': 'Skryť',
    'courseQuizzes': 'Kvízy',
    'courseShowAll': 'Zobraziť všetko',
    'courseContinueLesson': 'Pokračovať v lekcii',
    'courseExercise': 'Cvičenie',
    'courseQuiz': 'Kvíz',
    'courseCompleted': 'DOKONČENÉ',
    'courseCurrent': 'AKTUÁLNE',
    'courseCorruptedTitle': 'Kurz sa nepodarilo načítať',
    'courseCorruptedMessage': 'Dáta kurzu sú neúplné alebo poškodené. Skúste kurz stiahnuť znova v knižnici.',
    'courseBack': 'Späť',
    'courseStartQuiz': 'Začať kvíz',
    'courseContinueQuiz': 'Pokračovať v kvíze',
    'courseQuizUnlockHint': 'Odpovedz na otázky a odomkni lekcie',
    'courseNoBookmarks': 'Zatiaľ nemáš žiadne uložené bloky na precvičovanie.\nPridaj ich pomocou záložky v lekciách.',
    'courseNoQuestions': 'V tomto kurze nie sú žiadne otázky.',
    'courseUpdateAvailable': 'K dispozícii je nová verzia kurzu',
    'courseUpdateRequired': 'Aktualizujte kurz pre pokračovanie',
    'courseCardUpdate': 'Aktualizácia',
    'courseActionLessons': 'Lekcie',
    'lessonEmptyTitle': 'Obsah lekcie sa pripravuje',
    'lessonEmptyMessage': 'Táto lekcia zatiaľ nemá žiadny obsah.',
    'lessonFinishCourse': 'Dokončiť kurz',
    'lessonNextLesson': 'Ďalšia lekcia',
    'lessonBackToDetail': 'Späť na detail kurzu',
    'lessonCourseCompleted': 'Gratulujeme! Dokončil si celý kurz.',
    'lessonSelectAnswerFirst': 'Najprv vyber odpoveď',
    'lessonExplanation': 'Vysvetlenie',
    'lessonFeedbackClear': 'Už je to jasné',
    'lessonFeedbackPractice': 'Pridať na precvičovanie',
    'lessonFeedbackPracticeAdded': 'Pridané na precvičovanie',
    'mentorSheetInputHint': 'Opýtaj sa AI mentora',
    'mentorSheetNoHelp': 'Skús mi napísať vlastnými slovami, čomu nerozumieš — vysvetlím ti to inak.',
    'lessonFeedbackConfused': 'Nerozumiem tomu',
    'lessonFeedbackClarify': 'Upresni svoju otázku',
    'lessonFeedbackHint': 'Napíš viac o probléme...',
    'lessonFeedbackThanks': 'Ďakujeme za spätnú väzbu!',
    'lessonFeedbackSend': 'Odoslať',
    'lessonVideoError': 'Nepodarilo sa načítať video',
    'lessonWriteAnswer': 'Napíš odpoveď...',
    'lessonCheckAnswer': 'Skontrolovať',
    'lessonCorrect': 'Správne!',
    'lessonQuestionLabel': 'Otázka',
    'quizTitle': 'Kvíz',
    'quizExerciseTitle': 'Cvičenie',
    'quizCompleted': 'Kvíz dokončený!',
    'quizReviewCompleted': 'Opakovanie dokončené!',
    'quizAllCorrect': 'Výborne! Všetko správne!',
    'quizGreatJob': 'Skvelá práca!',
    'quizTryAgain': 'Skús to znova!',
    'quizGreatReview': 'Skvelé opakovanie!',
    'quizDone': 'Hotovo',
    'quizConfirmSubmit': 'Naozaj chceš kvíz odoslať? Potom sa k nemu už nedá vrátiť.',
    'quizConfirmBack': 'Späť',
    'quizConfirmSend': 'Odoslať',
    'quizConfirmExitMessage': 'Naozaj chcete kvíz ukončiť? Nie je možné sa vrátiť ani ho spustiť znova.',
    'quizConfirmExitLeave': 'Ukončiť',
    'quizConfirmExitStay': 'Pokračovať',
    'quizThankYou': 'Skvelé, vďaka. Teraz viem, aké úlohy ti nabudúce ponúknem.',
    'quizRetry': 'Skúsiť znova',
    'quizReview': 'Opakovanie',
    'quizFinish': 'Dokončiť',
    'quizNext': 'Ďalej',
    'quizCheck': 'Skontrolovať',
    'quizAnswerHint': 'Zadaj odpoveď...',
    'quizCorrectLabel': 'Správne!',
    'quizIncorrectLabel': 'Nesprávne',
    'quizAskAi': 'Opýtať sa AI',
    'quizAnswersSaved': 'Odpovede boli uložené, ďakujeme',
    'chatContextFallbackPrompt': 'Môžeš mi to prosím vysvetliť inak?',
    'exerciseSelectCorrect': 'Vyber správnu odpoveď',
    'exerciseSelectAll': 'Vyber všetky správne odpovede',
    'exerciseWriteAnswer': 'Napíš svoju odpoveď',
    'exerciseAnswerHint': 'Tvoja odpoveď...',
    'exerciseCorrect': 'Správne',
    'exerciseIncorrect': 'Nesprávne',
    'trueFalseTrue': 'Áno',
    'trueFalseFalse': 'Nie',
    'exerciseExplanationLabel': 'Vysvetlenie:',
    'achievementsTitle': 'Úspechy',
    'achievementsTrophies': 'Trofeje',
    'achievementsCoins': 'Mince EDUX',
    'achievementsEarnedTrophies': 'Získané trofeje',
    'achievementsChallenges': 'Výzvy',
    'achievementsSkills': 'Zručnosti',
    'achievementsSkillsPlaceholder': 'Teším sa, čo spoločne zvládneme.',
    'skillTabAll': 'Všetky',
    'skillTabBeginner': 'Začiatočník',
    'skillTabIntermediate': 'Pokročilý',
    'skillTabExpert': 'Expert',
    'achievementsGoals': 'Ciele',
    'challengeMasterpiece': 'Majstrovský kúsok',
    'trophyBiologist': 'Majstrovský biológ',
    'trophyBiologistDesc': 'Získaj 90 % alebo viac v kvíze',
    'trophyWeekStreak': 'Týždenná séria',
    'trophyWeekStreakDesc': 'Uč sa 7 dní v rade',
    'goalCompleteLessons': 'Dokončiť 10 lekcií',
    'goalCompleteLessonsDesc': '+100 XP po dokončení',
    'goalPerfectScores': 'Získať 5 perfektných skóre',
    'goalPerfectScoresDesc': '+150 XP po dokončení',
    'timeYesterday': 'Včera',
    'timeJustNow': 'Práve teraz',
    // ── Legacy in-app Terms screen (unused, kept in Czech — see note above)
    'termsTitle': 'Podmínky použití',
    'termsLastUpdated': 'Poslední aktualizace: 19. ledna 2026',
    'termsSection1Title': '1. Úvodní ustanovení',
    'termsSection1Body':
        'Tyto podmínky použití upravují práva a povinnosti uživatelů '
        'aplikace EDU-AI. Používáním aplikace souhlasíte s těmito '
        'podmínkami. Aplikace je určena pro vzdělávací účely a je '
        'provozována společností EduAI s.r.o.',
    'termsSection2Title': '2. Uživatelský účet',
    'termsSection2Body':
        'Pro využívání plných funkcí aplikace je nutné vytvořit '
        'uživatelský účet. Uživatel je povinen poskytnout pravdivé '
        'údaje a chránit své přihlašovací údaje. Za veškeré aktivity '
        'provedené pod vaším účtem nesete odpovědnost.',
    'termsSection3Title': '3. Autorská práva',
    'termsSection3Body':
        'Veškerý obsah v aplikaci, včetně kurzů, textů, grafiky a '
        'softwarového kódu, je chráněn autorským právem. Uživatel '
        'získává pouze licenci k osobnímu nekomerčnímu využití obsahu. '
        'Kopírování, distribuce nebo komerční využití bez písemného '
        'souhlasu je zakázáno.',
    'termsSection4Title': '4. Pravidla používání',
    'termsSection4Body':
        'Uživatel se zavazuje používat aplikaci v souladu s právními '
        'předpisy a dobrými mravy. Je zakázáno šířit nevhodný obsah, '
        'pokoušet se o neoprávněný přístup k systémům, nebo jakýmkoli '
        'způsobem narušovat chod aplikace.',
    'termsSection5Title': '5. Ochrana osobních údajů',
    'termsSection5Body':
        'Zpracování osobních údajů se řídí Zásadami ochrany osobních '
        'údajů a nařízením GDPR. Shromažďujeme pouze údaje nezbytné '
        'pro poskytování služeb. Vaše údaje nikdy neprodáváme třetím '
        'stranám.',
    'termsSection6Title': '6. Omezení odpovědnosti',
    'termsSection6Body':
        'Aplikace je poskytována "tak jak je". Provozovatel nenese '
        'odpovědnost za případné škody vzniklé používáním aplikace, '
        'ztrátu dat nebo přerušení služby. Maximální odpovědnost je '
        'omezena na výši zaplacených poplatků.',
    'termsSection7Title': '7. Změny podmínek',
    'termsSection7Body':
        'Vyhrazujeme si právo tyto podmínky kdykoli změnit. O změnách '
        'budete informováni prostřednictvím aplikace nebo e-mailem. '
        'Pokračováním v používání aplikace po změně podmínek '
        'vyjadřujete souhlas s novým zněním.',
    'termsSection8Title': '8. Kontakt',
    'termsSection8Body':
        'V případě dotazů nebo připomínek nás můžete kontaktovat na '
        'e-mailové adrese podpora@eduai.cz nebo prostřednictvím '
        'kontaktního formuláře v aplikaci.',
    'privacyTitle': 'Súkromie a zabezpečenie',
    'privacyComingSoon': 'Pripravujeme',
    'privacyComingSoonMessage':
        'Na nastavení súkromia a zabezpečenia práve pracujeme. Čoskoro tu nájdete možnosti na správu vašich dát a bezpečnostné nastavenia.',
    'aboutSavedBookmarks': 'Uložené záložky',
    'bookmarksListTitle': 'Uložené záložky',
    'bookmarksListEmpty': 'Zatiaľ nemáš žiadne uložené záložky.\nPridaj ich pomocou záložky v lekciách.',
    'bookmarksListCourseNotDownloaded': 'Kurz nie je stiahnutý',
    'aboutTitle': 'O aplikácii',
    'aboutSectionAppInfo': 'Informácie o aplikácii',
    'aboutAppName': 'EduAI',
    'aboutLabelName': 'Názov',
    'aboutLabelVersion': 'Verzia',
    'aboutLabelBuild': 'Build',
    'aboutBuildValue': 'Release',
    'aboutLabelFlutter': 'Flutter',
    'aboutFlutterValue': 'SDK 3.10+',
    'aboutVersionUnavailable': 'Nedostupná',
    'aboutSectionStatus': 'Stav systému',
    'aboutDatabase': 'Databáza',
    'aboutDatabaseReady': 'Pripravená',
    'aboutDatabaseNotInit': 'Neinicializovaná',
    'aboutUserLoggedIn': 'Používateľ prihlásený',
    'aboutGuestPin': 'Hosť (PIN)',
    'aboutYes': 'Áno',
    'aboutNo': 'Nie',
    'aboutApiAuth': 'API autorizácia',
    'aboutConnection': 'Pripojenie',
    'aboutConnectionChecking': 'Kontrola...',
    'aboutConnectionError': 'Chyba',
    'aboutSyncState': 'Sync stav',
    'aboutSyncReady': 'Pripravené',
    'aboutSyncSyncing': 'Synchronizácia...',
    'aboutSyncError': 'Chyba',
    'aboutLastSync': 'Posledný sync',
    'aboutNextSync': 'Ďalší sync',
    'aboutSyncNever': 'Zatiaľ neprebehol',
    'aboutSectionDbStats': 'Štatistiky databázy',
    'aboutCoursesCount': 'Počet kurzov',
    'aboutPendingSync': 'Čakajúci sync',
    'aboutSectionActions': 'Akcie',
    'aboutForceSync': 'Vynútiť synchronizáciu',
    'aboutClearSyncQueue': 'Vymazať sync frontu',
    'aboutRefreshStatus': 'Obnoviť stav',
    'aboutClearAuthToken': 'Vymazať auth token',
    'aboutClearCourses': 'Vymazať kurzy z knižnice',
    'aboutFactoryReset': 'Továrenský reset (zmazať všetko)',
    'aboutSectionApiConfig': 'API konfigurácia',
    'aboutBaseUrl': 'Base URL',
    'aboutAuth': 'Auth',
    'aboutAuthValue': 'Laravel Sanctum',
    'aboutConnWifi': 'WiFi',
    'aboutConnMobile': 'Mobilné dáta',
    'aboutConnEthernet': 'Ethernet',
    'aboutConnOffline': 'Offline',
    'aboutSyncCompleted': 'Synchronizácia dokončená',
    'aboutClearTokenTitle': 'Vymazať token?',
    'aboutClearTokenMessage': 'Toto vás odhlási z aplikácie. Pokračovať?',
    'aboutTokenCleared': 'Token vymazaný',
    'aboutClearCoursesTitle': 'Vymazať kurzy?',
    'aboutClearCoursesMessage':
        'Toto zmaže všetky stiahnuté kurzy z tvojej lokálnej knižnice. '
        'Postup v kurzoch bude stratený. Pokračovať?',
    'aboutNoUser': 'Žiadny prihlásený používateľ',
    'aboutFactoryResetTitle': 'Továrenský reset?',
    'aboutFactoryResetMessage':
        'Toto zmaže VŠETKY lokálne dáta: používateľov, kurzy, '
        'postup, záložky, auth token aj sync frontu. '
        'Aplikácia sa vráti do východiskového stavu ako po čistej inštalácii.\n\n'
        'Naozaj pokračovať?',
    'aboutDeleteAll': 'Zmazať všetko',
    'aboutTimeJustNow': 'práve teraz',
    'aboutTimeSoon': 'o chvíľu',
    'themeTitle': 'Motív',
    'themeDefault': 'Klasický fialový motív',
    'themeOcean': 'Modrý motív inšpirovaný oceánom',
    'themeSunset': 'Teplý motív v oranžových tónoch',
    'themeCustom': 'Vlastný motív',
    'themeCreateNew': 'Vytvoriť nový motív',
    'themeImportJson': 'Importovať JSON',
    'themeImportTitle': 'Import motívu',
    'themeImportHint': 'Vlož JSON motívu…',
    'themeImportButton': 'Importovať',
    'themeImportError': 'Neplatný JSON motívu',
    'themeImportSuccess': 'Motív úspešne importovaný',
    'themeEditorTitle': 'Editor motívu',
    'themeEditorName': 'Názov motívu',
    'themeEditorNameHint': 'Môj motív',
    'themeEditorSave': 'Uložiť motív',
    'themeEditorExport': 'Exportovať JSON',
    'themeEditorExportCopied': 'JSON skopírovaný do schránky',
    'themeEditorDelete': 'Zmazať motív',
    'themeEditorDeleteConfirm': 'Naozaj chceš zmazať tento motív?',
    'themeEditorDeleteYes': 'Zmazať',
    'themeEditorCancel': 'Zrušiť',
    'themeEditorConfirm': 'Potvrdiť',
    'themeEditorNameEmpty': 'Zadaj názov motívu',
    'themeEditorGroupCoreBrand': 'Hlavné farby',
    'themeEditorGroupStatus': 'Stavové farby',
    'themeEditorGroupUi': 'UI prvky',
    'themeEditorGroupCards': 'Karty a pozadie',
    'themeEditorGroupAvatars': 'Avatary',
    'themeEditorGroupSubjects': 'Predmety',
    'themeEditorGroupOther': 'Ďalšie',
    'themeEditorPickColor': 'Vybrať farbu',
    'colorPickerHexLabel': 'Hex:',
    'emailVerificationTitle': 'Overenie e-mailu',
    'emailVerificationCodePrompt': 'Zadaj 6-miestny kód z e-mailu',
    'emailVerificationVerify': 'Overiť',
    'emailVerificationResend': 'Neprišiel kód? Odoslať znova',
    'emailVerificationSending': 'Odosielam kód...',
    'emailCheckingAccount': 'Overujem e-mail...',
    'emailVerificationOfflineTitle': 'Si offline',
    'emailVerificationOfflineMessage':
        'Na overenie e-mailu je potrebné pripojenie na internet. Môžeš pokračovať bez overenia a overiť e-mail neskôr.',
    'emailVerificationRetry': 'Skúsiť znova',
    'emailVerificationOfflineLabel': 'Bez pripojenia',
    'emailSendCodeError': 'Nepodarilo sa odoslať kód',
    'emailMissingError': 'E-mail nebol zadaný',
    'emailLoadingProfile': 'Načítavam profil...',
    'emailErrInvalidCode': 'Neplatný kód',
    'emailErrCodeExpired': 'Kód vypršal',
    'emailErrRateLimited': 'Počkajte pred ďalším odoslaním',
    'emailErrNetwork': 'Chyba pripojenia',
    'emailErrUnknown': 'Nastala neočakávaná chyba',
    'bannerGuestMessage': 'Postup sa uloží až po prihlásení.',
    'bannerVerifyMessage': 'Over svoj e-mail pre plný prístup',
    'bannerOfflineMessage': 'Pripojte sa na internet pre registráciu',
    'dialogRegistration': 'Registrácia',
    'dialogEmailVerification': 'Overenie e-mailu',
    'dialogRegistrationSuccess': 'Registrácia prebehla úspešne!',
    'dialogEmailVerified': 'E-mail bol úspešne overený!',
    'dialogEmailInputPrompt': 'Zadajte svoj e-mail pre registráciu a plný prístup k aplikácii.',
    'dialogSendCodePrompt': 'Na tento e-mail vám pošleme overovací kód.',
    'dialogSendCode': 'Odoslať kód',
    'dialogEnterCode': 'Zadajte 6-miestny kód z e-mailu',
    'dialogSendNewCode': 'Odoslať nový kód',
    'syncSyncing': 'Synchronizácia...',
    'syncDone': 'Synchronizácia dokončená',
    'syncFailed': 'Synchronizácia zlyhala',
    'actionContinue': 'Pokračovať',
    'actionCancel': 'Zrušiť',
    'actionDelete': 'Vymazať',
    'actionBack': 'Späť',
    'welcomeAccessPin': 'Access Free Courses with PIN',
    'loginTitle': 'Prihlásenie',
    'loginEmailPlaceholder': 'student@example.com',
    'authLoginRequired': 'Pridelil ti tento kurz učiteľ? Najprv sa prihlás',
    'authDefaultStudentName': 'Študent',
    'profileLanguageDefault': 'Slovenčina',
    'subjectBiology': 'Biológia',
    'subjectGrammar': 'Gramatika',
    'subjectLiterature': 'Literatúra',
    'subjectMath': 'Matematika',
    'subjectChemistry': 'Chémia',
    'subjectEnglish': 'Angličtina',
    'libraryLoginBadge': 'Login',
    'skillMolecular': 'Molekulárna',
    'skillEcological': 'Ekologická',
    'skillEvolutionary': 'Evolučná',
    'skillCells': 'Bunky',
    'skillDna': 'DNA',
    'skillProtein': 'Proteín',
    'skillEcosystems': 'Ekosystémy',
    'skillProteins': 'Proteíny',
    'chatyTitle': 'Chaty',
    'chatySubtitle': 'Vyber si mentora alebo kouča na konzultáciu',
    'chatyInfoBanner': 'Všetci AI mentori a AI učitelia sú dostupní 24/7 na pomoc s učením.',
    'chatyEndedFilter': 'Ukončené',
    'chatyOfflineBanner': 'Nie si online',
    'chatyNewChat': 'Nový chat',
    'chatyTimeNow': 'teraz',
    'chatMockAiTeacher': 'AI Učiteľ',
    'chatMockAiTeacherMsg': 'Dobrá práca na poslednom kvíze!',
    'chatMockMathMentor': 'Mentor Matematika',
    'chatMockMathMentorMsg': 'Skús si precvičiť derivácie',
    'chatMockTeacherJana': 'Mgr. Jana Nováková',
    'chatMockTeacherJanaMsg': 'Skvelý rozbor básne!',
    'chatMockYesterday': 'včera',
    'chatMockStudyCoach': 'Kouč Pre Štúdium',
    'chatMockStartConversation': 'Začať konverzáciu',
    'chatMockTeacherPetr': 'Ing. Petr Svoboda',
    'chatMockTeacherPetrMsg': 'Ty: Potrebujem pomoc s fotosyntézou',
    'chatMockThreeHoursAgo': 'pred 3 hod',
    'chatMockLanguageMentor': 'Mentor Cudzie jazyky',
    'chatDetailToday': 'Dnes',
    'chatDetailOnline': 'Online',
    'chatDetailOffline': 'Offline',
    'chatDetailInputHint': 'Napíš mi...',
    'chatDetailHelperText': 'Napíš správu alebo polož otázku',
    'chatDetailMockAiGreeting': 'Ahoj! Som tvoj EDU-AI asistent. Ako ti dnes môžem pomôcť?',
    'chatDetailMockUserMsg': 'Môžeš mi vysvetliť bunkové štruktúry?',
    'chatDetailOfflineBanner': 'Nie si online — história je dostupná, ale nové správy nie je možné odoslať',
    'chatFeedbackTitle': 'Čo sa ti nepáčilo?',
    'chatFeedbackSubtitle': 'Tvoja spätná väzba nám pomôže zlepšiť odpovede',
    'chatFeedbackSelectReason': 'Vyber dôvod',
    'chatFeedbackDetails': 'Ďalšie podrobnosti (voliteľné)',
    'chatFeedbackHint': 'Napíš viac o probléme...',
    'chatFeedbackCancel': 'Zrušiť',
    'chatFeedbackSubmit': 'Odoslať',
    'chatFeedbackThanks': 'Ďakujeme za spätnú väzbu!',
    'chatFeedbackIncorrect': 'Nesprávne informácie',
    'chatFeedbackIncomplete': 'Neúplná odpoveď',
    'chatFeedbackUnclear': 'Nezrozumiteľné vysvetlenie',
    'chatFeedbackInappropriate': 'Nevhodná odpoveď',
    'chatFeedbackOther': 'Iný dôvod',
    'chatNewConversation': 'Nová konverzácia',
    'chatSelectPersona': 'Vyber si mentora',
    'courseMentor': 'Mentor kurzu',
    'chatEmptyState': 'Zatiaľ žiadne konverzácie.\nZačni chatovať!',
    'chatRequiresInternet': 'Chat vyžaduje pripojenie na internet',
    'chatStreamError': 'Chyba pri generovaní odpovede',
    'chatSuggestionsTitle': 'Mohlo by ťa zaujímať:',
    'chatRetry': 'Skúsiť znova',
    'chatDeleteConfirm': 'Naozaj chceš zmazať túto konverzáciu?',
    'chatDelete': 'Zmazať',
    'drawerNavigation': 'NAVIGÁCIA',
    'drawerProfile': 'Profil',
    'drawerMore': 'ĎALŠIE',
    'drawerHelp': 'Nápoveda',
    'dialogEmailHint': 'vas@email.sk',
    'stepWriteAnswer': 'Napíš odpoveď...',
    'stepExplanation': 'Vysvetlenie',
    'stepAudioError': 'Nepodarilo sa načítať audio',
    'stepNumericHint': 'Zadaj číslo...',
    'stepVideoError': 'Nepodarilo sa načítať video',
    'engineCheck': 'Skontrolovať',
    'engineNext': 'Ďalej',
    'engineContinue': 'Pokračovať',
    'engineSelectAnswer': 'Najprv vyber odpoveď',
    'engineAnswerAllQuestions': 'Najprv odpovedz na všetky otázky',
    'engineTryAgain': 'Skúsiť znova',
    'statStreak': 'Streak',
    'statDays': 'dní',
    'statTrophies': 'Trofeje',
    'courseCardCompleted': 'DOKONČENÉ',
    'promoDefaultBadge': 'NOVÉ',
    'aboutSendDebugReport': 'Odoslať diagnostický report',
    'aboutDebugReportTitle': 'Odoslať report?',
    'aboutDebugReportMessage':
        'Zhromaždí diagnostické informácie o aplikácii '
        '(verzia, stav databázy, sync fronta, štatistiky) '
        'a odošle ich vývojárom. Neobsahuje osobné dáta ani obsah kurzov.',
    'aboutDebugReportSend': 'Odoslať',
    'aboutDebugReportSending': 'Odosielam report...',
    'aboutDebugReportSuccess': 'Diagnostický report bol odoslaný',
    'aboutDebugReportOffline': 'Na odoslanie reportu je potrebné pripojenie na internet',
    'blockDisplayTitleContent': 'Obsah',
    'blockDisplayTitleQuestion': 'Otázka',
    'blockDisplayTitleHint': 'Nápoveda',
    'blockDisplayTitleSolution': 'Riešenie',
    'blockDisplayTitleTask': 'Úloha',
    'blockDisplayTitleImage': 'Obrázok',
    'blockDisplayTitleVideo': 'Video',
    'blockDisplayTitleAudio': 'Audio',
    'blockDisplayTitleLearning': 'Učivo',
    'blockDisplayTitleExercise': 'Cvičenie',
    'personaAiTeacherName': 'Asistent učiteľa',
    'personaAiTeacherSubtitle': 'Všeobecný vzdelávací asistent',
    'personaAiTeacherDesc': 'AI asistent ti zodpovie otázky k tvojim kurzom a môže odovzdať otázku učiteľovi.',
    'personaMathMentorName': 'Mentor kurzu',
    'personaMathMentorSubtitle': 'Špecialista na matematiku',
    'personaMathMentorDesc': 'AI asistent ti vysvetlí pojmy a postupy riešenia konkrétnych úloh v kurze.',
    'personaStudyCoachName': 'Študijný kouč',
    'personaStudyCoachSubtitle': 'Pomáha s technikami učenia',
    'personaStudyCoachDesc': 'AI asistent špecializovaný na organizáciu prípravy a well-being.',
    'personaLanguageMentorName': 'Poradca k prijímačkám',
    'personaLanguageMentorSubtitle': 'Zodpovedá otázky k JPZ',
    'personaLanguageMentorDesc': 'Odpovede z FAQ',
    'personaSkolnikName': 'Školník',
    'personaSkolnikSubtitle': 'Vie všetko o vašej škole',
    'personaSkolnikDesc': 'Digitálny knihovník ti odpovie na otázky zo školského poriadku a webu.',
    'personaCermatikName': 'Cermatík',
    'personaCermatikSubtitle': 'Sprievodca prijímačkami',
    'personaCermatikDesc': 'Digitálny knihovník ti nájde informácie o prijímacích skúškach na strednú.',
    'newChatSubtitle': 'Vyber si asistenta, mentora alebo knihovníka',
    'newChatNoMentors': 'Momentálne nie je dostupný žiadny mentor.',
    'mentorAvailabilityOnline': 'online',
    'mentorAvailabilityCourseOnly': 'len v kurze',
    'mentorKindAi': 'AI',
    'mentorKindLibrary': 'knižnica',
    'levelTitle1': 'Začiatočník',
    'levelTitle2': 'Učeň',
    'levelTitle3': 'Študent',
    'levelTitle4': 'Pokročilý',
    'levelTitle5': 'Expert',
    'levelTitle6': 'Majster',
    'levelTitle7': 'Guru',
    'levelTitle8': 'Legenda',
    'levelTitle9': 'Génius',
    'levelTitle10': 'Nedostižný',
    'trophyFirstLessonTitle': 'Prvá lekcia',
    'trophyFirstLessonDesc': 'Dokonči svoju prvú lekciu',
    'trophyDiligentStudentTitle': 'Usilovný študent',
    'trophyDiligentStudentDesc': 'Dokonči 5 lekcií',
    'trophyQuizNoviceTitle': 'Kvízový nováčik',
    'trophyQuizNoviceDesc': 'Dokonči svoj prvý kvíz',
    'trophyMasterpieceTitle': 'Majstrovský kúsok',
    'trophyMasterpieceDesc': 'Dokonči celý kurz',
    'trophyMonthStreakTitle': 'Mesačná séria',
    'trophyMonthStreakDesc': 'Uč sa 30 dní v rade',
    'goal100XpTitle': 'Získať 100 XP',
    'goal500XpTitle': 'Získať 500 XP',
    'goal1000XpTitle': 'Získať 1000 XP',
    'goalXpDesc': 'Zbieraj body za dokončené lekcie a cvičenia',
    'goal3DayStreakTitle': 'Séria 3 dní',
    'goal14DayStreakTitle': 'Séria 14 dní',
    'goalDailyStreakDesc': 'Uč sa každý deň po sebe',
    'goalLevel3Title': 'Dosiahnuť úroveň 3',
    'goalLevelDesc': 'Každá úroveň = 500 XP',
    'goalComplete10LessonsTitle': 'Dokonči 10 lekcií',
    'goalPracticeDesc': 'Učenie robí majstra',
    'challenge5000XpTitle': 'Získať 5000 XP',
    'challenge5000XpDesc': 'Dokáž svoju vytrvalosť',
    'challenge3CoursesTitle': 'Dokonči 3 kurzy',
    'challenge3CoursesDesc': 'Preskúmaj rôzne témy',
    'challenge60DayStreakTitle': 'Séria 60 dní',
    'challenge60DayStreakDesc': 'Naozajstná disciplína',
    'sharedDeviceBannerLabel': 'Zdieľané zariadenie — odhlásenie po 15 min nečinnosti',
    'sharedDeviceDialogTitle': 'Zdieľané zariadenie',
    'sharedDeviceDialogMessage': 'Toto zariadenie je označené ako zdieľané — po 15 minútach nečinnosti budete automaticky odhlásení. Chcete sa odhlásiť teraz, alebo označiť zariadenie ako vlastné a zostať prihlásení?',
    'sharedDeviceDialogKeepLoggedIn': 'Toto je moje zariadenie',
    'sharedDeviceConvertError': 'Zariadenie sa nepodarilo označiť ako vlastné. Skúste to prosím znova.',
    'eloInsufficientData': 'Na odhad v tejto oblasti zatiaľ nemáme dosť údajov.',
    'confidenceHigher': 'vyššia',
    'confidenceMedium': 'stredná',
    'confidenceLower': 'nižšia',
    'confidenceVeryLow': 'veľmi nízka',
    'shellDashboardSubtitle': 'Pokračuj v učení a zlepšuj sa každý deň.',
    'shellKurzySubtitle': 'Vyber si kurz a začni sa učiť vlastným tempom.',
    'shellGuestCtaTitle': 'Postup sa uloží\naž po prihlásení.',
    'shellGuestCtaButton': 'Zaregistrovať sa',
    'shellGames': 'Hry',
    'shellShop': 'Obchod',
    'progressCardTitle': 'Tvoj postup',
    'progressCardCompleted': 'Hotovo',
    'progressCardDetail': 'Zobraziť detail',
    'progressCardHintStart': 'Skvelý začiatok!',
    'progressCardHintGoing': 'Ide ti to skvele!',
    'progressCardHintDone': 'Máš hotovo. Paráda!',
    'progressCardLessons': '{done} z {total} lekcií',
    'continueLessonTitle': 'Pokračuj v lekcii',
    'continueLessonBadge': 'AKTUÁLNE',
    'continueLessonButton': 'Pokračovať v lekcii',
    'continueLessonEmpty': 'Zatiaľ si nezačal žiadnu lekciu.',
    'continueLessonAllDone': 'Všetky lekcie máš hotové.',
    'continueLessonQuizOnly': 'Otvor kurz a pusť sa do kvízu.',
    'continueLessonOpenCourse': 'Otvoriť kurz',
    'continueLessonSteps': '{done} z {total} krokov',
    'recentActivityTitle': 'Nedávna aktivita',
    'recentActivityShowAll': 'Zobraziť všetko',
    'recentActivityEmpty': 'Zatiaľ zbierame dáta o tvojej aktivite.',
    'kurzySearchHint': 'Hľadať kurz…',
    'kurzyFilterButton': 'Filter',
    'kurzySearchEmpty': 'Žiadny kurz nezodpovedá hľadaniu.',
    'courseCardStart': 'Začať kurz',
    'courseCardContinue': 'Pokračovať',
    'courseCardReview': 'Prejsť znova',
    'courseBackToAll': 'Späť na všetky kurzy',
    'courseTabLessons': 'Lekcie',
    'courseTabAbout': 'O kurze',
    'courseTabSkills': 'Zručnosti',
    'courseTabStats': 'Štatistiky',
    'courseSaveButton': 'Uložiť kurz',
    'courseShowAllLessons': 'Zobraziť všetky lekcie ({count})',
    'courseShowFewerLessons': 'Zobraziť menej',
    'courseOpenLesson': 'Otvoriť',
    'courseSkillsInCourse': 'Zručnosti v kurze',
    'courseSkillsEmpty':
        'Zručnosti sa objavia, keď vyriešiš pár úloh.',
    'courseStatsPlaceholder': 'Štatistiky kurzu ešte pripravujeme.',
    'courseDetailedStats': 'Zobraziť detailné štatistiky',
    'courseTrophyHint': 'Dokonči a získaj trofej!',
    'lessonAiHelpTitle': 'AI nápoveda',
    'lessonAiHelpQuestion': 'Potrebuješ pomôcť?',
    'lessonAiHelpBody': 'Opýtaj sa AI asistenta na čokoľvek k tejto lekcii.',
    'lessonAiHelpButton': 'Otvoriť chat s AI',
    'courseLevelLabel': 'Úroveň: {level}',
    'skillLevelLabel': 'Úroveň {level}',
    'ageGateTitle': 'Než začneme',
    'ageGateQuestion': 'Máš viac ako {age} rokov?',
    'ageGateYes': 'Áno',
    'ageGateNo': 'Nie',
    'ageGateCountryLabel': 'Krajina',
    'ageGateCountryQuestion': 'V ktorej krajine bývaš?',
    'consentIntroTitle': 'Potrebuješ súhlas rodiča',
    'consentIntroBody':
        'Napíš e-mail svojho rodiča. Pošleme mu správu a on ti povie kód, '
        'ktorým sa do aplikácie prihlásiš.',
    'consentEmailLabel': 'E-mail rodiča',
    'consentEmailInvalid': 'Skontroluj e-mail — niečo tam chýba.',
    'consentSend': 'Odoslať rodičovi',
    'consentWaitingTitle': 'Poslali sme rodičovi e-mail',
    'consentWaitingBody':
        'Požiadaj ho, nech ho otvorí. Povie ti kód na vstup do aplikácie.',
    'consentEnterCode': 'Zadať kód',
    'consentGenericError': 'Niečo sa nepodarilo. Skús to prosím znova.',
    'consentNetworkError':
        'Nepodarilo sa to odoslať — skontroluj pripojenie na internet a skús to znova.',
    'consentConfirmTitle': 'Potvrdenie súhlasu',
    'consentConfirmBody':
        'Zadajte šesťznakový kód z e-mailu. Tým potvrdzujete súhlas '
        's používaním EDU-AI vaším dieťaťom.',
    'consentConfirmCta': 'Potvrdiť súhlas',
    'consentConfirmSuccess':
        'Súhlas potvrdený. Prihlasovacie kódy sme vám poslali e-mailom.',
    'consentConfirmFailure': 'Kód je neplatný alebo vypršal. Požiadajte o nový.',
    'consentConfirmInvalidLink':
        'Tento odkaz nie je platný. Skontrolujte, či ste ho skopírovali celý, '
        'alebo si nechajte poslať nový e-mail.',
    'consentConfirmSuccessNoMail':
        'Súhlas bol potvrdený. Prihlasovacie kódy sa však nepodarilo odoslať e-mailom '
        '(počet detských účtov: {count}). Nižšie si nechajte poslať odkaz na správu '
        'súhlasu — tam kódy vygenerujete znova.',
    'consentManageTitle': 'Správa súhlasu',
    'consentManageChildren': 'Účty detí',
    'consentManageNewCode': 'Nový kód',
    'consentManageNewCodeHint':
        'Zapíšte si ho — znova ho už nezobrazíme. Starý kód prestal platiť.',
    'consentManageRevoke': 'Odvolať súhlas',
    'consentManageRevokeConfirm':
        'Naozaj odvolať? Účty sa okamžite zablokujú a dáta zmažeme do 30 dní.',
    'consentManageRevoked': 'Súhlas bol odvolaný.',
    'consentManageRevokedDetail': 'Účty sú zablokované. Dáta zmažeme do 30 dní.',
    'consentManageExpired': 'Odkaz vypršal. Nechajte si poslať nový.',
    'consentManageResend': 'Poslať odkaz znova',
    'consentManageResendSent': 'Ak e-mail poznáme, odkaz je na ceste.',
    'consentManageLoadError':
        'Nepodarilo sa načítať — skontrolujte pripojenie na internet a skúste to znova.',
    'consentManageRetry': 'Skúsiť znova',
    'minorNameLocked': 'Prezývku pri detskom účte nie je možné meniť.',
    'doplnkyTitle': 'Doplnky',
    'doplnkySubtitle': 'Minihry, úprava avatara a motívy aplikácie na jednom mieste.',
    'doplnkyAvatarTitle': 'Editor avatara',
    'doplnkyAvatarPerex': 'Obleč si svojho maskota — vyber mu čiapku, okuliare a ďalšie doplnky.',
    'doplnkyThemeTitle': 'Editor motívov',
    'doplnkyThemePerex': 'Zmeň si farby aplikácie — vyber si z pripravených motívov, alebo si vytvor vlastný.',
    'doplnkyOpen': 'Otvoriť',
    'miniGamesTitle': 'Minihry',
    'miniGamesSubtitle': 'Hraj hry a získavaj odmeny!',
    'miniGamesEmpty': 'Zatiaľ žiadne minihry',
    'miniGamesError': 'Nepodarilo sa načítať minihry',
    'miniGamesRetry': 'Skúsiť znova',
    'miniGamesPlay': 'Hrať',
    'miniGamesComingSoon': 'Hru pripravujeme',
    'miniGamesOffline': 'Potrebuješ pripojenie',
    'miniGamesSensorGyroscope': 'Gyroskop',
    'miniGamesLocked': 'Hra teraz nie je dostupná',
    'miniGamesStartFailed': 'Hru sa nepodarilo spustiť',
    'gameTapToStart': 'Spustiť hru',
    'gameReadyHeadline': 'Vyskáč sa čo najvyššie!',
    'gameRuleClimb': 'Skáčeš sám — ty len riadiš, kam dopadneš',
    'gameRuleCoin': 'Zbieraj Edux mince za body',
    'gameRuleBoost': 'Hviezda ťa vystrelí raketou nahor',
    'gameRuleFall': 'Spadneš dole = koniec',
    'gameHintTilt': 'Nakláňaj zariadenie do strán',
    'gameHintKeys': 'Ovládaj šípkami ← →',
    'gameHintButtons': 'Ovládaj šípkami ← → dole na obrazovke',
    'gameSteerLeft': 'Doľava',
    'gameSteerRight': 'Doprava',
    'gameScore': 'Skóre',
    'gameOver': 'Koniec hry',
    'gameCoinsCollected': 'Mince',
    'gameBack': 'Späť na hry',
    'gamePaused': 'Pauza',
    'gameResume': 'Pokračovať',
    'gameQuit': 'Ukončiť hru',
    'gameQuitConfirm': 'Ukončiť hru? Pokus sa ti nevráti.',
    'gameExit': 'Zavrieť hru',
    'authFormHeadline': 'Prihlásiť sa',
    'authHeroTaglineExpanded': 'Škola vo vrecku!',
    'profileSetupSubtitle': 'Všetky úpravy môžeš neskôr zmeniť v nastaveniach profilu',
    'profileSetupColorLabel': 'Farebný profil',
    'profileSetupVibeTitle': 'Vyber si svoj vibe!',
    'profileSetupVibeSubtitle':
        'Vyber si vzhľad svojho avatara. Ďalšie doplnky získaš za svoju aktivitu.',
    'profileSetupVibeNone': 'Bez doplnku',
    'libraryCodeButton': 'Zadať kód kurzu',
    'libraryLoggedOnlyTitle': 'Kurz len pre prihlásených',
    'libraryLoggedOnlyBody':
        'Tento kurz je dostupný len prihláseným používateľom. Prihlás sa a hneď '
            'sa ti otvorí — o svoj doterajší postup neprídeš.',
    'libraryLoggedOnlyAction': 'Prihlásiť sa',
    'libraryLinkOpenFailed': 'Odkaz sa nepodarilo otvoriť',
    'lessonIncorrect': 'Zatiaľ nie',
    'themeFire': 'Hrejivý motív vo farbách ohňa',
    'themeLight': 'Vzdušný svetlý motív',
    'themeNeutral': 'Pokojný motív v sivých tónoch',
    'chatyPickConversation': 'Vyber konverzáciu vľavo, alebo založ novú.',
    'stepAiFeedback': 'Hodnotené AI',
    'openFeedbackTitle': 'Spätná väzba',
    'openFeedbackStrengths': 'Čo sa podarilo',
    'openFeedbackImprovements': 'Čo zlepšiť',
    'openFeedbackNextStep': 'Čo ďalej',
    'openFeedbackSolution': 'Vzorová odpoveď',
    'openFeedbackEvaluating': 'Premýšľam nad tvojou odpoveďou...',
    'openFeedbackQuizPending': 'Odpoveď je odoslaná. Spätnú väzbu uvidíš na konci kvízu.',
    'openFeedbackFailed': 'Spätnú väzbu sa teraz nepodarilo pripraviť. Tvoja odpoveď je uložená — skús to prosím znova.',
    'openFeedbackNotEvaluable': 'K tejto otázke ti spätnú väzbu pripraviť nedokážem. Tvoja odpoveď je uložená a učiteľ ju uvidí — pokojne pokračuj ďalej.',
    'openFeedbackOffline': 'Teraz nie si pripojený, takže spätná väzba musí počkať. Odpoveď máš uloženú.',
    'openFeedbackRetry': 'Skúsiť znova',
    'openFeedbackRework': 'Upraviť odpoveď',
    'openAnswerEmpty': 'Napíš prosím aspoň krátku odpoveď vlastnými slovami, alebo prilož fotku riešenia.',
    'openPhotoAdd': 'Priložiť fotku',
    'openPhotoCamera': 'Odfotiť',
    'openPhotoGallery': 'Vybrať z galérie',
    'openPhotoRemove': 'Odobrať fotku',
    'openPhotoAttached': 'Fotka je priložená',
    'openPhotoUploading': 'Nahrávam fotku...',
    'openPhotoUploadFailed': 'Fotku sa nepodarilo nahrať. Skús to prosím znova.',
    'openPhotoUnreadable': 'Z fotky sa mi riešenie nepodarilo prečítať. Skús ju odfotiť znova, alebo odpovedz textom.',
    'openPhotoTooLarge': 'Fotka je príliš veľká. Skús ju odfotiť znova.',
    'statStreakSubtitle': 'Skvelá práca!\nPokračuj v učení.',
    'statTrophiesSubtitle': 'Zbieraj trofeje a odomykaj\nnové odmeny.',
    'sectionMyCourses': 'Moje kurzy',
    'sectionShowAllCourses': 'Zobraziť všetky',
    'shopTitle': 'Obchod',
    'shopPermanentItems': 'Trvalé predmety',
    'shopSlotHead': 'Hlava',
    'shopSlotEyes': 'Oči',
    'shopSlotMouth': 'Ústa',
    'shopSlotArms': 'Ruky',
    'shopSlotLegs': 'Nohy',
    'shopSlotTorso': 'Trup',
    'shopSlotFace': 'Tvár',
    'shopSlotNeck': 'Krk',
    'shopSlotHeld': 'V ruke',
    'shopEquipped': 'Nasadené',
    'shopEquip': 'Nasadiť',
    'shopUnequip': 'Zložiť',
    'shopGetFree': 'Získať zadarmo',
    'shopPurchaseFailed': 'Predmet sa nepodarilo získať. Skontroluj pripojenie.',
    'shopOfflineNotice': 'Bez pripojenia — ukazujeme uloženú ponuku.',
    'shopLoadFailed': 'Obchod sa nepodarilo načítať.',
    'shopEmptySlot': 'Zatiaľ tu nič nie je.',
    'shopRetry': 'Skúsiť znova',
  };
}
