/// Responsive layout primitives.
///
/// Until BR-UWJD4M the whole app was clamped to a 640px column in
/// `MaterialApp.builder`, so a 1780px browser window showed a phone floating in
/// the middle of the screen. The clamp is gone; width-dependent layout now lives
/// here and is applied per page instead of globally.
library;

import 'package:flutter/material.dart';

/// Material 3 window size classes, narrowed to the three the app cares about.
///
/// The [medium] cut-off is 900 rather than Material's 840: the design only
/// specifies a phone (390) and a desktop (1440) artboard, and a portrait tablet
/// (768–834) is too narrow for the split-pane layout — its hero pane would be
/// squeezed under 400px.
enum WidthClass {
  /// Phones. Unchanged from the pre-BR-UWJD4M layout.
  compact,

  /// Portrait tablets and small windows. Full-bleed, content still single-column.
  medium,

  /// Landscape tablets and desktop. Split-pane layouts are allowed here.
  expanded,
}

const double kCompactMaxWidth = 600;
const double kMediumMaxWidth = 900;

extension WidthClassX on BuildContext {
  WidthClass get widthClass {
    final width = MediaQuery.sizeOf(this).width;
    if (width < kCompactMaxWidth) return WidthClass.compact;
    if (width < kMediumMaxWidth) return WidthClass.medium;
    return WidthClass.expanded;
  }

  bool get isExpanded => widthClass == WidthClass.expanded;
}

/// Column count for card grids (courses, dashboard sections).
///
/// Derived from the *available* width, not the screen width — inside the shell
/// the content area is already narrowed by the sidebar, and a screen-based
/// count would overflow it.
int gridColumns(double availableWidth) {
  if (availableWidth < 520) return 1;
  if (availableWidth < 900) return 2;
  if (availableWidth < 1240) return 3;
  return 4;
}

/// Whether the dashboard has room for its right-hand rail (progress, current
/// lesson, recent activity) beside the main column.
bool hasSideRail(double availableWidth) => availableWidth >= 940;

/// Narrowest the course hero's action group (Lekce / Cvičení / Kvíz) stays
/// readable at. The three buttons split the width evenly and their labels are
/// not clipped, so below this they paint over each other (BR-BCNXAP).
const double kHeroActionsMinWidth = 340;

/// Widest the action group is drawn at, per the desktop artboard.
const double kHeroActionsMaxWidth = 420;

/// Roughly what the hero's "Uložit kurz" button measures — icon, gap, label and
/// padding. Only used to pick a layout, never to size the button itself.
const double kHeroSaveButtonWidth = 170;

/// Gap between the action group and the save button.
const double kHeroActionsGap = 12;

/// Whether [availableWidth] fits the course hero's action group *and* the save
/// button on one line.
///
/// Used twice: to decide whether the whole row still fits beside the course
/// icon, and — once it has dropped below the icon — whether the save button
/// stays on the same line as the three action buttons.
bool heroActionRowFits(double availableWidth) =>
    availableWidth >=
    kHeroActionsMinWidth + kHeroActionsGap + kHeroSaveButtonWidth;

/// Width of the white auth panel in the split-pane login.
///
/// The design puts it at 48% of a 1440px artboard (691px). A pure ratio would
/// give 922px on a 1920px display — 230px wider than anything that was drawn —
/// so it is clamped at both ends. The lower bound keeps the hero pane usable at
/// the [WidthClass.expanded] threshold.
double authPanelWidth(double screenWidth) =>
    (screenWidth * 0.48).clamp(420.0, 720.0);

/// Centres [child] and caps how wide it may grow.
///
/// Replaces the old global clamp: pages opt in with a width that suits their
/// content instead of every screen inheriting 640px, dialogs and bottom sheets
/// included.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  /// Long-form reading (lessons, quizzes, legal text) — keeps the line length
  /// readable rather than letting text run the full width of a monitor.
  static const double reading = 720;

  /// Lists, dashboards and card grids, which tolerate more width.
  static const double browsing = 1100;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
