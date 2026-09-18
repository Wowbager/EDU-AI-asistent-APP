// The buttons at the foot of a block card, drawn in one place.
//
// They used to live inside `BlockStepEngine` as private `_build*` methods, which
// made them unreachable from anywhere that does not mount an engine — and the
// editor's "Náhled" deliberately does not, because the engine is what makes a card
// interactive. The consequence was a preview of a card that omitted the card's own
// controls: the author could not see whether the question mark appears at all, how
// much room the action row takes, or what a quiz card looks like with the thumbs
// stripped out.
//
// So the *drawing* moved here and the *deciding* stayed in the engine. The engine
// still works out which label a button carries and whether it is enabled from its
// own state machine; these widgets only know how to paint the result. Nothing about
// a real student's session changes — `BlockStepEngine` passes exactly what it used
// to compute inline.

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/step_navigation.dart';

/// One icon in the left-hand bubble.
class BlockActionButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;

  const BlockActionButton({
    super.key,
    required this.icon,
    this.isActive = false,
    this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 22,
          color: isActive
              ? (activeColor ?? AppColors.quizPurple)
              : AppColors.primaryDark64,
        ),
      ),
    );
  }
}

/// The left-hand bubble: bookmark, like, dislike, hint.
///
/// A quiz strips everything but the hint — there is no bookmarking your way
/// through a test.
///
/// The callbacks are nullable on purpose and are passed straight through. A
/// `GestureDetector` with a null `onTap` does not absorb the tap, which is how the
/// block-level row behaves when its owner wires nothing to it; the per-step row
/// passes closures instead and therefore does absorb. That difference belongs to
/// the caller, so it is not smoothed over here.
class BlockActionBar extends StatelessWidget {
  final ExportMode exportMode;
  final bool isBookmarked;
  final bool isLiked;
  final bool isDisliked;

  /// Whether this card or step has a hint or a detailed help to offer.
  final bool showHint;

  final VoidCallback? onBookmark;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onHint;

  const BlockActionBar({
    super.key,
    this.exportMode = ExportMode.courseV2,
    this.isBookmarked = false,
    this.isLiked = false,
    this.isDisliked = false,
    this.showHint = false,
    this.onBookmark,
    this.onLike,
    this.onDislike,
    this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final isQuiz = exportMode == ExportMode.quizV2;

    final buttons = <Widget>[
      if (!isQuiz) ...[
        BlockActionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          isActive: isBookmarked,
          onTap: onBookmark,
        ),
        BlockActionButton(
          icon: Icons.thumb_up_outlined,
          isActive: isLiked,
          activeColor: AppColors.success,
          onTap: onLike,
        ),
        BlockActionButton(
          icon: Icons.thumb_down_outlined,
          isActive: isDisliked,
          activeColor: AppColors.orange,
          onTap: onDislike,
        ),
      ],
      if (showHint)
        BlockActionButton(
          icon: Icons.help_outline,
          isActive: false,
          onTap: onHint,
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(36),
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons,
      ),
    );
  }
}

/// The right-hand button: a green check when the block or step is done, a labelled
/// pill when there is something to confirm, a check circle otherwise.
class BlockMainButton extends StatelessWidget {
  /// Done. Wins over everything else, as it does in the engine.
  final bool isComplete;

  /// `Zkontrolovat`, `Další`, `Pokračovat`, `Zkusit znovu` — or null for the circle.
  final String? label;

  final bool enabled;
  final VoidCallback? onTap;

  /// Shown as a snackbar when the button is pressed with nothing to do. The engine
  /// uses it for "pick an answer first"; passing the text in rather than reaching
  /// for `AppStrings` keeps this file about drawing.
  final String? disabledMessage;

  const BlockMainButton({
    super.key,
    this.isComplete = false,
    this.label,
    this.enabled = true,
    this.onTap,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isComplete) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            boxShadow: AppDecorations.shadowStrong,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 24),
        ),
      );
    }

    final text = label;
    if (text != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryDark : AppColors.surfaceLight,
            borderRadius: AppDecorations.radiusM,
          ),
          child: Text(
            text,
            style: AppTextStyles.statValue(
              color: enabled ? Colors.white : AppColors.disabled,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final tap = onTap;
        if (tap != null) {
          tap();
          return;
        }
        final message = disabledMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: AppTextStyles.body(color: AppColors.primaryDark),
            ),
            backgroundColor: AppColors.orangeBg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusS),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppDecorations.shadowStrong,
        ),
        child: Icon(
          Icons.check,
          color: enabled ? AppColors.primaryDark : AppColors.disabled,
          size: 24,
        ),
      ),
    );
  }
}
