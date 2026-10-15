import 'package:flutter/material.dart';

import 'age_gate_page.dart';

/// What the user answered on the age gate.
enum AgeGateOutcome {
  /// At or above the confirmed country's threshold — carry on.
  oldEnough,

  /// Under the threshold: the guardian consent flow takes over.
  needsConsent,

  /// Backed out of the gate without answering.
  dismissed,
}

/// The gate's answer, plus the country it was confirmed against (only ever
/// set for [AgeGateOutcome.needsConsent] — the consent request needs it to
/// pick the right threshold and email locale).
class AgeGateResult {
  final AgeGateOutcome outcome;
  final String? country;

  const AgeGateResult(this.outcome, [this.country]);
}

/// Shows [AgeGatePage] as a full-screen route and resolves once it is
/// answered.
///
/// The gate guards *account creation*, not sign-in — signing into an account
/// that already exists asks nothing, because that account passed the gate
/// when it was made (BR-N9Y48J). Call sites therefore await this immediately
/// before the step that would create the account (the OAuth credential
/// exchange, the magic-link registration branch) rather than in front of the
/// login form. The answer is never persisted, so an abandoned flow gets asked
/// again next time — see [AgeGatePage].
Future<AgeGateResult> showAgeGate(BuildContext context) async {
  final result = await Navigator.of(context).push<AgeGateResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (routeContext) => AgeGatePage(
        onOldEnough: () => Navigator.of(routeContext)
            .pop(const AgeGateResult(AgeGateOutcome.oldEnough)),
        onNeedsConsent: (country) => Navigator.of(routeContext)
            .pop(AgeGateResult(AgeGateOutcome.needsConsent, country)),
        onBack: () => Navigator.of(routeContext).pop(),
      ),
    ),
  );

  // A pop with no result is a dismissal — the software back arrow on the
  // country step, or a system back once the gate has nothing left to step
  // back through.
  return result ?? const AgeGateResult(AgeGateOutcome.dismissed);
}
