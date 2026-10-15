import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/consent/minor_mode.dart';
import '../core/database/app_database.dart' show UsersTableCompanion;
import '../core/layout/breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/navigation_providers.dart';
import '../data/repositories/course_repository.dart';
import '../models/course_model.dart' as models;
import 'course_detail_page.dart';
import '../core/network/api_endpoints.dart';
import '../core/strings/app_strings.dart';
import 'package:eduai/core/util/silent_log.dart';
import 'package:eduai/core/widgets/code_input_field.dart';
import '../routing/deep_link.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/language_switcher.dart';
import '../core/oauth/oauth_sign_in_buttons.dart';
import '../data/repositories/oauth_repository.dart';
import '../features/email_validation/providers/email_validation_providers.dart';
import 'consent/age_gate_route.dart';
import 'privacy_page.dart';
import 'terms_page.dart';
import '../core/util/shell_route.dart';

/// Root of the phone / portrait-tablet (bottom-sheet) login layout. The
/// wide-window layout keys (splitPaneKey, waveKey, …) live with the shared
/// scaffold in `widgets/auth_hero_scaffold.dart`.
const Key sheetKey = Key('auth-sheet');

class AuthPage extends ConsumerStatefulWidget {
  /// Callback when user submits email - passes the entered email.
  final void Function(String email) onEmailSubmit;

  /// Callback when PIN login completes successfully (guest user created).
  ///
  /// Carries the server's verdict on whether this login still owes the
  /// sign-up onboarding (BR-YXVMKY). A course PIN always passes false — it
  /// creates a guest, and a guest came to open a course, not to fill in a
  /// profile. A student login code passes what `/api/resolve-code` said, so
  /// the student is onboarded on their first entry and never again.
  final void Function(bool profileSetupRequired)? onPinLoginComplete;

  /// Optional back button callback (shown when guest navigates here to log in).
  final VoidCallback? onBack;

  /// When true, starts directly in email/SSO mode (skips PIN screen).
  final bool startInLoginMode;

  /// Callback when OAuth sign-in completes successfully.
  final ValueChanged<OAuthExchangeResult>? onOAuthSuccess;

  /// Invoked when the age gate says the user is under the local threshold.
  /// Passes the country the gate resolved, so the consent request carries
  /// it. Null means the age gate never fires (callers that have not wired up
  /// the guardian consent flow) — an OAuth sign-in then goes straight to the
  /// credential exchange.
  final ValueChanged<String?>? onNeedsParentalConsent;

  /// Opened by a guest from inside their own session (MainScreen's "log in"),
  /// so whoever types a student code here is that guest: their progress must
  /// follow them into the account whatever the shared-device choice says
  /// (BR-35W2HV). False for the logged-out login screen.
  final bool guestUpgrade;

  const AuthPage({
    super.key,
    required this.onEmailSubmit,
    this.onPinLoginComplete,
    this.onBack,
    this.startInLoginMode = false,
    this.onOAuthSuccess,
    this.onNeedsParentalConsent,
    this.guestUpgrade = false,
  });

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> with SingleTickerProviderStateMixin {
  late bool _isSignUpMode = widget.startInLoginMode;
  bool _isLookingUpPin = false;
  String? _pinError;

  /// The e-mail form is asking the server whether the address has an account.
  bool _isCheckingEmail = false;

  /// Guards the one-shot deep-link auto-submit so it fires at most once.
  bool _deepLinkConsumed = false;

  /// Recognizers for the terms/privacy spans in the sign-up RichText.
  /// TextSpan recognizers are not widgets — they must be disposed manually.
  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = _openTerms;
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = _openPrivacy;

  /// Inverted UI state: true when user opts OUT of shared-device mode
  /// (i.e. wants to stay permanently logged in). Default false = shared.
  late bool _keepLoggedIn =
      !(ref.read(sessionMetaProvider).pendingSharedDevice);

  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  final TextEditingController _emailController = TextEditingController();

  final CodeInputController _codeController = CodeInputController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _heightAnimation = Tween<double>(begin: 0.52, end: 0.72).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    // If starting in login mode, jump animation to end state immediately
    if (widget.startInLoginMode) {
      _animationController.value = 1.0;
    }

    // A /course/:code or /pin/:code deep link opened straight onto this login
    // screen (logged-out visitor). DeepLinkEntry parked the code; pick it up
    // and resolve it through the normal guest PIN flow so the course opens
    // without the user re-typing the code they already clicked.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeConsumeDeepLink());
  }

