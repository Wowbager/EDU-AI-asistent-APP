// The editor's "Náhled": one card, every step visible at once, and nothing to click
// through.
//
// It renders with `StepContentRenderer` — the same widget the student's app uses —
// and stacks one per step, with the same action row underneath from
// `block_action_buttons.dart`. When the app's renderer or its buttons change, this
// view changes with them; there is no second implementation to keep in step.
//
// **What makes it inert is where the callbacks go, not the absence of buttons.**
// The first version left the buttons out entirely and called that the reason —
// which was a consequence mistaken for a cause, and it cost the author a preview of
// the card that omitted the card's own controls. `BlockStepEngine` is still not
// mounted, so `_currentStepIndex`, `_stepAnswers`, `onStepProgress` and
// `onBlockCompleted` are not in the tree at all: `stepChanged` and `completed` are
// impossible here by construction. Every tap in this file terminates in
// `onRefTapped`, i.e. in a `clicked` message.
//
// Two deliberate departures from what the student sees, because the reader here is
// the author rather than the pupil:
//
//  * every question is rendered as though it had been answered, so the per-option
//    feedback and the worked solution are on screen without anyone answering
//    anything (plan §5 M5 asks for "markers for content that exists but is not
//    currently rendered");
//  * an option carrying `go_to` is labelled with where it leads, so branching can
//    be read off the card instead of reconstructed by playing it;
//  * the row is drawn in its completed state — the green check rather than a greyed
//    "Zkontrolovat". The engine's own name for a step rendered with its answer and
//    solution showing is a *history* step, and this is the row it pairs with one. A
//    disabled check button sitting under the answer's own feedback would make the
//    card contradict itself.

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/block_model.dart';
import '../models/step_navigation.dart';
import '../widgets/block_action_buttons.dart';
import '../widgets/step_content_renderer.dart';
import 'preview_mode.dart';
import 'preview_ref.dart';

class PreviewExpandedBlock extends StatelessWidget {
  final ContentBlock block;
  final ExportMode exportMode;
  final String? lessonId;
  final void Function(PreviewRef ref) onRefTapped;

  /// The step the editor currently has selected, outlined so the two views agree
  /// about what is being worked on.
  final String? highlightedStepId;

  /// How to name the other cards a branch can lead to.
  ///
  /// The player holds one card, so it cannot look another one up — and it must not
  /// guess, because printing a raw `block_id` would show a teacher an identifier
  /// they must never see or change (plan §8). The editor supplies the names, and
  /// decides per mode whether a name or an id is the right one.
  final Map<String, String> blockLabels;

  const PreviewExpandedBlock({
    super.key,
    required this.block,
    required this.onRefTapped,
    this.exportMode = ExportMode.courseV2,
    this.lessonId,
    this.highlightedStepId,
    this.blockLabels = const {},
  });

