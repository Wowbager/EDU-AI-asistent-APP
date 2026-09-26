// The editor's preview surface: a bare scaffold that renders a block — or a whole
// lesson — from JSON handed in over the message channel.
//
// It sits outside `AuthWrapper`: there is no student here, nothing is downloaded,
// and nothing is written. Every callback the engine offers is either reported back
// to the editor or dropped on the floor, and `PreviewScope` marks the subtree so
// that any code which *would* persist, award XP, enrol a practice card, call the
// API or report analytics can refuse at the point of effect.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import '../core/theme/app_colors.dart';
import '../models/block_model.dart';
import '../models/step_navigation.dart';
import '../widgets/block_step_engine.dart';
import 'preview_channel.dart';
import 'preview_expanded_block.dart';
import 'preview_hint.dart';
import 'preview_lesson_player.dart';
import 'preview_mode.dart';
import 'preview_ref.dart';

class PreviewPage extends StatefulWidget {
  /// The channel to the editor. Null is the platform's own; tests pass a fake.
  final PreviewChannel? channel;

  const PreviewPage({super.key, this.channel});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  late final PreviewChannel _channel;

  /// Keeps Flutter's semantics tree on for as long as the preview is open.
  SemanticsHandle? _semantics;

  ContentBlock? _block;

  /// Every block `setBlock` sent, in order. The editor sends the blocks one teacher's
  /// card is made of (one per question); Náhled draws them one under another, as a
  /// pupil meets them. `_block` is the first.
  List<ContentBlock> _blocks = const [];
  Map<String, dynamic>? _course;
  String? _lessonId;
  String? _startBlockId;

  /// How the editor wants other cards named in branch markers — never ids unless
  /// the editor is in its advanced mode.
  Map<String, String> _blockLabels = const {};
  ExportMode _exportMode = ExportMode.courseV2;
  String? _error;

  /// Which of the editor's two modes is on screen.
  ///
  ///  * `expanded` — one card, every step at once, nothing interactive.
  ///  * `play`     — the lesson as a pupil takes it, from the selected card on.
  String _view = 'expanded';

  /// The step the editor has selected, outlined in the expanded view.
  String? _highlightedStepId;

  final GlobalKey<PreviewLessonPlayerState> _playerKey =
      GlobalKey<PreviewLessonPlayerState>();

  /// Bumped only when the step graph changes, so the engine is re-created then and
  /// not on every keystroke in the editor.
  int _mountGeneration = 0;
  List<String> _stepIds = const [];
  String? _restoreStepId;

  /// Where a played card or lesson last said the pupil is — the same thing that
  /// went up as `stepChanged` — kept for `inspect`.
  ({String blockId, String stepId, List<String> shownStepIds})? _position;

  @override
  void initState() {
    super.initState();
    _semantics = SemanticsBinding.instance.ensureSemantics();
    _channel = widget.channel ?? createPreviewChannel();
    _channel.listen(_onEditorMessage);
    _channel.send({'type': 'ready'});
  }

  @override
  void dispose() {
    _channel.dispose();
    _semantics?.dispose();
    super.dispose();
  }

  void _onEditorMessage(Map<String, dynamic> message) {
    final type = message['type'];
    try {
      switch (type) {
        case 'setBlock':
          _applyBlock(message);
        case 'setLesson':
          _applyLesson(message);
        case 'reset':
        case 'restart':
          setState(() {
            _mountGeneration++;
            _restoreStepId = null;
            _highlightedStepId = null;
            _error = null;
            _position = null;
          });
          _playerKey.currentState?.restart();
        case 'back':
          _playerKey.currentState?.back();
        case 'inspect':
          _inspect(message['id']);
        case 'highlight':
          // In the expanded view every step is on screen, so a highlight has
          // somewhere to land: it outlines the step the editor is working on. A
          // played view never shows which step is focused — the pupil's screen has
          // no such thing — so it reads nothing of this.
          final ref = message['ref'];
          setState(() {
            _highlightedStepId = ref is Map ? ref['stepId'] as String? : null;
          });
      }
    } catch (error) {
      // A draft is allowed to be broken — that is the normal state of something
      // being written. It must never take the player down with it.
      setState(() => _error = '$error');
    }
  }

