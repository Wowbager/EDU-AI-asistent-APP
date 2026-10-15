import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'user_avatar.dart';

/// A slide-out navigation drawer.
///
/// Simplified menu that navigates to full pages.
/// User details are shown in ProfilePage, not duplicated here.
class ProfileDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final int avatarIndex;
  final VoidCallback? onClose;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLibraryTap;
  final VoidCallback? onAchievementsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onAboutTap;
  final VoidCallback? onLogoutTap;
  final bool isGuest;

  const ProfileDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    this.avatarIndex = 0,
    this.isGuest = false,
    this.onClose,
    this.onProfileTap,
    this.onLibraryTap,
    this.onAchievementsTap,
    this.onSettingsTap,
    this.onHelpTap,
    this.onAboutTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      // Full-width on phones, capped on wider windows — the old global 640px
      // clamp used to hide the fact that this reads the real window width.
      width: math.min(MediaQuery.sizeOf(context).width, 400),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with close button
            _buildTopBar(),
            const SizedBox(height: 24),
            // Compact user header - tap to go to profile
            _buildUserHeader(),
            const SizedBox(height: 24),
            _buildDivider(),
            // Navigation section
            _buildSectionHeader(AppStrings.drawerNavigation),
            _buildMenuItem(
              icon: Icons.person_outline,
              label: AppStrings.drawerProfile,
              onTap: onProfileTap,
            ),
            _buildMenuItem(
              icon: Icons.library_books_outlined,
              label: AppStrings.libraryTitle,
              onTap: onLibraryTap,
            ),
            _buildMenuItem(
              icon: Icons.emoji_events_outlined,
              label: AppStrings.achievementsTitle,
              onTap: onAchievementsTap,
            ),
            const SizedBox(height: 4),
            _buildDivider(),
            // More section
            _buildSectionHeader(AppStrings.drawerMore),
            _buildMenuItem(
              icon: Icons.settings_outlined,
              label: AppStrings.profileSectionSettings,
              onTap: onSettingsTap,
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              label: AppStrings.drawerHelp,
              onTap: onHelpTap,
            ),
            _buildMenuItem(
              icon: Icons.info_outline,
              label: AppStrings.profileAbout,
              onTap: onAboutTap,
            ),
            const Spacer(),
            // Logout / Login button
            _buildDivider(),
            _buildMenuItem(
              icon: isGuest ? Icons.login : Icons.logout,
              label: isGuest ? AppStrings.profileLogin : AppStrings.profileLogout,
              onTap: onLogoutTap,
              isDestructive: !isGuest,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 48,
              height: 48,
              decoration: AppDecorations.circleButton,
              child: Icon(
                Icons.close,
                size: 24,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return GestureDetector(
      onTap: onProfileTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // Avatar
            UserAvatar(size: 56, avatarIndex: avatarIndex),
            const SizedBox(width: 16),
            // Name and email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: AppTextStyles.cardTitle(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    style: AppTextStyles.bodySmall(
                      color: AppColors.primaryDark48,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow indicating tap to view profile
            Icon(
              Icons.chevron_right,
              size: 24,
              color: AppColors.primaryDark32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: AppColors.primaryDark08,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: AppTextStyles.chipLabel(
          color: AppColors.primaryDark48,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? AppColors.error
        : AppColors.primaryDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.errorBg
                    : AppColors.background,
                borderRadius: AppDecorations.radiusS,
              ),
              child: Icon(
                icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTextStyles.menuItem(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
