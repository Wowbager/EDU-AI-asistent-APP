import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/user_stats_repository.dart';
import 'nav_destinations.dart';
import 'user_avatar.dart';

/// Left-hand navigation for tablet and desktop.
///
/// Two shapes, same destinations (see [navDestinations]):
/// * [expanded] — logo, labelled rows, guest CTA and, at the very bottom, the
///   account block. Identity closes the sidebar; settings and logout are not
///   repeated here because the account block already opens the profile, which
///   carries both (BR-ATWZK8).
/// * collapsed — an icon rail for tablet-width windows where the full sidebar
///   would eat the content area.
///
/// The account block and the whole destination list live here rather than in a
/// top bar: on a wide viewport the sidebar is the one piece of chrome that is
/// always on screen, so putting the identity, the XP and every destination in
/// it means nothing is duplicated across the top of each page (BR-KN9XUT).
class SideNav extends ConsumerStatefulWidget {
  static const double expandedWidth = 264;

  /// Sized so the longest label fits on two lines without ellipsing — 88px
  /// truncated it.
  static const double railWidth = 96;

  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  /// Opens a destination that is a pushed route rather than a tab.
  final ValueChanged<NavPush>? onPushTapped;

  /// The push destination whose route is currently on screen, if any.
  ///
  /// A pushed page draws its own copy of this sidebar (see `DetailShell`) while
  /// the tab underneath has not moved. Without this the highlight would stay on
  /// whatever tab the user came from while a different page fills the content
  /// area (BR-WB6EUH).
  final NavPush? activePush;

  /// Show labels, the guest CTA and the notices. False renders the narrow
  /// icon rail.
  final bool expanded;

  /// Guests get the "sign up for full access" card above the account block.
  final bool isGuest;

  /// Tapping the account block (name, level, XP). The single way into the
  /// profile from the sidebar — and therefore into settings and logout.
  final VoidCallback? onProfileTap;

  /// The page on screen belongs to "Můj účet" — the profile itself, or the
  /// avatar editor reached from it.
  ///
  /// Same problem [activePush] solves, for the one destination that is not a
  /// row in the list: without it the sidebar keeps lighting the tab the user
  /// came from while "Můj účet" fills the content area (BR-5JSXBV). Lit is not
  /// the same as unreachable — [onProfileTap] decides that (BR-NYNNM8).
  final bool accountActive;

  final VoidCallback? onRegisterTap;

  /// Shared-device / e-mail-validation strips. On a phone these span the top
  /// of the screen; with a sidebar there is a natural column for them, and
  /// keeping them out of the content area means the page below does not shift
  /// when a notice appears or clears.
  final Widget? notices;

  const SideNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.onPushTapped,
    this.activePush,
    this.expanded = true,
    this.isGuest = false,
    this.onProfileTap,
    this.accountActive = false,
    this.onRegisterTap,
    this.notices,
  });

  @override
  ConsumerState<SideNav> createState() => _SideNavState();
}

/// How much of the guest card the sidebar can still afford.
///
/// The destination list is the sidebar's job; the register card is a prompt.
/// So when the column runs short the card gives up its illustration, then its
/// headline, rather than pushing destinations below the fold (BR-3APJQC).
enum _CtaDensity { full, medium, compact, minimal }

class _SideNavState extends ConsumerState<SideNav> {
  /// Height each density costs the column — card plus the 12px gap under it.
  /// Measured, and only ever used to pick the tallest one that still fits.
  static const double _ctaFullHeight = 272;
  static const double _ctaMediumHeight = 232;
  static const double _ctaCompactHeight = 176;

  /// Starting guesses, so the first frame is already close and the card does
  /// not visibly shrink after it. Both are replaced by the real heights as
  /// soon as the first layout reports them.
  double _navContentHeight = navDestinations.length * 56.0;
  double _noticesHeight = 60;

  void _setNavContentHeight(double value) {
    if (!mounted || value == _navContentHeight) return;
    setState(() => _navContentHeight = value);
  }

  void _setNoticesHeight(double value) {
    if (!mounted || value == _noticesHeight) return;
    setState(() => _noticesHeight = value);
  }

