import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/consent/minor_mode.dart';
import '../core/layout/breakpoints.dart';
import '../core/providers/core_providers.dart';
import '../data/repositories/oauth_repository.dart';
import '../features/email_validation/presentation/email_validation_banner.dart';
import '../features/email_validation/providers/email_validation_providers.dart';
import 'shared_device_banner.dart';

/// The full-width strips that sit above every shell's content.
///
/// Shared by `AdaptiveShell` and `DetailShell` for two reasons: a shared-device
/// countdown should not disappear the moment you open a course, and — because
/// a pushed page redraws the chrome — a shell without them would sit the
/// content ~50px higher, which reads as the whole view jumping on navigation.
class ShellBanners extends ConsumerWidget {
  final VoidCallback onLogout;

  /// Rebuild hook for the shared-device banner after "this is my device".
  final VoidCallback? onConverted;

  /// Lets the e-mail validation dialog offer SSO. Null hides that section —
  /// pushed pages cannot reach the app-level OAuth handler.
  final ValueChanged<OAuthExchangeResult>? onOAuthSuccess;

  const ShellBanners({
    super.key,
    required this.onLogout,
    this.onConverted,
    this.onOAuthSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShared = ref.watch(sessionMetaProvider).sharedDevice;
    final showEmailBanner = ref.watch(showEmailValidationBannerProvider);
    // A minor can never self-register for a full account — the server rejects
    // it and never merges guest data into a minor's account — so the "sign up
    // for full access" prompt is a dead end for them (BR-8FDF37).
    final isMinor = ref.watch(minorModeProvider);

    // On expanded widths these notices sit in the sidebar, directly above the
    // guest "sign up for full access" card and its button — repeating the
    // same sentence in a banner one row higher reads as a bug. Registered-
    // but-unverified users keep their banner: the card is guest-only.
    //
    // Must be the exact predicate `SideNav` gates the card on, or the two
    // disagree and the banner hides with no card to replace it (BR-7CDXBR).
    final guestPromptCoveredByCta =
        ref.watch(canOfferSignupProvider) && context.isExpanded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isShared)
          SharedDeviceBanner(onLogout: onLogout, onConverted: onConverted),
        if (showEmailBanner && !isMinor && !guestPromptCoveredByCta)
          EmailValidationBanner(onOAuthSuccess: onOAuthSuccess),
      ],
    );
  }
}
