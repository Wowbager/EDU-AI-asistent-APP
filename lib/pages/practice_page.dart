import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/practice/practice_filter.dart';
import '../core/practice/practice_scope.dart';
import '../core/providers/practice_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'quiz_page.dart';
import '../core/layout/breakpoints.dart';

/// PracticePage — entry point for the FSRS spaced-repetition queue.
///
/// Shows the due-card count, lets the student narrow practice to chosen
/// subjects and areas, resolves the queued cards to their content blocks
/// across courses, and reuses the proven exercise [QuizPage] to run the
/// session.
///
/// FSRS review write-back IS wired: QuizPage runs with isFsrsPractice=true and
/// calls PracticeService.reviewCard per graded block (scheduler + review log),
/// and shows a session summary (success rate + XP) on completion.
class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  bool _starting = false;

  /// Starts a session from today's queue, or — when [bonus] — from the extra
  /// set offered after the day is cleared.
  Future<void> _start({bool bonus = false}) async {
    setState(() => _starting = true);
    try {
      final result = await ref.read(
        (bonus ? playableBonusPracticeProvider : playablePracticeProvider)
            .future,
      );
      if (!mounted) return;

      final blocks = result.blocks;
      if (blocks.isEmpty) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.practiceEmpty)));
        return;
      }

      // Practice cards may span multiple courses; QuizPage attributes the
      // session to a single course. MVP: use the first resolved block's
      // course context for evaluation/ELO.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizPage(
            questionBlocks: blocks,
            courseTitle: AppStrings.practiceTitle,
            courseId: result.courseId ?? '',
            progress: QuizProgress(),
            evaluate: true,
            isExercise: true,
            isFsrsPractice: true,
          ),
        ),
      );
      if (mounted) setState(() => _starting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.genericError('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    final queueAsync = ref.watch(playablePracticeProvider);
    final filter = ref.watch(practiceFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primaryDark,
        title: Text(
          AppStrings.practiceTitle,
          style: AppTextStyles.heading2Bold(),
        ),
      ),
      body: SafeArea(
        child: queueAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                AppStrings.genericError('$e'),
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: AppColors.primaryDark64),
              ),
            ),
          ),
          data: (result) {
            final isEmpty = result.blocks.isEmpty;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _hero(isEmpty: isEmpty, dueCount: result.blocks.length),
                // A narrowed scope that happens to have nothing due today
                // looks exactly like "you're done" unless we say otherwise —
                // and the student would have no idea their own selection is
                // what emptied the queue.
                if (isEmpty && !filter.isAll) ...[
                  const SizedBox(height: 16),
                  _filteredEmptyNotice(),
                ],
                if (!isEmpty) ...[const SizedBox(height: 28), _startButton()],
                // Everything due is done — but the student came here to
                // practise, so offer an extra set rather than sending them
                // away (BR-A6HU52).
                if (isEmpty) ...[
                  const SizedBox(height: 28),
                  _BonusOffer(
                    starting: _starting,
                    onStart: () => _start(bonus: true),
                  ),
                ],
                const SizedBox(height: 28),
                const _ScopePicker(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero({required bool isEmpty, required int dueCount}) {
    // Hero card — gives the practice entry a clear identity instead of a bare
    // emoji + button.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              isEmpty ? '🎉' : '🧠',
              style: const TextStyle(fontSize: 38),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isEmpty
                ? AppStrings.practiceEmpty
                : AppStrings.practiceDueCount(dueCount),
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2Bold(color: Colors.white),
          ),
          if (!isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              AppStrings.practiceDashSubtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filteredEmptyNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.practiceScopeEmpty,
            style: AppTextStyles.body(color: AppColors.primaryDark72),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  ref.read(practiceFilterProvider.notifier).reset(),
              child: Text(
                AppStrings.practiceScopeSelectAll,
                style: AppTextStyles.actionSmall(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _starting ? null : _start,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusM),
        ),
        child: _starting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                AppStrings.practiceStart,
                style: AppTextStyles.actionSmall(color: Colors.white),
              ),
      ),
    );
  }
}

