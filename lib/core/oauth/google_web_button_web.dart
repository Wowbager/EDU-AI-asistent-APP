import 'package:flutter/widgets.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

/// The Google Identity Services button, rendered by google_sign_in_web. A
/// click drives the sign-in flow; the result arrives on
/// `GoogleSignIn.instance.authenticationEvents` (see [GoogleOAuthClient]).
///
/// [GoogleOAuthClient.ensureInitialized] must have completed before this is
/// built, or the GIS SDK has no client ID to render against.
///
/// Google restricts how far the rendered button can be styled (branding
/// rules), so it can't perfectly match the custom Microsoft/Apple buttons.
/// The configuration below gets it as close as allowed: white outline theme,
/// large size, rounded, left-aligned logo, Czech "Sign in with Google" text.
///
/// GIS draws the button at a fixed pixel [width] (400 at most), and the
/// plugin centres it in an `overflow: hidden` box the size of its slot, so
/// [width] must not exceed the room the caller has — anything wider is cut
/// off on both sides, logo first (BR-N3MXDH). See `GoogleWebButtonSlot`.
Widget googleRenderedSignInButton({required double width}) {
  final plugin = GoogleSignInPlatform.instance;
  if (plugin is GoogleSignInPlugin) {
    return plugin.renderButton(
      configuration: GSIButtonConfiguration(
        theme: GSIButtonTheme.outline,
        size: GSIButtonSize.large,
        shape: GSIButtonShape.rectangular,
        text: GSIButtonText.signinWith,
        logoAlignment: GSIButtonLogoAlignment.left,
        minimumWidth: width,
        locale: 'cs',
      ),
    );
  }
  return const SizedBox.shrink();
}
