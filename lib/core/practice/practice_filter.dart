import 'dart:convert';

import '../database/app_database.dart';

/// The student's chosen practice scope: which subjects (courses) and areas
/// (lessons) the daily queue may draw from.
///
/// Two levels, mirroring the practice picker:
///   * [courseIds] — whole subjects. A subject selected as a whole keeps
///     including areas that are added to it later (a course update that adds a
///     lesson shouldn't silently fall out of the student's selection), which is
///     why it is stored as the course id rather than expanded into area keys.
///   * [lessonKeys] — individual areas, as `"<courseId>|<lessonId>"`.
///
/// An empty filter means "everything" — the product rule is *no selection =
/// practise it all*, so the default costs the student nothing.
///
/// The course id is stored exactly as it appears on the card row. A card's
/// `courseId` may be either the local course row id or the course's own
/// `course_id` field (see `playablePracticeProvider`); the picker collapses
/// both spellings of one course into a single subject and puts every spelling
/// into the filter, so matching can stay a plain string comparison here.
class PracticeFilter {
  /// Subjects selected as a whole.
  final Set<String> courseIds;

  /// Individually selected areas, keyed by [areaKey].
  final Set<String> lessonKeys;

  const PracticeFilter({
    this.courseIds = const {},
    this.lessonKeys = const {},
  });

  /// The default, unrestricted scope — every card is eligible.
  static const PracticeFilter all = PracticeFilter();

  /// True when nothing is selected, i.e. the whole deck is in scope.
  bool get isAll => courseIds.isEmpty && lessonKeys.isEmpty;

  /// Number of areas the student picked one by one, plus whole subjects.
  int get selectionCount => courseIds.length + lessonKeys.length;

  /// Composite key identifying one area within one subject.
  static String areaKey(String courseId, String lessonId) =>
      '$courseId|$lessonId';

  /// Whether cards of [lessonId] inside [courseId] are in scope.
  bool allowsArea(String courseId, String lessonId) =>
      isAll ||
      courseIds.contains(courseId) ||
      lessonKeys.contains(areaKey(courseId, lessonId));

  /// Whether the area identified by an [areaKey] is in scope.
  bool allowsKey(String key) {
    final sep = key.indexOf('|');
    if (sep < 0) return allowsArea(key, '');
    return allowsArea(key.substring(0, sep), key.substring(sep + 1));
  }

  /// Whether [card] is in scope. Cards with no lesson context (an auto-bookmark
  /// from a wrong quiz answer carries no lesson) use the empty lesson id, which
  /// the picker surfaces as the subject's "other" area — so they stay
  /// selectable instead of becoming unreachable.
  bool allowsCard(PracticeCardsTableData card) =>
      allowsArea(card.courseId, card.lessonId);

  PracticeFilter copyWith({
    Set<String>? courseIds,
    Set<String>? lessonKeys,
  }) =>
      PracticeFilter(
        courseIds: courseIds ?? this.courseIds,
        lessonKeys: lessonKeys ?? this.lessonKeys,
      );

  Map<String, dynamic> toJson() => {
        'courses': courseIds.toList()..sort(),
        'lessons': lessonKeys.toList()..sort(),
      };

  String encode() => jsonEncode(toJson());

  /// Parses [raw]; any malformed payload degrades to [all] rather than
  /// throwing — a corrupt preference must never block practice.
  static PracticeFilter decode(String? raw) {
    if (raw == null || raw.isEmpty) return all;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return all;
      return PracticeFilter(
        courseIds: _stringSet(json['courses']),
        lessonKeys: _stringSet(json['lessons']),
      );
    } catch (_) {
      return all;
    }
  }

  static Set<String> _stringSet(dynamic raw) {
    if (raw is! List) return const {};
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  @override
  bool operator ==(Object other) =>
      other is PracticeFilter &&
      _setEquals(courseIds, other.courseIds) &&
      _setEquals(lessonKeys, other.lessonKeys);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(courseIds),
        Object.hashAllUnordered(lessonKeys),
      );

  @override
  String toString() =>
      isAll ? 'PracticeFilter.all' : 'PracticeFilter($courseIds, $lessonKeys)';

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
