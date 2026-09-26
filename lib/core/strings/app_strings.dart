import 'locale_manager.dart';

/// Centralized user-facing strings for the EDU AI app.
///
/// Values are resolved at runtime against [LocaleManager.current], so the
/// entire UI follows the active locale. To change wording, edit the [_cz]
/// and [_en] maps below. Technical strings (API keys, route names, debug
/// logs) are NOT included here.
///
/// **Important:** these are non-const getters. You cannot use
/// `const Text(AppStrings.x)` — drop the `const` keyword. The static
/// function entries (e.g. [genericError]) interpolate against the active
/// locale at call time.
class AppStrings {
  AppStrings._();

  // ── Internal lookup ───────────────────────────────────────────────────

  static String _t(String key) {
    final cz = _cz[key];
    final en = _en[key];
    switch (LocaleManager.current) {
      case AppLocale.cs:
        return cz ?? en ?? key;
      case AppLocale.en:
        return en ?? cz ?? key;
    }
  }

  // ── Navigation ──
  static String get navPrehled => _t('navPrehled');
  static String get navChat => _t('navChat');
  static String get navKurzy => _t('navKurzy');
  static String get navNovinky => _t('navNovinky');

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
  static String get practiceTitle => _t('practiceTitle');
  static String get practiceStart => _t('practiceStart');
  static String get practiceEmpty => _t('practiceEmpty');
  static String get practiceDashSubtitle => _t('practiceDashSubtitle');
  static String get promoBadge => _t('promoBadge');
  static String get promoTitle => _t('promoTitle');
  static String get promoDescription => _t('promoDescription');
  static String get sectionQuickQuizzes => _t('sectionQuickQuizzes');
  static String get sectionContinue => _t('sectionContinue');
  static String get defaultUserName => _t('defaultUserName');

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
  static String get authHeadline => _t('authHeadline');
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
  static String get authEmptyEmailError => _t('authEmptyEmailError');
  static String get authInvalidEmailError => _t('authInvalidEmailError');
  static String codeNotFound(String pin) =>
      LocaleManager.current == AppLocale.en
          ? 'Code "$pin" was not found'
          : 'Kód "$pin" nebyl nalezen';
  static String get authUserCreateError => _t('authUserCreateError');
  static String get authCourseLoadError => _t('authCourseLoadError');
  static String get authCourseDownloadError => _t('authCourseDownloadError');
  static String get authKeepLoggedInLabel => _t('authKeepLoggedInLabel');

