import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Header strip above the content on tablet/desktop.
///
/// Carries the page's name and nothing else. It used to also hold the XP pill,
/// a profile chip and a row of circular actions (games, avatars,
/// notifications), but with a sidebar on screen that was a second navigation
/// competing with the first — so identity, XP and every destination moved into
/// `SideNav` and this went back to being a heading (BR-KN9XUT).
class DesktopTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// When set, the left side becomes a "← <label>" link instead of the
  /// title/subtitle block. Detail pages use this ("Zpět na všechny kurzy");
  /// the page's own heading then lives in its hero card.
  final String? backLabel;
  final VoidCallback? onBack;

  const DesktopTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.backLabel,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: backLabel != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: onBack,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back,
                              size: 20, color: AppColors.primaryDark),
                          const SizedBox(width: 8),
                          Text(backLabel!, style: AppTextStyles.bodySemiBold()),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading2Bold(),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTextStyles.body(color: AppColors.primaryDark64),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
