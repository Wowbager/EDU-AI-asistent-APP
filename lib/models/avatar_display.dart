import 'package:flutter/material.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/util/contrast.dart';
import 'avatar_model.dart';

/// Presentation for the avatar domain model.
///
/// Kept out of `avatar_model.dart` so the model stays free of Flutter imports
/// and can be exercised in plain Dart tests.
extension AvatarSlotLabel on AvatarSlot {
  String get label => switch (this) {
        AvatarSlot.torso => AppStrings.shopSlotTorso,
        AvatarSlot.legs => AppStrings.shopSlotLegs,
        AvatarSlot.eyes => AppStrings.shopSlotEyes,
        AvatarSlot.mouth => AppStrings.shopSlotMouth,
        AvatarSlot.face => AppStrings.shopSlotFace,
        AvatarSlot.head => AppStrings.shopSlotHead,
        AvatarSlot.neck => AppStrings.shopSlotNeck,
        AvatarSlot.hands => AppStrings.shopSlotArms,
        AvatarSlot.held => AppStrings.shopSlotHeld,
      };
}

/// Rarity drives the shop tile's border.
extension AvatarRarityColor on AvatarRarity {
  /// Fill/border colour. Pastels drawn from the card palette — sized for a
  /// 2–4 px border around a white tile, not for glyphs.
  Color get accent => switch (this) {
        AvatarRarity.common => AppColors.cardBlue,
        AvatarRarity.rare => AppColors.hintIconColor,
        AvatarRarity.epic => AppColors.gradientPurple,
      };

  /// The same rarity as *text* on [background].
  ///
  /// [accent] was 1.0–1.7:1 against the surfaces it was printed on, which put
  /// the shop's labels somewhere between hard and impossible to read
  /// (BR-YXSVVC). Darkening per backdrop keeps the rarity hue while clearing
  /// WCAG AA, and it does so for user-authored themes too — the pastels differ
  /// per theme, the requirement does not.
  Color labelOn(Color background) => readableOn(accent, background);
}