  // ── Profile ──
  static String get profileTitle => _t('profileTitle');
  static String get profileSectionAccount => _t('profileSectionAccount');
  static String get profileEditProfile => _t('profileEditProfile');
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
  static String get profileSetupNameLabel => _t('profileSetupNameLabel');
  static String get profileSetupNameHint => _t('profileSetupNameHint');
  static String get profileSetupAvatarLabel => _t('profileSetupAvatarLabel');
  static String get profileSetupSubjectsLabel => _t('profileSetupSubjectsLabel');
  static String get profileSetupNameError => _t('profileSetupNameError');
  static String get profileSetupSyncWarning => _t('profileSetupSyncWarning');
  static String profileSetupSaveError(String error) =>
      LocaleManager.current == AppLocale.en
          ? 'Error while saving: $error'
          : 'Chyba při ukládání: $error';

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
  static String get libraryCodeShort => _t('libraryCodeShort');
  static String libraryCodeNotFound(String code) =>
      LocaleManager.current == AppLocale.en
          ? 'Course with code "$code" was not found'
          : 'Kurz s kódem "$code" nebyl nalezen';
  static String get libraryLoginRequired => _t('libraryLoginRequired');
  static String get libraryLoadError => _t('libraryLoadError');
  static String get librarySearchingCourse => _t('librarySearchingCourse');
  static String get libraryEmptyTitle => _t('libraryEmptyTitle');
  static String get libraryEmptySubtitle => _t('libraryEmptySubtitle');
  static String get libraryCoursesLoadError => _t('libraryCoursesLoadError');
  static String get libraryCourseAlreadyCompleted => _t('libraryCourseAlreadyCompleted');
  static String libraryCourseDownloadFailed(String name) =>
      LocaleManager.current == AppLocale.en
          ? 'Failed to download course "$name". Please try again.'
          : 'Kurz "$name" se nepodařilo stáhnout. Zkuste to znovu.';
  static String libraryCourseAdded(String name) =>
      LocaleManager.current == AppLocale.en
          ? 'Course "$name" added to your library'
          : 'Kurz "$name" přidán do tvé knihovny';
  static String libraryCourseDownloadError(String error) =>
      LocaleManager.current == AppLocale.en
          ? 'Failed to download course: $error'
          : 'Nepodařilo se stáhnout kurz: $error';
  static String libraryCourseUpdated(String name) =>
      LocaleManager.current == AppLocale.en
          ? 'Course "$name" has been updated'
          : 'Kurz "$name" byl aktualizován';
  static String libraryCourseUpdateError(String error) =>
      LocaleManager.current == AppLocale.en
          ? 'Failed to update course: $error'
          : 'Nepodařilo se aktualizovat kurz: $error';
  static String get libraryUpdating => _t('libraryUpdating');
  static String get libraryDownloading => _t('libraryDownloading');
  static String get libraryUpdate => _t('libraryUpdate');
  static String get libraryLaunch => _t('libraryLaunch');
  static String get libraryDownload => _t('libraryDownload');
  static String lessonsCount(int count) =>
      LocaleManager.current == AppLocale.en
          ? '$count lessons'
          : '$count lekcí';
  static String practiceDueCount(int count) =>
      LocaleManager.current == AppLocale.en
          ? '$count cards to review'
          : '$count karet k procvičení';
  static String durationHours(int hours) =>
      LocaleManager.current == AppLocale.en
          ? '${hours}h'
          : '$hours hod';
  /// Smart duration: "45 min", "1 h", "1 h 20 min"
  static String durationSmart(int totalMinutes) {
    final isEn = LocaleManager.current == AppLocale.en;
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return isEn ? '${hours}h' : '$hours hod';
    return isEn ? '${hours}h $mins min' : '$hours hod $mins min';
  }

  // ── Course Detail ──
  static String get courseProgress => _t('courseProgress');
  static String get courseDescription => _t('courseDescription');
  static String get courseLessons => _t('courseLessons');
  static String get courseShowMore => _t('courseShowMore');
  static String get courseShowLess => _t('courseShowLess');
  static String courseShowMoreCount(int count) =>
      LocaleManager.current == AppLocale.en
          ? 'Show more ($count)'
          : 'Zobrazit další ($count)';
  static String get courseQuizzes => _t('courseQuizzes');
  static String get courseShowAll => _t('courseShowAll');
  static String get courseContinueLesson => _t('courseContinueLesson');
  static String get courseExercise => _t('courseExercise');
  static String get courseQuiz => _t('courseQuiz');
  static String get courseCompleted => _t('courseCompleted');
  static String get courseCurrent => _t('courseCurrent');
  static String courseQuestionsCount(int count) =>
      LocaleManager.current == AppLocale.en
          ? '$count questions'
          : '$count otázek';
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
  static String lessonTitle(int index, String title) =>
      LocaleManager.current == AppLocale.en
          ? 'Lesson $index: $title'
          : 'Lekce $index: $title';
  static String get lessonEmptyTitle => _t('lessonEmptyTitle');
  static String get lessonEmptyMessage => _t('lessonEmptyMessage');
  static String get lessonFinishCourse => _t('lessonFinishCourse');
  static String get lessonNextLesson => _t('lessonNextLesson');
  static String get lessonBackToDetail => _t('lessonBackToDetail');
  static String get lessonCourseCompleted => _t('lessonCourseCompleted');
  static String get lessonSelectAnswerFirst => _t('lessonSelectAnswerFirst');
  static String get lessonExplanation => _t('lessonExplanation');
  static String lessonDetailedExplanation(String title) =>
      LocaleManager.current == AppLocale.en
          ? 'More detailed explanation: $title'
          : 'Podrobnější vysvětlení: $title';
  static String lessonExplanationTitle(String title) =>
      LocaleManager.current == AppLocale.en
          ? 'Explanation: $title'
          : 'Vysvětlení: $title';
  static String get lessonFeedbackClear => _t('lessonFeedbackClear');
  static String get lessonFeedbackPractice => _t('lessonFeedbackPractice');
  static String get lessonFeedbackPracticeAdded => _t('lessonFeedbackPracticeAdded');
  static String get lessonFeedbackConfused => _t('lessonFeedbackConfused');
  static String get lessonFeedbackClarify => _t('lessonFeedbackClarify');
  static String get lessonFeedbackHint => _t('lessonFeedbackHint');
  static String lessonFeedbackCharCount(int count) =>
      LocaleManager.current == AppLocale.en
          ? '$count/500 characters'
          : '$count/500 znaků';
  static String get lessonFeedbackThanks => _t('lessonFeedbackThanks');
  static String get lessonFeedbackSend => _t('lessonFeedbackSend');
  static String get lessonVideoError => _t('lessonVideoError');
  static String get lessonWriteAnswer => _t('lessonWriteAnswer');
  static String get lessonCheckAnswer => _t('lessonCheckAnswer');
  static String get lessonCorrect => _t('lessonCorrect');
  static String lessonCorrectAnswer(String answer) =>
      LocaleManager.current == AppLocale.en
          ? 'Correct answer: $answer'
          : 'Správná odpověď: $answer';
  static String get lessonQuestionLabel => _t('lessonQuestionLabel');

