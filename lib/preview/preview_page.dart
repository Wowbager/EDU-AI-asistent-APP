// The editor's preview surface: a bare scaffold that renders a block — or a whole
// lesson — from JSON handed in over the message channel.
//
// It sits outside `AuthWrapper`: there is no student here, nothing is downloaded,
// and nothing is written. Every callback the engine offers is either reported back
// to the editor or dropped on the floor, and `PreviewScope` marks the subtree so
// that any code which *would* persist, award XP, enrol a practice card, call the
// API or report analytics can refuse at the point of effect.

import 'package:flutter/material.dart';

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
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  late final PreviewChannel _channel;

  ContentBlock? _block;
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

  @override
  void initState() {
    super.initState();
    _channel = createPreviewChannel();
    _channel.listen(_onEditorMessage);
    _channel.send({'type': 'ready'});
  }

  @override
  void dispose() {
    _channel.dispose();
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
          });
          _playerKey.currentState?.restart();
        case 'back':
          _playerKey.currentState?.back();
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
    final blockJson = raw is List && raw.isNotEmpty
        ? raw.first as Map<String, dynamic>
        : raw as Map<String, dynamic>;

    final block = ContentBlock.fromJson(blockJson);
    final stepIds = block.steps.map((s) => s.stepId).toList();
    final remount = message['remount'] == true || !_sameIds(stepIds, _stepIds);

    setState(() {
      _error = null;
      _block = block;
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
      _exportMode = _modeFrom(message['exportMode']);
      _view = (message['view'] as String?) ?? 'play';
      // Everything the single-card view was holding. None of it is read down the
      // lesson path, but one mode leaving its state standing while the other is on
      // screen is exactly the shape the restore-point bug had.
      _highlightedStepId = null;
      _blockLabels = const {};
      _stepIds = const [];
      _restoreStepId = null;
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
        child: PreviewExpandedBlock(
          block: block,
          exportMode: _exportMode,
          lessonId: _lessonId,
          highlightedStepId: _highlightedStepId,
          blockLabels: _blockLabels,
          onRefTapped: _reportRef,
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
          _channel.send({
            'type': 'stepChanged',
            'blockId': block.blockId,
            'stepId': stepId,
            'shownStepIds': [for (final i in onScreen) _stepIdAt(block, i)],
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
      onStepChanged: (blockId, stepId, shownStepIds) => _channel.send({
        'type': 'stepChanged',
        'blockId': blockId,
        'stepId': stepId,
        'shownStepIds': shownStepIds,
      }),
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