/// The follow-up to "you're done for today": an explicitly opt-in extra set.
///
/// Rendered only once the daily queue is empty, and only when the bonus queue
/// resolves to blocks that can actually be played — a button that then reports
/// "nothing to practise" would be worse than no button at all.
class _BonusOffer extends ConsumerWidget {
  const _BonusOffer({required this.starting, required this.onStart});

  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched here rather than in the page body so the extra query only runs
    // for the students who reach the empty state.
    final bonus = ref.watch(playableBonusPracticeProvider);
    final hasBonus = bonus.asData?.value.blocks.isNotEmpty ?? false;
    if (!hasBonus) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.practiceBonusHint,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.primaryDark72),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: starting ? null : onStart,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusM),
          ),
          child: Text(
            AppStrings.practiceBonusStart,
            style: AppTextStyles.actionSmall(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// Two-level picker: subject (course) → areas (lessons), multi-select across
/// subjects. Selecting a subject takes all of its areas; selecting nothing
/// practises everything.
///
/// Hidden entirely when the student has a single area — there is nothing to
/// choose between, and an empty-looking control would only raise questions.
class _ScopePicker extends ConsumerWidget {
  const _ScopePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeAsync = ref.watch(practiceScopeProvider);
    final filter = ref.watch(practiceFilterProvider);

    final subjects = scopeAsync.asData?.value ?? const <PracticeSubject>[];
    final areaCount = subjects.fold<int>(0, (sum, s) => sum + s.areas.length);
    if (areaCount < 2) return const SizedBox.shrink();

    final selectedAreas = subjects.fold<int>(
      0,
      (sum, s) => sum + PracticeSelection.selectedAreaCount(filter, s),
    );

    return Container(
      decoration: AppDecorations.cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: 8),
      // The card's own decoration would swallow the ink splashes of the
      // ExpansionTiles below, which paint on the nearest Material ancestor.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.practiceScopeTitle,
                      style: AppTextStyles.cardTitleSmall(),
                    ),
                  ),
                  if (!filter.isAll)
                    TextButton(
                      onPressed: () =>
                          ref.read(practiceFilterProvider.notifier).reset(),
                      child: Text(
                        AppStrings.practiceScopeSelectAll,
                        style: AppTextStyles.actionSmall(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                filter.isAll
                    ? AppStrings.practiceScopeAllHint
                    : AppStrings.practiceScopeSelected(selectedAreas),
                style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
              ),
            ),
            for (final subject in subjects)
              _SubjectTile(
                subject: subject,
                scope: subjects,
                filter: filter,
                initiallyExpanded: subjects.length == 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({
    required this.subject,
    required this.scope,
    required this.filter,
    required this.initiallyExpanded,
  });

  final PracticeSubject subject;
  final List<PracticeSubject> scope;
  final PracticeFilter filter;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(practiceFilterProvider.notifier);
    final selected = PracticeSelection.selectedAreaCount(filter, subject);
    final isFull = selected == subject.areas.length;

    return Theme(
      // ExpansionTile draws its own dividers, which fight the card border.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 24, bottom: 8),
        leading: Checkbox(
          tristate: true,
          value: isFull ? true : (selected == 0 ? false : null),
          activeColor: AppColors.primary,
          // A tap always means "all or nothing" for the subject — letting the
          // tri-state widget cycle through its own third value would leave the
          // student toggling into a partial state they cannot interpret.
          onChanged: (_) => notifier.setSubject(
            scope: scope,
            subject: subject,
            selected: !isFull,
          ),
        ),
        title: Text(subject.title, style: AppTextStyles.bodySemiBold()),
        subtitle: subject.dueCount > 0
            ? Text(
                AppStrings.practiceScopeDueCount(subject.dueCount),
                style: AppTextStyles.meta(color: AppColors.primaryDark48),
              )
            : null,
        children: [
          for (final area in subject.areas)
            _AreaRow(
              area: area,
              scope: scope,
              selected: PracticeSelection.isAreaSelected(filter, area),
            ),
        ],
      ),
    );
  }
}

class _AreaRow extends ConsumerWidget {
  const _AreaRow({
    required this.area,
    required this.scope,
    required this.selected,
  });

  final PracticeArea area;
  final List<PracticeSubject> scope;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(practiceFilterProvider.notifier);
    final title = area.isUnassigned
        ? AppStrings.practiceScopeOther
        : (area.title.isNotEmpty ? area.title : area.lessonId);

    return InkWell(
      onTap: () =>
          notifier.setArea(scope: scope, area: area, selected: !selected),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor: AppColors.primary,
              onChanged: (value) => notifier.setArea(
                scope: scope,
                area: area,
                selected: value ?? false,
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body(color: AppColors.primaryDark80),
              ),
            ),
            if (area.dueCount > 0)
              Text(
                AppStrings.practiceScopeDueCount(area.dueCount),
                style: AppTextStyles.meta(color: AppColors.primaryDark48),
              ),
          ],
        ),
      ),
    );
  }
}