  void _applyBlock(Map<String, dynamic> message) {
    final raw = message['block'];
    final blocksJson = raw is List
        ? raw.cast<Map<String, dynamic>>()
        : [raw as Map<String, dynamic>];
    if (blocksJson.isEmpty) throw const FormatException('setBlock without a block');

    final blocks = blocksJson.map(ContentBlock.fromJson).toList();
    final block = blocks.first;
    final stepIds = [
      for (final b in blocks) ...b.steps.map((s) => s.stepId),
    ];
    final remount = message['remount'] == true || !_sameIds(stepIds, _stepIds);

    setState(() {
      _error = null;
      if (remount || _view != ((message['view'] as String?) ?? 'expanded')) {
        _position = null;
      }
      _block = block;
      _blocks = blocks;
      _course = null;
      _lessonId = null;
      _startBlockId = null;
      _exportMode = _modeFrom(message['exportMode']);
      _view = (message['view'] as String?) ?? 'expanded';
      _highlightedStepId = message['stepId'] as String?;
      final labels = message['blockLabels'];
      _blockLabels = labels is Map
          ? labels.map((key, value) => MapEntry('$key', '$value'))
          : const {};
      _stepIds = stepIds;
      if (remount) {
        _mountGeneration++;
        _restoreStepId = message['stepId'] as String?;
      }
    });
  }

