// The editor's "Vyzkoušet": the lesson as a pupil meets it.
//
// This mirrors `lesson_detail_page`'s grammar — a growing list where exactly one
// block is current, the finished ones stay above as history, and completing one
// advances and scrolls — without any of its dependencies on auth, Drift or the API.
// Everything a real session would write is either reported to the editor or dropped.
//
// It adds one thing the student's app does not have and the author needs: **back**.
// `BlockStepEngine` cannot go backwards — `_currentStepIndex` only ever increments,
// or is set from `savedProgress` — and rewriting its navigation would make every
// future app upgrade a merge. So the history lives out here instead, and going back
// re-mounts the engine at a place it has already been. The cost is that answers are
// re-entered, which is what you want anyway when the reason you went back was to
// take the other branch.

//
// Two more things the editor relies on:
//
//  * **Where the run is.** Every time the step on screen changes — the first card
//    mounting, the next card, a branch to another card, back, restart, a move
//    within a card — `onStepChanged` reports `(blockId, stepId)`, once per change.
//    It comes from the engine's `onStepShown`, which is fired from the one setter
//    all of the engine's moves go through, rather than from a call at each place
//    this file moves. The editor follows the run with it.
//  * **Positions are card ids, not indices.** The author edits while the run is
//    open: cards are reordered and deleted under it. An index into `blocks` then
//    points at a different card, so the history and the current card are kept by
//    `blockId` and resolved against the lesson as it is now.
//
// Taps are the pupil's here. `PreviewScope(interactive: true)` makes every
// `PreviewTarget` inert, so clicking text or a picture does what it does in the
// app — nothing — and never jumps the editor.

import 'package:flutter/material.dart';

import '../models/block_model.dart';
import '../models/step_navigation.dart';
import '../widgets/block_step_engine.dart';
import 'preview_hint.dart';
import 'preview_mode.dart';
import 'preview_ref.dart';

/// Somewhere the author has been: which card, and how far into it.
@immutable
class _Visit {
  final String blockId;
  final int stepIndex;

  const _Visit(this.blockId, this.stepIndex);

  @override
  bool operator ==(Object other) =>
      other is _Visit && other.blockId == blockId && other.stepIndex == stepIndex;

  @override
  int get hashCode => Object.hash(blockId, stepIndex);
}

class PreviewLessonPlayer extends StatefulWidget {
  final List<ContentBlock> blocks;
  final ExportMode exportMode;
  final String? lessonId;

  /// Where to start — the card the author had selected when the run began.
  final String? startBlockId;

  final void Function(PreviewRef ref) onRefTapped;

  /// The step now on screen, whenever it changes. See the file comment.
  final void Function(String blockId, String stepId) onStepChanged;
  final void Function({required int xp, required double scoreKoef, String? mark}) onCompleted;

  /// Reports whether there is anywhere to go back to, so the editor can enable or
  /// disable its own button rather than guessing.
  final void Function(bool canGoBack) onNavState;

  const PreviewLessonPlayer({
    super.key,
    required this.blocks,
    required this.onRefTapped,
    required this.onStepChanged,
    required this.onCompleted,
    required this.onNavState,
    this.exportMode = ExportMode.courseV2,
    this.lessonId,
    this.startBlockId,
  });

  @override
  State<PreviewLessonPlayer> createState() => PreviewLessonPlayerState();
}

class PreviewLessonPlayerState extends State<PreviewLessonPlayer> {
  final ScrollController _scroll = ScrollController();

  /// The card the author is on; the cards from [_firstId] up to it are history.
  late String _currentId;

  /// The first card shown, so starting mid-lesson does not render the cards
  /// before it as though they had been completed.
  late String _firstId;

  /// Where the author has been, oldest first. The current position is the last
  /// entry, so a back is "drop the last, restore the one before".
  final List<_Visit> _history = [];

  /// Bumped to force the engine to re-create, which is the only way it restarts at
  /// an earlier step.
  int _generation = 0;
  StepProgressData? _restore;

  /// The step the current card's engine last showed, and the last position sent
  /// to the editor — so a rebuild that changes nothing sends nothing.
  int _shownStep = 0;
  _Visit? _reported;