  @override
  Widget build(BuildContext context) {
    return PreviewScope(
      mode: PreviewMode(
        enabled: true,
        interactive: false,
        blockId: block.blockId,
        lessonId: lessonId,
        onRefTapped: onRefTapped,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in block.steps) ...[
            _StepCard(
              step: step,
              block: block,
              exportMode: exportMode,
              highlighted: step.stepId == highlightedStepId,
              onRefTapped: onRefTapped,
              blockLabels: blockLabels,
            ),
            const SizedBox(height: 12),
          ],
          if (block.steps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Karta zatím nemá žádný krok.'),
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final BlockStep step;
  final ContentBlock block;
  final ExportMode exportMode;
  final bool highlighted;
  final void Function(PreviewRef ref) onRefTapped;
  final Map<String, String> blockLabels;

  const _StepCard({
    required this.step,
    required this.block,
    required this.exportMode,
    required this.highlighted,
    required this.onRefTapped,
    required this.blockLabels,
  });

  /// A question rendered as answered, with nothing selected.
  ///
  /// `StepContentRenderer` gates the feedback banners on `isAnswered`, so without
  /// this the author would see the options and nothing else — exactly the content
  /// they most need to check. No option is marked selected, so nothing claims the
  /// student chose it.
  StepAnswerState? get _answerState =>
      step.isEvaluationStep ? const StepAnswerState(isAnswered: true) : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.primaryDark12,
          width: highlighted ? 2 : 1,
        ),
      ),
      // A card-level target, under the leaf ones `StepContentRenderer` and
      // `_helpMarkers` add. Before this, the click-to-edit hit area was only
      // ever whatever glyphs/image a leaf `PreviewTarget` drew around — for a
      // short line of text that is a sliver of the card, and the rest (the
      // padding around it, the gaps between children, a step with no leaf
      // target at all) was dead space that didn't jump the editor anywhere.
      // `opaque` makes this target claim that dead space too; `outline:
      // false` keeps it invisible, because a 1.5px border flashing around the
      // *entire* card on every hover would be noise fighting the card's own
      // `highlighted` border above. It still loses every tap to a leaf
      // target or to `_bottomRow`'s own buttons — see
      // `PreviewTarget.behavior`'s doc comment for why nesting is safe.
      child: PreviewTarget(
        stepId: step.stepId,
        outline: false,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepContentRenderer(
              step: step,
              exportMode: exportMode,
              answerState: _answerState,
              // Everything the author wrote, whether or not a student would see it
              // at this moment. This view is for reading the card, not simulating it.
              showSolution: true,
              hideResults: false,
              hideFeedback: false,
            ),
            ..._branchMarkers(),
            ..._helpMarkers(),
            const SizedBox(height: 16),
            _bottomRow(),
          ],
        ),
      ),
    );
  }

  String? get _hint => step.hint ?? block.atomicHint;
  String? get _help => step.help ?? block.atomicHelp;
  bool get _hasHelp => (_hint ?? '').isNotEmpty || (_help ?? '').isNotEmpty;

  /// The card's own controls, in the state this view renders its content in.
  ///
  /// The question mark is gated per step rather than per block, because every step
  /// is on screen at once here: it shows exactly where the engine would show it if
  /// that step were the current one.
  Widget _bottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BlockActionBar(
          exportMode: exportMode,
          showHint: _hasHelp,
          onHint: () => onRefTapped(_helpRef()),
          // Bookmark, like and dislike have no authored field behind them, so they
          // report the step. Reporting something true beats a dead zone that reads
          // as a broken preview.
          onBookmark: () => onRefTapped(_stepRef()),
          onLike: () => onRefTapped(_stepRef()),
          onDislike: () => onRefTapped(_stepRef()),
        ),
        BlockMainButton(isComplete: true, onTap: () => onRefTapped(_stepRef())),
      ],
    );
  }

  PreviewRef _stepRef() => PreviewRef(blockId: block.blockId, stepId: step.stepId);

  /// The most specific place the question mark's text is actually written.
  ///
  /// A block-level hint is sent **without** a `stepId`: the editor reads a ref
  /// carrying one as addressing the step, and would write the card's hint onto a
  /// step that never had one.
  PreviewRef _helpRef() {
    if ((step.hint ?? '').isNotEmpty) {
      return PreviewRef(blockId: block.blockId, stepId: step.stepId, field: 'hint');
    }
    if ((step.help ?? '').isNotEmpty) {
      return PreviewRef(blockId: block.blockId, stepId: step.stepId, field: 'help');
    }
    if ((block.atomicHint ?? '').isNotEmpty) {
      return PreviewRef(blockId: block.blockId, field: 'hint');
    }
    return PreviewRef(blockId: block.blockId, field: 'help');
  }

  /// Where each answer leads, read straight off the options.
  List<Widget> _branchMarkers() {
    final options = step.evaluationConfig?.options ?? const [];
    final branching = options.where((o) => (o.goTo ?? '').isNotEmpty).toList();
    if (branching.isEmpty) return const [];

    return [
      const SizedBox(height: 10),
      for (final option in branching)
        _Marker(
          icon: Icons.call_split,
          text: '${_shorten(option.text)} → ${_describeTarget(option.goTo!)}',
        ),
    ];
  }

  /// What the question mark would say, spelled out.
  ///
  /// Untruncated, unlike the branch labels: the "?" beside them is now the way to
  /// go and edit the text, so these markers are here to be *read*, and forty
  /// characters of a hint is not a hint. Each one lands on the same field the
  /// question mark does.
  List<Widget> _helpMarkers() {
    final markers = <Widget>[];
    final hint = _hint;
    final help = _help;
    if ((hint ?? '').isNotEmpty) {
      markers.add(PreviewTarget(
        stepId: step.stepId,
        field: 'hint',
        child: _Marker(icon: Icons.lightbulb_outline, text: 'Nápověda: $hint'),
      ));
    }
    if ((help ?? '').isNotEmpty) {
      markers.add(PreviewTarget(
        stepId: step.stepId,
        field: 'help',
        child: _Marker(icon: Icons.school_outlined, text: 'Pomoc: $help'),
      ));
    }
    if (markers.isEmpty) return const [];
    return [const SizedBox(height: 10), ...markers];
  }

  String _describeTarget(String goTo) {
    switch (goTo) {
      case 'NEXT_STEP':
        return 'další krok';
      case 'AGAIN':
        return 'znovu';
      case 'END':
        return 'konec karty';
      case 'CHAT':
      case 'LECTURE':
        return 'výklad s AI';
    }
    final index = block.steps.indexWhere((s) => s.stepId == goTo);
    if (index >= 0) return 'krok ${index + 1}';
    final label = blockLabels[goTo];
    return label == null ? 'jiná karta' : 'karta „$label“';
  }

  static String _shorten(String text) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length > 40 ? '${flat.substring(0, 40)}…' : flat;
  }
}

/// A note about the card that the student would not see here — drawn only in the
/// preview, and visually distinct from the content so it is never mistaken for it.
class _Marker extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Marker({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDark48),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: AppColors.primaryDark64),
            ),
          ),
        ],
      ),
    );
  }
}
