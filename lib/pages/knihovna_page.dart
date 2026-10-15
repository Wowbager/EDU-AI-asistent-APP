import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/core_providers.dart';
import '../core/services/course_enroll_service.dart';
import '../core/theme/app_theme.dart';
import '../core/util/classroom_join_flow.dart';
import '../core/util/markdown_link_handler.dart';
import '../core/widgets/code_input_field.dart';
import '../data/repositories/course_repository.dart';
import '../models/course_model.dart' as models;
import '../widgets/detail_shell.dart';
import '../widgets/widgets.dart';
import 'course_detail_page.dart';
import '../core/strings/app_strings.dart';
import '../core/layout/breakpoints.dart';
import '../core/util/shell_route.dart';

/// Returns the search box text as a course code when it looks like one — a
/// course code is exactly 6 alphanumerics (uppercased, same rule as
/// [UpperCaseAlphanumericFormatter]), so separators and spaces are stripped
/// first. Returns null for anything else, so the code dialog opens empty.
/// Used to prefill the code entry from the catalogue search (BR-P84ZAA).
String? courseCodeFromQuery(String query) {
  final code = query.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  return code.length == 6 ? code : null;
}

/// KnihovnaPage - Library page showing all available courses.
/// Users can download courses from here to add them to their Kurzy (courses) list.
class KnihovnaPage extends ConsumerStatefulWidget {
  /// Called when back button is tapped and there's no route to pop.
  /// Used when KnihovnaPage is embedded as a tab to navigate home.
  final VoidCallback? onBack;

  const KnihovnaPage({super.key, this.onBack});

  @override
  ConsumerState<KnihovnaPage> createState() => _KnihovnaPageState();
}

class _KnihovnaPageState extends ConsumerState<KnihovnaPage> {
  final Set<String> _downloadingCourses = {};
  final Set<String> _updatingCourses = {};
  /// Maps course ID to downloaded version for comparison.
  final Map<String, int> _downloadedVersions = {};
  final Map<String, ({int completed, int total})> _courseProgress = {};

  // 6-char course code input — single field rendered as boxes
  final CodeInputController _codeController = CodeInputController();
  bool _isLookingUpCode = false;
  String? _codeError;

  /// Repaint hook for the code dialog. It lives on its own route, so this
  /// page's `setState` does not reach it.
  void Function(VoidCallback)? _dialogSetState;

