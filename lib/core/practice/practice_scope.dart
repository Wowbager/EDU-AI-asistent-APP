import '../database/app_database.dart';
import 'practice_filter.dart';
import 'queue_builder.dart';

/// What the picker knows about one course: its display title and the titles of
/// its lessons, in course order.
///
/// Supplied by the caller (the provider reads them out of Drift) so the tree
/// building below stays a pure, testable function.
class PracticeCourseInfo {
  /// Stable id of the course row — the identity the picker groups on.
  final String id;

  final String title;

  /// lessonId → lesson title, in course order (insertion order is preserved).
  final Map<String, String> lessonTitles;

  const PracticeCourseInfo({
    required this.id,
    required this.title,
    this.lessonTitles = const {},
  });
}

/// One selectable area (lesson) inside a subject.
class PracticeArea {
  /// Lesson id, or `''` for cards with no lesson context.
  final String lessonId;

  final String title;

  /// Every `"<courseId>|<lessonId>"` key that maps to this area — more than one
  /// when the same course reached the deck under both id spellings.
  final Set<String> keys;

  /// Cards of this area waiting for the student today.
  final int dueCount;

  /// Cards of this area in the deck at all, due or not.
  final int totalCount;

  const PracticeArea({
    required this.lessonId,
    required this.title,
    required this.keys,
    required this.dueCount,
    required this.totalCount,
  });

  /// True when this area holds the cards that carry no lesson (auto-bookmarks
  /// from wrong quiz answers). The UI labels it separately.
  bool get isUnassigned => lessonId.isEmpty;
}

/// One selectable subject (course) with its areas.
class PracticeSubject {
  /// Course row id — or the raw card course id when the course row is gone.
  final String id;

  final String title;

  /// Every raw `card.courseId` spelling that maps to this subject.
  final Set<String> courseIds;

  final List<PracticeArea> areas;

  const PracticeSubject({
    required this.id,
    required this.title,
    required this.courseIds,
    required this.areas,
  });

  int get dueCount => areas.fold(0, (sum, a) => sum + a.dueCount);

  int get totalCount => areas.fold(0, (sum, a) => sum + a.totalCount);

  /// Every area key of this subject — what "select the whole subject" expands
  /// to when the student then deselects one of its areas.
  Set<String> get areaKeys => areas.expand((a) => a.keys).toSet();
}

