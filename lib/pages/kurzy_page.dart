import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/core_providers.dart';
import '../core/util/drag_scroll_behavior.dart';
import '../core/util/silent_log.dart';
import '../data/repositories/user_course_repository.dart';
import '../models/course_card_view.dart';
import '../models/course_model.dart';
import '../widgets/widgets.dart';
import 'course_detail_page.dart';
import 'knihovna_page.dart';
import '../core/layout/breakpoints.dart';
import '../core/util/shell_route.dart';

class KurzyPage extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToLibrary;

  const KurzyPage({super.key, this.onNavigateToLibrary});

  @override
  ConsumerState<KurzyPage> createState() => _KurzyPageState();
}

class _KurzyPageState extends ConsumerState<KurzyPage> {
  int _selectedFilterIndex = 0;
  final Set<String> _hydrationAttempts = <String>{};
  final List<String> _filters = [
    AppStrings.filterAll,
    AppStrings.filterInProgress,
    AppStrings.filterNotStarted,
    AppStrings.filterCompleted
  ];

  /// Free-text course search. Wide layouts get a search field (the design
  /// asks for one); phones keep the chip row alone, where a text field would
  /// eat a third of the screen.
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// Zero-based page for the grid's pager. Reset whenever the result set
  /// changes, otherwise filtering down to 3 courses while on page 2 shows an
  /// empty grid.
  int _page = 0;

  /// Cards per page in the grid layout.
  static const int _pageSize = 8;

