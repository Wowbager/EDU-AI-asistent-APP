import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/deep_link.dart';
import '../consent/minor_mode.dart';
import '../providers/core_providers.dart';
import '../services/classroom_join_service.dart';
import '../strings/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/code_input_field.dart';

/// How an attempt to join a class by code ended (BR-3V2P22). The code is a
/// six-character student code or, since BR-TT6TD7, a four-character class
/// code; the server tells them apart by length and so does nothing here.
enum ClassroomJoinOutcome {
  /// The user confirmed and the server put the account in the class
  /// (student code: by folding the placeholder in).
  joined,

  /// The class was found but the user answered "Ne" in the dialog.
  declined,

  /// The code matches no class (404) — the caller keeps its own
  /// "course not found" wording; nothing about classes was shown.
  notAClass,

  /// The current account may not join classes (guest / minor). No request
  /// was made, so the caller should behave as if classes did not exist.
  ineligible,

  /// No connection; nothing was tried.
  offline,

  /// The server refused (code already used, already a member, …) or the
  /// request failed. [ClassroomJoinFlowResult.message] is what to show.
  failed,
}

class ClassroomJoinFlowResult {
  final ClassroomJoinOutcome outcome;
  final ClassroomSummary? classroom;
  final String? message;

  const ClassroomJoinFlowResult(this.outcome, {this.classroom, this.message});

  bool get isJoined => outcome == ClassroomJoinOutcome.joined;
}

/// May this account join a class by code?
///
/// Mirrors the server's own refusals so the app never shows a class dialog
/// it would then have to take back: a guest has no account to fold the
/// teacher's placeholder into (they should log in with the code instead),
/// and a minor's pseudonymous account is consent-bound and never merged.
/// `canOfferSignupProvider` is true exactly for anonymous guests, so an
/// e-mail account and a code-login school student both pass.
bool canJoinClassroom(WidgetRef ref) {
  if (ref.read(minorModeProvider)) return false;
  return !ref.read(canOfferSignupProvider);
}

/// Where the current account stands on joining a class, for the `/join/:code`
/// deep link (BR-TT6TD7), which — unlike the profile button — can arrive
/// before the account is known and has to wait for it.
enum ClassroomJoinEligibility {
  /// The local user row is still loading. [canOfferSignupProvider] reads a
  /// missing row as "guest", so without this state a real account would be
  /// told to log in during the first frames after boot.
  unknown,

  /// Anonymous guest: has to log in (or sign up) first.
  guest,

  /// Minor: may never join by code.
  ineligible,

  /// A real account: e-mail, SSO or code-login student.
  eligible,
}

final classroomJoinEligibilityProvider =
    Provider<ClassroomJoinEligibility>((ref) {
  if (ref.watch(minorModeProvider)) return ClassroomJoinEligibility.ineligible;
  if (!ref.watch(activeUserStreamProvider).hasValue) {
    return ClassroomJoinEligibility.unknown;
  }
  return ref.watch(canOfferSignupProvider)
      ? ClassroomJoinEligibility.guest
      : ClassroomJoinEligibility.eligible;
});

/// Is [code] shaped like something the join endpoints accept: a four-
/// character class code or a six-character student code, letters/digits.
bool isClassroomJoinCodeShape(String code) =>
    RegExp(r'^[A-Za-z0-9]{4}([A-Za-z0-9]{2})?$').hasMatch(code.trim());

