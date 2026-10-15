import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/practice_repository.dart';
import '../../models/course_model.dart';
import '../database/app_database.dart';
import '../practice/practice_feedback.dart';
import '../practice/practice_filter.dart';
import '../practice/practice_scope.dart';
import '../practice/practice_service.dart';
import '../practice/queue_builder.dart';
import '../practice/skip_condition_evaluator.dart';
import '../services/practice_filter_store.dart';
import 'core_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Practice Repository Provider
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the practice repository.
final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PracticeRepository(db: db);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Practice Service Provider
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the practice service.
final practiceServiceProvider = Provider<PracticeService>((ref) {
  final repo = ref.watch(practiceRepositoryProvider);
  return PracticeService(repo: repo);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Practice Scope (subject → area selection)
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the practice-filter store.
final practiceFilterStoreProvider = Provider<PracticeFilterStore>((ref) {
  return PracticeFilterStore(ref.watch(sharedPreferencesProvider));
});

/// The student's chosen practice scope.
///
/// Read synchronously from SharedPreferences at construction so the dashboard
/// tile never renders an unfiltered count first and then correct itself.
class PracticeFilterNotifier extends StateNotifier<PracticeFilter> {
  PracticeFilterNotifier(this._store) : super(_store.read());

  final PracticeFilterStore _store;

  Future<void> _set(PracticeFilter next) async {
    if (next == state) return;
    state = next;
    await _store.write(next);
  }

  /// Switch one area on or off.
  Future<void> setArea({
    required List<PracticeSubject> scope,
    required PracticeArea area,
    required bool selected,
  }) =>
      _set(PracticeSelection.setArea(
        filter: state,
        scope: scope,
        area: area,
        selected: selected,
      ));

  /// Switch a whole subject — and with it all of its areas — on or off.
  Future<void> setSubject({
    required List<PracticeSubject> scope,
    required PracticeSubject subject,
    required bool selected,
  }) =>
      _set(PracticeSelection.setSubject(
        filter: state,
        scope: scope,
        subject: subject,
        selected: selected,
      ));

  /// Back to practising everything.
  Future<void> reset() => _set(PracticeFilter.all);
}

final practiceFilterProvider =
    StateNotifierProvider<PracticeFilterNotifier, PracticeFilter>((ref) {
  // Rebuilt when the active account changes so the selection is re-read from
  // storage — the logout teardown wipes the stored value, and without this the
  // in-memory state would carry one student's scope over to the next on a
  // shared device. Rebuilding mid-session is harmless: every change is written
  // through immediately, so the re-read returns the same filter.
  ref.watch(activeUserProvider);
  return PracticeFilterNotifier(ref.watch(practiceFilterStoreProvider));
});

/// The subject → area tree the practice picker renders, built from every card
/// in the student's deck (not just today's queue — an area with nothing due
/// today must still be visible, otherwise the list would rearrange itself
/// daily and selections would look lost).
///
/// Draws on the same practiceable set as the queue, so an `only_once` course
/// doesn't show up as a pickable subject that then yields nothing.
final practiceScopeProvider = FutureProvider<List<PracticeSubject>>((ref) async {
  final user = await ref.watch(activeUserProvider.future);
  if (user == null) return const [];

  final cards =
      await ref.watch(practiceRepositoryProvider).getPracticeableCards(user.id);
  if (cards.isEmpty) return const [];

  final db = ref.watch(appDatabaseProvider);
  final courses = <String, PracticeCourseInfo>{};
  for (final rawCourseId in cards.map((c) => c.courseId).toSet()) {
    final info = await _resolveCourseInfo(db, rawCourseId);
    if (info != null) courses[rawCourseId] = info;
  }

  return buildPracticeScope(cards: cards, courses: courses);
});

/// Loads a course by either id spelling a card may carry and reduces it to what
/// the picker needs. See [playablePracticeProvider] for why both lookups.
Future<PracticeCourseInfo?> _resolveCourseInfo(
    AppDatabase db, String rawCourseId) async {
  final row = await db.getCourseById(rawCourseId) ??
      await db.getCourseByFieldCourseId(rawCourseId);
  if (row == null) return null;

  try {
    final data = jsonDecode(row.data) as Map<String, dynamic>;
    final course = Course.fromJsonData(id: row.id, data: data);
    return PracticeCourseInfo(
      id: row.id,
      title: course.title.isNotEmpty ? course.title : row.name,
      lessonTitles: {
        for (final lesson in course.lessons) lesson.id: lesson.title,
      },
    );
  } catch (_) {
    // Unparseable course JSON still names a real course — offer it with no
    // lesson breakdown rather than hiding its cards from the picker.
    return PracticeCourseInfo(id: row.id, title: row.name);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Practice Data Providers
// ═══════════════════════════════════════════════════════════════════════════════

/// Future provider for today's practice queue for the active user.
final practiceQueueProvider = FutureProvider<List<PracticeCardsTableData>>((ref) async {
  final user = await ref.watch(activeUserProvider.future);
  if (user == null) return [];

  // Watched, not read: changing the selection has to rebuild the queue, the
  // dashboard count and the quiz from the same source.
  final filter = ref.watch(practiceFilterProvider);
  final service = ref.watch(practiceServiceProvider);
  return service.generateQueue(user.id, filter: filter);
});

/// Today's queue resolved to the actual, answerable content blocks — see
/// [_resolvePlayable].
final playablePracticeProvider =
    FutureProvider<({List<ContentBlock> blocks, String? courseId})>((ref) async {
  final queue = await ref.watch(practiceQueueProvider.future);
  return _resolvePlayable(ref, queue);
});

/// The bonus set offered once today's queue is empty (BR-A6HU52): cards
/// scheduled ahead — nearest and previously-wrong first — and, when there are
/// none of those, already-practised cards again.
///
/// Deliberately a provider of its own rather than a fallback inside
/// [practiceQueueProvider]: the dashboard count and the "you're done" hero read
/// the daily queue, and folding bonus cards into it would make the student look
/// permanently behind and bring back the just-answered card (BR-ZBJ99Z).
final practiceBonusQueueProvider =
    FutureProvider<List<PracticeCardsTableData>>((ref) async {
  final user = await ref.watch(activeUserProvider.future);
  if (user == null) return [];

  final filter = ref.watch(practiceFilterProvider);
  final cards =
      await ref.watch(practiceRepositoryProvider).getPracticeableCards(user.id);

  return QueueBuilder.buildBonusQueue(allCards: cards, filter: filter);
});

/// The bonus set resolved to playable blocks — same resolution (and same
/// skip_condition rules) the daily queue goes through, so a bonus round can't
/// offer content the normal session would have dropped.
final playableBonusPracticeProvider =
    FutureProvider<({List<ContentBlock> blocks, String? courseId})>((ref) async {
  final queue = await ref.watch(practiceBonusQueueProvider.future);
  return _resolvePlayable(ref, queue);
});

/// Resolves practice card rows to the actual, answerable content blocks.
///
/// A card row is only useful if its course/block can be loaded locally AND
/// the block is answerable (has a question or v2 steps). Cards that can't be
/// resolved — missing course content, stale block id, or a non-question block
/// that was bookmarked — are dropped here. This is the single source of truth
/// so the homepage count, the start screen and the quiz all show the SAME
/// number (previously the homepage counted raw card rows while the quiz only
/// played the resolvable ones, e.g. "12" vs "4").
Future<({List<ContentBlock> blocks, String? courseId})> _resolvePlayable(
  Ref ref,
  List<PracticeCardsTableData> queue,
) async {
  if (queue.isEmpty) return (blocks: <ContentBlock>[], courseId: null);


  final db = ref.watch(appDatabaseProvider);
  final blockByCourse = <String, Map<String, ContentBlock>>{};
  final resolved = <ContentBlock>[];
  String? firstCourseId;

  // Student ELO profile for skip_condition evaluation (queue rule 5).
  // All queue cards belong to the same user.
  List<double?> profilElo = const [];
  final activeUser = await ref.watch(activeUserProvider.future);
  if (activeUser != null) {
    final eloProfile =
        await ref.watch(eloRepositoryProvider).getProfile(activeUser.id);
    profilElo = eloProfile?.profilElo ?? const [];
  }

  for (final card in queue) {
    var lookup = blockByCourse[card.courseId];
    if (lookup == null) {
      lookup = {};
      // A card's courseId may be either the local primary id (e.g. quiz
      // auto-bookmark passes localCourse.id) or the field course_id (e.g.
      // lesson bookmarks pass widget.course.id = "A2-Rovnice_c1"). Try both
      // so cards aren't silently dropped over an id-scheme mismatch.
      final row = await db.getCourseById(card.courseId) ??
          await db.getCourseByFieldCourseId(card.courseId);
      if (row != null) {
        final data = jsonDecode(row.data) as Map<String, dynamic>;
        final course = Course.fromJsonData(id: row.id, data: data);
        for (final lesson in course.lessons) {
          for (final block in course.getBlocksForLesson(lesson.id)) {
            lookup[block.blockId] = block;
          }
        }
        // Unassigned blocks (present in course `blocks[]` but not referenced by
        // any lesson) are still playable in quizzes and can be bookmarked /
        // auto-bookmarked on a wrong answer, which seeds a practice card. Without
        // them in the lookup those cards resolve to nothing and silently vanish
        // from the queue + count (BR-A2DD22). putIfAbsent so lesson-bound blocks
        // (with their merged default_practice flag) keep priority.
        for (final block in course.getAllBlocks()) {
          lookup.putIfAbsent(block.blockId, () => block);
        }
      }
      blockByCourse[card.courseId] = lookup;
    }

    // Step-level bookmarks store blockId as "baseBlockId:stepId"; fall back to
    // the base block so those cards resolve too.
    var block = lookup[card.blockId];
    if (block == null && card.blockId.contains(':')) {
      block = lookup[card.blockId.split(':').first];
    }
    // Include any resolvable block: answerable blocks (question / v2 steps) are
    // graded automatically, display/content blocks are self-rated in the quiz
    // (Nevím / Připomeň / Jde to / Pamatuji). Only blocks whose course/content
    // can't be resolved at all are dropped.
    if (block != null) {
      // Queue rule 5: skip the block when its skip_condition is satisfied
      // (e.g. "GPF_mastery > 0.8"). The card's own condition (synced from the
      // server) wins over the block's authoring-time one.
      final condition = (card.skipCondition?.trim().isNotEmpty ?? false)
          ? card.skipCondition
          : block.fsrs?.skipCondition;
      if (SkipConditionEvaluator.shouldSkip(
        condition: condition,
        block: block,
        profilElo: profilElo,
      )) {
        continue;
      }
      resolved.add(withPracticeFeedback(block));
      firstCourseId ??= card.courseId;
    }
  }

  return (blocks: resolved, courseId: firstCourseId);
}

/// Count of practice cards the user can actually review now — derived from
/// [playablePracticeProvider] so it matches the quiz exactly.
final dueCardsCountProvider = FutureProvider<int>((ref) async {
  final result = await ref.watch(playablePracticeProvider.future);
  return result.blocks.length;
});
