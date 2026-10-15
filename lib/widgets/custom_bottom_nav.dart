import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/layout/breakpoints.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/core_providers.dart';

class CustomBottomNav extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  /// Run-up above the bar over which the scrim fades in from fully
  /// transparent — 44px in the ZČU design (Figma frame 22-588).
  static const double _scrimRunway = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomAreaHeight = bottomPadding > 0 ? bottomPadding : 16.0;
    final unread = ref.watch(unreadNewsCountProvider);

    // DecoratedBox (not Container) on purpose: it is a plain RenderProxyBox,
    // so hitTestSelf() is false and the transparent upper part of the scrim
    // keeps letting taps through to the page content scrolling underneath.
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.bottomNavScrimGradient),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrim run-up above the bar (transparent, absorbs no taps)
          const SizedBox(height: _scrimRunway),
          // Navigation bar (transparent background)
          // Capped: without the old global 640px clamp a `spaceAround` row
          // would fling the icons into the far corners of a desktop window.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ContentWidth(
              maxWidth: 640,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  // Main navigation bar
                  Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppDecorations.radiusXL,
                      boxShadow: AppDecorations.shadowMedium,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          0,
                          'assets/icons/home.svg',
                          AppStrings.navPrehled,
                        ),
                        _buildNavItem(
                          1,
                          'assets/icons/chat.svg',
                          AppStrings.navChat,
                        ),
                        const SizedBox(width: 60), // Space for center button
                        _buildNavItem(
                          3,
                          'assets/icons/kurzy.svg',
                          AppStrings.navKurzy,
                        ),
                        _buildNavItem(
                          4,
                          'assets/icons/novinky.svg',
                          AppStrings.navNovinky,
                          badgeCount: unread,
                        ),
                      ],
                    ),
                  ),
                  // Center floating button
                  Positioned(
                    top: -10,
                    child: GestureDetector(
                      onTap: () => onItemTapped(2),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppDecorations.radiusPill,
                          boxShadow: AppDecorations.shadowStrong,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/add.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              selectedIndex == 2
                                  ? AppColors.primary
                                  : AppColors.primaryDark,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom spacing (transparent)
          SizedBox(height: bottomAreaHeight),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String iconPath,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.primaryDark;

    final item = GestureDetector(
      onTap: () => onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.navLabel(
                color: color,
                weight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );

    if (badgeCount <= 0) return item;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        item,
        Positioned(
          top: -2,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
