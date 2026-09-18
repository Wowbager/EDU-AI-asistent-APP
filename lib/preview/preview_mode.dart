// The preview flag, and the hit-target that makes a rendered leaf clickable.
//
// Two jobs:
//
//  1. Say, at any depth in the widget tree, that this is a preview and not a
//     student's session. The flag is read at the point of effect — inside the
//     widget that would write, award or report — rather than at the call site, so
//     a future caller cannot forget to pass it.
//
//  2. Wrap rendered leaves in a target that reports the `PreviewRef` behind them
//     and draws a hover outline, which is what makes click-to-edit possible.
//
// Nothing here is used in a normal session: `PreviewMode.of(context)` returns the
// disabled instance when no `PreviewScope` is above, and every guard is a no-op.

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'preview_ref.dart';

@immutable
class PreviewMode {
  /// True only inside the editor's preview. Never true in the student's app.
  final bool enabled;

  /// Called when the author clicks a rendered leaf.
  final void Function(PreviewRef ref)? onRefTapped;

  /// The block being previewed, so a leaf only has to know its own part of the ref.
  final String? blockId;
  final String? lessonId;

  /// Whether the student's own controls answer, advance and play.
  ///
  /// False only in the editor's expanded preview, where the author is reading the
  /// card rather than taking it: a tap on an answer reports where that answer is
  /// authored instead of selecting it. Defaults to true, so a student's session
  /// and the "Vyzkoušet" preview behave identically.
  final bool interactive;

  const PreviewMode({
    this.enabled = false,
    this.onRefTapped,
    this.blockId,
    this.lessonId,
    this.interactive = true,
  });

  static const disabled = PreviewMode();

  static PreviewMode of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PreviewScope>();
    return scope?.mode ?? disabled;
  }

  /// Read without subscribing — for guards inside callbacks and `initState`.
  static PreviewMode read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PreviewScope>();
    return scope?.mode ?? disabled;
  }

  /// True when the caller must not persist, award, enrol, call the API or report.
  ///
  /// Check this immediately before the effect, not where the widget is built:
  ///
  /// ```dart
  /// if (PreviewMode.read(context).sideEffectsSuppressed) return;
  /// await _progressRepository.save(progress);
  /// ```
  bool get sideEffectsSuppressed => enabled;

  PreviewRef refFor({String? stepId, String? optionId, String? field}) => PreviewRef(
        lessonId: lessonId,
        blockId: blockId,
        stepId: stepId,
        optionId: optionId,
        field: field,
      );
}

class PreviewScope extends InheritedWidget {
  final PreviewMode mode;

  const PreviewScope({super.key, required this.mode, required super.child});

  @override
  bool updateShouldNotify(PreviewScope oldWidget) => oldWidget.mode != mode;
}

/// A rendered leaf that reports where it came from when the author clicks it.
///
/// Outside preview mode this is the child and nothing else — no gesture detector,
/// no mouse region, no rebuild cost in a student's session.
class PreviewTarget extends StatefulWidget {
  final Widget child;
  final String? stepId;
  final String? optionId;

  /// The document field this leaf renders, e.g. `content`, `question.solution`,
  /// `text`, `feedback`. It is what the editor focuses on a click.
  final String? field;

  /// Draws the 1.5px hover outline around [child].
  ///
  /// Off for the card-level target `_StepCard` wraps around its whole body
  /// (see `preview_expanded_block.dart`): that target exists to widen the hit
  /// area to blank space, not to be seen, and a border around the entire card
  /// on every hover would be noise fighting the card's own `highlighted`
  /// border. The leaf targets nested inside it keep their outline as normal.
  final bool outline;

  /// How this target claims hits.
  ///
  /// `deferToChild` (the default, and what every leaf target wants) makes a
  /// target with no visible pixels of its own — e.g. a `Container` with a
  /// transparent border around see-through padding — untappable there,
  /// because it has nothing for the gesture arena to hit-test against except
  /// what [child] itself paints. That is exactly right for a leaf: the click
  /// area should be the glyphs/image, not the padding around them. The
  /// card-level target wants the opposite — a click on blank card padding
  /// should still count — so it passes `opaque`.
  final HitTestBehavior behavior;

  const PreviewTarget({
    super.key,
    required this.child,
    this.stepId,
    this.optionId,
    this.field,
    this.outline = true,
    this.behavior = HitTestBehavior.deferToChild,
  });

  @override
  State<PreviewTarget> createState() => _PreviewTargetState();
}

class _PreviewTargetState extends State<PreviewTarget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mode = PreviewMode.of(context);
    if (!mode.enabled) return widget.child;

    final ref = mode.refFor(
      stepId: widget.stepId,
      optionId: widget.optionId,
      field: widget.field,
    );

    // A leaf target nested inside this one (e.g. the image or a question's
    // options, rendered by `StepContentRenderer` inside the card-level
    // target `_StepCard` adds) still wins a tap that lands on it: Flutter's
    // gesture arena hands a tap to whichever recognizer's hit-test entry was
    // added first, and a descendant's entry is always added before its
    // ancestor's (hit-testing recurses into children before adding the
    // parent's own entry, so `HitTestResult.path` lists the deepest hit
    // first, and `GestureArenaManager.sweep` picks `members.first` as the
    // default winner when nobody explicitly resolves early — see
    // `packages/flutter/lib/src/gestures/arena.dart`). `opaque` on the outer
    // target only makes it *additionally* claim blank space the inner one
    // doesn't cover — it never steals a hit the inner one already answered.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: () => mode.onRefTapped?.call(ref),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.outline && _hovered ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
