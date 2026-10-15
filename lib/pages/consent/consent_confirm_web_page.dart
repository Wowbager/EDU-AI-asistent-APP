import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/consent_repository.dart';
import 'resend_link_form.dart';

/// Public page the parent opens from the emailed link. This is the **only**
/// place a consent can be confirmed — the child's app never reaches this
/// route with a valid id, because the id only ever exists in the parent's
/// inbox.
///
/// Runs standalone in the public-web context, outside `AuthWrapper` — same
/// mechanism as `/privacy` (see `lib/routing/app_router.dart`). A parent
/// opening this link on their own device must never boot the child's
/// login/auth stack.
class ConsentConfirmWebPage extends StatefulWidget {
  /// The `id` query parameter from the emailed link
  /// (`/consent/confirm?id=<uuid>`). Null or blank means the link was
  /// mangled — a corporate link-rewriter, a copy/paste that dropped the
  /// query string, … — and the page must say so rather than silently
  /// posting an empty id to the server.
  final String? publicId;

  /// Confirm the code the parent typed. Returns a [ConsentConfirmResult],
  /// never a bare bool, so this screen can tell "wrong/expired code"
  /// ([ConsentFailure.rejected]) apart from "the request never reached the
  /// server" ([ConsentFailure.network]), and — on success — whether the
  /// codes email actually went out ([ConsentConfirmResult.mailSent]).
  final Future<ConsentConfirmResult> Function(String code) onConfirm;

  /// Recovery path for a confirmed consent whose codes email failed to
  /// send: the accounts exist, but the parent has no codes. This re-emails
  /// a fresh consent-management magic link, from which the parent can
  /// regenerate each child's code (`ConsentManageWebPage`). Same endpoint
  /// and copy as the management page's own "send me the link again".
  final Future<ConsentActionResult> Function(String email) onRequestManageLink;

  /// The `code` query parameter from the emailed link, used to prefill the
  /// field so the parent does not retype what the same email already shows
  /// (BR-FBD2E9). Prefill only — the parent still presses Confirm.
  ///
  /// Deliberately NOT auto-submitted: corporate mail scanners (SafeLinks,
  /// Proofpoint) fetch every URL in an incoming message, and a submit on load
  /// would let one of them burn a `ConsentCode` attempt — or grant a legally
  /// load-bearing parental consent that no human ever saw.
  ///
  /// Null when the link predates this change or a rewriter dropped the param;
  /// the field then starts empty exactly as before.
  final String? initialCode;

  const ConsentConfirmWebPage({
    super.key,
    required this.publicId,
    required this.onConfirm,
    required this.onRequestManageLink,
    this.initialCode,
  });

  @override
  State<ConsentConfirmWebPage> createState() => _ConsentConfirmWebPageState();
}

enum _ConfirmStatus { form, sending, done }

class _ConsentConfirmWebPageState extends State<ConsentConfirmWebPage> {
  // Normalised the same way _submit() normalises typed input, so a prefilled
  // code and a hand-typed one reach the server in identical shape.
  late final TextEditingController _code = TextEditingController(
    text: (widget.initialCode ?? '').trim().toUpperCase(),
  );
  _ConfirmStatus _status = _ConfirmStatus.form;
  ConsentConfirmResult? _result;

  bool get _hasValidId => (widget.publicId ?? '').trim().isNotEmpty;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _status = _ConfirmStatus.sending);

    final result = await widget.onConfirm(_code.text.trim().toUpperCase());

    if (!mounted) return;
    setState(() {
      _result = result;
      _status = _ConfirmStatus.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: !_hasValidId
                  ? _buildInvalidLink()
                  : _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidLink() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.link_off, size: 64, color: AppColors.error),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentConfirmInvalidLink,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(),
        ),
        const SizedBox(height: 24),
        // The copy promises "have a new email sent" — this is that action.
        // It cannot re-confirm the original consent (no id to work with),
        // but it gets the parent into the one flow that still works: a
        // fresh consent-management link, from which they can regenerate
        // codes for their children.
        ResendLinkForm(onRequestManageLink: widget.onRequestManageLink),
      ],
    );
  }

  Widget _buildContent() {
    final result = _result;

    if (_status == _ConfirmStatus.done && result != null && result.confirmed) {
      return result.mailSent
          ? _buildMailSentSuccess()
          : _MailFailedRecovery(
              totalChildren: result.totalChildren,
              onRequestManageLink: widget.onRequestManageLink,
            );
    }

    return _buildForm(result);
  }

  Widget _buildMailSentSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_outlined, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentConfirmSuccess,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(),
        ),
      ],
    );
  }

  Widget _buildForm(ConsentConfirmResult? result) {
    final failed = _status == _ConfirmStatus.done && result != null && !result.confirmed;
    final errorText = !failed
        ? null
        : (result.failure == ConsentFailure.network
            ? AppStrings.consentNetworkError
            : AppStrings.consentConfirmFailure);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.consentConfirmTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading3(),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.consentConfirmBody,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          maxLength: 6,
          textAlign: TextAlign.center,
          decoration: InputDecoration(errorText: errorText),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _status == _ConfirmStatus.sending ? null : _submit,
          child: Text(AppStrings.consentConfirmCta),
        ),
      ],
    );
  }
}

/// Shown in place of the normal success screen when the consent was
/// confirmed but the codes email did not go out. Offers the one working
/// recovery: re-emailing the consent-management magic link.
class _MailFailedRecovery extends StatelessWidget {
  final int totalChildren;
  final Future<ConsentActionResult> Function(String email) onRequestManageLink;

  const _MailFailedRecovery({
    required this.totalChildren,
    required this.onRequestManageLink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.warning_amber_outlined, size: 64, color: AppColors.warning),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentConfirmSuccessNoMail(totalChildren),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(),
        ),
        const SizedBox(height: 24),
        ResendLinkForm(onRequestManageLink: onRequestManageLink),
      ],
    );
  }
}
