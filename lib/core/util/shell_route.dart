import 'package:flutter/material.dart';
import '../layout/breakpoints.dart';

/// Route for pages that redraw the shell chrome themselves (see `DetailShell`).
///
/// On a wide viewport the pushed page carries its own copy of the sidebar, so
/// the platform's slide transition drags the whole navigation across the
/// screen — it reads as the entire app jumping sideways rather than as the
/// content changing. A short cross-fade leaves the two identical sidebars
/// sitting still.
///
/// Phones keep the platform transition: there is no duplicated chrome there,
/// and the slide is the expected "going deeper" affordance.
Route<T> shellPageRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (context.widthClass == WidthClass.compact) {
    return MaterialPageRoute<T>(builder: builder);
  }

  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 100),
  );
}
