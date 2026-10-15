import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/breakpoints.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/avatar_display.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_view.dart';
import '../widgets/detail_shell.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/nav_destinations.dart';
import '../widgets/shop_item_card.dart';

/// Root of the wide-window shop layout (mascot pane + item panel). Exposed
/// so tests can assert which layout is live.
const Key shopWideKey = Key('shop-wide');

/// Avatar cosmetics shop.
///
/// Everything on this screen resolves from the local database, so it works
/// offline: the catalog, the artwork and the worn outfit are all cached. The
/// one action that genuinely needs a connection is *acquiring* an item — only
/// the server can grant ownership.
class ShopPage extends ConsumerStatefulWidget {
  /// True when the editor was opened from "Můj účet" instead of Doplňky, so
  /// the sidebar keeps its highlight on the account block rather than jumping
  /// to a destination the user never tapped (BR-KB7XSJ).
  final bool fromAccount;

  const ShopPage({super.key, this.fromAccount = false});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  /// Tab order from the design, extended with the slots the artwork added.
  static const _tabs = <AvatarSlot>[
    AvatarSlot.head,
    AvatarSlot.face,
    AvatarSlot.eyes,
    AvatarSlot.mouth,
    AvatarSlot.neck,
    AvatarSlot.hands,
    AvatarSlot.held,
    AvatarSlot.legs,
    AvatarSlot.torso,
  ];

  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    // Reachable from the sidebar on tablet/desktop, so it redraws the
    // navigation rather than replacing the whole window (BR-KN9XUT).
    final isMobile = context.widthClass == WidthClass.compact;
    if (isMobile) return _buildScaffold(context, showHeader: true);