  /// Free-text catalogue search. Wide layouts only — on a phone a text field
  /// would eat a third of the screen, same reasoning as Kurzy.
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

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
  void initState() {
    super.initState();
    _loadDownloadedCourses();
    // Auto-refresh courses from API so the list isn't empty on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCourses();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _pin => _codeController.code;

  void _onCodeChanged(String value) {
    // Only clear the error while the user is actively typing. A programmatic
    // clear after an invalid submit empties the field and fires onChanged('')
    // synchronously — it must NOT wipe the just-set error, or the code silently
    // disappears with no feedback (BR-ANKRJP).
    if (value.isEmpty) return;
    if (_codeError != null) {
      setState(() => _codeError = null);
    }
  }

  void _clearPin() => _codeController.clear();

  /// Apply a state change to this page and, when open, to the code dialog.
  void _setCodeState(VoidCallback fn) {
    setState(fn);
    _dialogSetState?.call(() {});
  }

  /// Lookup and download course by code, then navigate to it.
  ///
  /// Delegates the resolve+enroll+download steps to the shared
  /// [enrollCourseByCode] service so the manual code input and the /course|/pin
  /// deep links behave identically; this method only maps the outcome to the
  /// input's error text and navigates on success.
  Future<void> _lookupCourseByCode() async {
    final code = _pin;
    if (code.length < 6) {
      _setCodeState(() => _codeError = AppStrings.libraryCodeShort);
      return;
    }

    _setCodeState(() {
      _isLookingUpCode = true;
      _codeError = null;
    });

    final outcome = await enrollCourseByCode(ref, code);
    if (!mounted) return;

    // Not a course PIN — maybe a student code. The same six-character box
    // is where a logged-in student pastes the code their teacher handed out
    // to join a class (BR-3V2P22); the flow asks "Chceš se připojit ke
    // třídě X?" itself and stays silent when the code is no class either,
    // so the plain "course not found" wording below still applies then.
    if (outcome.error == EnrollErrorKind.notFound) {
      final join = await tryJoinClassroomByCode(context, ref, code);
      if (!mounted) return;

      switch (join.outcome) {
        case ClassroomJoinOutcome.joined:
          _clearPin();
          _setCodeState(() => _isLookingUpCode = false);
          if (_dialogSetState != null) Navigator.of(context).pop();
          return;
        case ClassroomJoinOutcome.declined:
          _setCodeState(() => _isLookingUpCode = false);
          return;
        case ClassroomJoinOutcome.failed:
        case ClassroomJoinOutcome.offline:
          _setCodeState(() {
            _isLookingUpCode = false;
            _codeError = join.message ?? enrollErrorText(outcome);
          });
          _clearPin();
          return;
        case ClassroomJoinOutcome.notAClass:
        case ClassroomJoinOutcome.ineligible:
          break; // fall through to the course wording
      }
    }

    if (!outcome.isSuccess) {
      _setCodeState(() {
        _isLookingUpCode = false;
        // A guest hitting a logged_only course gets the dialog below instead —
        // an inline "you must log in" is a dead end with no way to act on it.
        _codeError =
            outcome.error == EnrollErrorKind.loginRequiredForCourse
                ? null
                : enrollErrorText(outcome);
      });
      _clearPin();
      if (outcome.error == EnrollErrorKind.loginRequiredForCourse) {
        await showLoginRequiredForCourseDialog(context, ref);
      }
      return;
    }

    _clearPin();
    _setCodeState(() {
      _isLookingUpCode = false;
      _downloadedVersions[outcome.course!.id] =
          outcome.downloadedVersion ?? _downloadedVersions[outcome.course!.id] ?? 0;
    });

    // Close the code dialog first, otherwise the course opens behind it.
    if (_dialogSetState != null) Navigator.of(context).pop();

    if (!mounted) return;
    Navigator.of(context).push(
      shellPageRoute(
        context,
        builder: (_) => CourseDetailPage(
          course: outcome.course!,
          userCourseId: outcome.userCourseId,
        ),
      ),
    );
  }

  Future<void> _refreshCourses() async {
    final repository = ref.read(courseRepositoryProvider);
    await repository.refreshCourses();
  }

  Future<void> _loadDownloadedCourses() async {
    final db = ref.read(appDatabaseProvider);
    final user = await db.getActiveUser();
    if (user == null) return;

    final userCourses = await db.getUserCourses(user.id);
    setState(() {
      _downloadedVersions.clear();
      _courseProgress.clear();
      for (final uc in userCourses) {
        _downloadedVersions[uc.courseId] = uc.downloadedVersion;
        _courseProgress[uc.courseId] = (
          completed: uc.completedLessons,
          total: uc.totalLessons,
        );
      }
    });
  }

  Future<void> _downloadCourse(Course course) async {
    final db = ref.read(appDatabaseProvider);
    final userCourseRepo = ref.read(userCourseRepositoryProvider);
    final courseRepo = ref.read(courseRepositoryProvider);
    final user = await db.getActiveUser();

    if (user == null) {
      // No active user means the session was wiped (e.g. shared-device
      // inactivity logout). Return to login cleanly instead of stranding the
      // user on a library page that can never download.
      ref.read(logoutCoordinatorProvider).forceLogoutToLogin();
      return;
    }

    // Block guests from logged_only courses.
    // Allow only real accounts: a user with an email OR a server-authenticated
    // student PIN login (flagged locally via isEmailValidated). Guests hold a
    // Sanctum token too, so token presence must NOT count as logged in
    // (BR-N2ENN4).
    if (course.data['logged_only'] == true &&
        user.email.isEmpty &&
        !user.isEmailValidated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.authLoginRequired),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _downloadingCourses.add(course.id);
    });

