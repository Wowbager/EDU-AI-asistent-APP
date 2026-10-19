// The preview flag, and the hit-target that makes a rendered leaf clickable.
//
// Two jobs:
//
//  1. Say, at any depth in the widget tree, that this is a preview and not a
//     student's session. The flag is read at the point of effect — inside the
//     widget that would write, award or report — rather than at the call site, so
//     a future caller cannot forget to pass it.
//
//  2. Wrap rendered leaves in a target that reports the `PreviewRef` behind them,
//     which is what makes click-to-edit possible in "Náhled".
//
// A target changes nothing about how its child is laid out or painted. It used to
// draw a hover outline through a permanent 1.5 px transparent border, so every
// wrapped leaf was 3 px narrower than in the student's app and text wrapped at a
// different word — the preview disagreed with the app it exists to show. The only
// visible sign of a target now is the pointer cursor.
//
// Nothing here is used in a normal session: `PreviewMode.of(context)` returns the
// disabled instance when no `PreviewScope` is above, and every guard is a no-op.

import 'package:flutter/material.dart';

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
/// no mouse region, no rebuild cost in a student's session. The same holds in
/// "Vyzkoušet": there the author is taking the card as a pupil would, a tap belongs
/// to the pupil's controls, and the editor follows the run on its own
/// (`PreviewLessonPlayer`'s `stepChanged`). A tap either answers or reports where
/// something is authored, never both — the rule the option taps already follow.
class PreviewTarget extends StatelessWidget {
  final Widget child;
  final String? stepId;
  final String? optionId;

  /// The document field this leaf renders, e.g. `content`, `question.solution`,
  /// `text`, `feedback`. It is what the editor focuses on a click.
  final String? field;

  /// How this target claims hits.
  ///
  /// `deferToChild` (the default, and what every leaf target wants) makes the
  /// click area the glyphs or the image, not the padding around them. The
  /// card-level target wants the opposite — a click on blank card padding should
  /// still count — so it passes `opaque`.
  final HitTestBehavior behavior;

  const PreviewTarget({
    super.key,
    required this.child,
    this.stepId,
    this.optionId,
    this.field,
    this.behavior = HitTestBehavior.deferToChild,
  });

  @override
  Widget build(BuildContext context) {
    final mode = PreviewMode.of(context);
    if (!mode.enabled || mode.interactive) return child;

    final ref = mode.refFor(stepId: stepId, optionId: optionId, field: field);

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
      child: GestureDetector(
        behavior: behavior,
        onTap: () => mode.onRefTapped?.call(ref),
        child: child,
      ),
    );
  }
}
