import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/consent_repository.dart';

/// Shared "send me the link again" form used everywhere a parent needs a
/// fresh consent-management magic link: the confirm page's mail-failed
/// success state, its invalid-link state, and the manage page's
/// expired-link state.
///
/// The endpoint answers a constant result regardless of whether the address
/// is known ([ConsentFailure.rejected] included) — that anti-enumeration
/// property is deliberate and preserved here: a rejected response still
/// shows the neutral "if we know it, it's on its way" copy.
///
/// [ConsentFailure.network] is different in kind, not degree: the request
/// never reached the server, so nothing was sent to anyone. Claiming "it's
/// on its way" in that case would be the same false-success failure this
/// whole feature exists to avoid elsewhere (see `ConsentRequestPage`,
/// `ConsentManageWebPage._revoke`) — so it gets its own copy, and the form
/// stays up so the parent can retry once they're back online.
class ResendLinkForm extends StatefulWidget {
  final Future<ConsentActionResult> Function(String email) onRequestManageLink;

  const ResendLinkForm({super.key, required this.onRequestManageLink});

  @override
  State<ResendLinkForm> createState() => _ResendLinkFormState();
}

class _ResendLinkFormState extends State<ResendLinkForm> {
  final TextEditingController _email = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _validationError;
  String? _networkError;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() {
        _validationError = AppStrings.consentEmailInvalid;
        _networkError = null;
      });
      return;
    }

    setState(() {
      _validationError = null;
      _networkError = null;
      _sending = true;
    });

    final result = await widget.onRequestManageLink(email);
    if (!mounted) return;

    setState(() {
      _sending = false;
      if (result.failure == ConsentFailure.network) {
        // Nothing was actually sent — do not claim otherwise, and keep the
        // button available so the parent can try again.
        _networkError = AppStrings.consentNetworkError;
      } else {
        // Success and "we don't recognise this address" (a rejected
        // response) both land on the same neutral confirmation — that is
        // what keeps this anti-enumeration.
        _sent = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Text(
        AppStrings.consentManageResendSent,
        textAlign: TextAlign.center,
        style: AppTextStyles.body(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: AppStrings.consentEmailLabel,
            errorText: _validationError,
          ),
        ),
        if (_networkError != null) ...[
          const SizedBox(height: 8),
          Text(
            _networkError!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall(color: AppColors.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(AppStrings.consentManageResend),
        ),
      ],
    );
  }
}