  // ── Quiz ──
  static String get quizTitle => _t('quizTitle');
  static String get quizExerciseTitle => _t('quizExerciseTitle');
  static String quizCardProgress(int current, int total) =>
      LocaleManager.current == AppLocale.en
          ? 'Card $current of $total'
          : 'Karta $current z $total';
  static String quizCorrectCount(int correct, int total) =>
      LocaleManager.current == AppLocale.en
          ? '$correct/$total correct'
          : '$correct/$total správně';
  static String get quizCompleted => _t('quizCompleted');
  static String get quizReviewCompleted => _t('quizReviewCompleted');
  static String quizCorrectResult(int correct, int total) =>
      LocaleManager.current == AppLocale.en
          ? '$correct of $total correct'
          : '$correct z $total správně';
  static String quizCardsReviewed(int total) =>
      LocaleManager.current == AppLocale.en
          ? 'You went through $total cards'
          : 'Prošel jsi $total karet';
  static String practiceSummarySuccess(int percent) =>
      LocaleManager.current == AppLocale.en
          ? 'Success rate $percent%'
          : 'Úspěšnost $percent %';
  static String practiceSummaryXp(int xp) =>
      LocaleManager.current == AppLocale.en
          ? '+$xp XP earned'
          : '+$xp XP získáno';
  static String get practiceCompleted => LocaleManager.current == AppLocale.en
      ? 'Practice complete!'
      : 'Procvičování dokončeno!';
  static String get practiceRatePrompt => LocaleManager.current == AppLocale.en
      ? 'How well do you remember this?'
      : 'Jak dobře si to pamatuješ?';
  static String get practiceRateAgain =>
      LocaleManager.current == AppLocale.en ? "Don't know" : 'Nevím';
  static String get practiceRateHard =>
      LocaleManager.current == AppLocale.en ? 'Remind me' : 'Připomeň';
  static String get practiceRateGood =>
      LocaleManager.current == AppLocale.en ? 'Okay' : 'Jde to';
  static String get practiceRateEasy =>
      LocaleManager.current == AppLocale.en ? 'I remember' : 'Pamatuji';
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
  static String quizCorrectAnswer(String answer) =>
      LocaleManager.current == AppLocale.en
          ? 'Correct answer: $answer'
          : 'Správná odpověď: $answer';
  static String get quizCorrectLabel => _t('quizCorrectLabel');
  static String get quizIncorrectLabel => _t('quizIncorrectLabel');
  static String get quizAskAi => _t('quizAskAi');
  static String get quizAnswersSaved => _t('quizAnswersSaved');

