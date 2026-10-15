// BR-6CEUUB — right after install, "Začněte s návodem" opened the intro course
// bundled with the build (v8) although the device was online and the library
// had a newer one; the update only appeared later as a banner locking the
// lessons. Tapping the guide now fetches the newer version first and records
// it on the enrollment, so the course opens current and unlocked.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/practice_providers.dart';
import 'package:eduai/core/services/practice_filter_store.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/core/sync/sync_status.dart';
import 'package:eduai/data/datasources/local/course_local_datasource.dart';
import 'package:eduai/data/datasources/remote/course_remote_datasource.dart';
import 'package:eduai/data/repositories/course_repository.dart';
import 'package:eduai/data/repositories/user_course_repository.dart';
import 'package:eduai/pages/prehled_page.dart';
import 'package:eduai/pages/quiz_page.dart' show QuizProgress;

const _serverId = 17;

class _OnlineConn implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The library holds v18 of the onboarding course.
class _ServerAtV18 implements CourseRemoteDataSource {
  RemoteCourse get _course => RemoteCourse(
        id: _serverId,
        courseId: 'EDU_ONBOARDING_APP',
        name: 'Co umí EDU AI asistent',
        version: 18,
        status: 'published',
        language: 'cs',
        data: const {},
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 9, 24),
      );

  @override
  Future<ApiResult<RemoteCourse>> getCourse(int id) async =>
      ApiResult.success(_course);

  @override
  Future<ApiResult<List<RemoteCourse>>> getAllCourses() async =>
      ApiResult.success([_course]);

  @override
  Future<ApiResult<Map<String, dynamic>>> downloadCourseJson(
          int serverId) async =>
      ApiResult.success({
        'course_id': 'EDU_ONBOARDING_APP',
        'version': 18,
        'name': 'Co umí EDU AI asistent',
        'blocks': [
          {'block_id': 'b1', 'block_type': 'text', 'content': 'x'}
        ],
        'lessons': [
          {
            'lesson_id': 'L01',
            'name': 'Server v18',
            'blocks': [
              {'block_id': 'b1', 'order': 1}
            ],
          }
        ],
      });

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The dashboard pulls Google Fonts over the network. Once the test waits in
/// real time those requests fail and fail the test, so they are never answered.
class _SilentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _SilentHttpClient();
}

class _SilentHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Records the pages the dashboard opens. The test never pumps a frame after
/// the tap, so the pushed CourseDetailPage is never built — it pulls fonts and
/// timers this test is not about.
class _PushRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

/// Same suppression the other dashboard tests use: the test-only Ahem font is
/// far wider than the real one, so labels overflow their rows.
void _ignoreOverflow() {
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

void main() {
  testWidgets('the guide opens the library version, not the bundled one',
      (tester) async {
    _ignoreOverflow();
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _SilentHttpOverrides();
    addTearDown(() => HttpOverrides.global = previousHttpOverrides);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final courseRepo = CourseRepository(
      localDataSource: CourseLocalDataSource(db),
      remoteDataSource: _ServerAtV18(),
      connectivity: _OnlineConn(),
      syncQueue: SyncQueue(db),
    );

    // First launch: MainScreen seeds the bundled v8 and enrolls the learner.
    late String courseId;
    await tester.runAsync(() async {
      await courseRepo.ensureBundledCoursesLoaded();
      courseId = (await db.getCourseByFieldCourseId('EDU_ONBOARDING_APP'))!.id;
      await db.into(db.userCoursesTable).insert(UserCoursesTableCompanion(
            id: const Value('uc-onboarding'),
            userId: const Value('u1'),
            courseId: Value(courseId),
            downloadedVersion: const Value(8),
          ));
    });
    final enrollment = UserCourse(
      id: 'uc-onboarding',
      userId: 'u1',
      courseId: courseId,
      status: UserCourseStatus.downloaded,
      progressPercent: 0,
      completedLessons: 0,
      totalLessons: 1,
      currentLessonIndex: 0,
      timeSpentSeconds: 0,
      progressData: const {},
      downloadedVersion: 8,
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.utc(2026, 9, 29),
      updatedAt: DateTime.utc(2026, 9, 29),
    );

    final recorder = _PushRecorder();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 2000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          courseRepositoryProvider.overrideWithValue(courseRepo),
          activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
          userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
          userCoursesStreamProvider
              .overrideWith((ref) => Stream.value([enrollment])),
          dueCardsCountProvider.overrideWith((ref) async => 0),
          practiceFilterProvider
              .overrideWith((ref) => PracticeFilterNotifier(PracticeFilterStore(
                    prefs,
                  ))),
        ],
        child: MaterialApp(
          navigatorObservers: [recorder],
          home: const Scaffold(
            body: PrehledPage(quizProgressCache: <String, QuizProgress>{}),
          ),
        ),
      ),
    );
    await tester.pump();
    final pushesBefore = recorder.pushed.length;

    await tester.tap(find.text(AppStrings.guideButton));
    // The open path awaits real database and (faked) network futures.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));

    late CoursesTableData row;
    late UserCoursesTableData uc;
    await tester.runAsync(() async {
      row = (await db.getCourseById(courseId))!;
      uc = (await db.getUserCourseById('uc-onboarding'))!;
    });

    final lessons = (jsonDecode(row.data) as Map<String, dynamic>)['lessons']
        as List<dynamic>;
    expect((lessons.first as Map<String, dynamic>)['name'], 'Server v18',
        reason: 'the newer library version is fetched before opening');
    expect(row.version, 18);
    expect(uc.downloadedVersion, 18,
        reason: 'no update banner right after opening the latest version');

    expect(recorder.pushed.length, pushesBefore + 1,
        reason: 'the course is opened once its content is current');

    // Unmount here so drift's zero-delay stream-close timers run inside the
    // test instead of tripping the pending-timer check after it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