  /// [available] is the height left between the logo and the account block.
  _CtaDensity _densityFor(double available) {
    // The last measured notice height is stale the moment the shell stops
    // sending notices — a shared-device session converted to "this is my
    // device" gives the card its illustration back.
    final notices = widget.notices == null ? 0.0 : _noticesHeight;
    final room = available - _navContentHeight - notices;
    if (room >= _ctaFullHeight) return _CtaDensity.full;
    if (room >= _ctaMediumHeight) return _CtaDensity.medium;
    if (room >= _ctaCompactHeight) return _CtaDensity.compact;
    return _CtaDensity.minimal;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = widget.expanded;
    final unread = ref.watch(unreadNewsCountProvider);
    final user = ref.watch(activeUserStreamProvider).valueOrNull;
    final stats = ref.watch(userStatsStreamProvider).valueOrNull;

    return Container(
      width: expanded ? SideNav.expandedWidth : SideNav.railWidth,
      height: double.infinity,
      color: AppColors.surface,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLogo(),
            const SizedBox(height: 16),
            // Everything between the logo and the account block shares one
            // budget. Reading it from a LayoutBuilder rather than adding up
            // constants means the sidebar knows exactly what it has to spend,
            // whatever the window height and the platform's safe areas.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final density = _densityFor(constraints.maxHeight);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The nav list still scrolls as a last resort, so the
                      // account block never gets pushed off-screen (laptop +
                      // open keyboard, tiny window) — it is the only way into
                      // the profile from here.
                      Expanded(
                        child: SingleChildScrollView(
                          child: _MeasureHeight(
                            onChange: _setNavContentHeight,
                            child: Column(
                              children: [
                                for (final destination in navDestinations)
                                  _NavRow(
                                    destination: destination,
                                    // A pushed route wins over the tab
                                    // underneath: the shell keeps sitting on
                                    // whatever tab the user left, but that tab
                                    // is not what is on screen. Either/or, so
                                    // exactly one row is ever lit.
                                    isSelected: widget.activePush != null
                                        ? destination.push == widget.activePush
                                        : destination.index != null &&
                                            widget.selectedIndex ==
                                                destination.index,
                                    expanded: expanded,
                                    badgeCount:
                                        destination.showsNewsBadge ? unread : 0,
                                    onTap: () {
                                      final index = destination.index;
                                      if (index != null) {
                                        widget.onItemTapped(index);
                                      } else {
                                        widget.onPushTapped
                                            ?.call(destination.push!);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (expanded) ...[
                        if (widget.notices != null)
                          _MeasureHeight(
                            onChange: _setNoticesHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: ClipRRect(
                                borderRadius: AppDecorations.radiusL,
                                child: widget.notices,
                              ),
                            ),
                          ),
                        if (widget.isGuest) ...[
                          _buildGuestCta(density),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
            _AccountBlock(
              name: (user?.name ?? '').trim().isEmpty
                  ? AppStrings.defaultUserName
                  : user!.name,
              avatarIndex: user?.avatarIndex ?? 0,
              stats: stats,
              expanded: expanded,
              onTap: widget.onProfileTap,
              isSelected: widget.accountActive,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final expanded = widget.expanded;
    return Padding(
      padding: EdgeInsets.fromLTRB(expanded ? 24 : 16, 24, 16, 0),
      child: Align(
        alignment: expanded ? Alignment.centerLeft : Alignment.center,
        child: SvgPicture.asset(
          'assets/logo.svg',
          height: expanded ? 40 : 28,
          fit: BoxFit.contain,
          colorFilter:
              ColorFilter.mode(AppColors.progressFill, BlendMode.srcIn),
        ),
      ),
    );
  }

  /// The register card, at the largest size the column can pay for.
  ///
  /// The illustration goes first because it is decoration; the headline goes
  /// next because the button underneath says the same thing in fewer words.
  /// What never goes is the button itself — a guest must always have the way
  /// out of a guest account in front of them.
  Widget _buildGuestCta(_CtaDensity density) {
    final imageHeight = switch (density) {
      _CtaDensity.full => 88.0,
      _CtaDensity.medium => 48.0,
      _CtaDensity.compact || _CtaDensity.minimal => null,
    };
    final showTitle = density != _CtaDensity.minimal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppDecorations.radiusL,
        ),
        child: Column(
          children: [
            if (imageHeight != null) ...[
              Image.asset(
                'assets/images/skins_bg.png',
                height: imageHeight,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
            ],
            if (showTitle) ...[
              Text(
                AppStrings.shellGuestCtaTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySemiBold(),
              ),
              const SizedBox(height: 12),
            ],
            GestureDetector(
              onTap: widget.onRegisterTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppDecorations.radiusM,
                  boxShadow: AppDecorations.shadowMedium,
                ),
                child: Text(
                  AppStrings.shellGuestCtaButton,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.actionSmall(color: AppColors.surface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reports how tall its child ended up.
///
/// The sidebar has to know two heights it cannot derive: the notices the shell
/// handed it (a foreign widget) and the destination list at the user's text
/// scale. Both are laid out with all the room they ask for and neither depends
/// on the guest card, so feeding them back into the next build settles in one
/// extra frame instead of oscillating.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onChange;

  const _MeasureHeight({required this.onChange, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size.height) return;
    _reported = size.height;
    // Layout is in flight, so the listener cannot call setState yet.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(_reported!));
  }
}

/// Who is signed in, and how far they have got.
///
/// The layout the design asks for is name on top, XP underneath — so this is a
/// two-line block rather than the single pill the top bar used to carry. The
/// rail has no room for the name, so it shows the avatar with the level badge
/// on it and the XP underneath — on tablet widths nothing else carries the XP
/// (BR-H98WYB).
///
/// Since the settings/logout icons went away it is also the sidebar's only door
/// to the profile, so it carries a chevron and the "My account" tooltip and
/// semantic label — an avatar on its own does not read as a control.
class _AccountBlock extends StatelessWidget {
  final String name;
  final int avatarIndex;
  final UserStats? stats;
  final bool expanded;
  final VoidCallback? onTap;

  /// A "Můj účet" page is on screen. Marked with an outline rather than the
  /// solid fill a selected [_NavRow] gets: this block carries a name, an XP
  /// line and an avatar, and inverting all three for the current page turns
  /// the quietest corner of the sidebar into its loudest.
  final bool isSelected;

  const _AccountBlock({
    required this.name,
    required this.avatarIndex,
    required this.stats,
    required this.expanded,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = _Avatar(
      avatarIndex: avatarIndex,
      level: stats?.level ?? 1,
      size: expanded ? 40 : 36,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 8),
      child: Tooltip(
        message: AppStrings.profileTitle,
        // Merged so the name and the XP line read as one "My account" button
        // rather than three loose nodes a screen reader walks past.
        child: MergeSemantics(
          child: Semantics(
            button: true,
            label: AppStrings.profileTitle,
            child: Material(
              color: AppColors.background,
              // `shape` rather than `borderRadius` — Material asserts the two
              // are never supplied together, and the selected state needs the
              // side.
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.radiusM,
                side: isSelected
                    ? BorderSide(color: AppColors.primary, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: AppDecorations.radiusM,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: expanded ? 12 : 8,
                    vertical: 10,
                  ),
                  child: expanded
                      ? Row(
                          children: [
                            avatar,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.actionSmall(),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${stats?.xpPoints ?? 0} XP',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.navLabel(
                                      color: AppColors.primaryDark64,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.primaryDark64,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            avatar,
                            const SizedBox(height: 6),
                            // The rail has no room for the name, but the XP
                            // has to live somewhere: on tablet widths this is
                            // the only place it is shown, now that the
                            // dashboard header is phone-only (BR-H98WYB).
                            Text(
                              '${stats?.xpPoints ?? 0} XP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.navLabel(
                                color: AppColors.primaryDark64,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's avatar with the level ring sitting on its corner.
class _Avatar extends StatelessWidget {
  final int avatarIndex;
  final int level;
  final double size;

  const _Avatar({
    required this.avatarIndex,
    required this.level,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(size: size, avatarIndex: avatarIndex),
          Positioned(
            right: -4,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Center(
                child: Text(
                  '$level',
                  style: AppTextStyles.badge(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final NavDestination destination;
  final bool isSelected;
  final bool expanded;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavRow({
    required this.destination,
    required this.isSelected,
    required this.expanded,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        isSelected ? AppColors.surface : AppColors.primaryDark;

    // A destination without a bespoke SVG falls back to a Material glyph
    // sized to match the 22px artwork.
    final asset = destination.iconAsset;
    final icon = asset != null
        ? SvgPicture.asset(
            asset,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
          )
        : Icon(destination.icon, size: 22, color: foreground);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 8, vertical: 4),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: AppDecorations.radiusM,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDecorations.radiusM,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 16 : 8,
              vertical: 12,
            ),
            child: expanded
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          destination.label(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.menuItem(color: foreground),
                        ),
                      ),
                      if (badgeCount > 0) _Badge(count: badgeCount),
                    ],
                  )
                : Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          icon,
                          if (badgeCount > 0)
                            Positioned(
                              top: -6,
                              right: -10,
                              child: _Badge(count: badgeCount),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination.label(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.navLabel(color: foreground),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}