    try {
      // Step 1: Add course to user's library
      await userCourseRepo.startCourse(
        userId: user.id,
        courseId: course.id,
      );

      // Step 2: Download full course JSON from R2 (with lesson details)
      final success = await courseRepo.downloadFullCourseJson(course.id);

      if (!success) {
        if (mounted) {
          setState(() {
            _downloadingCourses.remove(course.id);
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.libraryCourseDownloadFailed(course.name)),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Step 3: Update downloadedVersion in user_courses to mark it as
      // fully downloaded and trigger the Kurzy stream to refresh.
      // Read version from DB — downloadFullCourseJson may have bumped it.
      final courseRow = await db.getCourseById(course.id);
      final actualVersion = courseRow?.version ?? course.version;
      final userCourse = await db.getUserCourseByUserAndCourse(user.id, course.id);
      if (userCourse != null) {
        await db.updateUserCourseDownloadedVersion(
          id: userCourse.id,
          downloadedVersion: actualVersion,
        );
      }

      // Sync now that content is local — seeds default_practice cards and
      // pushes them so the practice set is complete right after download.
      ref.read(syncServiceProvider).sync();

      if (mounted) {
        setState(() {
          _downloadedVersions[course.id] = actualVersion;
          _downloadingCourses.remove(course.id);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.libraryCourseAdded(course.name)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingCourses.remove(course.id);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.libraryCourseDownloadError('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateCourse(Course course) async {
    final db = ref.read(appDatabaseProvider);
    final userCourseRepo = ref.read(userCourseRepositoryProvider);
    final courseRepo = ref.read(courseRepositoryProvider);
    final user = await db.getActiveUser();

    if (user == null) return;

    setState(() {
      _updatingCourses.add(course.id);
    });

    try {
      // Get the user course entry
      final userCourse = await db.getUserCourseByUserAndCourse(user.id, course.id);
      if (userCourse == null) return;

      // Re-download full course JSON from R2 (with new lesson details)
      await courseRepo.downloadFullCourseJson(course.id);

      // Read version from DB — downloadFullCourseJson may have bumped it.
      final courseRow = await db.getCourseById(course.id);
      final actualVersion = courseRow?.version ?? course.version;

      // Update the downloaded version in user_courses
      await db.updateUserCourseDownloadedVersion(
        id: userCourse.id,
        downloadedVersion: actualVersion,
      );

      // Sync so any newly flagged default_practice blocks in the updated
      // content get seeded into the practice set and pushed right away.
      ref.read(syncServiceProvider).sync();

      if (mounted) {
        setState(() {
          _downloadedVersions[course.id] = actualVersion;
          _updatingCourses.remove(course.id);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.libraryCourseUpdated(course.name)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updatingCourses.remove(course.id);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.libraryCourseUpdateError('$e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openCourse(Course course) async {
    final courseRepo = ref.read(courseRepositoryProvider);
    final db = ref.read(appDatabaseProvider);
    final user = await db.getActiveUser();

    // Check for a newer version on the API before opening (non-blocking on failure)
    await courseRepo.checkAndUpdateCourseVersion(course.id);
    if (!mounted) return;

    final fullCourse = await courseRepo.getCourseById(course.id);
    if (fullCourse == null || !mounted) return;

    // Block guests from logged_only courses.
    // Allow only real accounts: a user with an email OR a server-authenticated
    // student PIN login (flagged locally via isEmailValidated). Guests hold a
    // Sanctum token too, so token presence must NOT count as logged in
    // (BR-N2ENN4).
    if (fullCourse.data['logged_only'] == true) {
      final activeUser = user ?? await db.getActiveUser();
      if (activeUser == null ||
          (activeUser.email.isEmpty && !activeUser.isEmailValidated)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.authLoginRequired),
            ),
          );
        }
        return;
      }
    }

    final userCourse = user != null
        ? await db.getUserCourseByUserAndCourse(user.id, course.id)
        : null;

    final courseModel = models.Course.fromJsonData(
      id: fullCourse.id,
      data: fullCourse.data,
      completedLessons: userCourse?.completedLessons ?? 0,
      isCompleted: userCourse?.status == 'completed',
    );

    await Navigator.of(context).push(
      shellPageRoute(
      context,
        builder: (_) => CourseDetailPage(
          course: courseModel,
          userCourseId: userCourse?.id,
        ),
      ),
    );
    // Refresh downloaded versions when returning (progress may have changed)
    if (mounted) {
      _loadDownloadedCourses();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The library is both a main tab and a pushed route (promo card, empty
    // Kurzy state, profile). Only the pushed copy may draw the sidebar — as a
    // tab it already sits inside `AdaptiveShell` and would double it up.
    //
    // Asks this widget's own route, not `Navigator.canPop()`: that one flips
    // to true as soon as *anything* is pushed — including this page's own code
    // dialog — and the page would then wrap itself in a second sidebar.
    final isPushed = !(ModalRoute.of(context)?.isFirst ?? true);
    if (isPushed && context.widthClass != WidthClass.compact) {
      return DetailShell(
        backLabel: AppStrings.libraryTitle,
        child: _buildPage(context, isPushed: true),
      );
    }
    return _buildPage(context, isPushed: isPushed);
  }

  Widget _buildPage(BuildContext context, {required bool isPushed}) {
    final coursesAsync = ref.watch(coursesStreamProvider);
    final isMobile = context.widthClass == WidthClass.compact;
    final pad = isMobile ? 16.0 : 32.0;
    // On desktop the heading already lives in the shell chrome: the top bar
    // for the tab, the back link for the pushed copy.
    final showHeading = !(context.isExpanded && !isPushed);

    return Scaffold(
      backgroundColor: AppColors.background,
      // MainScreen's outer Scaffold already resizes for the keyboard.
      // Letting this inner Scaffold resize too double-counts the keyboard
      // inset, squeezing the code-input card off-screen.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            if (showHeading) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Row(
                  children: [
                    // The pushed copy on a wide viewport gets its back link
                    // from DetailShell's top bar instead.
                    if (isMobile || !isPushed) ...[
                      GestureDetector(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else if (widget.onBack != null) {
                            widget.onBack!();
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: AppDecorations.circleButton,
                          child: Icon(
                            Icons.arrow_back,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppStrings.libraryTitle,
                            style: AppTextStyles.heading2Bold(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.librarySubtitle,
                            style: AppTextStyles.body(
                                color: AppColors.primaryDark64),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!isMobile) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Row(
                  children: [
                    SizedBox(width: 320, child: _buildSearchField()),
                    const SizedBox(width: 12),
                    _buildCodeButton(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: coursesAsync.when(
                data: (courses) {
                  // Only show published courses (hide private courses — they are PIN-only)
                  final publishedCourses = courses
                      .where((c) => c.status == 'published')
                      .where((c) => c.data['private'] != true)
                      .where(_matchesQuery)
                      .toList();

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _refreshCourses,
                    child: isMobile
                        ? _buildList(publishedCourses)
                        : _buildWideBody(publishedCourses, pad),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.libraryCoursesLoadError,
                          style: AppTextStyles.cardTitleSmall(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesQuery(Course course) {
    if (_query.isEmpty) return true;
    final description =
        ((course.data['description'] as String?) ?? '').toLowerCase();
    return course.name.toLowerCase().contains(_query) ||
        description.contains(_query);
  }

  /// Phone layout, unchanged: code entry on top, then a single column of
  /// list-style cards.
  Widget _buildList(List<Course> courses) {
    if (courses.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCodeButton(),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: _query.isEmpty ? _buildEmptyState() : _buildNoMatchState(),
            ),
          ],
        ),
      );
    }

    // +1 for the code input section at the top
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: courses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildCodeButton(),
          );
        }
        final course = courses[index - 1];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < courses.length ? 12 : 0,
          ),
          child: _buildCourseCard(course),
        );
      },
    );
  }

  /// Tablet/desktop: the catalogue as a grid across the full content width.
  /// Code entry lives in the controls row as a button, not a rail card.
  Widget _buildWideBody(List<Course> courses, double pad) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = courses.isEmpty
            ? SizedBox(
                height: 320,
                child:
                    _query.isEmpty ? _buildEmptyState() : _buildNoMatchState(),
              )
            : _buildGrid(courses, constraints.maxWidth - pad * 2);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
          children: [grid],
        );
      },
    );
  }

  Widget _buildGrid(List<Course> courses, double availableWidth) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridColumns(availableWidth),
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        // Header + title (2 lines) + blurb (2 lines) + meta + action, without
        // the body overflowing at the narrowest column.
        mainAxisExtent: 340,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) =>
          _buildGridCard(courses[index], index),
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
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
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
              }),
              child:
                  Icon(Icons.close, size: 18, color: AppColors.primaryDark48),
            ),
        ],
      ),
    );
  }

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

  /// Opens the code entry. A permanently visible six-box field was a lot of
  /// chrome for something most visits never use — and on the wide layout it
  /// took a whole rail beside the catalogue.
  Widget _buildCodeButton() {
    return GestureDetector(
      onTap: _openCodeDialog,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppDecorations.radiusM,
          boxShadow: AppDecorations.shadowMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.surface),
            const SizedBox(width: 8),
            Text(
              AppStrings.libraryCodeButton,
              style: AppTextStyles.actionSmall(color: AppColors.surface),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCodeDialog() async {
    // Prefill the code field from the search box when it already holds
    // something that looks like a course code. Saves retyping when the user
    // typed the code into search first (BR-P84ZAA); otherwise open empty.
    final candidate = courseCodeFromQuery(_searchController.text);
    if (candidate != null) {
      _codeController.code = candidate;
    } else {
      _clearPin();
    }
    setState(() => _codeError = null);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // The lookup runs against page state; this lets it repaint the
          // dialog too, which is a separate route and would otherwise keep
          // showing a stale error/spinner.
          _dialogSetState = setDialogState;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.radiusL,
            ),
            title: Text(
              AppStrings.libraryCodeTitle,
              style: AppTextStyles.heading4(),
            ),
            // Fixed width: the boxes are Expanded inside a Row, so without a
            // bounded width they collapse to squares too small to read.
            content: SizedBox(
              width: 360,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.libraryCodeShort,
                  style: AppTextStyles.bodySmall(
                      color: AppColors.primaryDark64),
                ),
                const SizedBox(height: 12),
                // 6-char course code input — single field rendered as boxes
                CodeInputField(
                  length: 6,
                  controller: _codeController,
                  autofocus: true,
                  hasError: _codeError != null,
                  onChanged: _onCodeChanged,
                  onCompleted: (_) {
                    if (!_isLookingUpCode) _lookupCourseByCode();
                  },
                ),
                if (_codeError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _codeError!,
                    style: AppTextStyles.caption(color: AppColors.error),
                  ),
                ],
                if (_isLookingUpCode) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.librarySearchingCourse,
                        style: AppTextStyles.bodySmall(color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(AppStrings.actionCancel),
              ),
              FilledButton(
                onPressed:
                    _isLookingUpCode ? null : () => _lookupCourseByCode(),
                child: Text(AppStrings.libraryCodeButton),
              ),
            ],
          );
        },
      ),
    );

    _dialogSetState = null;
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
              AppStrings.libraryEmptyTitle,
              style: AppTextStyles.heading4(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.libraryEmptySubtitle,
              style: AppTextStyles.body(color: AppColors.primaryDark64),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Grid tile for the wide catalogue. Same data as [_buildCourseCard], laid
  /// out vertically so it survives a ~300px column.
  Widget _buildGridCard(Course course, int position) {
    final downloadedVersion = _downloadedVersions[course.id];
    // downloadedVersion == 0 means synced from server but not locally downloaded
    final isDownloaded = downloadedVersion != null && downloadedVersion > 0;
    final hasUpdate = isDownloaded && course.version > downloadedVersion;

    final data = course.data;
    final lessons = data['lessons'] as List<dynamic>?;
    final lessonCount = (lessons?.isNotEmpty ?? false)
        ? lessons!.length
        : (data['lesson_count'] as int? ?? 0);
    final hasFullContent =
        (data['blocks'] as List<dynamic>?)?.isNotEmpty ?? false;
    final totalMinutes = hasFullContent
        ? models.Course.totalCourseMinutes(data)
        : (data['estimated_minutes'] as int? ?? 0);

    final colors = _headerColors;

    return CourseGridCard(
      emoji: data['emoji'] as String? ?? '📖',
      coverImageUrl: CourseCoverImage.urlFrom(data),
      headerColor: colors[position % colors.length],
      title: course.name,
      description: data['description'] as String?,
      meta: '${AppStrings.lessonsCount(lessonCount)} · '
          '${AppStrings.durationSmart(totalMinutes)} · v${course.version}',
      pills: [
        if (data['badge'] is String)
          CourseCardPill(
            label: data['badge'] as String,
            color: AppColors.primaryDark,
          ),
        if (hasUpdate)
          CourseCardPill(
            label: AppStrings.courseCardUpdate,
            color: AppColors.primary,
          ),
        if (data['logged_only'] == true)
          CourseCardPill(
            label: AppStrings.libraryLoginBadge,
            color: Colors.blue.shade600,
            icon: Icons.lock_outline,
          ),
      ],
      footer: _buildActionButton(
        course,
        isDownloaded: isDownloaded,
        hasUpdate: hasUpdate,
        isDownloading: _downloadingCourses.contains(course.id),
        isUpdating: _updatingCourses.contains(course.id),
        fullWidth: true,
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    final downloadedVersion = _downloadedVersions[course.id];
    // downloadedVersion == 0 means synced from server but not locally downloaded
    final isDownloaded = downloadedVersion != null && downloadedVersion > 0;
    final hasUpdate = isDownloaded && course.version > downloadedVersion;
    final isDownloading = _downloadingCourses.contains(course.id);
    final isUpdating = _updatingCourses.contains(course.id);

    // Debug: print course info

    // Extract data from course
    final data = course.data;
    final emoji = data['emoji'] as String? ?? '📖';
    final description = data['description'] as String?;
    final badge = data['badge'] as String?;
    final lessons = data['lessons'] as List<dynamic>?;
    // Fall back to the denormalized lesson_count from the listing API when the
    // full lessons array hasn't been downloaded yet.
    final lessonCount = (lessons?.isNotEmpty ?? false)
        ? lessons!.length
        : (data['lesson_count'] as int? ?? 0);
    // Full course JSON carries a top-level `blocks` array; the lightweight
    // listing data (not-yet-downloaded courses) only has placeholder lessons.
    final hasFullContent = (data['blocks'] as List<dynamic>?)?.isNotEmpty ?? false;
    // For downloaded courses, sum block durations (matches the course detail
    // page) so library and in-course duration agree. Otherwise fall back to the
    // listing's estimated_minutes — the placeholder lessons have no blocks and
    // would otherwise yield a bogus ~5 min/lesson estimate.
    final totalMinutes = hasFullContent
        ? models.Course.totalCourseMinutes(data)
        : (data['estimated_minutes'] as int? ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusXL,
        boxShadow: AppDecorations.shadowLight,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Icon and badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.48),
                    shape: BoxShape.circle,
                  ),
                  child: CourseCoverImage(
                    url: CourseCoverImage.urlFrom(data),
                    fallback: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: AppDecorations.radiusXS,
                      border: Border.all(
                        color: AppColors.primaryDark,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: AppTextStyles.badgeSmall(),
                    ),
                  ),
                if (data['logged_only'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: AppDecorations.radiusXS,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 2),
                        Text(AppStrings.libraryLoginBadge, style: AppTextStyles.meta(color: Colors.blue.shade600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              course.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitleSmall(),
            ),
            // Description
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
              ),
            ],
            const SizedBox(height: 12),
            // Bottom row: Meta info and download button
            Row(
              children: [
                // Lesson count
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.primaryDark48,
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.lessonsCount(lessonCount),
                  style: AppTextStyles.meta(color: AppColors.primaryDark64),
                ),
                const SizedBox(width: 12),
                // Duration
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.primaryDark48,
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.durationSmart(totalMinutes),
                  style: AppTextStyles.meta(color: AppColors.primaryDark64),
                ),
                const SizedBox(width: 12),
                // Version
                Text(
                  'v${course.version}',
                  style: AppTextStyles.meta(color: AppColors.primaryDark48),
                ),
                const Spacer(),
                // Download/Update/Added button
                _buildActionButton(
                  course,
                  isDownloaded: isDownloaded,
                  hasUpdate: hasUpdate,
                  isDownloading: isDownloading,
                  isUpdating: isUpdating,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    Course course, {
    required bool isDownloaded,
    required bool hasUpdate,
    required bool isDownloading,
    required bool isUpdating,
    // Grid tiles give the action the full card width; list rows keep it a
    // chip sitting at the end of the meta row.
    bool fullWidth = false,
  }) {
    // Currently downloading or updating - show spinner
    if (isDownloading || isUpdating) {
      return Container(
        width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.16),
          borderRadius: AppDecorations.radiusS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isUpdating ? AppStrings.libraryUpdating : AppStrings.libraryDownloading,
              style: AppTextStyles.actionSmall(color: AppColors.primary),
            ),
          ],
        ),
      );
    }

    // Downloaded but update available - show update button
    if (isDownloaded && hasUpdate) {
      return GestureDetector(
        onTap: () => _updateCourse(course),
        child: Container(
          width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning,
            borderRadius: AppDecorations.radiusS,
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.32),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              const Icon(
                Icons.sync_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                AppStrings.libraryUpdate,
                style: AppTextStyles.actionSmall(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Downloaded and up-to-date - show launch button
    if (isDownloaded) {
      return GestureDetector(
        onTap: () => _openCourse(course),
        child: Container(
          width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: AppDecorations.radiusS,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                AppStrings.libraryLaunch,
                style: AppTextStyles.actionSmall(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Not downloaded - show download button
    return GestureDetector(
      onTap: () => _downloadCourse(course),
      child: Container(
        width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppDecorations.radiusS,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const Icon(
              Icons.download_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              AppStrings.libraryDownload,
              style: AppTextStyles.actionSmall(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