  // ── Chat-context prompts (shared by quiz + lesson detail) ──
  static String chatContextQuestionWithOptions(String text) =>
      LocaleManager.current == AppLocale.en
          ? 'Question with options:\n$text'
          : 'Otázka s možnostmi:\n$text';
  static String chatContextHelpIntro(String courseName) =>
      LocaleManager.current == AppLocale.en
          ? 'I need help with a task from the course "$courseName".'
          : 'Potřebuji pomoct s úlohou z kurzu "$courseName".';
  static String chatContextHelpIntroLesson(String courseName, String lessonName) =>
      LocaleManager.current == AppLocale.en
          ? 'I need help with a task from the course "$courseName", lesson "$lessonName".'
          : 'Potřebuji pomoct s úlohou z kurzu "$courseName", lekce "$lessonName".';
  static String chatContextHelpTaskContent(String text) =>
      LocaleManager.current == AppLocale.en
          ? 'Task content: $text'
          : 'Obsah úlohy: $text';
  static String chatContextHelpHint(String hint) =>
      LocaleManager.current == AppLocale.en
          ? 'The hint says: $hint'
          : 'Nápověda říká: $hint';
  static String chatContextHelpDetail(String help) =>
      LocaleManager.current == AppLocale.en
          ? 'More detailed explanation: $help'
          : 'Podrobnější vysvětlení: $help';
  static String chatContextStudentQuery(String msg) =>
      LocaleManager.current == AppLocale.en
          ? 'My question: $msg'
          : 'Můj dotaz: $msg';
  static String get chatContextFallbackPrompt => _t('chatContextFallbackPrompt');

  // ── Exercise ──
  static String get exerciseSelectCorrect => _t('exerciseSelectCorrect');
  static String get exerciseSelectAll => _t('exerciseSelectAll');
  static String get exerciseWriteAnswer => _t('exerciseWriteAnswer');
  static String get exerciseAnswerHint => _t('exerciseAnswerHint');
  static String exerciseCharCount(int count) =>
      LocaleManager.current == AppLocale.en
          ? '$count/500 characters'
          : '$count/500 znaků';
  static String get exerciseCorrect => _t('exerciseCorrect');
  static String get exerciseIncorrect => _t('exerciseIncorrect');
  static String exerciseCorrectAnswer(String answer) =>
      LocaleManager.current == AppLocale.en
          ? 'Correct answer is: $answer'
          : 'Správná odpověď je: $answer';
  static String get exerciseExplanationLabel => _t('exerciseExplanationLabel');