/// Groups a student's cards into the subject → area tree the practice picker
/// renders.
///
/// [courses] maps a raw `card.courseId` to the course it belongs to; a card
/// whose course cannot be resolved is dropped, exactly as it is when the queue
/// is resolved to playable blocks — otherwise the picker would offer an area
/// that can never produce a question.
///
/// Two raw course ids resolving to the same [PracticeCourseInfo.id] collapse
/// into one subject, so a course that reached the deck under both its row id
/// and its `course_id` field is not offered twice.
List<PracticeSubject> buildPracticeScope({
  required List<PracticeCardsTableData> cards,
  required Map<String, PracticeCourseInfo> courses,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();

  // courseRowId → mutable accumulator
  final subjects = <String, _SubjectAcc>{};

  for (final card in cards) {
    final info = courses[card.courseId];
    if (info == null) continue;

    final subject = subjects.putIfAbsent(
      info.id,
      () => _SubjectAcc(id: info.id, title: info.title, info: info),
    );
    subject.courseIds.add(card.courseId);

    final area = subject.areas.putIfAbsent(
      card.lessonId,
      () => _AreaAcc(lessonId: card.lessonId),
    );
    area.keys.add(PracticeFilter.areaKey(card.courseId, card.lessonId));
    area.total++;
    if (QueueBuilder.isEligible(card, at)) area.due++;
  }

  final result = subjects.values.map((s) {
    // Areas follow course order; the lesson-less bucket sorts last because it
    // is a catch-all rather than a place in the syllabus.
    final order = s.info.lessonTitles.keys.toList();
    final areas = s.areas.values.toList()
      ..sort((a, b) {
        if (a.lessonId.isEmpty != b.lessonId.isEmpty) {
          return a.lessonId.isEmpty ? 1 : -1;
        }
        final ai = order.indexOf(a.lessonId);
        final bi = order.indexOf(b.lessonId);
        // Lessons the course no longer lists keep a stable order after the
        // ones it does.
        if (ai == -1 || bi == -1) {
          if (ai == bi) return a.lessonId.compareTo(b.lessonId);
          return ai == -1 ? 1 : -1;
        }
        return ai.compareTo(bi);
      });

    return PracticeSubject(
      id: s.id,
      title: s.title,
      courseIds: s.courseIds,
      areas: [
        for (final a in areas)
          PracticeArea(
            lessonId: a.lessonId,
            title: s.info.lessonTitles[a.lessonId] ?? '',
            keys: a.keys,
            dueCount: a.due,
            totalCount: a.total,
          ),
      ],
    );
  }).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  return result;
}

/// Pure selection transforms behind the practice picker.
///
/// The picker renders an *empty* filter with every box ticked — an empty
/// filter genuinely does practise everything, so showing it as "nothing
/// selected" would be a lie. Unticking a box therefore has to expand the
/// implicit "everything" into an explicit selection first; ticking the last
/// missing box collapses it back. Both directions live here so the widget
/// stays dumb and this logic is unit-testable.
class PracticeSelection {
  const PracticeSelection._();

  /// Whether [area] of [subject] is currently in scope.
  static bool isAreaSelected(PracticeFilter filter, PracticeArea area) =>
      filter.isAll || area.keys.any(filter.allowsKey);

  /// How many of [subject]'s areas are in scope — drives the tri-state box.
  static int selectedAreaCount(PracticeFilter filter, PracticeSubject subject) =>
      subject.areas.where((a) => isAreaSelected(filter, a)).length;

  /// Returns [filter] with [area] switched on or off.
  static PracticeFilter setArea({
    required PracticeFilter filter,
    required List<PracticeSubject> scope,
    required PracticeArea area,
    required bool selected,
  }) {
    final keys = _expand(filter, scope);
    selected ? keys.addAll(area.keys) : keys.removeAll(area.keys);
    return _compact(keys, scope);
  }

  /// Returns [filter] with every area of [subject] switched on or off.
  static PracticeFilter setSubject({
    required PracticeFilter filter,
    required List<PracticeSubject> scope,
    required PracticeSubject subject,
    required bool selected,
  }) {
    final keys = _expand(filter, scope);
    final own = subject.areaKeys;
    selected ? keys.addAll(own) : keys.removeAll(own);
    return _compact(keys, scope);
  }

  /// Every area key currently in scope, with an empty filter expanded to the
  /// whole [scope].
  static Set<String> _expand(PracticeFilter filter, List<PracticeSubject> scope) {
    final keys = <String>{};
    for (final subject in scope) {
      for (final area in subject.areas) {
        if (isAreaSelected(filter, area)) keys.addAll(area.keys);
      }
    }
    return keys;
  }

  /// Turns an explicit set of area keys back into the smallest filter that
  /// expresses it.
  ///
  /// A subject whose areas are all selected is stored as the course id, not as
  /// its areas: a later course update that adds a lesson then stays inside the
  /// student's selection instead of quietly falling out of it. A selection
  /// covering everything — including the empty one, which the student reaches
  /// by unticking the last box — collapses to [PracticeFilter.all], the
  /// product's "no selection = practise it all".
  static PracticeFilter _compact(Set<String> keys, List<PracticeSubject> scope) {
    if (keys.isEmpty) return PracticeFilter.all;

    final courseIds = <String>{};
    final lessonKeys = <String>{};
    var coversEverything = true;

    for (final subject in scope) {
      final own = subject.areaKeys;
      if (own.isEmpty) continue;
      if (keys.containsAll(own)) {
        courseIds.addAll(subject.courseIds);
      } else {
        coversEverything = false;
        lessonKeys.addAll(own.where(keys.contains));
      }
    }

    if (coversEverything) return PracticeFilter.all;
    return PracticeFilter(courseIds: courseIds, lessonKeys: lessonKeys);
  }
}

class _SubjectAcc {
  _SubjectAcc({required this.id, required this.title, required this.info});

  final String id;
  final String title;
  final PracticeCourseInfo info;
  final Set<String> courseIds = {};
  final Map<String, _AreaAcc> areas = {};
}

class _AreaAcc {
  _AreaAcc({required this.lessonId});

  final String lessonId;
  final Set<String> keys = {};
  int due = 0;
  int total = 0;
}
