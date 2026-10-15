import 'package:flutter/material.dart';

import '../core/elo/gpf_structure.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_text_styles.dart';

/// One selectable lesson (or a course's unassigned-blocks group) on offer.
class GlobalQuizLessonOption {
  /// `GlobalQuizLessonGroup.key` — what the choice reports back.
  final String key;
  final String title;

  /// GPF domain codes the lesson's questions touch (relation == 2). Decides
  /// whether the row is on offer for the domains checked above it
  /// (BR-RQMMS5); empty for questions without usable vectors.
  final Set<String> domainCodes;

  const GlobalQuizLessonOption({
    required this.key,
    required this.title,
    this.domainCodes = const {},
  });
}

/// One course with its selectable lessons.
class GlobalQuizCourseNode {
  final String courseId;
  final String title;
  final List<GlobalQuizLessonOption> lessons;
  const GlobalQuizCourseNode({
    required this.courseId,
    required this.title,
    required this.lessons,
  });
}

/// What the student picked in the entry dialog.
class GlobalQuizEntryChoice {
  /// Selected GPF domain codes. Empty means "no domain filter" — either the
  /// dialog offered no domains (pool without vectors), or the student narrowed
  /// by course alone and left the domains unchecked (BR-JTY4AJ).
  final Set<String> domainCodes;

  /// Selected lesson-group keys, restricted to lessons that were actually on
  /// offer for [domainCodes] (BR-RQMMS5). Empty means "no course filter" —
  /// the student narrowed by domain alone; the quiz then draws from the whole
  /// pool.
  final Set<String> lessonKeys;

  const GlobalQuizEntryChoice({
    required this.domainCodes,
    required this.lessonKeys,
  });
}

/// Entry dialog of the global quiz ("Global Quiz v1", BR-RB8WRW): before the
/// ten questions are drawn, the student narrows what to practise — GPF
/// domains, and the courses and lessons to draw from. Only what the pool
/// actually contains is offered: the domains come from the pool, and the
/// course list follows the checked domains — a lesson is on offer only while
/// it holds a task in one of them (BR-RQMMS5). So a course whose questions
/// carry no GPF vectors never shows next to a domain pick, and unchecking a
/// domain takes the lessons that lived only there with it, instead of leaving
/// rows that lead to an empty pick.
///
/// The spec's first step — subject choice — is intentionally absent: the app
/// currently carries a single subject (mathematics), and the spec says to
/// skip straight through the choice when only one subject exists.
///
/// Everything starts checked; unchecking narrows. Clearing a whole section
/// drops that filter rather than emptying the quiz, so narrowing along a
/// single axis — domains only, or courses only — is a valid choice
/// (BR-JTY4AJ); with no domain checked every course is back on offer, the
/// vector-less ones included. Start stays disabled only while nothing at all
/// is checked (BR-RB8WRW follow-up: "deaktivovat button na spuštění").
/// Dismissing returns null (no quiz).
class GlobalQuizEntryDialog extends StatefulWidget {
  const GlobalQuizEntryDialog({
    super.key,
    required this.domains,
    required this.domainNames,
    required this.courses,
  });

  /// Domains represented in the pool, in [GpfStructure.domains] order.
  final List<GpfDomain> domains;

  /// Domain code → Czech display name, from `GpfLabelRepository.domainNames()`.
  final Map<String, String> domainNames;

  /// Courses (with lessons) the pool draws from. The section renders only
  /// when there is an actual choice to make — two or more rows overall.
  final List<GlobalQuizCourseNode> courses;

  @override
  State<GlobalQuizEntryDialog> createState() => _GlobalQuizEntryDialogState();
}

class _GlobalQuizEntryDialogState extends State<GlobalQuizEntryDialog> {
  late final Set<String> _domainCodes =
      widget.domains.map((d) => d.code).toSet();
  late final Set<String> _lessonKeys = {
    for (final course in widget.courses)
      for (final lesson in course.lessons) lesson.key,
  };

  /// Whether [lesson] is on offer for the current domain pick. With domains
  /// checked it must hold a task in one of them (BR-RQMMS5); with none checked
  /// — no domains on offer, or the student cleared the section to narrow by
  /// course alone (BR-JTY4AJ) — every lesson qualifies.
  bool _onOffer(GlobalQuizLessonOption lesson) =>
      _domainCodes.isEmpty || lesson.domainCodes.any(_domainCodes.contains);

  List<GlobalQuizLessonOption> _offeredLessons(GlobalQuizCourseNode course) =>
      course.lessons.where(_onOffer).toList();

  /// The lessons the quiz will draw from: checked, and on offer right now. A
  /// lesson hidden by the domain pick keeps its entry in [_lessonKeys], so
  /// re-checking its domain brings it back in the state the student left it.
  Set<String> get _effectiveLessonKeys => {
        for (final course in widget.courses)
          for (final lesson in course.lessons)
            if (_onOffer(lesson) && _lessonKeys.contains(lesson.key))
              lesson.key,
      };