  // ── Achievements ──
  static String get achievementsTitle => _t('achievementsTitle');
  static String achievementsXpRemaining(int xp, int nextLevel) =>
      LocaleManager.current == AppLocale.en
          ? '$xp XP to lvl $nextLevel'
          : 'Zbývá $xp XP do lvl $nextLevel';
  static String achievementsDaysCount(int days) {
    if (LocaleManager.current == AppLocale.en) {
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
    return '$days ${days == 1 ? 'den' : 'dní'}';
  }
  static String get achievementsTrophies => _t('achievementsTrophies');
  static String get achievementsEarnedTrophies => _t('achievementsEarnedTrophies');
  static String get achievementsChallenges => _t('achievementsChallenges');
  static String get achievementsSkills => _t('achievementsSkills');
  static String get achievementsSkillsPlaceholder => _t('achievementsSkillsPlaceholder');

  // Skill tab filters
  static String get skillTabAll => _t('skillTabAll');
  static String get skillTabBeginner => _t('skillTabBeginner');
  static String get skillTabIntermediate => _t('skillTabIntermediate');
  static String get skillTabExpert => _t('skillTabExpert');
  static String skillLevel(double level) =>
      LocaleManager.current == AppLocale.en
          ? 'Level: ${level.toStringAsFixed(1)}'
          : 'Úroveň: ${level.toStringAsFixed(1)}';
  static String skillConfidence(int low, int high) =>
      LocaleManager.current == AppLocale.en
          ? 'Confidence interval: $low–$high'
          : 'Interval jistoty: $low–$high';
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
  static String timeDaysAgo(int days) =>
      LocaleManager.current == AppLocale.en
          ? '$days days ago'
          : 'Před $days dny';
  static String timeHoursAgo(int hours) =>
      LocaleManager.current == AppLocale.en
          ? '${hours}h ago'
          : 'Před $hours hod';
  static String timeMinutesAgo(int minutes) =>
      LocaleManager.current == AppLocale.en
          ? '$minutes min ago'
          : 'Před $minutes min';
  static String get timeJustNow => _t('timeJustNow');
  static String timeDaysAgoShort(int days) =>
      LocaleManager.current == AppLocale.en
          ? '${days}d ago'
          : 'před ${days} d';

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
  static String aboutSyncQueueCleared(int count) =>
      LocaleManager.current == AppLocale.en
          ? 'Cleared $count items from sync queue'
          : 'Smazáno $count položek ze sync fronty';
  static String get aboutSyncCompleted => _t('aboutSyncCompleted');
  static String aboutSyncErrorMsg(String error) =>
      LocaleManager.current == AppLocale.en
          ? 'Sync error: $error'
          : 'Chyba synchronizace: $error';
  static String get aboutClearTokenTitle => _t('aboutClearTokenTitle');
  static String get aboutClearTokenMessage => _t('aboutClearTokenMessage');
  static String get aboutTokenCleared => _t('aboutTokenCleared');
  static String get aboutClearCoursesTitle => _t('aboutClearCoursesTitle');
  static String get aboutClearCoursesMessage => _t('aboutClearCoursesMessage');
  static String aboutCoursesCleared(int count) =>
      LocaleManager.current == AppLocale.en
          ? 'Cleared $count courses from library'
          : 'Smazáno $count kurzů z knihovny';
  static String get aboutNoUser => _t('aboutNoUser');
  static String get aboutFactoryResetTitle => _t('aboutFactoryResetTitle');
  static String get aboutFactoryResetMessage => _t('aboutFactoryResetMessage');
  static String get aboutDeleteAll => _t('aboutDeleteAll');
  static String aboutTimeJustNow() => _t('aboutTimeJustNow');
  static String aboutTimeSoon() => _t('aboutTimeSoon');
  static String aboutTimeMinutesAgo(int min, String time) =>
      LocaleManager.current == AppLocale.en
          ? '$min min ago ($time)'
          : 'před $min min ($time)';
  static String aboutTimeInMinutes(int min, String time) =>
      LocaleManager.current == AppLocale.en
          ? 'in $min min ($time)'
          : 'za $min min ($time)';
  static String aboutTimeToday(String time) =>
      LocaleManager.current == AppLocale.en
          ? 'today $time'
          : 'dnes $time';

  // ── Theme Selector ──
  static String get themeTitle => _t('themeTitle');
  static String get themeDefault => _t('themeDefault');
  static String get themeOcean => _t('themeOcean');
  static String get themeSunset => _t('themeSunset');
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
  static String courseQuizPrefix(String title) =>
      LocaleManager.current == AppLocale.en
          ? 'QUIZ: $title'
          : 'KVÍZ: $title';

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
  static String get chatEmptyState => _t('chatEmptyState');
  static String get chatRequiresInternet => _t('chatRequiresInternet');
  static String get chatStreamError => _t('chatStreamError');
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
  static String stepCorrectAnswer(String answer) =>
      LocaleManager.current == AppLocale.en
          ? 'Correct answer: $answer'
          : 'Správná odpověď: $answer';
  static String get stepExplanation => _t('stepExplanation');
  static String get stepAudioError => _t('stepAudioError');
  static String get stepNumericHint => _t('stepNumericHint');
  static String stepTolerance(String value) =>
      LocaleManager.current == AppLocale.en
          ? 'Tolerance: ± $value'
          : 'Tolerance: ± $value';
  static String stepCorrectNumber(String value) =>
      LocaleManager.current == AppLocale.en
          ? 'Correct answer: $value'
          : 'Správná odpověď: $value';
  static String get stepVideoError => _t('stepVideoError');

  // ── Widgets: Block Step Engine ──
  static String get engineCheck => _t('engineCheck');
  static String get engineNext => _t('engineNext');
  static String get engineContinue => _t('engineContinue');
  static String get engineSelectAnswer => _t('engineSelectAnswer');
  static String get engineEnterAnswer => _t('engineEnterAnswer');
  static String get engineTryAgain => _t('engineTryAgain');

  // ── Widgets: Stat Card ──
  static String get statStreak => _t('statStreak');
  static String get statDays => _t('statDays');
  static String statDaysPlural(int days) {
    if (LocaleManager.current == AppLocale.en) {
      return days == 1 ? 'day' : 'days';
    }
    return days == 1 ? 'den' : 'dní';
  }
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
  static String aboutDebugReportError(String e) =>
      LocaleManager.current == AppLocale.en
          ? 'Failed to send report: $e'
          : 'Nepodařilo se odeslat report: $e';

  // ── Errors ──
  static String genericError(String error) =>
      LocaleManager.current == AppLocale.en
          ? 'Error: $error'
          : 'Chyba: $error';

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
  static String lessonFallbackName(int oneBasedIndex) =>
      LocaleManager.current == AppLocale.en
          ? 'Lesson $oneBasedIndex'
          : 'Lekce $oneBasedIndex';

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
  static String sharedDeviceBannerCountdown(String time) =>
      LocaleManager.current == AppLocale.en
          ? 'Shared device — sign-out in $time'
          : 'Sdílené zařízení — odhlášení za $time';
  static String get sharedDeviceDialogTitle => _t('sharedDeviceDialogTitle');
  static String get sharedDeviceDialogMessage => _t('sharedDeviceDialogMessage');
  static String get sharedDeviceDialogKeepLoggedIn => _t('sharedDeviceDialogKeepLoggedIn');
  static String get sharedDeviceConvertError => _t('sharedDeviceConvertError');

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
    'practiceTitle': 'Procvičování',
    'practiceStart': 'Začít procvičování',
    'practiceEmpty': 'Teď nemáš nic k procvičení. Vrať se později!',
    'practiceDashSubtitle': 'Zopakuj si, co tě čeká dnes',
    'promoBadge': 'KNIHOVNA',
    'promoTitle': 'Prozkoumej kurzy!',
    'promoDescription': 'V knihovně najdeš kurzy,\nkteré máš nyní k dispozici',
    'sectionQuickQuizzes': 'Rychlé kvízy',
    'sectionContinue': 'Pokračovat',
    'defaultUserName': 'Uživatel',
    'chatTitle': 'Chat',
    'chatLockedMessage': 'Chat se vám otevře po získání vyšší úrovně',
    'addTitle': 'Připojit / Přidat',
    'contentComingSoon': 'Tento obsah teprve připravujeme',
    'novinkyTitle': 'Novinky',
    'novinkyEmpty': 'Zatím žádné novinky',
    'novinkyError': 'Nepodařilo se načíst novinky',
    'novinkyLoading': 'Načítání novinek…',
    'novinkyRetry': 'Zkusit znovu',
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
    'authEmptyEmailError': 'Zadej prosím e-mailovou adresu',
    'authInvalidEmailError': 'Zadej platnou e-mailovou adresu',
    'authUserCreateError': 'Nepodařilo se vytvořit uživatele',
    'authCourseLoadError': 'Kurz se nepodařilo načíst',
    'authCourseDownloadError': 'Kurz se nepodařilo stáhnout. Zkontroluj připojení a zkus to znovu.',
    'authKeepLoggedInLabel': 'Zůstat trvale přihlášen — nejedná se o sdílené zařízení',
    'profileTitle': 'Můj účet',
    'profileSectionAccount': 'Účet',
    'profileEditProfile': 'Upravit profil',
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
    'profileSetupTitle': 'Vytvoř svůj profil',
    'profileSetupNameLabel': 'Jak se jmenuješ?',
    'profileSetupNameHint': 'Tvoje jméno',
    'profileSetupAvatarLabel': 'Vyber si avatara',
    'profileSetupSubjectsLabel': 'Vyber si prostředí',
    'profileSetupNameError': 'Zadej prosím své jméno',
    'profileSetupSyncWarning': 'Profil uložen lokálně. Synchronizace proběhne později.',
    'editProfileTitle': 'Upravit profil',
    'editProfileNameLabel': 'Jméno',
    'editProfileEmailLabel': 'E-mail',
    'editProfileNameHint': 'Zadejte jméno',
    'editProfileEmailReadonly': 'E-mail nelze změnit',
    'editProfileEmptyNameError': 'Jméno nemůže být prázdné',
    'editProfileSaveError': 'Nepodařilo se uložit změny',
    'editProfileSaveButton': 'Uložit změny',
    'libraryTitle': 'Knihovna',
    'librarySubtitle': 'Vyber si kurzy a stáhni si je',
    'libraryCodeTitle': 'Máš kód kurzu?',
    'libraryCodeShort': 'Zadej 6místný kód',
    'libraryLoginRequired': 'Pro stažení kurzu se musíš přihlásit',
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
    'lessonFeedbackConfused': 'Nerozumím tomu',
    'lessonFeedbackClarify': 'Upřesni svůj dotaz',
    'lessonFeedbackHint': 'Napiš více o problému...',
    'lessonFeedbackThanks': 'Děkujeme za zpětnou vazbu!',
    'lessonFeedbackSend': 'Odeslat',
    'lessonVideoError': 'Nepodařilo se načíst video',
    'lessonWriteAnswer': 'Napiš odpověď...',
    'lessonCheckAnswer': 'Zkontrolovat',
    'lessonCorrect': 'Správně!',
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
    'exerciseExplanationLabel': 'Vysvětlení:',
    'achievementsTitle': 'Úspěchy',
    'achievementsTrophies': 'Trofeje',
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
    'bannerGuestMessage': 'Pro plný přístup se registrujte',
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
    'chatEmptyState': 'Zatím žádné konverzace.\nZačni chatovat!',
    'chatRequiresInternet': 'Chat vyžaduje připojení k internetu',
    'chatStreamError': 'Chyba při generování odpovědi',
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
    'stepAudioError': 'Nepodařilo se načíst audio',
    'stepNumericHint': 'Zadej číslo...',
    'stepVideoError': 'Nepodařilo se načíst video',
    'engineCheck': 'Zkontrolovat',
    'engineNext': 'Další',
    'engineContinue': 'Pokračovat',
    'engineSelectAnswer': 'Nejprve vyber odpověď',
    'engineEnterAnswer': 'Nejprve napiš odpověď',
    'engineTryAgain': 'Zkusit znovu',
    'statStreak': 'Streak',
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
    'personaAiTeacherName': 'AI asistent učitele',
    'personaAiTeacherSubtitle': 'Obecný vzdělávací asistent',
    'personaAiTeacherDesc': 'Pomáhá se všemi předměty',
    'personaMathMentorName': 'Mentor kurzu',
    'personaMathMentorSubtitle': 'Specialista na matematiku',
    'personaMathMentorDesc': 'Řeší příklady krok za krokem, používá matematické zápisy',
    'personaStudyCoachName': 'Studijní kouč',
    'personaStudyCoachSubtitle': 'Pomáhá s technikami učení',
    'personaStudyCoachDesc': 'Plánování, motivace, jak se učit efektivně',
    'personaLanguageMentorName': 'Poradce k přijímačkám',
    'personaLanguageMentorSubtitle': 'Zodpovídá dotazy k JPZ',
    'personaLanguageMentorDesc': 'Odpovědi z FAQ',
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
    'practiceTitle': 'Practice',
    'practiceStart': 'Start practice',
    'practiceEmpty': "Nothing to review right now. Check back later!",
    'practiceDashSubtitle': "Review what's due today",
    'promoBadge': 'LIBRARY',
    'promoTitle': 'Explore courses!',
    'promoDescription': 'Find courses in the library\nthat are available to you now',
    'sectionQuickQuizzes': 'Quick quizzes',
    'sectionContinue': 'Continue',
    'defaultUserName': 'User',
    'chatTitle': 'Chat',
    'chatLockedMessage': 'Chat will open after you reach a higher level',
    'addTitle': 'Connect / Add',
    'contentComingSoon': 'This content is still in preparation',
    'novinkyTitle': 'News',
    'novinkyEmpty': 'No news yet',
    'novinkyError': 'Could not load news',
    'novinkyLoading': 'Loading news…',
    'novinkyRetry': 'Try again',
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
    'authEmptyEmailError': 'Please enter an email address',
    'authInvalidEmailError': 'Please enter a valid email address',
    'authUserCreateError': 'Failed to create user',
    'authCourseLoadError': 'Failed to load course',
    'authCourseDownloadError': 'Failed to download the course. Check your connection and try again.',
    'authKeepLoggedInLabel': 'Stay logged in permanently — this is not a shared device',
    'profileTitle': 'My account',
    'profileSectionAccount': 'Account',
    'profileEditProfile': 'Edit profile',
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
    'profileSetupTitle': 'Create your profile',
    'profileSetupNameLabel': "What's your name?",
    'profileSetupNameHint': 'Your name',
    'profileSetupAvatarLabel': 'Pick an avatar',
    'profileSetupSubjectsLabel': 'Pick a focus area',
    'profileSetupNameError': 'Please enter your name',
    'profileSetupSyncWarning': 'Profile saved locally. Sync will run later.',
    'editProfileTitle': 'Edit profile',
    'editProfileNameLabel': 'Name',
    'editProfileEmailLabel': 'Email',
    'editProfileNameHint': 'Enter name',
    'editProfileEmailReadonly': 'Email cannot be changed',
    'editProfileEmptyNameError': 'Name cannot be empty',
    'editProfileSaveError': 'Failed to save changes',
    'editProfileSaveButton': 'Save changes',
    'libraryTitle': 'Library',
    'librarySubtitle': 'Pick courses and download them',
    'libraryCodeTitle': 'Have a course code?',
    'libraryCodeShort': 'Enter 6-digit code',
    'libraryLoginRequired': 'You need to log in to download a course',
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
    'lessonFeedbackConfused': "I don't understand",
    'lessonFeedbackClarify': 'Refine your question',
    'lessonFeedbackHint': 'Write more about the problem...',
    'lessonFeedbackThanks': 'Thanks for your feedback!',
    'lessonFeedbackSend': 'Send',
    'lessonVideoError': 'Failed to load video',
    'lessonWriteAnswer': 'Write an answer...',
    'lessonCheckAnswer': 'Check',
    'lessonCorrect': 'Correct!',
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
    'exerciseExplanationLabel': 'Explanation:',
    'achievementsTitle': 'Achievements',
    'achievementsTrophies': 'Trophies',
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
    'bannerGuestMessage': 'Sign up for full access',
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
    'chatEmptyState': 'No conversations yet.\nStart chatting!',
    'chatRequiresInternet': 'Chat requires an internet connection',
    'chatStreamError': 'Error generating answer',
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
    'stepAudioError': 'Failed to load audio',
    'stepNumericHint': 'Enter a number...',
    'stepVideoError': 'Failed to load video',
    'engineCheck': 'Check',
    'engineNext': 'Next',
    'engineContinue': 'Continue',
    'engineSelectAnswer': 'Pick an answer first',
    'engineEnterAnswer': 'Type an answer first',
    'engineTryAgain': 'Try again',
    'statStreak': 'Streak',
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
    'personaAiTeacherName': 'AI Teacher Assistant',
    'personaAiTeacherSubtitle': 'General educational assistant',
    'personaAiTeacherDesc': 'Helps with all subjects',
    'personaMathMentorName': 'Course Mentor',
    'personaMathMentorSubtitle': 'Math specialist',
    'personaMathMentorDesc': 'Solves problems step by step, uses math notation',
    'personaStudyCoachName': 'Study Coach',
    'personaStudyCoachSubtitle': 'Helps with study techniques',
    'personaStudyCoachDesc': 'Planning, motivation, how to study effectively',
    'personaLanguageMentorName': 'Admissions Adviser',
    'personaLanguageMentorSubtitle': 'Answers admissions exam questions',
    'personaLanguageMentorDesc': 'FAQ-based answers',
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
    'eloInsufficientData': 'Not enough data yet to estimate this area.',
    'confidenceHigher': 'higher',
    'confidenceMedium': 'medium',
    'confidenceLower': 'lower',
    'confidenceVeryLow': 'very low',
  };
}