  void _applyLesson(Map<String, dynamic> message) {
    setState(() {
      _error = null;
      _course = message['course'] as Map<String, dynamic>?;
      _lessonId = message['lessonId'] as String?;
      _startBlockId = message['startBlockId'] as String?;
      _block = null;
      _blocks = const [];
      _exportMode = _modeFrom(message['exportMode']);
      _view = (message['view'] as String?) ?? 'play';
      // Everything the single-card view was holding. None of it is read down the
      // lesson path, but one mode leaving its state standing while the other is on
      // screen is exactly the shape the restore-point bug had.
      _highlightedStepId = null;
      _blockLabels = const {};
      _stepIds = const [];
      _restoreStepId = null;
      _position = null;
      _mountGeneration++;
    });
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static ExportMode _modeFrom(Object? value) {
    switch (value) {
      case 'exercise_v2':
        return ExportMode.exerciseV2;
      case 'quiz_v2':
        return ExportMode.quizV2;
      default:
        return ExportMode.courseV2;
    }
  }

  /// Answers `inspect` with what is on screen, once the frame that draws it has
  /// been painted — so a reply means the last message the editor sent is showing.
  ///
  /// The editor's tests use it to wait for the player instead of sleeping. It
  /// reports state this page already holds and changes none of it.
  void _inspect(Object? id) {
    SchedulerBinding.instance.endOfFrame.then((_) {
      if (!mounted) return;
      final block = _block;
      final lesson = _course != null && _lessonId != null;
      final position = _position;
      _channel.send({
        'type': 'inspected',
        if (id != null) 'id': id,
        'view': _view,
        'content': _error != null
            ? 'error'
            : lesson
                ? 'lesson'
                : block != null
                    ? 'block'
                    : 'none',
        if (_error != null) 'error': _error,
        if (lesson) 'lessonId': _lessonId,
        'blockId': position?.blockId ?? block?.blockId,
        if (!lesson && _blocks.isNotEmpty)
          'blockIds': [for (final b in _blocks) b.blockId],
        'stepId': _view == 'expanded' ? _highlightedStepId : position?.stepId,
        'shownStepIds': _view == 'expanded'
            ? _stepIds
            : (position?.shownStepIds ?? const <String>[]),
        'canGoBack': _playerKey.currentState?.canGoBack ?? false,
      });
    });
  }

  void _reportRef(PreviewRef ref) {
    _channel.send({'type': 'clicked', 'ref': ref.toJson()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _error != null
            ? _PreviewPlaceholder(message: _error!)
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final course = _course;
    final lessonId = _lessonId;
    if (course != null && lessonId != null) return _buildLesson(course, lessonId);

    final block = _block;
    if (block == null) {
      return const _PreviewPlaceholder(
        message: 'Náhled čeká na obsah z editoru.',
      );
    }

    // One card. Expanded, it is read; played, it is taken.
    if (_view == 'expanded') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final shown in _blocks) ...[
              if (shown != _blocks.first) const SizedBox(height: 16),
              PreviewExpandedBlock(
                block: shown,
                exportMode: _exportMode,
                lessonId: _lessonId,
                highlightedStepId: _highlightedStepId,
                blockLabels: _blockLabels,
                onRefTapped: _reportRef,
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildBlock(block),
    );
  }

  Widget _buildBlock(ContentBlock block, {String? lessonId}) {
    return PreviewScope(
      mode: PreviewMode(
        enabled: true,
        blockId: block.blockId,
        lessonId: lessonId ?? _lessonId,
        onRefTapped: _reportRef,
      ),
      child: BlockStepEngine(
        key: ValueKey('${block.blockId}_$_mountGeneration'),
        block: block,
        exportMode: _exportMode,
        isCurrent: true,
        // Every one of these would touch storage, XP, the practice queue or the API
        // in a real session. Here they either travel back to the editor as
        // information, or go nowhere at all.
        onBlockCompleted: ({int earnedXp = 0, double scoreKoef = 1.0, String? mark}) {
          _channel.send({
            'type': 'completed',
            'xp': earnedXp,
            'scoreKoef': scoreKoef,
            if (mark != null) 'mark': mark,
          });
        },
        onHintRequested: () => showPreviewHint(context, block),
        // Where the pupil is, every time it changes — the same report, and the same
        // shape, as the lesson player's.
        onStepShown: (index, onScreen) {
          final stepId = _stepIdAt(block, index);
          if (stepId.isEmpty) return;
          final shown = [for (final i in onScreen) _stepIdAt(block, i)];
          _position = (blockId: block.blockId, stepId: stepId, shownStepIds: shown);
          _channel.send({
            'type': 'stepChanged',
            'blockId': block.blockId,
            'stepId': stepId,
            'shownStepIds': shown,
          });
        },
        onCrossBlockNavigate: (blockId) {
          _channel.send({
            'type': 'clicked',
            'ref': PreviewRef(blockId: blockId).toJson(),
          });
        },
        onChatRequested: () {},
        savedProgress: _restoreProgress(block),
      ),
    );
  }

  String _stepIdAt(ContentBlock block, int index) {
    if (index < 0 || index >= block.steps.length) return '';
    return block.steps[index].stepId;
  }

  /// After a re-mount, land on the step the editor asked for — the nearest one that
  /// survived the edit — instead of snapping back to the first.
  StepProgressData? _restoreProgress(ContentBlock block) {
    final stepId = _restoreStepId;
    if (stepId == null) return null;
    final index = block.steps.indexWhere((s) => s.stepId == stepId);
    // Index 0 is a real position, not "not found": going back to the first step has
    // to restore there rather than fall through to no progress at all.
    if (index < 0) return null;
    return StepProgressData(blockId: block.blockId, currentStepIndex: index);
  }

  /// "Vyzkoušet": the lesson as a pupil takes it, starting at the selected card.
  Widget _buildLesson(Map<String, dynamic> course, String lessonId) {
    final entries = BlockLoader.loadBlocksWithBindings(
      courseData: course,
      lessonId: lessonId,
    );

    if (entries.isEmpty) {
      return const _PreviewPlaceholder(message: 'Lekce zatím nemá žádné karty.');
    }

    return PreviewLessonPlayer(
      key: _playerKey,
      blocks: entries.map((e) => e.block).toList(),
      exportMode: _exportMode,
      lessonId: lessonId,
      startBlockId: _startBlockId,
      onRefTapped: _reportRef,
      onStepChanged: (blockId, stepId, shownStepIds) {
        _position = (blockId: blockId, stepId: stepId, shownStepIds: shownStepIds);
        _channel.send({
          'type': 'stepChanged',
          'blockId': blockId,
          'stepId': stepId,
          'shownStepIds': shownStepIds,
        });
      },
      onCompleted: ({required int xp, required double scoreKoef, String? mark}) {
        _channel.send({
          'type': 'completed',
          'xp': xp,
          'scoreKoef': scoreKoef,
          if (mark != null) 'mark': mark,
        });
      },
      onNavState: (canGoBack) =>
          _channel.send({'type': 'navState', 'canGoBack': canGoBack}),
    );
  }
}

/// A broken draft renders this, never a crash: the author is mid-sentence, and the
/// preview has to survive every intermediate state the document passes through.
class _PreviewPlaceholder extends StatelessWidget {
  final String message;

  const _PreviewPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 40, color: AppColors.primaryDark48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.primaryDark64),
            ),
          ],
        ),
      ),
    );
  }
}
