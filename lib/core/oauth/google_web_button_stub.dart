import 'package:flutter/widgets.dart';

/// Native platforms use the imperative sign-in button, so this renders nothing.
Widget googleRenderedSignInButton({required double width}) =>
    const SizedBox.shrink();