  /// If a deep-link code is pending and we're on the PIN screen, prefill it and
  /// auto-submit. Clearing the provider here also stops MainScreen from opening
  /// the same course a second time after login completes.
  void _maybeConsumeDeepLink() {
    if (_deepLinkConsumed || !mounted) return;
    // Only the PIN screen can resolve a code; skip when forced into login mode.
    if (widget.startInLoginMode) return;

    final code = ref.read(pendingDeepLinkCodeProvider);
    if (code == null || code.length != 6) return;

    _deepLinkConsumed = true;
    ref.read(pendingDeepLinkCodeProvider.notifier).state = null;

    setState(() => _codeController.code = code);
    _handlePinSubmit();
  }

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsPage()),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPage()),
    );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _animationController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _pin => _codeController.code;

  void _onCodeChanged(String value) {
    // Clear any prior error and rebuild so the submit button reflects length.
    // Only clear the error while the user is actively typing a new code. A
    // programmatic clear after an invalid submit empties the field and fires
    // onChanged('') synchronously — it must NOT wipe the just-set error, or the
    // code silently disappears with no feedback (BR-ANKRJP).
    if (value.isEmpty) return;
    if (_pinError != null) {
      setState(() => _pinError = null);
    }
  }

  void _clearPin() => _codeController.clear();

  Future<void> _handlePinSubmit() async {
    // Re-entrancy guard: a submit is already in flight. Without this the
    // deep-link auto-consume opens the course twice — setting the code fires
    // CodeInputField.onCompleted (→ submit #1) and _maybeConsumeDeepLink then
    // calls submit #2 directly, each pushing its own CourseDetailPage.
    if (_isLookingUpPin) return;
    if (_pin.length != 6) return;

    setState(() {
      _isLookingUpPin = true;
      _pinError = null;
    });

    // Persist user's session-mode choice. The auth response will overwrite
    // session_shared_device with what the server actually issued.
    final shared = !_keepLoggedIn;
    await ref.read(sessionMetaProvider).setPendingSharedDevice(shared);

    try {
      final courseRepo = ref.read(courseRepositoryProvider);
      final userCourseRepo = ref.read(userCourseRepositoryProvider);
      final db = ref.read(appDatabaseProvider);

      // Step 1: Check bundled / local courses first (offline-first)
      var course = await courseRepo.findCourseByCode(_pin);

      // Step 1b: If not found locally, call unified resolve-code API.
      // One call resolves both course PINs and student login codes.
      if (course == null) {
        final guestAuthService = ref.read(guestAuthServiceProvider);

        // Flush pending local progress while the guest token is still active:
        // /resolve-code folds the guest's server-side data into the student
        // account (absorbGuest, BR-4FTCFH), and anything not pushed by now
        // can't take part in that merge — it would be wiped by the
        // clearAllData below. Best-effort and time-boxed, like logout.
        try {
          final api = ref.read(apiClientProvider);
          if (api.isAuthenticated) {
            final sync = ref.read(syncServiceProvider);
            if (await sync.hasPendingChanges()) {
              await sync.forceSync().timeout(const Duration(seconds: 8));
            }
          }
        } catch (e, st) {
          silentLog('auth_page', e, st);
        }

        try {
          // "Shared device" is the default, and on its own it makes the
          // server skip the merge — so a guest-upgrade login has to ask for
          // it explicitly, or the wipe below loses everything (BR-35W2HV).
          final resolved = await guestAuthService
              .resolveCode(
                _pin,
                sharedDevice: shared,
                mergeGuest: widget.guestUpgrade,
              )
              .timeout(const Duration(seconds: 15));

          if (resolved != null && resolved.isUser) {
            // Student login code — save user and complete login
            final name = resolved.name ?? AppStrings.authDefaultStudentName;

            // BR-ZDXP7C: A student login code adopts a specific server-side
            // identity. If the currently-active local user is a *different*
            // person (a leftover guest, or another student on a shared
            // device), wipe local data first so their practice cards,
            // progress and bookmarks don't leak into the "clean" account.
            // Same-person re-login (matching email) keeps local data intact.
            final current = await db.getActiveUser();
            final samePerson = current != null &&
                current.email.isNotEmpty &&
                resolved.email != null &&
                current.email.toLowerCase() ==
                    resolved.email!.trim().toLowerCase();
            if (!samePerson) {
              await db.clearAllData();
            }

            var user = await db.getActiveUser();
            if (user == null) {
              final guestId = await db.createGuestUser();
              user = await db.getUserById(guestId);
            }
            if (user != null) {
              await db.updateUserProfile(userId: user.id, name: name);
              if (resolved.email != null) {
                await db.updateUserEmail(user.id, resolved.email!);
              }
              // Server-authenticated user — mark email as validated
              // so the "register for full access" banner doesn't show.
              await (db.update(db.usersTable)
                    ..where((u) => u.id.equals(user!.id)))
                  .write(const UsersTableCompanion(
                    isEmailValidated: Value(true),
                  ));
            }
            ref.invalidate(isAuthenticatedProvider);
            // A different student is now signed in on this device, and the
            // cached identity is what the avatar hangs off (BR-SPR9WH).
            ref.invalidate(activeUserProvider);
            // The resolve-code response carries `minor`; /api/user on the next
            // boot is the ongoing authority, but this makes the current
            // session correct immediately (name lock, hidden sign-up prompt)
            // without waiting for a restart.
            await ref.read(minorModeProvider.notifier).set(resolved.minor);
            // Pull the account's data (incl. any guest progress the server
            // just merged in) into the freshly wiped local DB.
            unawaited(ref.read(syncServiceProvider).forceSync());
            setState(() => _isLookingUpPin = false);
            widget.onPinLoginComplete?.call(resolved.profileSetupRequired);
            return;
          }

          if (resolved != null && resolved.isCourse) {
            // API found a course — import it locally and continue
            course = await courseRepo.importFromResolvedCode(_pin, resolved.courseData!);
          }
        } catch (e, st) { silentLog('auth_page', e, st); }

        if (course == null) {
          setState(() {
            _isLookingUpPin = false;
            _pinError = AppStrings.codeNotFound(_pin);
          });
          _clearPin();
          return;
        }
      }

      // Step 1c: Block guests from logged_only courses.
      // Allow only real accounts: a user with an email OR a server-authenticated
      // student PIN login (flagged locally via isEmailValidated). Guests hold a
      // Sanctum token too, so token presence must NOT count as logged in
      // (BR-N2ENN4).
      if (course.data['logged_only'] == true) {
        final activeUser = await db.getActiveUser();
        if (activeUser == null ||
            (activeUser.email.isEmpty && !activeUser.isEmailValidated)) {
          setState(() {
            _isLookingUpPin = false;
            _pinError = AppStrings.authLoginRequired;
          });
          _clearPin();
          return;
        }
      }

      // Step 2: Create or get guest user
      var user = await db.getActiveUser();
      if (user == null) {
        // Create guest user
        final guestId = await db.createGuestUser();
        user = await db.getUserById(guestId);
      }

      if (user == null) {
        setState(() {
          _isLookingUpPin = false;
          _pinError = AppStrings.authUserCreateError;
        });
        _clearPin();
        return;
      }

      // Step 2b: Register guest on server to get auth token.
      // The token is needed for subsequent authenticated API calls.
      // 15s timeout handles Railway cold starts (can take 10-12s).
      final apiClient = ref.read(apiClientProvider);
      if (!apiClient.isAuthenticated) {
        final guestAuthService = ref.read(guestAuthServiceProvider);
        try {
          final registerResult = await guestAuthService
              .registerGuest(sharedDevice: shared)
              .timeout(const Duration(seconds: 15));
          if (registerResult != null) {
            // Invalidate cached auth state so providers see the new token.
            ref.invalidate(isAuthenticatedProvider);
            await db.updateUserProfile(
              userId: user.id,
              name: registerResult.name,
            );
          } else {
          }
        } catch (e) {
          // Timeout or network error — proceed without token.
          // Bundled courses work offline; token will be obtained on next sync.
        }
      } else {
      }

      // Step 3: Add course to user's library
      await userCourseRepo.startCourse(
        userId: user.id,
        courseId: course.id,
      );

      // Step 4: Download full course JSON from R2
      final downloadSuccess = await courseRepo.downloadFullCourseJson(course.id);

      // Step 5: Get the full course data for navigation
      final fullCourse = await courseRepo.getCourseById(course.id);
      if (fullCourse == null) {
        setState(() {
          _isLookingUpPin = false;
          _pinError = AppStrings.authCourseLoadError;
        });
        _clearPin();
        return;
      }

      // Step 5b: Validate course has actual content (blocks inside lessons)
      final courseData = fullCourse.data;
      final lessons = courseData['lessons'] as List<dynamic>?;
      final hasBlocks = lessons != null &&
          lessons.isNotEmpty &&
          lessons.first is Map<String, dynamic> &&
          (lessons.first as Map<String, dynamic>)['blocks'] is List;

      if (!downloadSuccess && !hasBlocks) {
        // Mark course as not-downloaded so knihovna will re-download later
        final userCourse = await db.getUserCourseByUserAndCourse(user.id, course.id);
        if (userCourse != null) {
          await db.updateUserCourseDownloadedVersion(
            id: userCourse.id,
            downloadedVersion: 0,
          );
        }

        setState(() {
          _isLookingUpPin = false;
          _pinError = AppStrings.authCourseDownloadError;
        });
        _clearPin();
        // Still complete login so the user lands in the app
        widget.onPinLoginComplete?.call(false);
        return;
      }

      // Step 6: Get user course for progress tracking
      final userCourse = await db.getUserCourseByUserAndCourse(user.id, course.id);

      // Step 6.5: Block re-entry for only_once completed courses
      if (fullCourse.data['only_once'] == true) {
        // Check locally first
        if (userCourse != null && userCourse.status == 'completed') {
          setState(() {
            _isLookingUpPin = false;
            _pinError = AppStrings.libraryCourseAlreadyCompleted;
          });
          _clearPin();
          return;
        }

        // Check server — local data may have been cleared
        if (apiClient.isAuthenticated) {
          try {
            final result = await apiClient.get<Map<String, dynamic>>(
              ApiEndpoints.userCourses,
            ).timeout(const Duration(seconds: 10));
            if (result.isSuccess && result.data != null) {
              final serverCourses = result.data!['user_courses'] as List<dynamic>? ?? [];
              // Server returns course_id as string OR numeric — match both
              final courseStringId = fullCourse.courseId;
              final courseNumericId = fullCourse.serverId;
              final alreadyCompleted = serverCourses.any((uc) {
                if (uc is! Map<String, dynamic>) return false;
                if (uc['status'] != 'completed') return false;
                final remoteCourseId = uc['course_id'];
                return remoteCourseId == courseStringId ||
                    remoteCourseId == courseNumericId;
              });
              if (alreadyCompleted) {
                setState(() {
                  _isLookingUpPin = false;
                  _pinError = AppStrings.libraryCourseAlreadyCompleted;
                });
                _clearPin();
                return;
              }
            }
          } catch (_) {
            // Network error — allow entry (offline-first, local check already passed)
          }
        }
      }

      setState(() => _isLookingUpPin = false);

      // Step 7: Navigate to course detail, then switch to main app on return
      if (mounted) {
        final courseModel = models.Course.fromJsonData(
          id: fullCourse.id,
          data: fullCourse.data,
          completedLessons: userCourse?.completedLessons ?? 0,
          isCompleted: userCourse?.status == 'completed',
        );

        // MainScreen is not mounted yet, so the tab provider still holds its
        // default (Přehled) — the sidebar this pushed page draws would
        // highlight the wrong destination, and returning would land on the
        // dashboard rather than the course's own tab (BR-48B7DY).
        ref.read(mainTabIndexProvider.notifier).state = kKurzyTabIndex;

        await Navigator.of(context).push(
          shellPageRoute(
      context,
            builder: (_) => CourseDetailPage(
              course: courseModel,
              userCourseId: userCourse?.id,
            ),
          ),
        );

        // Step 8: After returning from course, switch to main app
        if (mounted) {
          widget.onPinLoginComplete?.call(false);
        }
      }
    } catch (e) {
      setState(() {
        _isLookingUpPin = false;
        _pinError = AppStrings.genericError('$e');
      });
      _clearPin();
    }
  }

  void _handleLogin() async {
    if (_isCheckingEmail) return;
    final email = _emailController.text.trim();
    // Persist user's session-mode choice for downstream verify/registerVerified.
    await ref.read(sessionMetaProvider).setPendingSharedDevice(!_keepLoggedIn);
    if (email.isEmpty) {
      // Show error if email is empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.authEmptyEmailError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.authInvalidEmailError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isCheckingEmail = true);

    // Nothing is sent yet: an e-mail with an account behind it goes on to its
    // sign-in code, an unknown one is a registration and meets the age gate
    // first (BR-J2WJEQ). The verification page sends the code.
    final proceed = await ref
        .read(emailVerificationProvider.notifier)
        .screenNewAccount(
          email,
          onNewAccount: widget.onNeedsParentalConsent == null
              ? null
              : _ageGateBeforeRegistration,
        );
    if (!mounted) return;
    setState(() => _isCheckingEmail = false);
    if (!proceed) return;

    widget.onEmailSubmit(email);
  }

  /// The age gate, run once an e-mail or a provider credential turns out to
  /// belong to no account yet. Returns whether the registration may proceed.
  ///
  /// It used to sit in front of this whole form, which meant a returning user
  /// was asked where they live and how old they are every time they signed in
  /// (BR-N9Y48J). The form is login and registration at once, so the gate
  /// belongs on the branch that actually creates an account: for e-mail the
  /// account check in [_handleLogin], before any code is sent (BR-J2WJEQ), and
  /// for OAuth the sign-in-only exchange in [OAuthSignInButtons] that reports
  /// "this would register" without registering — moving it off *every* social
  /// sign-in (BR-VTNTMQ).
  Future<bool> _ageGateBeforeRegistration() async {
    // Null means this caller has no consent flow wired up — nothing to hand a
    // minor off to, so the gate would be a dead end.
    if (widget.onNeedsParentalConsent == null) return true;

    final result = await showAgeGate(context);
    if (!mounted) return false;

    switch (result.outcome) {
      case AgeGateOutcome.oldEnough:
        return true;
      case AgeGateOutcome.needsConsent:
        widget.onNeedsParentalConsent?.call(result.country);
        return false;
      case AgeGateOutcome.dismissed:
        return false;
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUpMode = !_isSignUpMode;
    });
    if (_isSignUpMode) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  /// At its natural ratio the wave is only ~68px tall on a 390px phone, where
  /// the design has it nearer 100. Rendering it 1.5× the viewport width
  /// restores that height and crops the ends, which are flat anyway.
  static const double _waveCompactZoom = 1.5;

  /// How far the props sink into the wave, as a share of the wave's height.
  /// They have to overlap it or they read as floating above the ground; too
  /// much and the lower props disappear behind the sheet.
  static const double _heroWaveOverlap = 0.4;

  /// Breathing room between the top safe-area inset and the composition.
  static const double _heroTopGap = 8;

  @override
  Widget build(BuildContext context) {
    // Landscape tablet / desktop: the shared hero-scene scaffold draws the
    // illustration and the right-hand panel; the sheet layout's height
    // animation does not apply there — the panel is a fixed pane, so
    // switching modes only cross-fades its contents.
    if (context.isExpanded) {
      return AuthHeroScaffold(
        // Same switcher the sheet layout puts in the corner (BR-U75N5Y), over
        // the hero rather than the panel so it stays on the dark background.
        heroOverlay: const LanguageSwitcher(onDark: true),
        panel: AnimatedBuilder(
          animation: _animationController,
          builder: (context, _) => _buildFormColumn(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.authGradient,
        ),
        child: _buildSheetLayout(context),
      ),
    );
  }

  /// Phone / portrait tablet: illustration on top, white sheet over the bottom.
  Widget _buildSheetLayout(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Cap the card height so its top never rises above the top safe-area
            // inset. When the keyboard opens, Scaffold's default
            // resizeToAvoidBottomInset shrinks the body, but the card height is
            // computed from the full screen height — without this clamp the card
            // overflows upward and the header/back button slide under the status
            // bar (BR-PXB3N3).
            final mq = MediaQuery.of(context);
            final maxContainerHeight =
                mq.size.height - mq.viewInsets.bottom - mq.padding.top;
            final containerHeight = maxContainerHeight <= 0
                ? screenHeight * _heightAnimation.value
                : (screenHeight * _heightAnimation.value)
                    .clamp(0.0, maxContainerHeight)
                    .toDouble();
            final bgBottom = containerHeight - 20;

            // The composition stands on the wave, so it is anchored to the
            // wave's top edge rather than to the sheet, and it gets whatever
            // is left between there and the status bar. Both move as the
            // sheet grows into sign-up mode or the keyboard opens, so this is
            // recomputed every frame instead of being a constant offset.
            final waveHeight =
                mq.size.width * _waveCompactZoom * kAuthWaveAspectRatio;
            final heroBottom = bgBottom + waveHeight * (1 - _heroWaveOverlap);
            final heroBand =
                mq.size.height - mq.padding.top - _heroTopGap - heroBottom;

            return Stack(
              key: sheetKey,
              children: [
                // Ground wave, tucked just behind the top edge of the card.
                // The asset is 1440 wide; on a phone it is rendered wider than
                // the viewport so the curve keeps the height it has in the
                // design instead of flattening to a thin strip.
                Positioned(
                  bottom: bgBottom,
                  left: -(mq.size.width * (_waveCompactZoom - 1)) / 2,
                  child: buildAuthWave(
                    width: mq.size.width * _waveCompactZoom,
                  ),
                ),
                // Wordmark + the mascot standing on the wave. Drawn after the
                // wave so the props sit in front of it, same order the
                // split-pane hero uses.
                Positioned(
                  bottom: heroBottom,
                  left: 0,
                  right: 0,
                  child: AuthCompactHero(maxHeight: heroBand),
                ),
                // White form container
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: containerHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                        topRight: Radius.circular(26),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: kAuthFormColumnWidth,
                            ),
                            child: _buildFormColumn(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Language switcher — the only place to pick a language before
                // login (the profile picker needs an account). Sits on the
                // gradient above the card, which tops out at 72% of the screen.
                // Hidden while the keyboard is up: the card is then clamped to
                // the full remaining height and would slide under the pill.
                if (mq.viewInsets.bottom == 0)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8, right: 16),
                        child: LanguageSwitcher(onDark: true),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
  }

  /// The form itself — back button, headline and the mode-specific body.
  /// Shared by both layouts so the two never drift apart.
  Widget _buildFormColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
        if (_isSignUpMode || widget.onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: _isSignUpMode
                  ? (widget.onBack ?? _toggleMode)
                  : widget.onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark08,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
            ),
          ),
        // Headline
        Text(
          AppStrings.authFormHeadline,
          style: AppTextStyles.heading1().copyWith(
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        // Content based on mode
        _isSignUpMode ? _buildSignUpContent() : _buildWelcomeContent(),
      ],
    );
  }

  Widget _buildWelcomeContent() {
    return FadeTransition(
      opacity: _fadeOutAnimation.value == 0
          ? const AlwaysStoppedAnimation(0)
          : _fadeOutAnimation,
      child: Column(
        children: [
          // Code input label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppStrings.authCodeLabel,
              textAlign: TextAlign.left,
              style: AppTextStyles.bodyLarge(color: AppColors.primaryDark64),
            ),
          ),
          const SizedBox(height: 12),
          // Alphanumeric code input — single field rendered as 6 boxes
          CodeInputField(
            length: 6,
            controller: _codeController,
            hasError: _pinError != null,
            onChanged: _onCodeChanged,
            onCompleted: (_) {
              if (!_isLookingUpPin) _handlePinSubmit();
            },
          ),
          // Error message
          if (_pinError != null) ...[
            const SizedBox(height: 8),
            Text(
              _pinError!,
              style: AppTextStyles.caption(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          _buildKeepLoggedInCheckbox(),
          const SizedBox(height: 16),
          // Access Free Courses button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_pin.length == 6 && !_isLookingUpPin) ? _handlePinSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryDark48,
                disabledForegroundColor: Colors.white.withAlpha(179),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.radiusM,
                ),
                elevation: 0,
              ),
              child: _isLookingUpPin
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppStrings.authVerifyingCode,
                          style: AppTextStyles.buttonLarge(color: Colors.white),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.authContinue,
                          style: AppTextStyles.buttonLarge(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Divider with "or"
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.primaryDark12,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppStrings.authOr,
                  style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.primaryDark12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Log In / Sign Up button
          GestureDetector(
            onTap: _toggleMode,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryDark16,
                  width: 1,
                ),
                borderRadius: AppDecorations.radiusM,
              ),
              child: Center(
                child: Text(
                  AppStrings.authLoginSignUp,
                  style: AppTextStyles.bodyLarge(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Terms and Privacy Policy
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _openTerms,
                  child: Text(
                    AppStrings.authTerms,
                    style: AppTextStyles.caption(color: AppColors.primaryDark48).copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _openPrivacy,
                  child: Text(
                    AppStrings.authPrivacy,
                    style: AppTextStyles.caption(color: AppColors.primaryDark48).copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpContent() {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Column(
        children: [
          // Email input
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primaryDark16,
                width: 1,
              ),
              borderRadius: AppDecorations.radiusM,
            ),
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _handleLogin(),
              style: AppTextStyles.bodyLarge(),
              decoration: InputDecoration(
                hintText: AppStrings.authEmailHint,
                hintStyle: AppTextStyles.bodyLarge(color: AppColors.primaryDark48),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildKeepLoggedInCheckbox(),
          const SizedBox(height: 16),
          // Login button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isCheckingEmail ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryDark48,
                disabledForegroundColor: Colors.white.withAlpha(179),
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.radiusM,
                ),
                elevation: 0,
              ),
              child: _isCheckingEmail
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.authLogin,
                          style: AppTextStyles.buttonLarge(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Divider with "Nebo"
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.primaryDark12,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppStrings.authOrCzech,
                  style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.primaryDark12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OAuthSignInButtons(
            // The checkbox is the user's stated session choice here, so it is
            // both what we ask the backend for and what we remember.
            sharedDevice: !_keepLoggedIn,
            beforeExchange: _ageGateBeforeRegistration,
            onSuccess: (exchange) => widget.onOAuthSuccess?.call(exchange),
          ),
          const SizedBox(height: 24),
          // Terms and Privacy Policy
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.caption(color: AppColors.primaryDark48),
                children: [
                  TextSpan(text: AppStrings.authTermsNotice),
                  TextSpan(
                    text: AppStrings.authTermsLink,
                    recognizer: _termsRecognizer,
                    style: AppTextStyles.caption(color: AppColors.primaryDark64).copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: AppStrings.authTermsPrivacyJoiner),
                  TextSpan(
                    text: AppStrings.authPrivacyLink,
                    recognizer: _privacyRecognizer,
                    style: AppTextStyles.caption(color: AppColors.primaryDark64).copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opt-out checkbox: when checked, the new session is persistent (no
  /// inactivity logout). Default unchecked = shared device, auto-logout
  /// after 15 min idle / 8 h hard cap.
  Widget _buildKeepLoggedInCheckbox() {
    return InkWell(
      onTap: () {
        setState(() => _keepLoggedIn = !_keepLoggedIn);
      },
      borderRadius: AppDecorations.radiusS,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _keepLoggedIn,
                onChanged: (v) =>
                    setState(() => _keepLoggedIn = v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.authKeepLoggedInLabel,
                style: AppTextStyles.bodySmall(
                  color: AppColors.primaryDark64,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
