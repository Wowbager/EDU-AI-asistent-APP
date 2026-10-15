import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'custom_bottom_nav.dart';
import 'desktop_top_bar.dart';
import 'nav_destinations.dart';
import 'side_nav.dart';
import '../core/layout/breakpoints.dart';

/// Chooses the navigation chrome for the current viewport.
///
/// * mobile — the original floating bottom bar, untouched.
/// * tablet — icon rail on the left, no top bar (the extra 56px of vertical
///   chrome costs more than it gives on a short landscape screen).
/// * desktop — full labelled sidebar plus a top bar carrying the page title,
///   unless the page opts out of the bar via [showTopBar].
///
/// The shell owns the chrome only. Pages keep rendering their own content and
/// decide for themselves how it reflows — see `Breakpoints.gridColumns`.
class AdaptiveShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  /// Opens a sidebar destination that is a pushed route rather than a tab.
  final ValueChanged<NavPush>? onPushTapped;

  /// The selected tab's content.
  final Widget child;

  /// Title/subtitle for the desktop top bar.
  final String title;
  final String? subtitle;

  /// Full-width strips (shared-device warning, e-mail validation) shown above
  /// everything else, on every layout.
  final List<Widget> banners;

  /// Whether the desktop top bar is drawn above the page.
  ///
  /// Off for tabs whose content needs the full height: chat's two-pane layout
  /// puts its own heading in the list column, so a bar spanning both panes only
  /// pushed the conversation down and left the "new chat" button a row below
  /// the heading it belongs next to (BR-7VMQ2U).
  final bool showTopBar;

  final bool isGuest;

  /// Opens the profile — where settings and logout live, so the sidebar does
  /// not repeat either (BR-ATWZK8).
  final VoidCallback? onProfileTap;
  final VoidCallback? onRegisterTap;

  const AdaptiveShell({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.onPushTapped,
    required this.child,
    required this.title,
    this.subtitle,
    this.showTopBar = true,
    this.banners = const [],
    this.isGuest = false,
    this.onProfileTap,
    this.onRegisterTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = context.widthClass;
    if (size == WidthClass.compact) return _buildMobile(context);
    return _buildWide(context, expanded: size == WidthClass.expanded);
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top),
          ...banners,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: selectedIndex,
        onItemTapped: onItemTapped,
      ),
    );
  }

  Widget _buildWide(BuildContext context, {required bool expanded}) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SideNav(
            selectedIndex: selectedIndex,
            onItemTapped: onItemTapped,
            onPushTapped: onPushTapped,
            expanded: expanded,
            isGuest: isGuest,
            onProfileTap: onProfileTap,
            onRegisterTap: onRegisterTap,
            // With a sidebar the notices live in it rather than across the
            // top, so the content never shifts when one appears.
            notices: expanded && banners.isNotEmpty
                ? Column(mainAxisSize: MainAxisSize.min, children: banners)
                : null,
          ),
          Expanded(
            child: SafeArea(
              left: false,
              // Content runs the full width beside the sidebar — no centred
              // max-width box. Pages that need a reading measure cap
              // themselves.
              child: Column(
                children: [
                  if (!expanded) ...banners,
                  if (expanded && showTopBar)
                    DesktopTopBar(title: title, subtitle: subtitle),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
    );
  }
}
