import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';
import '../core/strings/locale_manager.dart';
import '../core/util/decimal_display.dart';
import '../widgets/detail_shell.dart';
import '../widgets/page_header.dart';
import '../widgets/user_avatar.dart';
import '../core/layout/breakpoints.dart';

/// Profile page with user info, stats, and settings.
///
/// Based on wireframe showing:
/// - Back button, avatar, name, email, level/XP
/// - Stats row (Kurzy, Streak, Úspěchy)
/// - Quick action cards (Úspěchy, Knihovna)
/// - Settings sections (Účet, Nastavení, Další)
/// - Logout button and version
class ProfilePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final int avatarIndex;
  final int level;
  final int xpPoints;
  final int coursesCount;
  final int streakDays;
  final int achievementsCount;
  final bool notificationsEnabled;
  final String currentLanguage;
  final VoidCallback? onBack;
  final VoidCallback? onAchievementsTap;
  final VoidCallback? onLibraryTap;
  final Future<String?> Function()? onEditProfileTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onDoplnkyTap;
  final Function(bool)? onNotificationsChanged;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onThemeTap;
  final VoidCallback? onAboutTap;
  final VoidCallback? onTermsTap;
  final VoidCallback? onLogoutTap;
  final bool isGuest;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userEmail,
    this.avatarIndex = 0,
    this.level = 1,
    this.xpPoints = 0,
    this.coursesCount = 0,
    this.streakDays = 1,
    this.achievementsCount = 0,
    this.notificationsEnabled = true,
    this.currentLanguage = '',
    this.onBack,
    this.onAchievementsTap,
    this.onLibraryTap,
    this.onEditProfileTap,
    this.onAvatarTap,
    this.onPrivacyTap,
    this.onDoplnkyTap,
    this.onNotificationsChanged,
    this.onLanguageTap,
    this.onThemeTap,
    this.onAboutTap,
    this.onTermsTap,
    this.onLogoutTap,
    this.isGuest = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with ThemeAwareState {
  late bool _notificationsEnabled;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _displayName = widget.userName;
  }

  @override
  Widget build(BuildContext context) {
    if (context.widthClass == WidthClass.compact) {
      return _buildPage(context, showHeader: true);
    }

    // On a wide viewport this is a pushed route sitting above the shell, so
    // without its own copy of the sidebar the user drops out of the navigation
    // entirely and the only way on is the back button (BR-5JSXBV). Same
    // treatment every other pushed page gets — see `DoplnkyPage`.
    return DetailShell(
      title: AppStrings.profileTitle,
      onBack: widget.onBack,
      // The account page itself: lit *and* not a button (BR-NYNNM8).
      isAccountPage: true,
      child: ContentWidth(
        maxWidth: ContentWidth.reading,
        child: _buildPage(context, showHeader: false),
      ),
    );
  }

  /// [ContentWidth] keeps the settings list at a readable measure instead of
  /// stretching its rows across a monitor.
  ///
  /// [showHeader] is off beside the sidebar: `DetailShell`'s top bar already
  /// carries the title and the back link, so drawing [PageHeader] too would
  /// print the heading twice.
  Widget _buildPage(BuildContext context, {required bool showHeader}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if (showHeader) ...[
                PageHeader(
                  title: AppStrings.profileTitle,
                  onBack: widget.onBack,
                ),
                const SizedBox(height: 24),
              ],
              // User info section
              _buildUserInfo(),
              const SizedBox(height: 24),
              // Stats row
              _buildStatsRow(),
              const SizedBox(height: 24),
              // Quick action cards
              _buildQuickActions(),
              const SizedBox(height: 24),
              // Účet section
              _buildSectionHeader(AppStrings.profileSectionAccount),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.person_outline,
                  label: AppStrings.profileEditProfile,
                  onTap: () async {
                    if (widget.onEditProfileTap != null) {
                      final newName = await widget.onEditProfileTap!();
                      if (newName != null && mounted) {
                        setState(() { _displayName = newName; });
                      }
                    }
                  },
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.checkroom_rounded,
                  label: AppStrings.profileEditAvatar,
                  onTap: widget.onAvatarTap,
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.shield_outlined,
                  label: AppStrings.profilePrivacy,
                  onTap: widget.onPrivacyTap,
                ),
              ]),
              const SizedBox(height: 24),
              // Nastavení section
              _buildSectionHeader(AppStrings.profileSectionSettings),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.palette_outlined,
                  label: AppStrings.profileTheme,
                  onTap: widget.onThemeTap,
                ),
                _buildDivider(),
                _buildDisabledItem(
                  icon: Icons.notifications_outlined,
                  label: AppStrings.profileNotifications,
                  trailing: AppStrings.profileComingSoon,
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.language,
                  label: AppStrings.profileLanguage,
                  trailing: LocaleManager.current.displayName,
                  onTap: _showLanguagePicker,
                ),
              ]),
              const SizedBox(height: 24),
              // Další section
              _buildSectionHeader(AppStrings.profileSectionMore),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.extension_outlined,
                  label: AppStrings.doplnkyTitle,
                  onTap: widget.onDoplnkyTap,
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  label: AppStrings.profileAbout,
                  onTap: widget.onAboutTap,
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.description_outlined,
                  label: AppStrings.profileTerms,
                  onTap: widget.onTermsTap,
                ),
              ]),
              const SizedBox(height: 24),
              // Logout button
              _buildLogoutButton(),
              const SizedBox(height: 16),
              // Version
              _buildVersion(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Avatar
          UserAvatar(size: 72, avatarIndex: widget.avatarIndex),
          const SizedBox(width: 16),
          // Name, email, level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: AppTextStyles.heading3(),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.userEmail,
                  style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.profileLevelXp(widget.level, _formatNumber(widget.xpPoints)),
                  style: AppTextStyles.labelMedium(color: AppColors.primaryDark64),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              label: AppStrings.profileStatCourses,
              value: widget.coursesCount.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox(
              label: AppStrings.profileStatStreak,
              value: widget.streakDays.toString(),
              icon: Icons.local_fire_department,
              iconColor: AppColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox(
              label: AppStrings.profileStatAchievements,
              value: widget.achievementsCount.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        border: Border.all(
          color: AppColors.primaryDark08,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.meta(color: AppColors.primaryDark48),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.heading4(),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppColors.primaryDark,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusL,
          boxShadow: AppDecorations.shadowLight,
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.emoji_events_outlined,
                label: AppStrings.profileQuickAchievements,
                onTap: widget.onAchievementsTap,
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: AppColors.primaryDark08,
            ),
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.library_books_outlined,
                label: AppStrings.profileQuickLibrary,
                onTap: widget.onLibraryTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: AppColors.primaryDark,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.actionText(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: AppTextStyles.meta(color: AppColors.primaryDark48),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusL,
          boxShadow: AppDecorations.shadowLight,
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  /// Show a modal dialog with available locales. Selecting one applies it
  /// immediately (via [LocaleManager.setLocale]) and rebuilds the UI.
  Future<void> _showLanguagePicker() async {
    final picked = await showDialog<AppLocale>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(AppStrings.profileLanguage),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            // Pin the width. AlertDialog otherwise sizes itself to the
            // intrinsic width of its content, which leaves the language name
            // squeezed next to the check icon and wraps it mid-word
            // ("Češti / na"). Shrink on narrow screens so the dialog still
            // fits inside the 40px inset padding on each side.
            width: (MediaQuery.sizeOf(ctx).width - 80).clamp(0.0, 320.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final locale in AppLocale.values)
                  ListTile(
                    title: Text(
                      locale.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Keep the trailing slot occupied on every row so the
                    // title width does not change with the selection.
                    trailing: SizedBox(
                      width: 24,
                      child: locale == LocaleManager.current
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                    ),
                    onTap: () => Navigator.of(ctx).pop(locale),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppStrings.actionCancel),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      await LocaleManager.setLocale(picked);
      if (mounted) setState(() {});
    }
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.statSuffix(),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.primaryDark32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.statSuffix(),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryDark,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.primaryDark16,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 1,
        color: AppColors.primaryDark08,
      ),
    );
  }

  Widget _buildDisabledItem({
    required IconData icon,
    required String label,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: AppColors.primaryDark32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.statSuffix(color: AppColors.primaryDark32),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark24),
            ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: widget.onLogoutTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppDecorations.radiusM,
            border: Border.all(
              color: AppColors.primaryDark16,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isGuest ? Icons.login : Icons.logout,
                size: 20,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isGuest ? AppStrings.profileLogin : AppStrings.profileLogout,
                style: AppTextStyles.statSuffix(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersion() {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.hasData
            ? 'v${snapshot.data!.version}'
            : '';
        return Center(
          child: Text(
            AppStrings.profileAppVersion(version),
            style: AppTextStyles.caption(color: AppColors.primaryDark32),
          ),
        );
      },
    );
  }

  /// Both branches used dot-and-comma English notation, which in Czech reads
  /// as the wrong number entirely — "1,234" is one and a bit, not a thousand
  /// (BR-5DZ6JD). Separators now follow the active locale.
  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${formatDecimal(number / 1000, fractionDigits: number % 1000 == 0 ? 0 : 1)}k';
    }
    return formatGrouped(number);
  }
}
