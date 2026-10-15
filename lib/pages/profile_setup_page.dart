import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../core/consent/minor_mode.dart';
import '../core/database/app_database.dart';
import '../core/providers/core_providers.dart';
import '../core/sync/sync_queue.dart';
import '../core/theme/app_theme.dart';
import '../core/util/silent_log.dart';
import '../core/util/svg_bounds.dart';
import '../features/email_validation/providers/email_validation_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/layout/breakpoints.dart';
import '../models/avatar_model.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/avatar_view.dart';

/// Sign-up onboarding: one pass through nickname + color profile, then the
/// avatar "vibe" step. Runs when an account is being created (the legacy
/// sign-up path — a new local user row is created and the guest's data
/// migrated onto it) and when an account still has no profile to speak of
/// (update-in-place: the active row is edited, never replaced). A returning
/// account never comes through here — it goes straight to the app
/// (BR-D27TFA, see `routing/login_destination.dart`).
class ProfileSetupPage extends ConsumerStatefulWidget {
  /// The email address entered by the user on the auth page. Empty for
  /// logins that never asked for one (PIN / login-code).
  final String email;

  /// Whether the email has been validated (false if user skipped verification when offline).
  final bool isEmailValidated;

  /// Callback when profile setup is complete.
  final VoidCallback onComplete;

  const ProfileSetupPage({
    super.key,
    required this.email,
    this.isEmailValidated = true,
    required this.onComplete,
  });

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage>
    with ThemeAwareState {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  /// 0 = nickname + color profile, 1 = avatar vibe.
  int _step = 0;

  /// Whether Continue edits the already-active account row instead of
  /// creating a new one. True when the page was reached by logging into an
  /// existing account (PIN / login-code — no email — or the same email that
  /// is already active). The create+migrate path is only for sign-ups that
  /// bring a *different* identity than the active row (typically a guest
  /// upgrading to a full account).
  bool _updateInPlace = false;

  /// The color profiles offered by the design. "Lavender" is the bundled
  /// Default theme under its design name; the other three ship as their own
  /// theme JSONs and also appear in the profile's theme selector.
  static const _colorProfiles = <(String asset, String label)>[
    ('assets/themes/default.json', 'Lavender'),
    ('assets/themes/fire.json', 'Fire'),
    ('assets/themes/light.json', 'Light'),
    ('assets/themes/neutral.json', 'Neutral'),
  ];

  final List<(ThemeConfig, String)> _themes = [];
  String? _selectedThemeName;

  /// The accessory picked on the vibe step; null = the "no accessory" tile.
  AvatarItem? _selectedItem;
  bool _vibeInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedThemeName = ThemeManager.current.name;
    _loadThemes();

    // Pre-fill the nickname from the active account. For a minor the field
    // is locked (mirrors edit_profile_page.dart), so an empty field would
    // strand them on the "nickname required" check (BR-8FDF37); for a
    // first login into an existing account the current name is the obvious
    // starting value the user came to adjust.
    ref.read(appDatabaseProvider).getActiveUser().then((user) {
      if (!mounted || user == null) return;
      final matchesActive = widget.email.isEmpty ||
          widget.email.toLowerCase() == user.email.toLowerCase();
      setState(() {
        // An e-mail-less row is either a guest or a student who signed in
        // with a login code; auth_page flags the latter as a real account
        // via isEmailValidated. Re-creating that row would drop the flag
        // and leave a signed-in student looking like a guest (BR-7U6V36).
        _updateInPlace =
            matchesActive && (user.email.isNotEmpty || user.isEmailValidated);
        if ((_updateInPlace || ref.read(minorModeProvider)) &&
            user.name.isNotEmpty &&
            _nameController.text.isEmpty) {
          _nameController.text = user.name;
        }
        // A minor logging in with a code has an empty email but very much an
        // existing account — never re-create their row (BR-8FDF37).
        if (ref.read(minorModeProvider) && widget.email.isEmpty) {
          _updateInPlace = true;
        }
      });
    });
  }

