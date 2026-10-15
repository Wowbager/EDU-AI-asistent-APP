import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/breakpoints.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/util/drag_scroll_behavior.dart';
import '../core/util/shell_route.dart';
import '../core/util/silent_log.dart';
import '../games/mini_game_registry.dart';
import '../models/mini_game_model.dart';
import '../widgets/avatar_view.dart';
import '../widgets/detail_shell.dart';
import '../widgets/nav_destinations.dart';
import '../widgets/page_header.dart';
import 'shop_page.dart';
import 'theme_selector_page.dart';

/// Extras listing ("Doplňky"): mini games, the avatar editor and the theme
/// editor on one page, each as a card in the mini-games style.
///
/// Every game's playability is decided by the server and rendered verbatim —
/// this page never computes a lock itself, so what the user sees and what the
/// API allows cannot drift apart. The two editor cards are local features and
/// render even when the games listing is loading or failed.
class DoplnkyPage extends ConsumerStatefulWidget {
  const DoplnkyPage({super.key});

  @override
  ConsumerState<DoplnkyPage> createState() => _DoplnkyPageState();
}

class _DoplnkyPageState extends ConsumerState<DoplnkyPage> {
  /// True while an attempt is being booked, so a double tap cannot spend two.
  bool _starting = false;

  Future<void> _refresh() async {
    ref.invalidate(miniGamesListProvider);
    await ref.read(miniGamesListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    // Reachable from the sidebar on tablet/desktop, so it has to redraw the
    // navigation the way every other pushed page does — otherwise opening a
    // game drops the user out of the shell entirely (BR-KN9XUT).
    final isMobile = context.widthClass == WidthClass.compact;
    if (isMobile) return _buildPage(context, showHeader: true);

    return DetailShell(
      title: AppStrings.doplnkyTitle,
      subtitle: AppStrings.doplnkySubtitle,
      // This page *is* the sidebar's Doplňky destination, so the sidebar has
      // to light that row rather than the tab left behind underneath it.
      activePush: NavPush.doplnky,
      child: _buildPage(context, showHeader: false),
    );
  }

  Widget _buildPage(BuildContext context, {required bool showHeader}) {
    final gamesAsync = ref.watch(miniGamesListProvider);

    // Warm the avatar up while the listing is being browsed, so tapping Hrát
    // finds a composed avatar already in hand instead of waiting on one.
    ref.watch(avatarControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Wide layouts get the title and subtitle from DetailShell's top
            // bar instead — repeating them here would print each twice.
            if (showHeader) ...[
              PageHeader(title: AppStrings.doplnkyTitle),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppStrings.doplnkySubtitle,
                  style: AppTextStyles.body(color: AppColors.primaryDark48),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ScrollConfiguration(
                behavior: const DragScrollBehavior(),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: [
                      ..._buildGamesSection(gamesAsync),
                      _buildEditorCard(
                        icon: Icons.checkroom_rounded,
                        title: AppStrings.doplnkyAvatarTitle,
                        perex: AppStrings.doplnkyAvatarPerex,
                        onOpen: _openAvatarEditor,
                      ),
                      const SizedBox(height: 16),
                      _buildEditorCard(
                        icon: Icons.palette_outlined,
                        title: AppStrings.doplnkyThemeTitle,
                        perex: AppStrings.doplnkyThemePerex,
                        onOpen: _openThemeEditor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The games portion of the list. Loading and errors stay inside this
  /// section so the editor cards below are always reachable.
  ///
  /// Only games this build has an engine for are listed — the server may
  /// announce a game before its client ships, and a "coming soon" card has no
  /// place between the editors here.
  List<Widget> _buildGamesSection(AsyncValue<MiniGameList> gamesAsync) {
    return gamesAsync.when(
      data: (list) => [
        for (final game in list.items.where(hasEngineFor)) ...[
          _buildGameCard(game),
          const SizedBox(height: 16),
        ],
      ],
      loading: () => const [
        SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
        SizedBox(height: 16),
      ],
      error: (error, stack) => [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.cardDecorationLight,
          child: Column(
            children: [
              Text(
                AppStrings.miniGamesError,
                style: AppTextStyles.body(color: AppColors.primaryDark64),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(miniGamesListProvider),
                child: Text(AppStrings.miniGamesRetry),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Editor cards ────────────────────────────────────────────────────────

  Widget _buildEditorCard({
    required IconData icon,
    required String title,
    required String perex,
    required VoidCallback onOpen,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryDark08,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.heading3()),
          const SizedBox(height: 8),
          Text(
            perex,
            style: AppTextStyles.body(color: AppColors.primaryDark48),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onOpen,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppDecorations.radiusS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.doplnkyOpen,
                      style: AppTextStyles.actionSmall(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAvatarEditor() {
    Navigator.of(context).push(
      shellPageRoute(context, builder: (_) => const ShopPage()),
    );
  }

  void _openThemeEditor() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ThemeSelectorPage(
          onBack: () => navigator.pop(),
          // Same belt and braces as the profile entry: the selector reports
          // every apply/save, so this page is never left painted in the
          // previous palette (BR-W3XQ5K).
          onThemeChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  // ── Game card ───────────────────────────────────────────────────────────

  Widget _buildGameCard(MiniGame game) {
    final locked = !game.isPlayable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumb(game),
              const Spacer(),
              if (game.sensor != null) ...[
                Text(
                  _sensorLabel(game.sensor!),
                  style: AppTextStyles.meta(color: AppColors.primaryDark48),
                ),
                const SizedBox(width: 12),
              ],
              if (game.durationMinutes != null) ...[
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppColors.primaryDark48,
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.miniGamesDuration(game.durationMinutes!),
                  style: AppTextStyles.meta(color: AppColors.primaryDark48),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            game.title,
            style: AppTextStyles.heading3(
              color: locked ? AppColors.primaryDark48 : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            game.perex,
            style: AppTextStyles.body(color: AppColors.primaryDark48),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatus(game)),
              const SizedBox(width: 12),
              _buildPlayButton(game),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(MiniGame game) {
    const size = 56.0;

    if (game.imageUrl == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primaryDark08,
          shape: BoxShape.circle,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        game.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A missing thumbnail must never blank the whole card.
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primaryDark08,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  /// The line under the description: attempts left, or why the game is locked.
  Widget _buildStatus(MiniGame game) {
    final text = _statusText(game);
    if (text == null) return const SizedBox.shrink();

    // The level gate is a standalone label in the design; the time- and
    // attempt-based states are prefixed with the play glyph.
    final showIcon = game.lockReason != MiniGameLock.level;

    return Row(
      children: [
        if (showIcon) ...[
          Icon(
            Icons.play_arrow_outlined,
            size: 16,
            color: AppColors.primaryDark48,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta(color: AppColors.primaryDark48),
          ),
        ),
      ],
    );
  }

  String? _statusText(MiniGame game) {
    switch (game.lockReason) {
      case MiniGameLock.level:
        return AppStrings.miniGamesMinLevel(game.minLevel);
      case MiniGameLock.offline:
        return AppStrings.miniGamesOffline;
      case MiniGameLock.attempts:
      case MiniGameLock.cooldown:
        final unlocksAt = game.unlocksAt;
        if (unlocksAt == null) return null;
        return AppStrings.miniGamesUnlocksIn(
          unlocksAt.difference(DateTime.now()),
        );
      case null:
        // Playable: show the quota when there is one.
        final left = game.attemptsLeft;
        return left == null ? null : AppStrings.miniGamesAttempts(left);
    }
  }

  Widget _buildPlayButton(MiniGame game) {
    final enabled = game.isPlayable;

    return GestureDetector(
      onTap: enabled ? () => _onPlay(game) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.disabledButton,
          borderRadius: AppDecorations.radiusS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: enabled ? Colors.white : AppColors.primaryDark32,
            ),
            const SizedBox(width: 6),
            Text(
              AppStrings.miniGamesPlay,
              style: AppTextStyles.actionSmall(
                color: enabled ? Colors.white : AppColors.primaryDark32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Start a run: book the attempt, play, report the score.
  ///
  /// The order is deliberate. The attempt is spent *before* the engine opens,
  /// because that call is also the server's final say on whether the user may
  /// play at all — the listing's verdict can be minutes stale. Games this build
  /// has no engine for never reach that call, so an unshipped game cannot burn
  /// a daily attempt.
  Future<void> _onPlay(MiniGame game) async {
    if (_starting) return;

    if (!hasEngineFor(game)) {
      _showMessage(AppStrings.miniGamesComingSoon);
      return;
    }

    setState(() => _starting = true);
    final MiniGameRun run;
    try {
      run = await ref.read(miniGamesRepositoryProvider).play(game.code);
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      // Either the entitlement moved under us or the device is offline. Either
      // way the listing is now the stale party, so refetch it.
      ref.invalidate(miniGamesListProvider);
      _showMessage(AppStrings.miniGamesLocked);
      return;
    }

    if (!mounted) return;
    setState(() => _starting = false);

    final avatarSprite = await _rasterizeAvatar();
    if (!mounted) {
      avatarSprite?.dispose();
      return;
    }

    final engine = buildMiniGame(
      game,
      seed: DateTime.now().millisecondsSinceEpoch,
      avatarSprite: avatarSprite,
    );
    if (engine == null) {
      avatarSprite?.dispose();
      _showMessage(AppStrings.miniGamesStartFailed);
      return;
    }

    final outcome = await Navigator.of(context).push<MiniGameOutcome>(
      MaterialPageRoute(builder: (_) => engine),
    );

    // The sprite outlives the route only long enough to be released here; the
    // engine never owns it, so it cannot be leaked by a game that forgets.
    avatarSprite?.dispose();

    final playId = run.playId;
    if (outcome != null && playId != null) {
      // Best effort: the run is over and paid for, so a failed report is not
      // the player's problem. This is also what banks the coins the run
      // collected (BR-HK9828).
      final reported = await ref
          .read(miniGamesRepositoryProvider)
          .submitScore(playId, outcome.score, outcome.coins);

      // The server owns the wallet, so the coins it just banked are only
      // knowable by asking. Without this the student finishes a run and the
      // Achievements screen still shows the old total until something else
      // happens to sync (BR-HK9828).
      if (reported && outcome.coins > 0) {
        final user = await ref.read(appDatabaseProvider).getActiveUser();
        if (user != null) {
          await ref.read(userStatsRepositoryProvider).syncFromServer(user.id);
        }
      }
    }

    // The attempt is spent whatever happened — the card must show that.
    ref.invalidate(miniGamesListProvider);
  }

  /// Flatten the player's avatar into a sprite the game can blit each frame.
  ///
  /// Reads whatever the avatar provider has already resolved rather than
  /// awaiting it: the listing warms that provider up while the user browses
  /// (see [build]), and a run must never be held up — let alone blocked — by
  /// artwork. Nothing resolved yet means no sprite, and the engine falls back
  /// to its primitive player.
  Future<ui.Image?> _rasterizeAvatar() async {
    try {
      final state = ref.read(avatarControllerProvider).value;
      if (state == null) return null;

      return await AvatarRasterizer.rasterize(state.equippedLayers);
    } catch (e, st) {
      silentLog('minigames:avatar', e, st);
      return null;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _sensorLabel(String sensor) => switch (sensor) {
        'gyroscope' => AppStrings.miniGamesSensorGyroscope,
        _ => sensor,
      };
}
