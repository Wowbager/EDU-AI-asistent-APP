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

import 'package:flutter/material.dart';

import '../models/block_model.dart';
import '../models/step_navigation.dart';
import '../widgets/block_step_engine.dart';
import 'preview_mode.dart';
import 'preview_ref.dart';

/// Somewhere the author has been: which block, and how far into it.
@immutable
class _Visit {
  final int blockIndex;
  final int stepIndex;

  const _Visit(this.blockIndex, this.stepIndex);

  @override
  bool operator ==(Object other) =>
      other is _Visit && other.blockIndex == blockIndex && other.stepIndex == stepIndex;

  @override
  int get hashCode => Object.hash(blockIndex, stepIndex);
}

class PreviewLessonPlayer extends StatefulWidget {
  final List<ContentBlock> blocks;
  final ExportMode exportMode;
  final String? lessonId;

  /// Where to start — the card the author has selected in the editor.
  final String? startBlockId;

  final void Function(PreviewRef ref) onRefTapped;
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

  /// Index of the block the author is on; everything before it is history.
  late int _current;

  /// Index of the first block shown, so starting mid-lesson does not render the
  /// cards before it as though they had been completed.
  late int _first;

  /// Where the author has been, oldest first. The current position is the last
  /// entry, so a back is "drop the last, restore the one before".
  final List<_Visit> _history = [];

  /// Bumped to force the engine to re-create, which is the only way it restarts at
  /// an earlier step.
  int _generation = 0;
  StepProgressData? _restore;

  @override
  void initState() {
    super.initState();
    _first = _indexOfStart();
    _current = _first;
    _history.add(_Visit(_current, 0));
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

    // The author can delete cards while the run is open. `_first`, `_current` and
    // the history are positions in `widget.blocks`, so a lesson that shrank leaves
    // them pointing past the end — and `build`'s `sublist` below throws where the
    // message handler's try/catch cannot see it, giving a red error widget instead
    // of the placeholder a broken draft is supposed to get. (Keying `_Visit` by
    // `blockId` is the real fix; this stops it crashing.)
    final last = widget.blocks.length - 1;
    if (last < 0 || (_current <= last && _first <= last)) return;
    setState(() {
      _first = _first.clamp(0, last);
      _current = _current.clamp(_first, last);
      _history.removeWhere((visit) => visit.blockIndex > last);
      if (_history.isEmpty) _history.add(_Visit(_current, 0));
      _restore = null;
      _generation++;
    });
    _reportNavState();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _indexOfStart() {
    if (widget.startBlockId == null) return 0;
    final index = widget.blocks.indexWhere((b) => b.blockId == widget.startBlockId);
    return index < 0 ? 0 : index;
  }

  bool get canGoBack => _history.length > 1;

  void _reportNavState() => widget.onNavState(canGoBack);

  /// Start the lesson again from the card the editor has selected.
  void restart() {
    setState(() {
      _first = _indexOfStart();
      _current = _first;
      _history
        ..clear()
        ..add(_Visit(_current, 0));
      _restore = null;
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
      _current = target.blockIndex;
      _restore = StepProgressData(
        blockId: widget.blocks[target.blockIndex].blockId,
        currentStepIndex: target.stepIndex,
      );
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
    if (_current + 1 >= widget.blocks.length) return;
    setState(() {
      _current++;
      _restore = null;
      _generation++;
    });
    _recordVisit(_Visit(_current, 0));
    _scrollToCurrent();
  }

  /// A cross-block `go_to`. In the student's app this jumps within the lesson, so
  /// it does here too — otherwise the branching an author most wants to test is the
  /// one thing the preview cannot show.
  void _jumpTo(String blockId) {
    final index = widget.blocks.indexWhere((b) => b.blockId == blockId);
    if (index < 0) {
      // Not in this lesson: tell the editor, which will select the card.
      widget.onRefTapped(PreviewRef(blockId: blockId));
      return;
    }
    setState(() {
      _current = index;
      _restore = null;
      _generation++;
    });
    _recordVisit(_Visit(_current, 0));
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

    // Clamped again at the point of use: `didUpdateWidget` catches a shrinking
    // lesson, but a build can also run from a `setState` that raced it.
    final last = widget.blocks.length - 1;
    final from = _first.clamp(0, last);
    final visible = widget.blocks.sublist(from, _current.clamp(from, last) + 1);

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final blockIndex = from + index;
        final block = widget.blocks[blockIndex];
        final isCurrent = blockIndex == _current;

        return PreviewScope(
          mode: PreviewMode(
            enabled: true,
            // The whole point of this mode: every control works.
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
            onBlockCompleted: ({int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {
              widget.onCompleted(xp: earnedXp, scoreKoef: scoreKoef, mark: mark);
              _advance();
            },
            onStepProgress: (progress) {
              if (!isCurrent) return;
              _recordVisit(_Visit(blockIndex, progress.currentStepIndex));
              final steps = block.steps;
              final at = progress.currentStepIndex;
              if (at >= 0 && at < steps.length) {
                widget.onStepChanged(block.blockId, steps[at].stepId);
              }
            },
            onCrossBlockNavigate: _jumpTo,
            onChatRequested: () {},
            savedProgress: isCurrent ? _restore : null,
          ),
        );
      },
    );
  }
}