  /// Header tints for the grid cards, cycled by position.
  List<Color> get _headerColors => [
        AppColors.cardLavender,
        AppColors.successBg,
        AppColors.cardPeach,
        AppColors.cardYellow,
        AppColors.cardBlue,
        AppColors.cardPeachDark,
      ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Trigger an R2 download for a course whose data column is empty. Runs
  /// at most once per courseId per page lifetime; the StreamProvider will
  /// rebuild the list once data lands and `lessons` becomes non-null.
  /// Resolve a displayable course title, or null when the name is unknown.
  ///
  /// Resolution order:
  ///   1. name embedded in the full course payload (R2 JSON)
  ///   2. local courses.name column (kept in sync from API)
  ///
  /// Treated as garbage: the local FK UUID (legacy code-entry rows) and the
  /// generic "Kurz"/"Course" placeholders that the buggy sync path used to
  /// write into the DB when the API sent no name. Courses that resolve to
  /// null are hidden from the listing until a background refresh fills the
  /// real name in — showing an unnamed, empty-data "Kurz" card confuses
  /// users more than a short delay does.
  void _ensureCourseDataDownloaded(String localCourseId) {
    if (!_hydrationAttempts.add(localCourseId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(courseRepositoryProvider)
            .downloadFullCourseJson(localCourseId);
      } catch (e, st) {
        silentLog('kurzy:hydrate', e, st);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userCoursesAsync = ref.watch(userCoursesStreamProvider);
    final isMobile = context.widthClass == WidthClass.compact;
    final isDesktop = context.isExpanded;
    final pad = isMobile ? 16.0 : 32.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // The desktop top bar already shows the page title and subtitle.
        if (!isDesktop) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Text(
              AppStrings.kurzyTitle,
              style: AppTextStyles.heading2Bold(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Filters, and on wide layouts search + the filter button beside them.
        if (isMobile)
          FilterChipRow(
            labels: _filters,
            selectedIndex: _selectedFilterIndex,
            onSelected: _onFilterSelected,
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: _buildWideControls(),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: ScrollConfiguration(
            behavior: const DragScrollBehavior(),
            child: RefreshIndicator(
              onRefresh: _refreshCourses,
              child: userCoursesAsync.when(
                data: (userCourses) {
                  // Hide only_once courses and courses whose name is unknown
                  // (empty catalog rows created by sync before the name
                  // arrived) — for the latter, kick off a background R2
                  // download so they appear once the name resolves.
                  final visibleCourses = userCourses.where((uc) {
                    if (uc.isOnlyOnce) return false;
                    if (resolveKnownCourseTitle(uc) == null) {
                      _ensureCourseDataDownloaded(uc.courseId);
                      return false;
                    }
                    return true;
                  }).toList();
                  final filteredCourses =
                      _searchCourses(_filterCourses(visibleCourses));

                  if (filteredCourses.isEmpty) {
                    // Wrap empty state in scrollable so pull-to-refresh still
                    // works.
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: _query.isNotEmpty
                              ? _buildNoMatchState()
                              : _buildEmptyState(),
                        ),
                      ],
                    );
                  }

                  if (isMobile) {
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: filteredCourses.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildCourseCard(filteredCourses[index]),
                    );
                  }

                  return _buildGrid(filteredCourses, pad);
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.6,
                      child: Center(
                        child: Text(AppStrings.genericError(error.toString())),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onFilterSelected(int index) {
    setState(() {
      _selectedFilterIndex = index;
      _page = 0;
    });
  }

  // ── Wide layout ───────────────────────────────────────────────────────

  Widget _buildWideControls() {
    return Row(
      children: [
        Expanded(
          child: FilterChipRow(
            labels: _filters,
            selectedIndex: _selectedFilterIndex,
            onSelected: _onFilterSelected,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(width: 280, child: _buildSearchField()),
        const SizedBox(width: 12),
        _buildFilterButton(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        boxShadow: AppDecorations.shadowLight,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: AppColors.primaryDark48),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _query = value.trim().toLowerCase();
                _page = 0;
              }),
              style: AppTextStyles.bodySmall(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: AppStrings.kurzySearchHint,
                hintStyle:
                    AppTextStyles.bodySmall(color: AppColors.primaryDark48),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _searchController.clear();
                _query = '';
                _page = 0;
              }),
              child: Icon(Icons.close,
                  size: 18, color: AppColors.primaryDark48),
            ),
        ],
      ),
    );
  }

  /// Placeholder: the design has a "Filtr" button, but nothing decides what it
  /// would filter on beyond the chips that are already there.
  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: () => _showComingSoon(AppStrings.kurzyFilterButton),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusM,
          boxShadow: AppDecorations.shadowLight,
        ),
        child: Row(
          children: [
            Icon(Icons.tune, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Text(AppStrings.kurzyFilterButton,
                style: AppTextStyles.actionSmall()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<UserCourse> courses, double pad) {
    final pageCount = (courses.length / _pageSize).ceil().clamp(1, 999);
    final page = _page.clamp(0, pageCount - 1);
    final pageCourses =
        courses.skip(page * _pageSize).take(_pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            gridColumns(constraints.maxWidth - pad * 2);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                // Tall enough for header + title (2 lines) + meta + progress
                // + CTA without the body overflowing at the narrowest column.
                mainAxisExtent: 320,
              ),
              itemCount: pageCourses.length,
              itemBuilder: (context, index) => _buildGridCard(
                pageCourses[index],
                page * _pageSize + index,
              ),
            ),
            const SizedBox(height: 24),
            _buildPager(page, pageCount, courses.length),
          ],
        );
      },
    );
  }

  Widget _buildPager(int page, int pageCount, int totalCourses) {
    return Row(
      children: [
        // Balances the count on the right so the pager stays centred.
        const Spacer(),
        if (pageCount > 1) ...[
          _pagerButton(
            icon: Icons.chevron_left,
            enabled: page > 0,
            onTap: () => setState(() => _page = page - 1),
          ),
          const SizedBox(width: 4),
          for (var i = 0; i < pageCount; i++) ...[
            _pagerNumber(i, page),
            const SizedBox(width: 4),
          ],
          _pagerButton(
            icon: Icons.chevron_right,
            enabled: page < pageCount - 1,
            onTap: () => setState(() => _page = page + 1),
          ),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              AppStrings.kurzyCount(totalCourses),
              style: AppTextStyles.meta(color: AppColors.primaryDark64),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pagerNumber(int index, int currentPage) {
    final isCurrent = index == currentPage;
    return GestureDetector(
      onTap: () => setState(() => _page = index),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: AppTextStyles.actionSmall(
              color: isCurrent ? AppColors.surface : AppColors.primaryDark64,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pagerButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: enabled ? AppDecorations.shadowLight : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primaryDark : AppColors.primaryDark24,
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — ${AppStrings.profileComingSoon}')),
    );
  }

  // ── Data ──────────────────────────────────────────────────────────────

  Future<void> _refreshCourses() async {
    try {
      // Trigger full sync (push pending + pull server state).
      await ref.read(syncServiceProvider).sync();
    } catch (e, st) {
      silentLog('kurzy:refresh', e, st);
    }
    // Stream provider rebuilds when local DB changes during sync; no manual
    // invalidate needed.
  }

  List<UserCourse> _filterCourses(List<UserCourse> courses) {
    switch (_selectedFilterIndex) {
      case 1: // Probíhající
        return courses.where((c) => c.status == UserCourseStatus.inProgress).toList();
      case 2: // Nezahájené
        return courses.where((c) => c.status == UserCourseStatus.downloaded).toList();
      case 3: // Dokončeno
        return courses.where((c) {
          if (c.status == UserCourseStatus.completed) return true;
          // Quiz-only courses: completed if quiz_completed flag is set
          final isQuizOnly = (c.courseData ?? {})['only_quiz'] == true;
          return isQuizOnly && c.progressData['quiz_completed'] == true;
        }).toList();
      default: // Všechny
        return courses;
    }
  }

  /// Title/description substring match. Client-side on an already-loaded list,
  /// so it stays instant and works offline like the rest of the page.
  List<UserCourse> _searchCourses(List<UserCourse> courses) {
    if (_query.isEmpty) return courses;
    return courses.where((uc) {
      final title = (resolveKnownCourseTitle(uc) ?? '').toLowerCase();
      final description =
          ((uc.courseData?['description'] as String?) ?? '').toLowerCase();
      return title.contains(_query) || description.contains(_query);
    }).toList();
  }

  /// Card data for one course, plus the hydration kick the list needs when
  /// the payload has not been downloaded yet.
  CourseCardView _courseView(UserCourse userCourse) {
    final view = CourseCardView.of(userCourse);
    // Auto-hydrate: if the course payload is missing (no lessons), kick off an
    // R2 download in the background so name + total lesson count populate.
    if (view.needsHydration) {
      _ensureCourseDataDownloaded(userCourse.courseId);
    }
    return view;
  }

  void _openCourse(UserCourse userCourse, String resolvedTitle) {
    // Always navigate. If full course data is missing the detail page
    // will hydrate it; meanwhile we pass the best-known title so the
    // app bar isn't blank.
    final course = Course.fromJsonData(
      id: userCourse.courseId,
      data: userCourse.courseData ?? {},
      completedLessons: userCourse.completedLessons,
      isCompleted: userCourse.isCompleted,
      fallbackName: resolvedTitle,
    );

    Navigator.of(context).push(
      shellPageRoute(
      context,
        builder: (_) => CourseDetailPage(
          course: course,
          userCourseId: userCourse.id,
        ),
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────

  Widget _buildCourseCard(UserCourse userCourse) {
    final view = _courseView(userCourse);

    return KurzyCourseCard(
      iconWidget: _courseIcon(view),
      iconBackgroundColor: AppColors.surfaceLight.withValues(alpha: 0.48),
      title: view.title,
      description: view.description,
      badge: view.badge,
      lessonCount: view.lessonCount,
      durationHours: view.durationHours,
      currentProgress: view.currentProgress,
      totalProgress: view.totalProgress,
      status: view.status,
      isBookmarked: false,
      hasUpdate: userCourse.hasUpdate,
      onTap: () => _openCourse(userCourse, view.title),
    );
  }

  /// Circular card icon: the course cover when set, the emoji otherwise.
  Widget _courseIcon(CourseCardView view) {
    return ClipOval(
      child: CourseCoverImage(
        url: view.coverImageUrl,
        width: 56,
        height: 56,
        fallback: Text(view.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  Widget _buildGridCard(UserCourse userCourse, int position) {
    final view = _courseView(userCourse);
    final colors = _headerColors;

    final cta = switch (view.status) {
      CourseStatus.completed => AppStrings.courseCardReview,
      CourseStatus.inProgress => AppStrings.courseCardContinue,
      CourseStatus.notStarted => AppStrings.courseCardStart,
    };

    return CourseGridCard(
      emoji: view.emoji,
      coverImageUrl: view.coverImageUrl,
      headerColor: colors[position % colors.length],
      title: view.title,
      meta: '${AppStrings.lessonsCount(view.lessonCount)} · '
          '${AppStrings.durationHours(view.durationHours)}',
      pills: [
        if (userCourse.hasUpdate)
          CourseCardPill(
            label: AppStrings.courseCardUpdate,
            color: AppColors.primary,
          ),
        if (view.status == CourseStatus.completed)
          CourseCardPill(
            label: AppStrings.courseCardCompleted,
            color: AppColors.success,
          ),
      ],
      currentProgress: view.currentProgress,
      // Always show the bar: a course grid without progress reads as a
      // catalogue, and 0% is information too.
      totalProgress: view.totalProgress > 0 ? view.totalProgress : 1,
      progressIsComplete: view.status == CourseStatus.completed,
      footer: CourseGridCardButton(
        label: cta,
        onTap: () => _openCourse(userCourse, view.title),
      ),
      onTap: () => _openCourse(userCourse, view.title),
      onMenuTap: () => _showComingSoon(AppStrings.kurzyFilterButton),
    );
  }

  // ── Empty states ──────────────────────────────────────────────────────

  Widget _buildNoMatchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          AppStrings.kurzySearchEmpty,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.primaryDark64),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📚', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.kurzyEmptyTitle,
              style: AppTextStyles.heading4(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.kurzyEmptySubtitle,
              style: AppTextStyles.body(color: AppColors.primaryDark64),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                if (widget.onNavigateToLibrary != null) {
                  widget.onNavigateToLibrary!();
                } else {
                  Navigator.of(context).push(
                    shellPageRoute(
      context,
                      builder: (context) => const KnihovnaPage(),
                    ),
                  );
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppDecorations.radiusM,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_books_rounded,
                      color: AppColors.surface,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.kurzyExploreLibrary,
                      style: AppTextStyles.statValueAlt(
                          color: AppColors.surface),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