  /// A section with a single row offers no choice — hide it and keep its one
  /// row implicitly selected. Counted as of the initial state (every domain
  /// checked) so the section does not pop in and out as domains toggle.
  bool get _showCourses =>
      widget.courses.fold<int>(
        0,
        (n, c) =>
            n +
            c.lessons
                .where((l) =>
                    widget.domains.isEmpty || l.domainCodes.isNotEmpty)
                .length,
      ) >=
      2;

  /// One live filter is enough: demanding one per section made the student
  /// answer a question they did not care about (BR-JTY4AJ). An empty section
  /// reaches the draw as "no restriction on that axis" — empty `domainCodes`
  /// skips the domain filter, empty `lessonKeys` keeps the whole pool — so the
  /// only unusable state is nothing checked anywhere. Lessons count only while
  /// on offer: a checked lesson hidden by the domain pick is not a choice.
  bool get _canStart =>
      _domainCodes.isNotEmpty || _effectiveLessonKeys.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusL),
      title:
          Text(AppStrings.globalQuizEntryTitle, style: AppTextStyles.subtitle()),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          minWidth: 280,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.globalQuizEntrySubtitle,
                style: AppTextStyles.caption(color: AppColors.primaryDark64),
              ),
              if (widget.domains.length >= 2) ...[
                const SizedBox(height: 16),
                _sectionLabel(AppStrings.globalQuizEntryDomains),
                for (final domain in widget.domains)
                  _checkRow(
                    label:
                        '${domain.emoji}  ${widget.domainNames[domain.code] ?? domain.code}',
                    checked: _domainCodes.contains(domain.code),
                    onChanged: (v) => setState(() {
                      v
                          ? _domainCodes.add(domain.code)
                          : _domainCodes.remove(domain.code);
                    }),
                  ),
              ],
              if (_showCourses) ...[
                const SizedBox(height: 16),
                _sectionLabel(AppStrings.globalQuizEntryCourses),
                for (final course in widget.courses) ..._courseRows(course),
              ],
              const SizedBox(height: 24),
              _startButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// A course row plus, when the course splits into several lessons, its
  /// lessons folded away behind an expander — collapsed by default so a
  /// student with several courses sees the course titles, not a wall of
  /// lessons (BR-9XFSMS). Mirrors the practice scope picker, which only opens
  /// a course up front when it is the only one on offer. A single-lesson
  /// course collapses into just the course row bound to that lesson's key.
  ///
  /// Only lessons on offer for the checked domains take part; a course with
  /// none left disappears altogether (BR-RQMMS5).
  List<Widget> _courseRows(GlobalQuizCourseNode course) {
    final lessons = _offeredLessons(course);
    if (lessons.isEmpty) return const [];

    final keys = lessons.map((l) => l.key).toList();
    final selectedCount = keys.where(_lessonKeys.contains).length;

    void setAll(bool v) => setState(() {
          v ? _lessonKeys.addAll(keys) : _lessonKeys.removeAll(keys);
        });

    if (lessons.length == 1) {
      return [
        _checkRow(
          label: course.title,
          checked: selectedCount == 1,
          onChanged: setAll,
        ),
      ];
    }

    final allSelected = selectedCount == keys.length;

    return [
      Theme(
        // ExpansionTile draws its own dividers, which fight the dialog's own
        // spacing.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.courses.length == 1,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 24),
          leading: Checkbox(
            value: selectedCount == 0 ? false : (allSelected ? true : null),
            tristate: selectedCount > 0 && !allSelected,
            activeColor: AppColors.primaryDark,
            visualDensity: VisualDensity.compact,
            // A tap means "all or nothing" — cycling the tri-state widget into
            // its own third value would leave a partial state nobody chose.
            onChanged: (_) => setAll(!allSelected),
          ),
          title: Text(
            course.title,
            style: AppTextStyles.bodyBold(color: AppColors.primaryDark),
          ),
          children: [
            for (final lesson in lessons)
              _checkRow(
                label: lesson.title,
                checked: _lessonKeys.contains(lesson.key),
                onChanged: (v) => setState(() {
                  v
                      ? _lessonKeys.add(lesson.key)
                      : _lessonKeys.remove(lesson.key);
                }),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: AppTextStyles.bodyBold(color: AppColors.primaryDark),
        ),
      );

  Widget _checkRow({
    required String label,
    required bool checked,
    required ValueChanged<bool> onChanged,
    bool tristate = false,
    bool bold = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Row(
        children: [
          Checkbox(
            value: tristate ? null : checked,
            tristate: tristate,
            activeColor: AppColors.primaryDark,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => onChanged(v ?? false),
          ),
          Expanded(
            child: Text(
              label,
              style: bold
                  ? AppTextStyles.bodyBold(color: AppColors.primaryDark)
                  : AppTextStyles.bodySmall(color: AppColors.primaryDark80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    final enabled = _canStart;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: enabled
            ? () => Navigator.of(context).pop(GlobalQuizEntryChoice(
                  domainCodes: Set.of(_domainCodes),
                  lessonKeys: _effectiveLessonKeys,
                ))
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryDark : AppColors.primaryDark48,
            borderRadius: AppDecorations.radiusS,
          ),
          child: Text(
            AppStrings.globalQuizEntryStart,
            textAlign: TextAlign.center,
            style: AppTextStyles.statValue(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
