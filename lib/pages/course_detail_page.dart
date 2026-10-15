import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/media/lesson_image_cache.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';
import '../models/course_model.dart';
import '../models/skill_display_model.dart';
import '../widgets/card_carousel.dart';
import '../widgets/course_card.dart';
import '../widgets/course_cover_image.dart';
import '../widgets/detail_shell.dart';
import '../widgets/progress_ring_card.dart';
import '../core/providers/core_providers.dart';
import '../core/providers/bookmark_provider.dart';
import '../data/repositories/user_course_repository.dart';
import '../main.dart' show routeObserver, countAchievementStats;
import 'lesson_detail_page.dart';
import 'exercise_page.dart';
import 'quiz_page.dart';
import 'course_quiz_launch.dart';
import 'achievements_page.dart';
import 'chat_detail_page.dart';
import '../models/chat_models.dart';
import 'package:eduai/core/util/silent_log.dart';
import '../core/layout/breakpoints.dart';
import '../core/util/shell_route.dart';

/// The wide hero's action row — the course actions plus "Uložit kurz" — and
/// the action group inside it. Named so the layout tests can measure where the
/// two landed (BR-BCNXAP).
const Key courseHeroActionsKey = Key('course-hero-actions');
const Key courseHeroActionButtonsKey = Key('course-hero-action-buttons');

/// Course Detail Page displaying full course information
class CourseDetailPage extends ConsumerStatefulWidget {
  final Course course;
  final String? userCourseId; // For progress tracking