  Future<void> _loadThemes() async {
    final loaded = <(ThemeConfig, String)>[];
    for (final (asset, label) in _colorProfiles) {
      try {
        final raw = await rootBundle.loadString(asset);
        loaded.add(
          (ThemeConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>), label),
        );
      } catch (e, st) {
        silentLog('profile_setup:themes', e, st);
      }
    }
    if (mounted) setState(() => _themes.addAll(loaded));
  }

  void _selectTheme(ThemeConfig config) {
    ThemeManager.apply(config);
    ThemeManager.saveSelectedTheme(config.name);
    setState(() => _selectedThemeName = config.name);
  }

  /// The fixed set of starter accessories the vibe step offers — two pairs
  /// the product chose as the "basic look": two for the face (glasses + mask)
  /// and two for the head (beanie + headphones). The rest of the catalog is
  /// left to the shop; onboarding stays a quick pick, not a scroll through
  /// everything (BR-ZHVC94). Order here is the order the tiles appear in.
  static const _vibeAccessoryCodes = <String>[
    'face_modre_bryle', // Modré brýle
    'face_maska_skraboska', // Škraboška
    'head_zimni_cepice', // Kulich (zimní čepice)
    'head_sluchatka', // Sluchátka
  ];

  /// Accessories on offer: the fixed starter set above, in that order,
  /// limited to what this account can wear now. Every starter ships free
  /// (price 0), but an item the catalog hasn't delivered yet — or can't draw
  /// — is skipped rather than shown as a broken tile. No purchases here.
  List<AvatarItem> _freeItems(AvatarState state) => _vibeAccessoryCodes
      .map((code) => state.byCode[code])
      .whereType<AvatarItem>()
      .where((i) => i.isDrawable && (i.price == 0 || i.owned))
      .toList();

  /// Pre-select whatever non-default accessory the account already wears, so
  /// a first login on a new device starts from the current look.
  void _initVibeSelection(AvatarState state, List<AvatarItem> items) {
    if (_vibeInitialized || items.isEmpty) return;
    _vibeInitialized = true;
    for (final code in state.equipped.values) {
      final worn = state.byCode[code];
      if (worn != null && !worn.isDefault) {
        _selectedItem = items.where((i) => i.code == worn.code).firstOrNull;
        if (_selectedItem != null) return;
      }
    }
  }

  Map<AvatarSlot, String> _previewEquipped(AvatarState state) {
    final equipped = Map<AvatarSlot, String>.from(state.equipped);
    // Strip non-default accessories so the "no accessory" tile really
    // previews a bare mascot; the base outfit (body, legs, face) stays.
    equipped.removeWhere((slot, code) {
      final item = state.byCode[code];
      return item != null && !item.isDefault;
    });
    final sel = _selectedItem;
    if (sel != null) {
      for (final conflict in sel.slot.conflicts) {
        equipped.remove(conflict);
      }
      equipped[sel.slot] = sel.code;
    }
    return equipped;
  }

  void _handleContinuePressed() {
    if (_step == 0) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.profileSetupNameError),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    _handleFinish();
  }

  Future<void> _handleFinish() async {
    // A minor's account already exists server-side with a pseudonymous name
    // — creating a fresh local user and migrating ALL of the minor's local
    // data onto it, only for the server to 403, orphans their real row
    // (BR-8FDF37). A minor may only ever complete this flow in place.
    if (ref.read(minorModeProvider) && !_updateInPlace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.minorNameLocked),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _step = 0);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      final String userId;

      if (_updateInPlace) {
        final activeUser = await db.getActiveUser();
        if (activeUser == null) throw StateError('no active user');
        userId = activeUser.id;

        // Same offline-first write the profile editor uses: local row first,
        // then the queued PUT /api/user/profile. Never for minors — their
        // name is server-assigned and locked.
        if (!ref.read(minorModeProvider) && name != activeUser.name) {
          await db.updateUserName(userId, name);
          await db.updateUserSyncStatus(userId, 1); // pending
          await ref.read(syncQueueProvider).enqueue(
                tableName: 'users',
                recordId: userId,
                operation: SyncOperation.update,
                payload: {'name': name},
              );
        }
        ref.invalidate(activeUserStreamProvider);
      } else {
        // Legacy sign-up path: create the account row and migrate the
        // guest's local data onto it (BR-4FTCFH).
        userId = const Uuid().v4();
        final oldUser = await db.getActiveUser();

        await db.createAndActivateUser(
          UsersTableCompanion(
            id: Value(userId),
            email: Value(widget.email),
            name: Value(name),
            avatarIndex: const Value(0),
            selectedSubjects: Value(jsonEncode(const [0])),
            isEmailValidated: Value(widget.isEmailValidated),
            isActive: const Value(true),
            syncStatus: const Value(1), // pending sync
          ),
        );

        if (oldUser != null && oldUser.id != userId) {
          await db.migrateUserData(oldUser.id, userId);
        }

        // Register/login on the backend. Proceeding locally on a failed sync
        // is this screen's existing offline-first design — the sync queue
        // retries later (see BR-8FDF37 for why minors never reach this).
        final syncSuccess = await ref
            .read(emailVerificationProvider.notifier)
            .syncUserWithServer();
        if (!syncSuccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.profileSetupSyncWarning),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }

      await _commitAvatar(userId);
      await _markOnboarded(userId);

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.profileSetupSaveError('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Write "this account has joined" onto the account itself, so no later
  /// login asks for the onboarding again — on this device or any other
  /// (BR-YXVMKY). Until this column existed the answer was device-local, and
  /// a new phone or a cleared browser re-ran the whole flow (BR-D27TFA).
  ///
  /// Queued like any other profile write rather than posted straight: the
  /// onboarding is allowed to finish offline, and [SyncQueue] merges this
  /// into whatever `users` entry is already pending — the nickname, usually —
  /// then leaves it to the periodic/reconnect sync, the same way the nickname
  /// above travels. A replay is harmless; the server only ever sets the
  /// timestamp, never moves it.
  Future<void> _markOnboarded(String userId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.updateUserSyncStatus(userId, 1); // pending
      await ref.read(syncQueueProvider).enqueue(
            tableName: 'users',
            recordId: userId,
            operation: SyncOperation.update,
            payload: {'onboarding_completed': true},
          );
    } catch (e, st) {
      // Never block the student on the door out of onboarding: the worst
      // case is being asked once more on the next login.
      silentLog('profile_setup:onboarded', e, st);
    }
  }

  /// Equip the chosen accessory. Free items still go through the server's
  /// purchase endpoint (the only thing that grants ownership), so this can
  /// fail offline — the onboarding never blocks on it, the shop sells the
  /// same items later.
  Future<void> _commitAvatar(String userId) async {
    final item = _selectedItem;
    if (item == null) return;
    try {
      final repo = ref.read(avatarRepositoryProvider);
      if (!item.owned) {
        await repo.purchase(userId, item);
      }
      await repo.equip(userId, item);
    } catch (e, st) {
      silentLog('profile_setup:avatar', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.shopPurchaseFailed),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      ref.invalidate(avatarControllerProvider);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Landscape tablet / desktop: the onboarding is a stop on the auth
    // journey, so it keeps the illustrated hero scene and puts each step in
    // the right-hand panel, exactly where the login form sits.
    if (context.isExpanded) {
      return AuthHeroScaffold(
        onBack: _step == 1 ? () => setState(() => _step = 0) : null,
        panel: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _step == 0
                ? _buildProfileStep(inPanel: true)
                : _buildVibeStep(inPanel: true),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: AppStrings.actionContinue,
              arrow: true,
              onPressed: _isSaving ? null : _handleContinuePressed,
            ),
          ],
        ),
      );
    }

    return ContentWidth(
      maxWidth: ContentWidth.reading,
      child: _buildPage(context),
    );
  }

  /// Phone / portrait tablet: plain page with the button in a bottom bar.
  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: _step == 0 ? _buildProfileStep() : _buildVibeStep(),
        ),
      ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark16,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: AuthPrimaryButton(
              label: AppStrings.actionContinue,
              arrow: true,
              onPressed: _isSaving ? null : _handleContinuePressed,
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: nickname + color profile ─────────────────────────────────────

  Widget _buildProfileStep({bool inPanel = false}) {
    final isMinor = ref.watch(minorModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.profileSetupTitle,
          style: AppTextStyles.heading1().copyWith(height: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.profileSetupSubtitle,
          style: AppTextStyles.body(color: AppColors.primaryDark48),
        ),
        const SizedBox(height: 32),
        Text(
          AppStrings.profileSetupNameLabel,
          style: AppTextStyles.cardTitle(),
        ),
        const SizedBox(height: 8),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.primaryDark16,
              width: 1,
            ),
            borderRadius: AppDecorations.radiusM,
          ),
          child: TextField(
            controller: _nameController,
            enabled: !isMinor,
            style: AppTextStyles.bodyLarge(),
            decoration: InputDecoration(
              hintText: AppStrings.profileSetupNameHint,
              hintStyle: AppTextStyles.bodyLarge(color: AppColors.primaryDark48),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              border: InputBorder.none,
              helperText: isMinor ? AppStrings.minorNameLocked : null,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          AppStrings.profileSetupColorLabel,
          style: AppTextStyles.cardTitle(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (config, label) in _themes) ...[
              Expanded(child: _buildThemeSwatch(config, label)),
              if ((config, label) != _themes.last) const SizedBox(width: 12),
            ],
          ],
        ),
        if (!inPanel) const SizedBox(height: 110), // Space for bottom bar
      ],
    );
  }

  Widget _buildThemeSwatch(ThemeConfig config, String label) {
    final selected = _selectedThemeName == config.name;

    return GestureDetector(
      onTap: () => _selectTheme(config),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: config.colors.primary,
                borderRadius: AppDecorations.radiusM,
                border: Border.all(
                  color: selected ? AppColors.primaryDark : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: selected
                  ? AppTextStyles.cardTitle()
                  : AppTextStyles.body(color: AppColors.primaryDark48),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: avatar vibe ───────────────────────────────────────────────────

  Widget _buildVibeStep({bool inPanel = false}) {
    final avatar = ref.watch(avatarControllerProvider);
    final state = avatar.valueOrNull ?? AvatarState.empty;
    final items = _freeItems(state);
    _initVibeSelection(state, items);

    // The catalog is only fetched once, on a first run — but until it lands
    // this step was an empty strip above an empty box, which reads as broken
    // rather than as loading (BR-VCD7JD).
    final loading = avatar.isLoading && items.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // In the hero panel the scaffold pins its own back arrow.
        if (!inPanel) ...[
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 0),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(
          AppStrings.profileSetupVibeTitle,
          style: AppTextStyles.heading1().copyWith(height: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.profileSetupVibeSubtitle,
          style: AppTextStyles.body(color: AppColors.primaryDark48),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildNoneTile(),
              for (final item in items) ...[
                const SizedBox(width: 12),
                _buildItemTile(item),
              ],
              if (loading) ...[
                const SizedBox(width: 12),
                _tileFrame(
                  selected: false,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: state.equippedLayers.isEmpty
              ? const SizedBox(height: 240)
              : AvatarView.fromState(
                  state.copyWith(equipped: _previewEquipped(state)),
                  size: 240,
                ),
        ),
        if (!inPanel) const SizedBox(height: 110), // Space for bottom bar
      ],
    );
  }

  Widget _buildNoneTile() {
    final selected = _selectedItem == null;
    return Semantics(
      label: AppStrings.profileSetupVibeNone,
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _selectedItem = null),
        child: _tileFrame(
          selected: selected,
          child: Icon(
            Icons.block,
            size: 32,
            color: AppColors.primaryDark48,
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(AvatarItem item) {
    final selected = _selectedItem?.code == item.code;
    return Semantics(
      label: item.name,
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _selectedItem = item),
        child: _tileFrame(selected: selected, child: _itemArtwork(item)),
      ),
    );
  }

  Widget _tileFrame({required bool selected, required Widget child}) {
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusL,
        border: Border.all(
          color: selected ? AppColors.primaryDark : AppColors.primaryDark12,
          width: selected ? 2 : 1,
        ),
      ),
      child: Center(child: child),
    );
  }

  /// Same crop the shop tiles use: the artwork shares the avatar's full
  /// canvas, so uncropped it would read as a speck in an empty frame.
  Widget _itemArtwork(AvatarItem item) {
    final svg = item.svgSource;
    if (svg == null) return const SizedBox.shrink();

    final content = item.contentBounds;
    final picture = SvgPicture.string(svg, fit: BoxFit.contain);
    if (content == null) {
      return Padding(padding: const EdgeInsets.all(8), child: picture);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return ClipRect(
          child: Transform(
            transform: cropTransform(content, side, fill: 0.7),
            child: SizedBox(width: side, height: side, child: picture),
          ),
        );
      },
    );
  }
}
