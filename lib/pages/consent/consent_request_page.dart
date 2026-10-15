import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/consent_repository.dart';
import '../../widgets/auth_buttons.dart';
import '../../widgets/auth_hero_scaffold.dart';

/// Child-facing side of the guardian consent flow: collect the parent's
/// email, ask the server to notify them, then park on a waiting screen. The
/// consent itself is never confirmed here — that happens on the parent's own
/// device, from the emailed link, followed by the child reading the emailed
/// login code out and typing it into the app's normal PIN/code screen
/// (`POST /api/resolve-code`, already wired — this page never sees the code).
///
/// `/api/consent/request` answers a constant `{"sent": true}` regardless of
/// whether the address is known (see the plan's Task 6), so a successful
/// [onSubmit] means "the server accepted the request", never "delivery is
/// confirmed". Nothing here is persisted — no email, no "we already asked"
/// flag — so leaving and re-entering this flow always starts fresh.
class ConsentRequestPage extends StatefulWidget {
  final String? country;

  /// Returns a [ConsentActionResult], not a bare bool, so this screen can
  /// tell "the request never reached the server" ([ConsentFailure.network] —
  /// offline, timeout, DNS) apart from "the server rejected it"
  /// ([ConsentFailure.rejected]). Collapsing those to one boolean would make
  /// it impossible to avoid claiming "we emailed your parent" when nothing
  /// was ever sent.
  final Future<ConsentActionResult> Function(String email) onSubmit;

  /// The child got the code from their parent and wants to type it in. The
  /// caller is responsible for getting back to the normal PIN/code screen —
  /// this page does not know how it is hosted (in-place state swap vs a
  /// pushed route).
  final VoidCallback onEnterCode;

  /// Leaves this screen — offered on both the form and the waiting screen.
  /// Waiting for the parent must never trap the child here.
  final VoidCallback onBack;

  /// How long the waiting screen stays before offering the code field. 10s
  /// per the bug report this flow originates from; overridable so tests
  /// don't need to sleep for real.
  final Duration waitingDuration;

  const ConsentRequestPage({
    super.key,
    required this.onSubmit,
    required this.onEnterCode,
    required this.onBack,
    this.country,
    this.waitingDuration = const Duration(seconds: 10),
  });

  @override
  State<ConsentRequestPage> createState() => _ConsentRequestPageState();
}

class _ConsentRequestPageState extends State<ConsentRequestPage> {
  final TextEditingController _email = TextEditingController();
  bool _waiting = false;
  bool _sending = false;
  bool _canEnterCode = false;
  String? _error;
  Timer? _timer;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();

    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = AppStrings.consentEmailInvalid);
      return;
    }

    setState(() {
      _error = null;
      _sending = true;
    });

    final result = await widget.onSubmit(email);

    if (!mounted) return;

    setState(() {
      _sending = false;
      // Only the waiting screen (which reads as "we emailed your parent")
      // may show once the server actually accepted the request. A network
      // failure means the request never left the device, so it stays on the
      // form with its own copy — never the generic "server said no" message,
      // and never the waiting screen's "we emailed your parent".
      _waiting = result.success;
      _error = result.success
          ? null
          : (result.failure == ConsentFailure.network
              ? AppStrings.consentNetworkError
              : AppStrings.consentGenericError);
    });

    if (result.success) {
      _timer = Timer(widget.waitingDuration, () {
        if (mounted) setState(() => _canEnterCode = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _waiting ? _buildWaitingContent() : _buildFormContent();

    // Wide windows keep the illustrated hero scene on screen and put this
    // step in the right-hand panel, exactly where the login form sits — the
    // consent request is a stop on the same journey, not a context switch.
    if (context.isExpanded) {
      return AuthHeroScaffold(onBack: widget.onBack, panel: content);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // On the waiting screen too: the 10s delay before the code
              // option appears must never read as "you're stuck here" — the
              // child can back out at any point.
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              ),
              const Spacer(),
              content,
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.consentIntroTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading3(),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.consentIntroBody,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: AppStrings.consentEmailLabel,
            errorText: _error,
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: AppStrings.consentSend,
          arrow: true,
          onPressed: _sending ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildWaitingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentWaitingTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading3(),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.consentWaitingBody,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(),
        ),
        const SizedBox(height: 32),
        if (_canEnterCode)
          AuthPrimaryButton(
            label: AppStrings.consentEnterCode,
            arrow: true,
            onPressed: widget.onEnterCode,
          ),
      ],
    );
  }
}