/// Try to join the class behind [code]: look it up, ask
/// "Chceš se připojit ke třídě X?", join on Ano, toast on success.
///
/// Performs no navigation and shows nothing for [ClassroomJoinOutcome.notAClass],
/// [ineligible] or [offline] — the caller decides how to word those, since
/// this runs *after* the same code failed as a course PIN in the library.
Future<ClassroomJoinFlowResult> tryJoinClassroomByCode(
  BuildContext context,
  WidgetRef ref,
  String code,
) async {
  if (!canJoinClassroom(ref)) {
    return const ClassroomJoinFlowResult(ClassroomJoinOutcome.ineligible);
  }

  if (!await ref.read(connectivityServiceProvider).isOnline) {
    return ClassroomJoinFlowResult(
      ClassroomJoinOutcome.offline,
      message: AppStrings.classroomJoinOffline,
    );
  }

  final service = ref.read(classroomJoinServiceProvider);

  final lookup = await service.lookup(code);
  if (lookup.isFailure || lookup.data == null) {
    if (lookup.statusCode == 404) {
      return const ClassroomJoinFlowResult(ClassroomJoinOutcome.notAClass);
    }
    return ClassroomJoinFlowResult(
      ClassroomJoinOutcome.failed,
      message: lookup.error,
    );
  }

  final classroom = lookup.data!.classroom;
  if (!context.mounted) {
    return const ClassroomJoinFlowResult(ClassroomJoinOutcome.declined);
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppStrings.classroomJoinTitle),
      content: Text(AppStrings.classroomJoinConfirm(classroom.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(AppStrings.classroomJoinNo),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(AppStrings.classroomJoinYes),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return ClassroomJoinFlowResult(
      ClassroomJoinOutcome.declined,
      classroom: classroom,
    );
  }

  final joined = await service.join(code);
  if (joined.isFailure || joined.data == null) {
    return ClassroomJoinFlowResult(
      ClassroomJoinOutcome.failed,
      classroom: classroom,
      message: joined.error,
    );
  }

  if (context.mounted) {
    showClassroomJoinedSnackBar(context, joined.data!.classroom);
  }

  return ClassroomJoinFlowResult(
    ClassroomJoinOutcome.joined,
    classroom: joined.data!.classroom,
  );
}

void showClassroomJoinedSnackBar(BuildContext context, ClassroomSummary c) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppStrings.classroomJoinSuccess(c.name)),
      backgroundColor: AppColors.primary,
    ),
  );
}

/// Act on the class code a `/join/:code` link parked in
/// [pendingClassroomJoinCodeProvider] (BR-TT6TD7). `MainScreen` calls this on
/// mount and again whenever the code or [classroomJoinEligibilityProvider]
/// changes, so it must be safe to call at any time:
///
/// * account still loading → nothing yet, the code stays parked;
/// * guest → "log in to join" with a way to do it; the code stays parked, and
///   the eligibility flip after the login is what runs the join;
/// * minor → told they cannot join, code dropped;
/// * real account → the same lookup / "Chceš se připojit…?" / join flow as
///   the profile dialog. Every refusal — "Už jsi ve třídě X.", unknown code,
///   offline — is a snackbar, since there is no input to show it under.
Future<void> joinClassroomFromDeepLink(BuildContext context, WidgetRef ref) async {
  final code = ref.read(pendingClassroomJoinCodeProvider);
  if (code == null || code.isEmpty) return;

  switch (ref.read(classroomJoinEligibilityProvider)) {
    case ClassroomJoinEligibility.unknown:
      return;
    case ClassroomJoinEligibility.guest:
      return _askGuestToLogInForClassroom(context, ref);
    case ClassroomJoinEligibility.ineligible:
      ref.read(pendingClassroomJoinCodeProvider.notifier).state = null;
      _showJoinSnackBar(context, AppStrings.classroomJoinNotAllowed);
      return;
    case ClassroomJoinEligibility.eligible:
      break;
  }

  // Consume before the first await, so a rebuild meanwhile cannot start a
  // second join for the same link.
  ref.read(pendingClassroomJoinCodeProvider.notifier).state = null;

  if (!isClassroomJoinCodeShape(code)) {
    _showJoinSnackBar(context, AppStrings.classroomJoinCodeNotFound);
    return;
  }

  final result = await tryJoinClassroomByCode(context, ref, code);
  if (!context.mounted) return;

  final message = switch (result.outcome) {
    ClassroomJoinOutcome.joined || ClassroomJoinOutcome.declined => null,
    ClassroomJoinOutcome.notAClass => AppStrings.classroomJoinCodeNotFound,
    ClassroomJoinOutcome.ineligible => AppStrings.classroomJoinNotAllowed,
    ClassroomJoinOutcome.offline ||
    ClassroomJoinOutcome.failed =>
      result.message ?? AppStrings.genericError(''),
  };
  if (message != null) _showJoinSnackBar(context, message);
}

/// "Log in to join" for a guest holding a /join link. Confirming bumps
/// [requestGuestLoginProvider] — MainScreen's guest-upgrade login, which keeps
/// the guest's progress — and leaves the code parked for after it.
Future<void> _askGuestToLogInForClassroom(
  BuildContext context,
  WidgetRef ref,
) async {
  final login = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppStrings.classroomJoinTitle),
      content: Text(AppStrings.classroomJoinLoginRequired),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(AppStrings.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(AppStrings.libraryLoggedOnlyAction),
        ),
      ],
    ),
  );
  if (login == true) ref.read(requestGuestLoginProvider.notifier).state++;
}