  const CourseDetailPage({
    super.key,
    required this.course,
    this.userCourseId,
  });

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage> with RouteAware {
  bool _isDescriptionExpanded = false;

  bool _isBookmarked = false;
  bool _quizStarted = false;
  bool _quizCompleted = false;
  final QuizProgress _quizProgress = QuizProgress();
  final QuizProgress _exerciseProgress = QuizProgress();
  Course? _courseOverride; // Mutable course that can be refreshed
  String? _resolvedUserCourseId; // Mutable — discovered at runtime if widget.userCourseId is null

  // Block-level progress tracking
  int _totalBlocks = 0;
  int _completedBlocks = 0;
  bool _isCourseCompleted = false;

  // Cvičení filtering: only show completed default_practice blocks
  Set<String> _completedBlockIds = {};
  Set<String> _removedPracticeBlocks = {};

  // Course update state
  bool _hasUpdate = false;
  bool _isUpdating = false;

  /// Selected tab of the wide layout: lessons / about / skills / stats.
  int _wideTab = 0;

  /// Width of the course page's right-hand rail.
  static const double _railWidth = 340;

  /// Wide hero geometry: padding around the card, the icon tile, and the gap
  /// between the tile and the text column.
  static const double _heroPadding = 24;
  static const double _heroIconSize = 160;
  static const double _heroIconGap = 24;

  Course get _course => _courseOverride ?? widget.course;

  /// Best-known userCourseId — from widget or discovered at runtime.
  String? get _userCourseId => _resolvedUserCourseId ?? widget.userCourseId;

  /// Whether the initial quiz is required and not yet completed.
  bool get _quizRequired => _course.startsWithQuiz && !_quizCompleted;

  /// A finished only-once course (typically a test) stays closed. The code
  /// input refuses it, but every other way here — a published test sits in
  /// Knihovna — used to offer "Začít kvíz" again and record a second attempt
  /// (BR-Y4WMCU), so the page itself has to say no.
  bool get _onlyOnceLocked => _course.onlyOnce && _course.isCompleted;

  /// Course unlocks every lesson at once — no sequential gate, and no single
  /// "current" lesson to badge (BR-K47WYE). A pending update or a required
  /// entry quiz still locks everything; those are different reasons to lock.
  bool get _openAll => _course.openAllLessons;

  /// Whether this is a quiz-only course (no lessons shown).
  bool get _isOnlyQuiz => _course.onlyQuiz;

  /// Label for the quiz button based on current state.
  String get _quizButtonLabel => _quizStarted ? AppStrings.courseContinueQuiz : AppStrings.courseStartQuiz;

  /// Course ids this course's bookmarks may be stored under: the local Drift
  /// row id and the server course code. They differ — and the code is the one
  /// the server (and therefore another device) uses (BR-ZBJ99Z).
  List<String> get _courseIdAliases =>
      [_course.id, if (_course.courseCode != null) _course.courseCode!];

  /// Whether the DB holds any bookmark for this course, regardless of whether
  /// its ContentBlock has been hydrated into the notifier yet.
  bool _hasBookmarks() => ref
      .read(bookmarkProvider.notifier)
      .hasBookmarksForCourse(_course.id, alsoMatch: _courseIdAliases);

  /// Blocks the "Cvičení" session plays: completed default_practice blocks
  /// plus the course's bookmarked blocks.
  List<ContentBlock> _exerciseBlocks() => _course.getExerciseBlocks(
        ref.read(bookmarkProvider.notifier).getBookmarksForCourse(
              _course.id,
              alsoMatch: _courseIdAliases,
            ),
        completedBlockIds: _completedBlockIds,
        removedBlockIds: _removedPracticeBlocks,
      );

  /// Resolve this course's DB bookmarks to real ContentBlocks.
  ///
  /// Bookmarks are loaded as bare keys on login; only [hydrateForCourse] turns
  /// them into blocks, and it used to run exclusively from the lesson page. A
  /// course opened straight from the dashboard therefore looked bookmark-free
  /// and hid its "Cvičení" button (BR-ZBJ99Z).
  void _hydrateBookmarks() {
    final blocks = _course.getAllBlocks();
    if (blocks.isEmpty) return;
    ref.read(bookmarkProvider.notifier).hydrateForCourse(
          _course.id,
          blocks,
          alsoMatch: _courseIdAliases,
        );
  }

  /// Lessons that actually have blocks — skip empty ones.
  List<Lesson> get _nonEmptyLessons {
    if (!_course.hasBlockV2Data) return _course.lessons;
    return _course.lessons
        .where((l) => _course.getBlocksForLesson(l.id).isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.course.isBookmarked;
    _calculateTotalBlocks();
    // Load progress data after init, then check for updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Same app-scoped list as the new-chat picker: without a refresh the
      // course mentor button keeps offering a mentor the admin switched off
      // until the app is restarted (BR-EER4ME).
      if (mounted) ref.invalidate(courseChatMentorsProvider(_course.id));
      _refreshCourseProgress().then((_) => _checkForUpdate());
    });
    // Courses downloaded before BR-BX9AA4 have text but no pictures kept on
    // the device; opening one online fills them in, so it works offline.
    unawaited(LessonImageCache.instance.prefetch(_course.imageUrls));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when a route that was pushed on top of this one is popped,
  /// making this page visible again. Handles the case where lesson pages
  /// use pushReplacement (which resolves the original push Future early).
  @override
  void didPopNext() {
    _refreshCourseProgress();
  }

  /// Calculate total blocks across all lessons
  void _calculateTotalBlocks() {
    _totalBlocks = _course.lessons.fold<int>(
      0,
      (sum, lesson) => sum + lesson.questionCount,
    );
  }

  /// Refresh course data from database to get updated lesson statuses
  Future<void> _refreshCourseProgress() async {
    try {
      final repository = ref.read(userCourseRepositoryProvider);
      UserCourse? userCourse;

      // Try by known ID first
      if (_userCourseId != null) {
        userCourse = await repository.getUserCourseById(_userCourseId!);
        if (userCourse != null) _resolvedUserCourseId = _userCourseId;
      }

      // Fallback: look up by course ID + active user
      if (userCourse == null) {
        final localCourseId = await _resolveLocalCourseId();
        if (localCourseId != null) {
          final db = ref.read(appDatabaseProvider);
          final user = await db.getActiveUser();
          if (user != null) {
            final row = await db.getUserCourseByUserAndCourse(user.id, localCourseId);
            if (row != null) {
              _resolvedUserCourseId = row.id;
              userCourse = await repository.getUserCourseById(row.id);
            }
          }
        }
      }

      if (userCourse == null || userCourse.courseData == null) return;

      // Count completed blocks from progress data
      int completedBlockCount = 0;
      final lessonsProgress = userCourse.progressData['lessons'] as Map<String, dynamic>?;
      if (lessonsProgress != null) {
        for (final entry in lessonsProgress.entries) {
          final lessonData = entry.value as Map<String, dynamic>?;
          final completedBlocks = lessonData?['completed_blocks'] as List<dynamic>?;
          completedBlockCount += completedBlocks?.length ?? 0;
        }
      }

      // For quiz-only courses: count answered quiz questions as completed blocks
      if (completedBlockCount == 0) {
        final quizAnswers = userCourse.progressData['quiz_answers'] as Map<String, dynamic>?;
        if (quizAnswers != null) {
          completedBlockCount = quizAnswers.values
              .where((a) => a is Map && a['is_answered'] == true)
              .length;
        }
      }

      // Rebuild course with updated progress. Carry forward the best-known
      // title (set by the caller / current course) so a stale R2 payload
      // missing `name` doesn't reset the app bar to "Kurz".
      final fallbackTitle = (userCourse.courseName?.trim().isNotEmpty ?? false)
          ? userCourse.courseName!.trim()
          : _course.title;
      final updatedCourse = Course.fromJsonData(
        id: _course.id,
        data: userCourse.courseData!,
        completedLessons: userCourse.completedLessons,
        isCompleted: userCourse.status == UserCourseStatus.completed,
        isBookmarked: _isBookmarked,
        lessonsProgress: lessonsProgress,
        fallbackName: fallbackTitle,
      );

      // Extract completed block IDs + removed practice blocks for Cvičení filtering
      final completedIds = Course.extractCompletedBlockIds(userCourse.progressData);
      final removed = userCourse.progressData['removed_practice_blocks'] as List<dynamic>?;
      final removedIds = removed?.map((e) => e as String).toSet() ?? <String>{};

      if (mounted) {
        setState(() {
          _courseOverride = updatedCourse;
          _completedBlocks = completedBlockCount;
          _completedBlockIds = completedIds;
          _removedPracticeBlocks = removedIds;
          _hasUpdate = userCourse!.hasUpdate;
          _calculateTotalBlocks(); // Recalculate in case course data changed
          // The rebuilt course, not the stored status: a course completed
          // before its author added lessons is not done (BR-PHJQDK).
          _isCourseCompleted = updatedCourse.isCompleted
              || (_completedBlocks >= _totalBlocks && _totalBlocks > 0);
        });
        // Course JSON is loaded now — turn this course's DB bookmarks into real
        // blocks so the Cvičení button sees them (BR-ZBJ99Z).
        _hydrateBookmarks();
      }
    } catch (e, st) { silentLog('course_detail_page', e, st); }
  }

  /// Check server for a newer course version (metadata only, no download).
  /// Called once on page open. Updates local metadata so hasUpdate reflects reality.
  Future<void> _checkForUpdate() async {
    try {
      final localCourseId = await _resolveLocalCourseId();
      if (localCourseId == null) return;
      final courseRepo = ref.read(courseRepositoryProvider);
      await courseRepo.checkCourseVersionOnly(localCourseId);
      // Re-read userCourse to pick up the new hasUpdate value
      await _refreshCourseProgress();
    } catch (e, st) { silentLog('course_detail_page', e, st); }
  }

  /// Resolve the local DB UUID for the course.
  /// _course.id is the slug (e.g. "A2-Rovnice_c1"), but DB lookups need the
  /// UUID primary key. We read it from the user_courses.courseId column.
  Future<String?> _resolveLocalCourseId() async {
    final db = ref.read(appDatabaseProvider);
    final ucId = _resolvedUserCourseId ?? widget.userCourseId;
    if (ucId != null) {
      final uc = await db.getUserCourseById(ucId);
      if (uc != null) return uc.courseId;
    }
    // Last resort: try _course.id directly (works when id IS the UUID)
    final row = await db.getCourseById(_course.id);
    return row?.id;
  }

  /// Download the latest course content and update the local version.
  Future<void> _performUpdate() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final db = ref.read(appDatabaseProvider);
      final courseRepo = ref.read(courseRepositoryProvider);

      final ucId = _resolvedUserCourseId ?? widget.userCourseId;
      if (ucId == null) throw Exception('No user course');

      // Resolve real DB UUID — _course.id may be a slug
      final localCourseId = await _resolveLocalCourseId();
      if (localCourseId == null) throw Exception('Course not found in DB');

      // Download full content from R2
      await courseRepo.downloadFullCourseJson(localCourseId);

      // Read version AFTER download — downloadFullCourseJson step 0 may
      // have bumped courses.version via upsertFromServer.
      final courseRow = await db.getCourseById(localCourseId);
      final version = courseRow?.version ?? 1;

      // Set downloadedVersion = courses.version to clear hasUpdate.
      await db.updateUserCourseDownloadedVersion(
        id: ucId,
        downloadedVersion: version,
      );

      // Sync so any newly flagged default_practice blocks in the updated
      // content get seeded into the practice set and pushed right away.
      ref.read(syncServiceProvider).sync();

      // Reload course data + clear _hasUpdate
      await _refreshCourseProgress();

      if (mounted) {
        setState(() {
          _isUpdating = false;
          _hasUpdate = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.libraryCourseUpdated(_course.title)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.libraryCourseUpdateError('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _navigateToCurrentLesson() {
    final lessons = _nonEmptyLessons;
    if (lessons.isEmpty) return;

    // Find the first in-progress lesson, or first non-completed lesson
    int idx = lessons.indexWhere(
      (l) => l.status == LessonStatus.inProgress,
    );

    // If no in-progress, find first non-completed
    if (idx == -1) {
      idx = lessons.indexWhere(
        (l) => l.status != LessonStatus.completed,
      );
    }

    // If all completed, go to first lesson
    if (idx == -1) idx = 0;

    _navigateToLesson(lessons[idx]);
  }

  Future<void> _navigateToLesson(Lesson lesson) async {
    // Find the real index in the full list for LessonDetailPage
    final realIndex = _course.lessons.indexOf(lesson);
    await Navigator.push(
      context,
      shellPageRoute(
        context,
        builder: (context) => LessonDetailPage(
          course: _course,
          lesson: lesson,
          lessonIndex: realIndex >= 0 ? realIndex : 0,
          userCourseId: _userCourseId,
        ),
      ),
    );
    // Refresh course progress when returning from lesson
    if (mounted) {
      await _refreshCourseProgress();
    } else {
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.widthClass == WidthClass.compact) return _buildPage(context);
    // Always a pushed route, so it has to redraw the navigation itself.
    return DetailShell(
      backLabel: AppStrings.courseBackToAll,
      child: _buildWidePage(context),
    );
  }

  /// Phone layout — unchanged.
  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main scrollable content
          SingleChildScrollView(
            child: Column(
              children: [
                // Header with cover image
                _buildHeader(),
                // White content area (starts right after header, overlaps by 40px)
                Container(
                  transform: Matrix4.translationValues(0, -40, 0),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Course info card content
                      _buildCourseInfoCardContent(),
                      // Divider
                      _buildDivider(),
                      // Progress section
                      _buildProgressSection(),
                      // Divider
                      _buildDivider(),
                      // Description section
                      _buildDescriptionSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // Adjust for the transform
                const SizedBox(height: 0),
                // Light purple background section with top radius
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Lessons section
                        _buildLessonsSection(),
                        // Skills card
                        _buildSkillsSection(),
                        // Quizzes section
                        _buildQuizzesSection(),
                        // Bottom padding for action bar
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Fixed top navigation buttons
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _buildNavigationButtons(),
          ),
          // Bottom action bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            _course.iconEmoji,
            style: const TextStyle(fontSize: 120),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Back button
            _buildCircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            // Bookmark + menu button hidden (TODO: re-enable when ready)
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: AppDecorations.circleButton,
        child: Icon(
          icon,
          color: AppColors.primaryDark,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildDivider({double topPadding = 32, double bottomPadding = 27}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildCourseInfoCardContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _course.title,
              style: AppTextStyles.heading1(),
            ),
            const SizedBox(height: 4),
            // Subtitle
            Text(
              _course.subtitle,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
            ),
            const SizedBox(height: 12),
            // Meta info row
            Row(
              children: [
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.primaryDark48,
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.lessonsCount(_course.lessonCount),
                  style: AppTextStyles.meta(color: AppColors.primaryDark64),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.primaryDark48,
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.durationSmart(_course.durationMinutes),
                  style: AppTextStyles.meta(color: AppColors.primaryDark64),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tags row + skills button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_course.badge.isNotEmpty) _buildBadge(_course.badge),
                      if (_course.difficulty.isNotEmpty) _buildBadge(_course.difficulty),
                      if (_isCourseCompleted) _buildCompletedBadge(),
                    ],
                  ),
                ),
                _buildCourseMentorButton(),
                _buildSkillsButton(),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: AppDecorations.radiusXS,
        border: Border.all(
          color: AppColors.primaryDark,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTextStyles.badgeSmall(),
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.16),
        borderRadius: AppDecorations.radiusXS,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            AppStrings.courseCompleted,
            style: AppTextStyles.badgeSmall(color: AppColors.success),
          ),
        ],
      ),
    );
  }

  /// Entry point to this course's own mentors.
  ///
  /// Course mentors are usually hidden — they are deliberately kept out of the
  /// general new-chat list, so this button is the only way a student reaches
  /// them. It renders nothing when the course has no mentors, so courses that
  /// never got one look exactly as before.
  Widget _buildCourseMentorButton() {
    return Consumer(
      builder: (context, ref, _) {
        final mentors =
            ref.watch(courseChatMentorsProvider(_course.id)).valueOrNull ??
                const <ChatMentor>[];

        if (mentors.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _openCourseMentor(mentors),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: AppDecorations.radiusS,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mentors.length == 1 ? mentors.first.emoji : '\u{1F4AC}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mentors.length == 1
                        ? mentors.first.name
                        : AppStrings.courseMentor,
                    style: AppTextStyles.badgeSmall(color: AppColors.surface),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// One mentor opens straight into a chat; several first ask which one.
  Future<void> _openCourseMentor(List<ChatMentor> mentors) async {
    if (mentors.length == 1) {
      await _startMentorChat(mentors.first);
      return;
    }

    final picked = await showModalBottomSheet<ChatMentor>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.chatSelectPersona, style: AppTextStyles.cardTitle()),
            const SizedBox(height: 16),
            ...mentors.map(
              (m) => ListTile(
                leading: Text(m.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(m.name, style: AppTextStyles.labelMedium()),
                subtitle: m.subtitle == null
                    ? null
                    : Text(m.subtitle!, style: AppTextStyles.meta()),
                onTap: () => Navigator.pop(ctx, m),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) await _startMentorChat(picked);
  }

  Future<void> _startMentorChat(ChatMentor mentor) async {
    try {
      final user = await ref.read(activeUserProvider.future);
      if (user == null) return;

      final session = await ref
          .read(chatRepositoryProvider)
          .createSession(user.id, mentor.slug);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            sessionId: session.id,
            sessionTitle:
                session.title.isNotEmpty ? session.title : mentor.name,
            persona: mentor.persona,
          ),
        ),
      );
    } catch (e, st) {
      silentLog('course_detail_page', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.chatRequiresInternet),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildSkillsButton() {
    return GestureDetector(
      onTap: _navigateToSkills,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.quizPurple,
          borderRadius: AppDecorations.radiusS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights,
              size: 16,
              color: AppColors.surface,
            ),
            const SizedBox(width: 6),
            Text(
              AppStrings.achievementsSkills,
              style: AppTextStyles.badgeSmall(color: AppColors.surface),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToSkills() async {
    final stats = ref.read(userStatsProvider).valueOrNull;
    final config = ref.read(gamificationConfigProvider).valueOrNull;
    final earnedIds = ref.read(earnedAchievementsProvider).valueOrNull ?? <String>[];

    ref.invalidate(skillDisplayProvider);
    final skills = await ref.read(skillDisplayProvider.future);

    // Count lessons/courses/quizzes from user courses
    final userCourses = ref.read(userCoursesStreamProvider).valueOrNull ?? [];
    final counts = countAchievementStats(userCourses);

    if (!mounted) return;
    Navigator.of(context).push(
      shellPageRoute(
        context,
        builder: (_) => AchievementsPage(
          level: stats?.level ?? 1,
          currentXp: stats?.xpForCurrentLevel ?? 0,
          xpForNextLevel: stats?.xpForNextLevel ?? 500,
          totalXp: stats?.xpPoints ?? 0,
          streakDays: stats?.streakDays ?? 1,
          trophiesCount: stats?.achievementsCount ?? 0,
          coinsEarned: stats?.coinsEarned ?? 0,
          lessonsCompleted: counts.lessons,
          coursesCompleted: counts.courses,
          quizzesCompleted: counts.quizzes,
          config: config,
          earnedIds: earnedIds.toSet(),
          skills: skills,
          scrollToSkills: true,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.courseProgress,
            style: AppTextStyles.cardTitle(),
          ),
          const SizedBox(height: 12),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    // Calculate progress based on completed blocks
    final progress = _isCourseCompleted ? 1.0
        : _totalBlocks > 0 ? _completedBlocks / _totalBlocks : 0.0;
    final Color progressColor =
        _isCourseCompleted ? AppColors.success : AppColors.progressFill;

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progressWidth = constraints.maxWidth * progress;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Background with diagonal stripes
              ClipRRect(
                borderRadius: AppDecorations.radiusXS,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.progressTrack,
                  ),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 24),
                    painter: _DiagonalStripesPainter(
                      stripeColor: AppColors.background,
                      stripeWidth: 4,
                      spacing: 8.964,
                    ),
                  ),
                ),
              ),
              // Progress fill with text
              if (progressWidth > 0)
                Container(
                  width: progressWidth.clamp(40.0, constraints.maxWidth), // Minimum width to show text
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: AppDecorations.radiusXS,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // White progress line at top
                      Positioned(
                        left: 4,
                        top: 4,
                        right: 4,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Progress text at the end of progress bar
                      Positioned(
                        right: 4,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            '$_completedBlocks/$_totalBlocks',
                            style: AppTextStyles.actionText(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final descriptionStyle = AppTextStyles.bodySmall(color: AppColors.primaryDark64).copyWith(
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.courseDescription,
            style: AppTextStyles.cardTitle(),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Measure if text would overflow at 3 lines
              final textSpan = TextSpan(
                text: _course.description,
                style: descriptionStyle,
              );
              final textPainter = TextPainter(
                text: textSpan,
                maxLines: 3,
                textDirection: TextDirection.ltr,
              );
              textPainter.layout(maxWidth: constraints.maxWidth);
              final needsExpansion = textPainter.didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _course.description,
                    maxLines: _isDescriptionExpanded ? null : 3,
                    overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                    style: descriptionStyle,
                  ),
                  // Only show expand button if text actually overflows
                  if (needsExpansion) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDescriptionExpanded = !_isDescriptionExpanded;
                        });
                      },
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppDecorations.radiusXS,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle: _isDescriptionExpanded ? -1.5708 : 1.5708,
                              child: Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _isDescriptionExpanded ? AppStrings.courseShowLess : AppStrings.courseShowMore,
                              style: AppTextStyles.actionText(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsSection() {
    // Hide lessons entirely for quiz-only courses
    if (_isOnlyQuiz) return const SizedBox.shrink();

    final lessons = _nonEmptyLessons;

    // Show error state when course has no lessons (corrupted/incomplete download)
    if (lessons.isEmpty) {
      return _buildCorruptedCourseNotice();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            AppStrings.courseLessons,
            style: AppTextStyles.heading1(),
          ),
          const SizedBox(height: 16),
          // Update required banner
          if (_hasUpdate) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: AppDecorations.radiusM,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.32),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.courseUpdateRequired,
                      style: AppTextStyles.bodySmall(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Quiz-first button when quiz is required
          if (_quizRequired) ...[
            _buildStartQuizCard(),
            const SizedBox(height: 12),
          ],
          // Lesson cards
          for (int i = 0; i < lessons.length; i++) ...[
            _buildLessonCard(lessons[i], i),
            if (i < lessons.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildCorruptedCourseNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppDecorations.radiusL,
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.32),
                width: 1,
              ),
              boxShadow: AppDecorations.shadowLight,
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.courseCorruptedTitle,
                  style: AppTextStyles.cardTitleSmall(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.courseCorruptedMessage,
                  style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: AppDecorations.radiusM,
                    ),
                    child: Text(
                      AppStrings.courseBack,
                      style: AppTextStyles.statValueAlt(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson, int index) {
    Color iconBgColor;
    String iconPath;
    // Null keeps the asset's own colours: the lock is drawn near-black, which
    // no palette key matches.
    Color? iconColor;

    switch (lesson.status) {
      case LessonStatus.completed:
        iconBgColor = AppColors.successBg;
        iconPath = 'assets/icons/check.svg';
        iconColor = AppColors.success;
        break;
      case LessonStatus.inProgress:
        iconBgColor = AppColors.background;
        iconPath = 'assets/icons/play.svg';
        iconColor = AppColors.progressFill;
        break;
      case LessonStatus.locked:
        iconBgColor = AppColors.background;
        iconPath = 'assets/icons/lock.svg';
        break;
    }

    // Force lock all lessons when quiz is required or update is available
    if (_quizRequired || _hasUpdate) {
      iconBgColor = AppColors.background;
      iconPath = 'assets/icons/lock.svg';
      iconColor = null;
    }

    final isInProgress = !_quizRequired && !_hasUpdate && !_openAll &&
        lesson.status == LessonStatus.inProgress;
    final isLocked = _quizRequired || _hasUpdate ||
        (!_openAll && lesson.status == LessonStatus.locked);

    return GestureDetector(
      onTap: isLocked ? null : () => _navigateToLesson(lesson),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: Row(
        children: [
          // Status icon circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: iconColor == null
                    ? null
                    : ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title and meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with optional AKTUALNI badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        lesson.title,
                        style: AppTextStyles.statValue(),
                      ),
                    ),
                    if (isInProgress) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primaryDark,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppStrings.courseCurrent,
                          style: AppTextStyles.badgeTiny(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Meta row
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/clipboard.svg',
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.courseQuestionsCount(lesson.questionCount),
                      style: AppTextStyles.meta(color: AppColors.primaryDark64),
                    ),
                    const SizedBox(width: 12),
                    SvgPicture.asset(
                      'assets/icons/clock.svg',
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.courseDurationMin(lesson.durationMinutes),
                      style: AppTextStyles.meta(color: AppColors.primaryDark64),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildQuizzesSection() {
    if (_course.quizzes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: CardSection(
        title: AppStrings.courseQuizzes,
        actionText: AppStrings.courseShowAll,
        onActionTap: () {
          // TODO: Navigate to all quizzes
        },
        carouselHeight: 200,
        cards: _course.quizzes.map((quiz) => CourseCard(
          iconWidget: Text(
            _course.iconEmoji,
            style: const TextStyle(fontSize: 32),
          ),
          iconBackgroundColor: _course.iconBackgroundColor.withValues(alpha: 0.48),
          title: AppStrings.courseQuizPrefix(quiz.title),
          badge: _course.badge,
          metaItems: [
            CardMetaItem(
              icon: Icons.grid_view_rounded,
              iconColor: AppColors.progressFill,
              label: '${quiz.questionCount}',
            ),
            CardMetaItem(
              icon: Icons.rocket_launch,
              iconColor: AppColors.orange,
              label: '+25 XP',
            ),
          ],
          onTap: () {
            // TODO: Navigate to quiz
          },
        )).toList(),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    // Hide action bar when course data is corrupted/empty
    if (_course.lessons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark08,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: _actionContent(),
    );
  }

  /// The primary action for the course's current state.
  ///
  /// Shared by the phone layout's bottom bar and the wide layout's hero card
  /// so the two cannot disagree about what "continue" means when an update is
  /// pending or an entry quiz is required.
  Widget _actionContent() {
    if (_onlyOnceLocked) return _buildOnlyOnceLockedNotice();
    if (_hasUpdate) return _buildUpdateBanner();
    if (_isOnlyQuiz || _quizRequired) return _buildQuizRequiredActionButton();
    if (_isCourseCompleted) return _buildCompletedActionButtons();
    return _buildInProgressActionButtons();
  }

  /// Takes the place of every action once an only-once course is finished.
  Widget _buildOnlyOnceLockedNotice() {
    return Container(
      width: double.infinity,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.16),
        borderRadius: AppDecorations.radiusM,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppStrings.libraryCourseAlreadyCompleted,
              textAlign: TextAlign.center,
              style: AppTextStyles.statValue(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  /// Update banner shown when a newer course version is available.
  Widget _buildUpdateBanner() {
    return GestureDetector(
      onTap: _isUpdating ? null : _performUpdate,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: AppDecorations.radiusM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _isUpdating
              ? [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.libraryUpdating,
                    style: AppTextStyles.statValue(color: Colors.white),
                  ),
                ]
              : [
                  Icon(Icons.system_update_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.libraryUpdate,
                    style: AppTextStyles.statValue(color: Colors.white),
                  ),
                ],
        ),
      ),
    );
  }

  /// Action buttons when course is in progress: Cviceni + Pokracovat v lekci
  Widget _buildInProgressActionButtons() {
    // Watch (not read) so the row rebuilds once _hydrateBookmarks fills the
    // notifier's in-memory blocks.
    ref.watch(bookmarkProvider);
    final hasExerciseBlocks = _exerciseBlocks().isNotEmpty || _hasBookmarks();
    final hasQuestions = _course.getAllQuestionBlocks().isNotEmpty;

    final continueButton = GestureDetector(
      onTap: _navigateToCurrentLesson,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: AppDecorations.radiusM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Text(
              AppStrings.courseActionLessons,
              style: AppTextStyles.statValue(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    // All buttons in a single row
    return Row(
      children: [
        // Lekce button (primary)
        Expanded(child: continueButton),
        // Cviceni button (secondary)
        if (hasExerciseBlocks)
          const SizedBox(width: 12),
        if (hasExerciseBlocks)
          Expanded(
            child: GestureDetector(
              onTap: _navigateToExercise,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: AppDecorations.radiusM,
                  border: Border.all(
                    color: AppColors.primaryDark,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/chat.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        AppColors.primaryDark,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.courseExercise,
                      style: AppTextStyles.statValue(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Kviz button (secondary)
        if (hasQuestions)
          const SizedBox(width: 12),
        if (hasQuestions)
          Expanded(
            child: GestureDetector(
              onTap: _navigateToQuiz,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: AppDecorations.radiusM,
                  border: Border.all(
                    color: AppColors.success,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      color: AppColors.success,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.courseQuiz,
                      style: AppTextStyles.statValue(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Action buttons when course is completed: Cviceni (bookmarked + default_practice) + Kviz (all questions)
  Widget _buildCompletedActionButtons() {
    ref.watch(bookmarkProvider);
    final hasExerciseBlocks = _exerciseBlocks().isNotEmpty || _hasBookmarks();
    final hasQuestions = _course.getAllQuestionBlocks().isNotEmpty;

    // If neither exercise blocks nor questions exist, show "Pokračovat" to re-enter lessons
    if (!hasExerciseBlocks && !hasQuestions) {
      return GestureDetector(
        onTap: _navigateToCurrentLesson,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: AppDecorations.radiusM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 6),
              Text(
                AppStrings.courseActionLessons,
                style: AppTextStyles.statValue(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        if (hasExerciseBlocks)
          Expanded(
            child: GestureDetector(
              onTap: _navigateToExercise,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: AppDecorations.radiusM,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bookmark_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.courseExercise,
                      style: AppTextStyles.statValue(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (hasExerciseBlocks && hasQuestions)
          const SizedBox(width: 12),
        if (hasQuestions)
          Expanded(
            child: GestureDetector(
              onTap: _navigateToQuiz,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: AppDecorations.radiusM,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.quiz_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.courseQuiz,
                      style: AppTextStyles.statValue(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Card button prompting user to start the initial quiz
  Widget _buildStartQuizCard() {
    return GestureDetector(
      onTap: _navigateToQuiz,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: AppDecorations.radiusXL,
          boxShadow: AppDecorations.shadowStrong,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _quizButtonLabel,
                    style: AppTextStyles.statValue(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.courseQuizUnlockHint,
                    style: AppTextStyles.meta(
                      color: Colors.white.withValues(alpha: 0.64),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white.withValues(alpha: 0.64),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Full-width quiz button for bottom bar when quiz is required
  Widget _buildQuizRequiredActionButton() {
    return GestureDetector(
      onTap: _navigateToQuiz,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: AppDecorations.radiusM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _quizButtonLabel,
              style: AppTextStyles.statValue(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to exercise based on default_practice + bookmarked blocks
  Future<void> _navigateToExercise() async {
    // Bookmarks may still be un-hydrated when the user taps straight through
    // from the dashboard — resolve them now so a course whose only exercise
    // material is bookmarked doesn't report "no bookmarks" (BR-ZBJ99Z).
    _hydrateBookmarks();
    final exerciseBlocks = _exerciseBlocks();

    if (exerciseBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bookmark_border, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.courseNoBookmarks,
                  style: AppTextStyles.subtitle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusS),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(
          questionBlocks: exerciseBlocks,
          courseTitle: _course.title,
          courseId: _course.id,
          progress: _exerciseProgress,
          onlyOnce: _course.onlyOnce,
          evaluate: true,
          isExercise: true,
          // In-lesson practice mirrors the dashboard practice UX: display
          // self-rating bar + hint on "Připomeň" + no mentor robot (BR-ZDYA83).
          selfRateDisplayBlocks: true,
        ),
      ),
    );
    if (mounted) {
      await _refreshCourseProgress();
    }
  }

  /// Navigate to the course quiz — ten ELO-matched questions like the global
  /// quiz, or every question where the quiz is the assessment (BR-WRMW7W);
  /// see [courseQuizBlocks].
  Future<void> _navigateToQuiz() async {
    // No button leads here for a finished only-once course; refuse anyway.
    if (_onlyOnceLocked) return;

    final questionBlocks = await courseQuizBlocks(ref, _course, _quizProgress);
    if (!mounted) return;

    if (questionBlocks.isEmpty) {
      // Show message if no questions available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.courseNoQuestions,
            style: AppTextStyles.subtitle(color: Colors.white),
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
      return;
    }

    // Mark quiz as started
    if (!_quizStarted) {
      setState(() => _quizStarted = true);
    }

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(
          questionBlocks: questionBlocks,
          courseTitle: _course.title,
          courseId: _course.id,
          progress: _quizProgress,
          evaluate: _course.quizEvaluate,
          onlyOnce: _course.onlyOnce,
        ),
      ),
    );

    // For onlyOnce courses, go back to course list after quiz completion.
    // Check BEFORE any setState to avoid rebuild-then-pop race.
    if (completed == true && _course.onlyOnce && mounted) {
      // Mark the user_course as completed so re-entry via PIN is blocked.
      if (_userCourseId != null) {
        final repository = ref.read(userCourseRepositoryProvider);
        await repository.updateProgress(
          id: _userCourseId!,
          progressPercent: 100,
        );
        // Force-sync so the completion reaches the server immediately.
        ref.read(syncServiceProvider).sync();
      }
      // Defer pop to next frame so any pending didPopNext rebuilds settle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    // Only unlock lessons when quiz is actually completed
    if (completed == true && _course.startsWithQuiz && mounted) {
      setState(() {
        _quizCompleted = true;
      });
    }

    // Refresh progress after returning from quiz
    if (mounted) {
      await _refreshCourseProgress();
    }
  }

  // ── Wide layout ───────────────────────────────────────────────────────
  //
  // Same data as the phone page, arranged per the desktop design: a hero card,
  // a tabbed content card, and a rail carrying progress and skills.
  // The phone builders above are untouched.

  Widget _buildWidePage(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const pad = 32.0;
        final contentWidth = constraints.maxWidth - pad * 2;
        final withRail = hasSideRail(contentWidth);

        return ListView(
          padding: const EdgeInsets.fromLTRB(pad, 8, pad, 40),
          children: [
            _buildWideHero(),
            const SizedBox(height: 24),
            if (withRail)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildWideTabsCard()),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: _railWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildWideRail(),
                    ),
                  ),
                ],
              )
            else ...[
              _buildWideTabsCard(),
              const SizedBox(height: 24),
              ..._buildWideRail(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildWideHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // What the card's content may use, and what is left for the text
        // column once the icon tile and the gap after it are taken out.
        final inner = constraints.maxWidth - _heroPadding * 2;
        final infoWidth = inner - _heroIconSize - _heroIconGap;
        // On tablet widths the text column is too narrow to hold the action
        // buttons next to "Uložit kurz": the three of them split what was left
        // until their labels ran over each other (BR-BCNXAP). Below that width
        // the row drops under the icon and takes the hero's full width.
        final stackActions = !heroActionRowFits(infoWidth);

        return Container(
          padding: const EdgeInsets.all(_heroPadding),
          decoration: BoxDecoration(
            color: _course.iconBackgroundColor.withValues(alpha: 0.32),
            borderRadius: AppDecorations.radiusXL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The design has a per-course illustration: the course cover
                  // when admin set one, otherwise the emoji blown up on a
                  // tinted tile (BR-YKYXC6).
                  Container(
                    width: _heroIconSize,
                    height: _heroIconSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.72),
                      borderRadius: AppDecorations.radiusL,
                    ),
                    child: CourseCoverImage(
                      url: _course.headerImage?.url,
                      fallback: Center(
                        child: Text(_course.iconEmoji,
                            style: const TextStyle(fontSize: 84)),
                      ),
                    ),
                  ),
                  const SizedBox(width: _heroIconGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _course.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.heading2Bold(),
                              ),
                            ),
                            if (_course.badge.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.16),
                                  borderRadius: AppDecorations.radiusPill,
                                ),
                                child: Text(
                                  _course.badge,
                                  style: AppTextStyles.badgeSmall(
                                      color: AppColors.primary),
                                ),
                              ),
                            ],
                            if (_isCourseCompleted) ...[
                              const SizedBox(width: 8),
                              _buildCompletedBadge(),
                            ],
                          ],
                        ),
                        if (_course.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _course.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                                color: AppColors.primaryDark72),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          children: [
                            _heroMeta(Icons.copy_rounded,
                                AppStrings.lessonsCount(_course.lessonCount)),
                            _heroMeta(
                                Icons.access_time,
                                AppStrings.durationSmart(
                                    _course.durationMinutes)),
                            if (_course.difficulty.isNotEmpty)
                              _heroMeta(
                                  Icons.bar_chart_rounded,
                                  AppStrings.courseLevelLabel(
                                      _course.difficulty)),
                          ],
                        ),
                        if (!stackActions) ...[
                          const SizedBox(height: 20),
                          _buildHeroActions(infoWidth),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (stackActions) ...[
                const SizedBox(height: 20),
                _buildHeroActions(inner),
              ],
            ],
          ),
        );
      },
    );
  }

  /// The hero's action row: the shared course actions plus "Uložit kurz".
  ///
  /// [availableWidth] is what the row may occupy. When both do not fit on one
  /// line the save button drops to a line of its own rather than squeezing the
  /// action buttons past the width their labels need.
  Widget _buildHeroActions(double availableWidth) {
    final besideSave = heroActionRowFits(availableWidth);
    final actionsWidth = math.min(
      besideSave
          ? availableWidth - kHeroActionsGap - kHeroSaveButtonWidth
          : availableWidth,
      kHeroActionsMaxWidth,
    );

    return Wrap(
      key: courseHeroActionsKey,
      spacing: kHeroActionsGap,
      runSpacing: kHeroActionsGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Reuses the phone bottom bar's chooser so update / quiz-required /
        // completed states behave identically.
        SizedBox(
          key: courseHeroActionButtonsKey,
          width: actionsWidth,
          child: _actionContent(),
        ),
        _buildSaveCourseButton(),
      ],
    );
  }

  Widget _heroMeta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryDark48),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.meta(color: AppColors.primaryDark64)),
      ],
    );
  }

  /// Placeholder: bookmarking a whole course is not wired up (the list cards
  /// hide their bookmark control for the same reason).
  Widget _buildSaveCourseButton() {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.courseSaveButton} — ${AppStrings.profileComingSoon}',
          ),
        ),
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusM,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 20, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Text(AppStrings.courseSaveButton,
                style: AppTextStyles.actionSmall()),
          ],
        ),
      ),
    );
  }

  Widget _buildWideTabsCard() {
    final tabs = [
      AppStrings.courseTabLessons,
      AppStrings.courseTabAbout,
      AppStrings.courseTabSkills,
      AppStrings.courseTabStats,
    ];

    return Container(
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _buildTab(tabs[i], i),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.primaryDark08),
          Padding(
            padding: const EdgeInsets.all(16),
            child: switch (_wideTab) {
              1 => _buildWideAbout(),
              2 => _buildSkillsList(limit: null),
              3 => _buildWidePlaceholder(AppStrings.courseStatsPlaceholder),
              _ => _buildWideLessons(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _wideTab == index;
    return InkWell(
      onTap: () => setState(() => _wideTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: isSelected ? AppColors.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.actionSmall(
            color: isSelected ? AppColors.primary : AppColors.primaryDark64,
          ),
        ),
      ),
    );
  }

  Widget _buildWidePlaceholder(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.primaryDark64),
        ),
      ),
    );
  }

  Widget _buildWideAbout() {
    if (_course.description.isEmpty) {
      return _buildWidePlaceholder(AppStrings.courseDescription);
    }
    return Text(
      _course.description,
      style: AppTextStyles.body(color: AppColors.primaryDark72, height: 1.6),
    );
  }

  Widget _buildWideLessons() {
    if (_isOnlyQuiz) return _buildWidePlaceholder(AppStrings.courseQuizzes);

    final lessons = _nonEmptyLessons;
    if (lessons.isEmpty) return _buildCorruptedCourseNotice();

    // Every lesson, like the phone list. The design folded all but the first
    // five behind a "show all" toggle, which on a desktop only hid lessons
    // there was room for (BR-M2EZY6).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasUpdate) ...[
          _buildWideNotice(AppStrings.courseUpdateRequired),
          const SizedBox(height: 12),
        ],
        if (_quizRequired) ...[
          _buildStartQuizCard(),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < lessons.length; i++) ...[
          _buildWideLessonRow(lessons[i], i),
          if (i < lessons.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildWideNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: AppDecorations.radiusM,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLessonRow(Lesson lesson, int index) {
    // Same gating as the phone card: a pending update or a required entry quiz
    // locks everything.
    final isLocked = _quizRequired || _hasUpdate ||
        (!_openAll && lesson.status == LessonStatus.locked);
    final isCurrent = !isLocked && !_openAll &&
        lesson.status == LessonStatus.inProgress;
    final isDone = lesson.status == LessonStatus.completed;

    final Color numberBg = isCurrent
        ? AppColors.primary
        : isDone
            ? AppColors.successBg
            : AppColors.background;
    final Color numberFg = isCurrent ? AppColors.surface : AppColors.primaryDark;

    return GestureDetector(
      onTap: isLocked ? null : () => _navigateToLesson(lesson),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.background,
          borderRadius: AppDecorations.radiusL,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: numberBg, shape: BoxShape.circle),
              child: Center(
                child: isDone
                    ? Icon(Icons.check, size: 20, color: AppColors.success)
                    : Text('${index + 1}',
                        style: AppTextStyles.actionSmall(color: numberFg)),
              ),
            ),
            const SizedBox(width: 16),
            // The title takes two thirds of what the fixed columns leave and
            // wraps onto a second line; one line cut longer titles off
            // (BR-M2EZY6).
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySemiBold(),
                  ),
                  if (lesson.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lesson.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall(
                          color: AppColors.primaryDark64),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Expanded, not Flexible: a loose meta left its unused share as dead
            // space after the action button instead of handing it to the title,
            // and its right alignment did nothing. On a narrow tablet column the
            // meta still trims rather than overflowing the row.
            Expanded(
              child: Text(
                '${AppStrings.courseQuestionsCount(lesson.questionCount)} · '
                '${AppStrings.courseDurationMin(lesson.durationMinutes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTextStyles.meta(color: AppColors.primaryDark64),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 132, child: _buildLessonAction(lesson, isLocked, isCurrent)),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonAction(Lesson lesson, bool isLocked, bool isCurrent) {
    if (isLocked) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: AppDecorations.radiusM,
          border: Border.all(color: AppColors.primaryDark12),
        ),
        child: Icon(Icons.lock_outline,
            size: 18, color: AppColors.primaryDark48),
      );
    }

    return GestureDetector(
      onTap: () => _navigateToLesson(lesson),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.primary : null,
          borderRadius: AppDecorations.radiusM,
          border:
              isCurrent ? null : Border.all(color: AppColors.primaryDark12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 18,
              color: isCurrent ? AppColors.surface : AppColors.primaryDark,
            ),
            const SizedBox(width: 6),
            Text(
              isCurrent
                  ? AppStrings.courseCardContinue
                  : AppStrings.courseOpenLesson,
              style: AppTextStyles.actionSmall(
                color: isCurrent ? AppColors.surface : AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWideRail() {
    final lessons = _nonEmptyLessons;
    final done = lessons.where((l) => l.status == LessonStatus.completed).length;

    return [
      ProgressRingCard(
        lessonsDone: _isCourseCompleted ? lessons.length : done,
        lessonsTotal: lessons.length,
        hintOverride:
            _isCourseCompleted ? null : AppStrings.courseTrophyHint,
        showBar: true,
        trailingIcon: Icons.emoji_events_outlined,
        actionLabel: AppStrings.courseDetailedStats,
        onDetailTap: _navigateToSkills,
      ),
      const SizedBox(height: 16),
      _buildSkillsCard(),
    ];
  }

  /// Phone placement of [_buildSkillsCard], under the lesson list.
  ///
  /// The wide layout carries the card in its rail, which the phone column has
  /// no equivalent of, so it gets its own padded slot matching the surrounding
  /// sections. Hidden outright when the learner has no ELO profile yet — the
  /// provider returns an empty list only in that case, so an untouched account
  /// doesn't grow an explanatory panel it can't act on.
  Widget _buildSkillsSection() {
    final skills = ref.watch(skillDisplayProvider).valueOrNull ?? const [];
    if (skills.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
      child: _buildSkillsCard(),
    );
  }

  Widget _buildSkillsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecorationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(AppStrings.courseSkillsInCourse,
                    style: AppTextStyles.heading4()),
              ),
              GestureDetector(
                onTap: _navigateToSkills,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  AppStrings.courseShowAll,
                  style: AppTextStyles.actionSmall(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSkillsList(limit: 3),
        ],
      ),
    );
  }

  /// Skill rows.
  ///
  /// These are the learner's overall ELO-derived skills, not per-course ones —
  /// the model has no course scoping for them. Shown as-is rather than faked.
  Widget _buildSkillsList({required int? limit}) {
    final skills = ref.watch(skillDisplayProvider).valueOrNull ?? const [];
    if (skills.isEmpty) {
      return Text(
        AppStrings.courseSkillsEmpty,
        style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
      );
    }

    final shown = limit == null ? skills : skills.take(limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          _buildSkillRow(shown[i]),
          if (i < shown.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSkillRow(SkillDisplay skill) {
    // SkillDisplay.level is 0 (no data) or 1–10.
    final fraction = (skill.level / 10).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(skill.emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                skill.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySemiBold(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: AppColors.progressTrack,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.progressFill),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.skillLevelLabel(skill.level.round()),
                    style: AppTextStyles.meta(color: AppColors.primaryDark64),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for diagonal stripes pattern
class _DiagonalStripesPainter extends CustomPainter {
  final Color stripeColor;
  final double stripeWidth;
  final double spacing;

  _DiagonalStripesPainter({
    required this.stripeColor,
    required this.stripeWidth,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final double step = stripeWidth + spacing;
    final double diagonal = size.width + size.height;

    for (double i = -size.height; i < diagonal; i += step) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