    return DetailShell(
      title: AppStrings.shopTitle,
      // Reached from Doplňky the user is still inside that destination, so the
      // sidebar keeps saying so one level down; reached from Můj účet the
      // account block is the row that has to stay lit instead.
      activePush: widget.fromAccount ? null : NavPush.doplnky,
      accountActive: widget.fromAccount,
      child: _buildScaffold(context, showHeader: false),
    );
  }

  Widget _buildScaffold(BuildContext context, {required bool showHeader}) {
    final avatarAsync = ref.watch(avatarControllerProvider);

    return Scaffold(
      // The phone layout is a white sheet with its own header. Inside the
      // shell that white ran on beside the sidebar and read as a page that had
      // lost its background, so wide layouts take the app's (BR-WJMTUF).
      backgroundColor: showHeader ? AppColors.surface : AppColors.background,
      body: SafeArea(
        bottom: false,
        child: avatarAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildError(),
          data: (state) =>
              _buildContent(context, state, showHeader: showHeader),
        ),
      ),
    );
  }

  /// Genuine load failure. Reaching this needs local storage itself to be
  /// broken — a lost connection resolves to the cached catalog instead.
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppStrings.shopLoadFailed,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge(color: AppColors.primaryDark64),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ref.invalidate(avatarControllerProvider),
            child: Text(AppStrings.shopRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AvatarState state, {
    required bool showHeader,
  }) {
    // Landscape tablet / desktop: mascot pane + item panel. Runs inside
    // [DetailShell], which supplies the sidebar and the page title
    // (BR-KN9XUT, BR-WJMTUF).
    if (context.isExpanded) return _buildWideContent(context, state);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Wide layouts get the title from DetailShell's top bar instead.
          if (showHeader) _buildHeader(context),
          // Only worth saying when the cache is actually all there is. With a
          // catalog on screen the user can shop normally, and a banner over a
          // working screen is noise.
          if (state.fromCache && state.catalog.isEmpty) _buildOfflineNotice(),
          const SizedBox(height: 16),
          _buildAvatarPreview(state),
          const SizedBox(height: 24),
          _buildItemsSection(
            state,
            backdrop: showHeader ? AppColors.surface : AppColors.background,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Landscape tablet / desktop: the mascot fills the left pane while the
  /// shop itself — slot tabs and item grid — sits in a right-hand panel,
  /// mirroring the auth journey's split layout. Runs inside [DetailShell]
  /// (BR-KN9XUT), so the page title lives in the shell's top bar, not here.
  Widget _buildWideContent(BuildContext context, AvatarState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Panel ratio from the shell's content area, not the window — the
        // sidebar has already taken its share of the width.
        final panelWidth = authPanelWidth(constraints.maxWidth);

        return Row(
          key: shopWideKey,
          // Stretch, so the panel spans the full height like the auth panel
          // does even while the catalog is still short.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 480, maxHeight: 480),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AvatarView.fromState(state),
                  ),
                ),
              ),
            ),
            Padding(
              // Same insets as the auth panel, so the two split layouts read
              // as one family.
              padding: const EdgeInsets.fromLTRB(0, 24, 20, 28),
              child: SizedBox(
                width: panelWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // The auth panel's own wash is too dark under the tile
                      // labels this panel carries (BR-YXSVVC).
                      gradient: AppColors.contentPanelGradient,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.fromCache && state.catalog.isEmpty)
                            _buildOfflineNotice(),
                          // Labels sit on the wash, so they have to clear its
                          // darkest point, not the white it starts from.
                          _buildItemsSection(
                            state,
                            backdrop: AppColors.contentPanelEnd,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────

  /// Two-row header: back button, then the page title underneath.
  /// Deliberately not [PageHeader] — that widget puts the title inline with
  /// the back button, the design stacks them.
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: AppDecorations.circleButton,
                  child: Icon(Icons.arrow_back,
                      color: AppColors.primaryDark, size: 24),
                ),
              ),
              // No balance badge while items are free — showing a currency the
              // shop does not charge would be a lie.
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(AppStrings.shopTitle, style: AppTextStyles.heading1()),
        ],
      ),
    );
  }

  Widget _buildOfflineNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryDark06,
          borderRadius: AppDecorations.radiusL,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 18, color: AppColors.primaryDark64),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.shopOfflineNotice,
                style: AppTextStyles.meta(color: AppColors.primaryDark80),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(avatarControllerProvider),
              child: Text(AppStrings.shopRetry),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar preview ──────────────────────────────────────────

  Widget _buildAvatarPreview(AvatarState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 280,
        // Square and as wide as the screen allows: the view crops to the
        // figure itself, so the height is what the avatar actually gets rather
        // than mostly empty canvas.
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: AvatarView.fromState(state),
          ),
        ),
      ),
    );
  }

  // ── Items ───────────────────────────────────────────────────

  Widget _buildItemsSection(AvatarState state, {required Color backdrop}) {
    final slot = _tabs[_selectedTab];
    final items = state.itemsForSlot(slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(AppStrings.shopPermanentItems,
              style: AppTextStyles.heading3()),
        ),
        const SizedBox(height: 16),
        FilterChipRow(
          labels: [for (final s in _tabs) s.label],
          selectedIndex: _selectedTab,
          onSelected: (i) => setState(() => _selectedTab = i),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: items.isEmpty
              ? Text(
                  AppStrings.shopEmptySlot,
                  style: AppTextStyles.meta(color: AppColors.primaryDark80),
                )
              : _buildGrid(context, state, items, backdrop),
        ),
      ],
    );
  }

  /// Item grid sized from the available width.
  ///
  /// A fixed three-column, fixed-aspect-ratio grid was tuned for a phone and
  /// fell apart on the web build: three tiles across a 1600 px viewport are
  /// ~520 px wide, and the aspect ratio then reserved a cell ~350 px taller
  /// than the content, which read as huge vertical gaps and none sideways.
  ///
  /// So: a target tile width decides the column count, and the row height is
  /// computed from that tile plus the text under it rather than guessed from a
  /// ratio. No slack at any width, and tiles stay a sane size on a desktop.
  Widget _buildGrid(
    BuildContext context,
    AvatarState state,
    List<AvatarItem> items,
    Color backdrop,
  ) {
    const spacing = 12.0;
    const targetTile = 150.0;

    // Gaps under the artwork plus the three text lines. The line part is run
    // through the text scaler so a large system font setting grows the row
    // rather than clipping the slot label off the bottom.
    final textBlock = 10 + MediaQuery.textScalerOf(context).scale(58);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Never fewer than the three the design was drawn for — on a narrow
        // phone one target-width tile would otherwise win.
        final columns = max(
          3,
          ((width + spacing) / (targetTile + spacing)).floor(),
        );
        final tile = (width - spacing * (columns - 1)) / columns;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 20,
            mainAxisExtent: tile + textBlock,
          ),
          itemBuilder: (context, i) => ShopItemCard(
            item: items[i],
            backdrop: backdrop,
            isEquipped: state.isEquipped(items[i]),
            onTap: () => _onItemTap(state, items[i]),
          ),
        );
      },
    );
  }

  /// One tap does the obvious next thing: acquire it, wear it, or take it off.
  ///
  /// A three-state tap beats a detail sheet here — the grid is the whole
  /// screen, and every step between "I like that hat" and seeing it on the
  /// avatar is a step children abandon.
  Future<void> _onItemTap(AvatarState state, AvatarItem item) async {
    final controller = ref.read(avatarControllerProvider.notifier);

    try {
      if (!item.owned) {
        await controller.purchase(item);
        await controller.equip(item);
        return;
      }

      if (state.isEquipped(item)) {
        // Default items are what a slot falls back to, so taking one off would
        // leave a hole in the avatar rather than give the user a choice.
        if (!item.isDefault) await controller.unequip(item.slot);
        return;
      }

      await controller.equip(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.shopPurchaseFailed)),
      );
    }
  }
}