void _showJoinSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Code-entry dialog for joining a class from Upravit profil: boxes, inline
/// error, then the shared confirm/join flow. Resolves to the flow result once
/// a join succeeded or the user cancelled (null).
///
/// Opens on the four-character class code (BR-TT6TD7) — the one a teacher
/// hands a whole class — with a switch to the six-character student code a
/// teacher mints for one pupil on the roster (BR-3V2P22).
Future<ClassroomJoinFlowResult?> showClassroomCodeDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showDialog<ClassroomJoinFlowResult>(
    context: context,
    builder: (_) => _ClassroomCodeDialog(ref: ref),
  );
}

class _ClassroomCodeDialog extends StatefulWidget {
  final WidgetRef ref;

  const _ClassroomCodeDialog({required this.ref});

  @override
  State<_ClassroomCodeDialog> createState() => _ClassroomCodeDialogState();
}

class _ClassroomCodeDialogState extends State<_ClassroomCodeDialog> {
  final CodeInputController _code = CodeInputController();
  bool _busy = false;
  String? _error;

  /// False = class code (4), true = student code (6).
  bool _studentCode = false;

  int get _length => _studentCode ? 6 : 4;

  void _toggleCodeKind() {
    _code.clear();
    setState(() {
      _studentCode = !_studentCode;
      _error = null;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.code;
    if (code.length < _length) {
      setState(() => _error = _studentCode
          ? AppStrings.libraryCodeShort
          : AppStrings.classroomJoinClassCodeShort);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await tryJoinClassroomByCode(context, widget.ref, code);
    if (!mounted) return;

    switch (result.outcome) {
      case ClassroomJoinOutcome.joined:
        Navigator.of(context).pop(result);
        return;
      case ClassroomJoinOutcome.declined:
        setState(() => _busy = false);
        return;
      case ClassroomJoinOutcome.notAClass:
        setState(() {
          _busy = false;
          _error = AppStrings.classroomJoinCodeNotFound;
        });
        _code.clear();
        return;
      case ClassroomJoinOutcome.ineligible:
        setState(() {
          _busy = false;
          _error = AppStrings.libraryLoginRequired;
        });
        return;
      case ClassroomJoinOutcome.offline:
      case ClassroomJoinOutcome.failed:
        setState(() {
          _busy = false;
          _error = result.message ?? AppStrings.genericError('');
        });
        _code.clear();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusL),
      title: Text(AppStrings.classroomJoinTitle, style: AppTextStyles.heading4()),
      // Fixed width: the boxes are Expanded inside a Row (see the library's
      // code dialog) and collapse without a bounded width.
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _studentCode
                  ? AppStrings.classroomJoinCodeHint
                  : AppStrings.classroomJoinClassCodeHint,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
            ),
            const SizedBox(height: 12),
            // Four boxes kept the size of six: a stretched 4-box row reads as
            // a different control, not a shorter code.
            SizedBox(
              width: _studentCode ? double.infinity : 240,
              child: CodeInputField(
                // Fresh state per length, so "completed" re-arms and focus
                // comes back after the switch.
                key: ValueKey(_length),
                length: _length,
                controller: _code,
                autofocus: true,
                hasError: _error != null,
                onChanged: (value) {
                  // The clear after a refused code fires onChanged('')
                  // synchronously; only real typing may wipe the error, or
                  // "Už jsi ve třídě X." vanishes as it appears (BR-ANKRJP).
                  if (value.isEmpty) return;
                  if (_error != null) setState(() => _error = null);
                },
                onCompleted: (_) {
                  if (!_busy) _submit();
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppTextStyles.caption(color: AppColors.error)),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.classroomJoinSearching,
                    style: AppTextStyles.bodySmall(color: AppColors.primary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : _toggleCodeKind,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                _studentCode
                    ? AppStrings.classroomJoinUseClassCode
                    : AppStrings.classroomJoinUseStudentCode,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(AppStrings.actionCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(AppStrings.classroomJoinSubmit),
        ),
      ],
    );
  }
}
