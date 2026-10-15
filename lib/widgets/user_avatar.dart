import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/core_providers.dart';
import '../core/theme/app_theme.dart';
import 'avatar_view.dart';

/// The signed-in user's own avatar, drawn in a circle.
///
/// The dress-up avatar (BR-7JRBCN) only ever showed up in the places that
/// *author* it — the shop and the onboarding picker — while every surface that
/// prints the user's name kept drawing the legacy `avatarIndex` emoji. So the
/// figure the user had assembled was nowhere near their name (BR-D6W3CR). This
/// widget is the one place that answers "what does this user look like", and
/// the sidebar, the profile header and the edit-profile form all use it.
///
/// The emoji stays as the fallback, not as a second avatar system: the catalog
/// resolves asynchronously and a signed-out or bare account has nothing
/// equipped, and a circle that renders empty for a beat reads as a bug of its
/// own.
class UserAvatar extends ConsumerWidget {
  /// Mirrors the legacy `avatarIndex` options, used only for the fallback.
  static const List<String> _fallbackEmojis = [
    '\u{1F98A}', // fox
    '\u{1F43C}', // panda
    '\u{1F981}', // lion
    '\u{1F438}', // frog
    '\u{1F989}', // owl
    '\u{1F431}', // cat
  ];

  /// Diameter of the circle.
  final double size;

  /// Legacy avatar slot — picks the backdrop colour, and the emoji to fall
  /// back to while there is nothing composed to draw.
  final int avatarIndex;

  const UserAvatar({
    super.key,
    required this.size,
    this.avatarIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.avatarColors;
    final safeIndex = avatarIndex.clamp(0, colors.length - 1);
    final layers =
        ref.watch(avatarControllerProvider).valueOrNull?.equippedLayers ??
            const [];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[safeIndex],
        shape: BoxShape.circle,
      ),
      // The figure is drawn full-bleed and the circle clips it, the same way
      // the shop's square preview crops to the content box — anything less and
      // a hat or a held item pokes out of the disc.
      child: ClipOval(
        child: layers.isEmpty
            ? Center(
                child: Text(
                  _fallbackEmojis[safeIndex.clamp(
                    0,
                    _fallbackEmojis.length - 1,
                  )],
                  style: TextStyle(fontSize: size * 0.5),
                ),
              )
            : AvatarView(layers: layers, size: size),
      ),
    );
  }
}
