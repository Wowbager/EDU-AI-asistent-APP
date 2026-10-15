import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/consent/minor_mode.dart';
import '../core/database/app_database.dart';
import '../core/network/api_client.dart';
import '../core/oauth/oauth_clients.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/locale_manager.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/inactivity_watcher.dart';
import '../data/repositories/consent_repository.dart';
import '../data/repositories/oauth_repository.dart';
import '../pages/auth_page.dart';
import '../pages/consent/consent_request_page.dart';
import '../pages/consent/age_gate_route.dart';
import '../pages/email_verification_page.dart';
import '../pages/main_screen.dart';
import '../pages/profile_setup_page.dart';
import 'account_verification.dart';
import 'login_destination.dart';
import 'package:eduai/core/util/silent_log.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

enum AppState { loading, auth, consentRequest, emailVerification, profileSetup, main }

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  AppState _appState = AppState.loading;
  String _userEmail = '';
  bool _isEmailValidated = false; // Track if email was validated (false if skipped offline)
  bool _isGuestUpgrade = false; // Track when guest is upgrading to full account

  /// Country the age gate resolved when the child answered "no". Travels
  /// with the consent request so the server picks the right threshold and
  /// email locale — never persisted, so a fresh gate answer is required
  /// every time this screen is (re-)entered.
  String? _consentCountry;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  /// Check if user is already logged in on app startup
  Future<void> _checkExistingAuth() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final apiClient = ref.read(apiClientProvider);
      final connectivity = ref.read(connectivityServiceProvider);
      final session = ref.read(sessionMetaProvider);

      // Shared-device sessions: if app was backgrounded past the inactivity
      // limit or hard cap, log out before any API calls so we don't briefly
      // flash the main UI to a previous student.
      if (session.sharedDevice &&
          (session.isInactivityExpired() || session.isHardCapExceeded())) {
        await _forceLogoutToAuth();
        return;
      }

      final activeUser = await db.getActiveUser();

      if (activeUser != null) {
        _userEmail = activeUser.email;

        // Restore the minor flag before any network call — an offline start
        // must still be gated the same way an online one would be (the flag
        // must never fail open).
        await ref.read(minorModeProvider.notifier).restore();

        // If online, verify with the API server
        final isOnline = await connectivity.isOnline;
        if (isOnline && apiClient.isAuthenticated) {
          try {
            final response = await apiClient.get('/api/user')
                .timeout(const Duration(seconds: 10), onTimeout: () {
              return ApiResult.failure('timeout');
            });
            if (response.statusCode == 200) {
              final userData = response.data as Map<String, dynamic>;
              final serverName = userData['name'] as String? ?? '';
              final serverAvatarIndex = userData['avatar_index'] as int? ?? 0;
              final serverSubjects = userData['selected_subjects'];

              // Convert subjects to string for storage
              String? subjectsString;
              if (serverSubjects != null) {
                if (serverSubjects is List) {
                  subjectsString = serverSubjects.map((e) => e.toString()).join(',');
                } else if (serverSubjects is String) {
                  subjectsString = serverSubjects;
                }
              }


              // Update local user data from server
              await db.updateUserProfile(
                userId: activeUser.id,
                name: serverName.isNotEmpty ? serverName : null,
                avatarIndex: serverAvatarIndex,
                selectedSubjects: subjectsString,
              );

              // The server owns email verification; mirror it so a row that
              // was written unverified (SSO signup, offline skip) converges
              // instead of showing the verify banner forever (BR-3XVWV7) —
              // and so a login-code student left looking like a guest gets
              // their account back (BR-7U6V36).
              var isEmailValidated = activeUser.isEmailValidated;
              if (shouldMarkEmailValidated(
                isEmailValidated: isEmailValidated,
                email: activeUser.email,
                serverUser: userData,
              )) {
                await db.markEmailValidated(activeUser.id);
                isEmailValidated = true;
              }

              // Server truth for the minor flag, refreshed on every boot.
              await ref
                  .read(minorModeProvider.notifier)
                  .set(userData['is_minor'] == true);

              // Check if profile is complete
              if (serverName.isNotEmpty) {
                setState(() {
                  _appState = AppState.main;
                });
              } else {
                setState(() {
                  _isEmailValidated = isEmailValidated;
                  _appState = AppState.profileSetup;
                });
              }
            } else if (response.statusCode == 401 || response.statusCode == 403) {
              // Token is definitely invalid — log out. If this account is a
              // minor, this may be the first reconnect after a guardian
              // revoked consent — the only moment we can still reach this
              // device's local Drift copy — so wipe it explicitly (decision
              // 12). LogoutCoordinator.teardown already wipes everything
              // unconditionally below; this is an extra, minor-scoped
              // guarantee that doesn't depend on that shared path.
              await wipeLocalDataIfMinor(
                isMinor: ref.read(minorModeProvider),
                db: db,
              );
              // Intentionally redundant with clearAllData() inside teardown()
              // below for a minor — see wipeLocalDataIfMinor's doc comment.
              await ref.read(logoutCoordinatorProvider).teardown();
              setState(() {
                _appState = AppState.auth;
              });
            } else {
              // Other status (null/timeout, 500, etc.) — use local data
              _proceedWithLocalUser(activeUser);
            }
          } catch (apiError) {
            // API call failed - check if it's 401 unauthorized
            if (apiError.toString().contains('401')) {
              // Token is invalid - log out. See the comment above: a minor's
              // local data must be wiped, not just logged out.
              await wipeLocalDataIfMinor(
                isMinor: ref.read(minorModeProvider),
                db: db,
              );
              // Intentionally redundant with clearAllData() inside teardown()
              // below for a minor — see wipeLocalDataIfMinor's doc comment.
              await ref.read(logoutCoordinatorProvider).teardown();
              setState(() {
                _appState = AppState.auth;
              });
            } else {
              // Other error (network issue) - use local data
              _proceedWithLocalUser(activeUser);
            }
          }
        } else if (isOnline) {
          // Online but no token: the session lapsed while the app was closed
          // (expired/revoked). We can't use authenticated features, so route to
          // login rather than stranding the user on cached screens where
          // online-only features (news) would 401.
          await db.logoutUser();
          if (mounted) {
            setState(() {
              _appState = AppState.auth;
            });
          }
        } else {
          // Offline - use local data so the app still works without network.
          _proceedWithLocalUser(activeUser);
        }
      } else {
        // No user - show auth screen
        setState(() {
          _appState = AppState.auth;
        });
      }
    } catch (e) {
      setState(() {
        _appState = AppState.auth;
      });
    }
  }

  /// Proceed with local user data (used when offline)
  void _proceedWithLocalUser(UsersTableData activeUser) {
    if (activeUser.name.isNotEmpty) {
      setState(() {
        _appState = AppState.main;
      });
    } else {
      setState(() {
        _isEmailValidated = activeUser.isEmailValidated;
        _appState = AppState.profileSetup;
      });
    }
  }

  void _handleEmailSubmit(String email) {
    setState(() {
      _userEmail = email;
      _isGuestUpgrade = false;
      _appState = AppState.emailVerification;
    });
  }

  Future<void> _handleOAuthSuccess(OAuthExchangeResult exchange) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.setAuthToken(exchange.token);
      ref.invalidate(isAuthenticatedProvider);

      // Persist session metadata so inactivity/expiry logic works correctly.
      await ref.read(sessionMetaProvider).applyFromAuthResponse({
        'token': exchange.token,
        'shared_device': exchange.sharedDevice,
        'expires_at': exchange.expiresAt,
        'session_started_at': exchange.sessionStartedAt,
      });

      // Write the authenticated user into the local DB so the app shows their
      // real profile (not the guest "Uživatel") and progress binds to their
      // account. The magic-link flow does the same after /api/user; the OAuth
      // exchange already returns the full user, so no extra request is needed.
      await _persistOAuthUser(exchange.user);

      final needsProfileSetup =
          await _needsProfileSetup(exchange.profileSetupRequired);

      if (mounted) {
        setState(() {
          _userEmail = exchange.user['email'] as String? ?? '';
          // The SSO provider has proven ownership of the email, so the account
          // is verified no matter what the (possibly stale) local row said.
          // ProfileSetupPage writes a brand-new user row from this flag, so
          // without it an SSO signup lands as unverified and gets the "verify
          // your email" banner (BR-3XVWV7).
          _isEmailValidated = true;
          _appState = needsProfileSetup ? AppState.profileSetup : AppState.main;
        });
      }

      // Pull server data immediately after OAuth login.
      try {
        ref.read(syncServiceProvider).forceSync();
      } catch (e, st) { silentLog('root_navigator', e, st); }
    } catch (e, st) {
      silentLog('root_navigator', e, st);
    }
  }

  /// Mirror the OAuth-verified user into the local Drift DB.
  ///
  /// [activeUserStreamProvider] (the source for the displayed name/email and
  /// for progress binding) reads the local users table, not the auth response.
  /// A guest with an empty email is upgraded in place (preserving their local
  /// data); a different account creates a fresh active row and migrates any
  /// prior local data onto it.
  Future<void> _persistOAuthUser(Map<String, dynamic> u) async {
    final db = ref.read(appDatabaseProvider);

    final email = (u['email'] as String?) ?? '';
    if (email.isEmpty) return; // backend guarantees a verified email; guard anyway
    final name = (u['name'] as String?) ?? '';
    final avatarIndex = (u['avatar_index'] as int?) ?? 0;
    final rawSubjects = u['selected_subjects'];
    final subjects = rawSubjects is List
        ? jsonEncode(rawSubjects.map((e) => e.toString()).toList())
        : null;

    final activeUser = await db.getActiveUser();
    // A minor's local row also has an empty email — same shape as a guest —
    // but must never be "upgraded in place" with an OAuth account's real
    // name/email (BR-8FDF37, decision 7). Excluding minors here falls
    // through to the "different account" branch below, which creates a
    // fresh local row instead of mutating the minor's own.
    final isGuestUpgrade = activeUser != null &&
        activeUser.email.isEmpty &&
        !ref.read(minorModeProvider);

    if (isGuestUpgrade) {
      await db.updateUserEmail(activeUser.id, email);
      await db.markEmailValidated(activeUser.id);
      if (name.isNotEmpty) {
        await db.updateUserProfile(
          userId: activeUser.id,
          name: name,
          avatarIndex: avatarIndex,
          selectedSubjects: subjects,
        );
      }
    } else if (activeUser == null || activeUser.email != email) {
      // No active user, or a different account than the one already active.
      final newUserId = const Uuid().v4();
      await db.createAndActivateUser(
        UsersTableCompanion(
          id: Value(newUserId),
          email: Value(email),
          name: Value(name),
          avatarIndex: Value(avatarIndex),
          selectedSubjects: Value(subjects ?? '[0]'),
          isEmailValidated: const Value(true),
          isActive: const Value(true),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (activeUser != null && activeUser.id != newUserId) {
        await db.migrateUserData(activeUser.id, newUserId);
      }
    } else if (!activeUser.isEmailValidated) {
      // Same account is already active locally but flagged unverified (e.g.
      // verification was skipped offline). The provider has now proven the
      // email, so clear the flag instead of leaving the banner up forever.
      await db.markEmailValidated(activeUser.id);
    }

    ref.invalidate(activeUserStreamProvider);
    // Same for the cached read beside it: an OAuth login can land on a
    // different account than the one that was active, and the avatar is built
    // on that cache (BR-SPR9WH).
    ref.invalidate(activeUserProvider);
  }

  void _handleGuestLogin(String email) {
    setState(() {
      _userEmail = email;
      _isGuestUpgrade = true;
      _appState = AppState.emailVerification;
    });
  }

  /// Whether the login that just completed has to stop at the profile
  /// onboarding — see [loginNeedsProfileSetup] for the rule. Reads the local
  /// row the callers don't have at hand.
  Future<bool> _needsProfileSetup(bool profileSetupRequired) async {
    final user = await ref.read(appDatabaseProvider).getActiveUser();
    // No local row at all says nothing about the account's profile — only the
    // server's verdict does (a sign-up creates that row in ProfileSetupPage).
    if (user == null) return profileSetupRequired;
    return loginNeedsProfileSetup(
      profileSetupRequired: profileSetupRequired,
      activeUserEmail: user.email,
      activeUserName: user.name,
      isMinor: ref.read(minorModeProvider),
    );
  }

  /// The age gate, shown when a verified e-mail turns out to have no account
  /// behind it — that step, not opening the login form, is where an account
  /// gets created (BR-N9Y48J). Returns whether registration may continue.
  ///
  /// Normally AuthPage has already asked, before the code was even sent
  /// (BR-J2WJEQ), and the notifier skips this. It only fires when that
  /// account check could not reach the server — including the offline
  /// "continue without verification" branch, which creates a local account.
  Future<bool> _confirmRegistrationAge() async {
    final result = await showAgeGate(context);
    if (!mounted) return false;

    switch (result.outcome) {
      case AgeGateOutcome.oldEnough:
        return true;
      case AgeGateOutcome.needsConsent:
        setState(() {
          _consentCountry = result.country;
          _appState = AppState.consentRequest;
        });
        return false;
      case AgeGateOutcome.dismissed:
        // The verification code is spent either way (or, offline, was never
        // sent), so there is nothing to return to on this screen — go back to
        // where the flow started.
        _handleBackToAuth();
        return false;
    }
  }

  Future<void> _handleVerificationComplete(
      bool needsProfileSetup, bool isEmailValidated) async {
    final stopAtProfileSetup = await _needsProfileSetup(needsProfileSetup);
    if (!mounted) return;
    setState(() {
      _isEmailValidated = isEmailValidated;
      _appState = stopAtProfileSetup ? AppState.profileSetup : AppState.main;
    });
  }

  void _handleProfileComplete() {
    setState(() {
      _appState = AppState.main;
    });
  }

  void _handleBackToAuth() {
    setState(() {
      _userEmail = '';
      if (_isGuestUpgrade) {
        _isGuestUpgrade = false;
        _appState = AppState.main;
      } else {
        _appState = AppState.auth;
      }
    });
  }

  Future<void> _handlePinLoginComplete(bool profileSetupRequired) async {
    // A course PIN created a guest, who never onboards — it always passes
    // false, so the PIN still lands straight in the course (BR-D27TFA).
    // A student login code carries the server's verdict: the account existed
    // before the student ever opened the app, so only `onboarded_at` can say
    // whether this is their first entry or their hundredth (BR-YXVMKY).
    final stopAtProfileSetup = await _needsProfileSetup(profileSetupRequired);
    if (!mounted) return;
    setState(() {
      _appState = stopAtProfileSetup ? AppState.profileSetup : AppState.main;
    });

    // Pull server data (progress, bookmarks, stats, achievements) immediately.
    // Critical for new-device login where local DB is empty.
    try {
      ref.read(syncServiceProvider).forceSync();
    } catch (e, st) { silentLog('root_navigator', e, st); }
  }

  void _handleLogout() {
    _forceLogoutToAuth();
  }

  /// Tear down the session (best-effort flush → revoke → local wipe) and return
  /// to the login screen, dropping any pushed routes. Used by the logout
  /// button, the InactivityWatcher, and the start-up expiry check.
  ///
  /// The reset runs from a `finally` and behind
  /// [LogoutCoordinator.defaultNavigationDeadline], never as a plain
  /// continuation of the teardown: a stalled wipe used to leave the shared
  /// device sitting on the emptied Courses screen instead of the login form,
  /// and nothing retried it — teardown had already cleared `shared_device`, so
  /// [InactivityWatcher] stopped seeing an idle session to log out (BR-VUESR3).
  Future<void> _forceLogoutToAuth() async {
    try {
      await ref
          .read(logoutCoordinatorProvider)
          .teardown()
          .timeout(LogoutCoordinator.defaultNavigationDeadline);
    } catch (e, st) {
      silentLog('root_navigator', e, st);
    } finally {
      _resetToAuth();
    }
  }

  /// Pop everything above the root route and show the auth screen. Also invoked
  /// via [forceAuthScreenProvider] when logout is triggered from elsewhere —
  /// a 401 on any endpoint, or a null active user in a pushed page.
  void _resetToAuth() {
    ref.read(oauthNavigatorKeyProvider).currentState?.popUntil((r) => r.isFirst);
    if (!mounted) return;
    setState(() {
      _userEmail = '';
      _appState = AppState.auth;
    });
  }

  @override
  Widget build(BuildContext context) {
    // When logout is triggered from outside this widget (a 401 on any endpoint,
    // or a null active user in a pushed page), return to the login screen.
    ref.listen<int>(forceAuthScreenProvider, (_, _) => _resetToAuth());

    final Widget screen;
    switch (_appState) {
      case AppState.loading:
        screen = Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ),
        );
        break;
      case AppState.auth:
        screen = AuthPage(
          onEmailSubmit: _handleEmailSubmit,
          onPinLoginComplete: _handlePinLoginComplete,
          onOAuthSuccess: _handleOAuthSuccess,
          onNeedsParentalConsent: (country) => setState(() {
            _consentCountry = country;
            _appState = AppState.consentRequest;
          }),
        );
        break;
      case AppState.consentRequest:
        screen = ConsentRequestPage(
          country: _consentCountry,
          onSubmit: (email) => ref.read(consentRepositoryProvider).requestConsent(
                email: email,
                locale: LocaleManager.current.code,
                country: _consentCountry,
              ),
          // The child types the code their parent read out on the normal
          // PIN/code screen (POST /api/resolve-code) — not something this
          // flow handles itself.
          onEnterCode: () => setState(() => _appState = AppState.auth),
          onBack: () => setState(() => _appState = AppState.auth),
        );
        break;
      case AppState.emailVerification:
        screen = EmailVerificationPage(
          email: _userEmail,
          onVerified: _handleVerificationComplete,
          onBack: _handleBackToAuth,
          onNewAccount: _confirmRegistrationAge,
        );
        break;
      case AppState.profileSetup:
        screen = ProfileSetupPage(
          email: _userEmail,
          isEmailValidated: _isEmailValidated,
          onComplete: _handleProfileComplete,
        );
        break;
      case AppState.main:
        screen = MainScreen(
          onLogout: _handleLogout,
          onGuestLogin: _handleGuestLogin,
          onOAuthSuccess: _handleOAuthSuccess,
          onPinLoginComplete: _handlePinLoginComplete,
        );
        break;
    }

    return InactivityWatcher(
      onLogout: _forceLogoutToAuth,
      child: screen,
    );
  }
}
