import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../models/mentor_presentation.dart';

/// One mentor in the "Nový chat" list (Figma 515:475).
///
/// Card, avatar, title, two-line description, then the availability chip and
/// the kind tag on the right. Sizes follow the frame; colours, radii, shadow
/// and type come from the theme so the card follows the theme editor and stays
/// in step with the course and lesson cards it sits next to.
class MentorCard extends StatelessWidget {
  const MentorCard({
    super.key,
    required this.mentor,
    required this.onTap,
  });

  /// Drawn at 51px in the frame; rounded to the even number the rest of the
  /// app uses for avatars.
  static const double _avatarSize = 52;

  final ChatMentor mentor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${mentor.name}. ${mentor.cardDescription}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.cardDecorationLight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            mentor.name,
                            style: AppTextStyles.cardTitleSmall(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // The chip pair is fixed content beside a title that
                        // can be squeezed to nothing; scaling it down is the
                        // last resort before the row overflows on a 320px
                        // phone with the text size turned up.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _buildMeta(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mentor.cardDescription,
                      style: AppTextStyles.caption(
                        color: AppColors.primaryDark48,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = mentor.avatarUrl;

    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              // An artwork that fails to load must not leave a blank disc —
              // the emoji is still a usable identity for the mentor.
              errorBuilder: (_, _, _) => _buildEmoji(),
            )
          : _buildEmoji(),
    );
  }

  Widget _buildEmoji() {
    return Center(
      child: Text(
        mentor.emoji,
        style: const TextStyle(fontSize: 26),
      ),
    );
  }

  /// Availability chip + kind tag, both at the top right of the card.
  Widget _buildMeta() {
    final metaStyle = AppTextStyles.caption(color: AppColors.primaryDark32);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/clock.svg',
          width: 10,
          height: 10,
          colorFilter: ColorFilter.mode(
            AppColors.primaryDark32,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 4),
        Text(mentor.availabilityLabel, style: metaStyle),
        const SizedBox(width: 8),
        Text(mentor.kindLabel, style: metaStyle),
      ],
    );
  }
}