  @override
  void initState() {
    super.initState();
    _firstId = _startId();
    _currentId = _firstId;
    _history.add(_Visit(_currentId, 0));
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportNavState());
  }

  @override
  void didUpdateWidget(PreviewLessonPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different starting card, or a different lesson, restarts the run. An edit
    // to the content of the card being played does not.
    if (oldWidget.startBlockId != widget.startBlockId ||
        oldWidget.lessonId != widget.lessonId) {
      restart();
      return;
    }
    if (widget.blocks.isEmpty) return;

    // Cards deleted under the run: forget the visits to them, and if the current
    // or the first card went, fall back to the latest place that still exists.
    final ids = widget.blocks.map((b) => b.blockId).toSet();
    final lostCurrent = !ids.contains(_currentId);
    final lostFirst = !ids.contains(_firstId);
    final before = _history.length;
    _history.removeWhere((visit) => !ids.contains(visit.blockId));
    if (_history.isEmpty) _history.add(_Visit(widget.blocks.first.blockId, 0));

    // The current card lost the step it was on: re-mount it on the nearest one
    // that is left, because the engine indexes its steps by position.
    final current = _blockById(_currentId);
    final shrunk = current != null && _shownStep >= current.steps.length;

    if (!lostCurrent && !lostFirst && !shrunk && before == _history.length) return;
    setState(() {
      if (lostCurrent) _currentId = _history.last.blockId;
      if (lostFirst) _firstId = _history.first.blockId;
      if (_indexOf(_firstId) > _indexOf(_currentId)) _firstId = _currentId;
      final block = _blockById(_currentId)!;
      _restore = shrunk || lostCurrent
          ? StepProgressData(
              blockId: _currentId,
              currentStepIndex: (lostCurrent ? _history.last.stepIndex : _shownStep)
                  .clamp(0, block.steps.isEmpty ? 0 : block.steps.length - 1),
            )
          : _restore;
      _generation++;
    });
    _reportNavState();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _indexOf(String blockId) => widget.blocks.indexWhere((b) => b.blockId == blockId);

  ContentBlock? _blockById(String blockId) {
    for (final block in widget.blocks) {
      if (block.blockId == blockId) return block;
    }
    return null;
  }

  String _startId() {
    final start = widget.startBlockId;
    if (start != null && _indexOf(start) >= 0) return start;
    return widget.blocks.isEmpty ? '' : widget.blocks.first.blockId;
  }

  bool get canGoBack => _history.length > 1;

  void _reportNavState() => widget.onNavState(canGoBack);

  /// Tell the editor which step is on screen, unless it already knows.
  void _reportPosition(String blockId, int stepIndex) {
    final block = _blockById(blockId);
    if (block == null || stepIndex < 0 || stepIndex >= block.steps.length) return;
    final visit = _Visit(blockId, stepIndex);
    if (visit == _reported) return;
    _reported = visit;
    widget.onStepChanged(blockId, block.steps[stepIndex].stepId);
  }

  /// Start the lesson again from the card the run started on.
  void restart() {
    setState(() {
      _firstId = _startId();
      _currentId = _firstId;
      _history
        ..clear()
        ..add(_Visit(_currentId, 0));
      _restore = null;
      _reported = null;
      _generation++;
    });
    _reportNavState();
    _scrollToCurrent();
  }

  /// Retrace one move: a step within the current card, or back to the previous card.
  ///
  /// The engine is re-created at the restored position, because it has no way to
  /// step backwards on its own. Answers given after that point are gone, which is
  /// the honest outcome — the author is about to give different ones.
  void back() {
    if (!canGoBack) return;
    _history.removeLast();
    final target = _history.last;
    setState(() {
      _currentId = target.blockId;
      if (_indexOf(_firstId) > _indexOf(_currentId)) _firstId = _currentId;
      _restore = StepProgressData(blockId: target.blockId, currentStepIndex: target.stepIndex);
      _generation++;
    });
    _reportNavState();
    _scrollToCurrent();
  }

  void _recordVisit(_Visit visit) {
    if (_history.isNotEmpty && _history.last == visit) return;
    _history.add(visit);
    _reportNavState();
  }

  void _advance() {
    final next = _indexOf(_currentId) + 1;
    if (next <= 0 || next >= widget.blocks.length) return;
    setState(() {
      _currentId = widget.blocks[next].blockId;
      _restore = null;
      _generation++;
    });
    _recordVisit(_Visit(_currentId, 0));
    _scrollToCurrent();
  }

  /// A cross-block `go_to`. In the student's app this jumps within the lesson, so
  /// it does here too — otherwise the branching an author most wants to test is the
  /// one thing the preview cannot show.
  void _jumpTo(String blockId) {
    if (_indexOf(blockId) < 0) {
      // Not in this lesson: tell the editor, which will select the card.
      widget.onRefTapped(PreviewRef(blockId: blockId));
      return;
    }
    setState(() {
      _currentId = blockId;
      if (_indexOf(_firstId) > _indexOf(_currentId)) _firstId = _currentId;
      _restore = null;
      _generation++;
    });
    _recordVisit(_Visit(_currentId, 0));
    _scrollToCurrent();
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.blocks.isEmpty) {
      return const Center(child: Text('Lekce zatím nemá žádné karty.'));
    }

    // Resolved at the point of use: `didUpdateWidget` repairs a lesson that lost
    // cards, but a build can also run from a `setState` that raced it.
    final last = widget.blocks.length - 1;
    final current = _indexOf(_currentId).clamp(0, last);
    final from = _indexOf(_firstId).clamp(0, current);
    final visible = widget.blocks.sublist(from, current + 1);

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final block = visible[index];
        final isCurrent = from + index == current;

        return PreviewScope(
          mode: PreviewMode(
            enabled: true,
            // The whole point of this mode: every control works, and taps belong
            // to them rather than to click-to-edit.
            interactive: true,
            blockId: block.blockId,
            lessonId: widget.lessonId,
            onRefTapped: widget.onRefTapped,
          ),
          child: BlockStepEngine(
            // The generation is in the key so that a back or a restart re-creates
            // the engine; without it the engine keeps its own forward-only state.
            key: ValueKey('${block.blockId}_${isCurrent ? _generation : 'done'}'),
            block: block,
            exportMode: widget.exportMode,
            isCurrent: isCurrent,
            isCompleted: !isCurrent,
            hasHint: block.hasHint,
            onHintRequested: block.hasHint ? () => showPreviewHint(context, block) : null,
            onBlockCompleted: ({int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {
              widget.onCompleted(xp: earnedXp, scoreKoef: scoreKoef, mark: mark);
              _advance();
            },
            onStepProgress: (progress) {
              if (!isCurrent) return;
              _recordVisit(_Visit(block.blockId, progress.currentStepIndex));
            },
            onStepShown: isCurrent
                ? (stepIndex) {
                    _shownStep = stepIndex;
                    _reportPosition(block.blockId, stepIndex);
                  }
                : null,
            onCrossBlockNavigate: _jumpTo,
            onChatRequested: () {},
            savedProgress: isCurrent ? _restore : null,
          ),
        );
      },
    );
  }
}
