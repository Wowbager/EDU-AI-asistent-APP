import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/data/repositories/gamification_config_repository.dart';
import 'package:eduai/models/gamification_config_model.dart';
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/lesson_detail_page.dart';
import 'package:eduai/widgets/progress_ring_card.dart';

// BR-CPX4N9 — the lesson page's "Tvůj postup" stayed at 0 % after a lesson.
//
// The lesson page counted finished lessons from the course it was opened
// with, wrote the completion to the DB and never looked at it again, then
// opened the next lesson with that same course. The rail read "0 z 4 lekcí"
// until the student went back to the course page, which re-reads progress.
//
// Three lessons rather than the reporter's four: past three the rail adds a
// "show all" row, which overflows under the test font.

const _userId = 'user-1';
const _userCourseId = 'uc-1';

/// Three lessons of one multiple-choice block each.
Map<String, dynamic> _courseData({bool openAll = false}) => {
      'course_id': 'C-RAIL',
      'name': 'Co umí EDU AI asistent',
      'language': 'cs',
      if (openAll) 'open_all_lessons': true,
      'lessons': [
        for (var i = 1; i <= 3; i++)
          {
            'lesson_id': 'L$i',
            'name': 'Lekce $i',
            'order': i,
            'blocks': [
              {'block_id': 'B$i', 'order': 1},
            ],
          },
      ],
      'blocks': [
        for (var i = 1; i <= 3; i++)
          {
            'block_id': 'B$i',
            'type': 'exercise',
            'steps': [
              {
                'id': 's1',
                'type': 'question',
                'order': 1,
                'question': {
                  'type': 'multiple_choice',
                  'question': 'Kolik je 2 + 2?',
                  'options': [
                    {'id': 'a', 'text': 'tri', 'is_correct': false},
                    {'id': 'b', 'text': 'ctyri', 'is_correct': true},
                  ],
                },
              },
            ],
          },
      ],
    };

List<LessonStatus> _statuses(Course course) =>
    course.lessons.map((l) => l.status).toList();

/// Completing a block kicks off a sync; the real one wants a signed-in client.
class _NoSync implements SyncService {
  @override
  Future<void> sync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Offline, so the trophy and streak writes queue up instead of calling the
/// API — which, with [_SilentHttpOverrides], would never answer and keep the
/// "next lesson" button waiting on the lesson's save forever.
class _Offline implements ConnectivityService {
  @override
  Future<bool> get isOnline async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No achievements to check. The real repository downloads the config when
/// none is cached, and that request would outlive the test.
class _NoGamificationConfig implements GamificationConfigRepository {
  @override
  Future<GamificationConfig?> getConfig() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// google_fonts fetches its fonts over HTTP. The test binding answers every
/// request with 400, and inside a real-async window that failure lands as a
/// test error; a request that never answers stays silent.
class _SilentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _NeverAnswering();
}

class _NeverAnswering implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Course.withLessonProgress', () {
    test('re-derives statuses the way the course page does', () {
      final course = Course.fromJsonData(id: 'local-1', data: _courseData());
      expect(_statuses(course), [
        LessonStatus.inProgress,
        LessonStatus.locked,
        LessonStatus.locked,
      ]);

      final after = course.withLessonProgress(
        lessonsProgress: {
          'L1': {'is_completed': true},
        },
        completedLessons: 1,
      );

      expect(_statuses(after), [
        LessonStatus.completed,
        LessonStatus.inProgress,
        LessonStatus.locked,
      ]);
      expect(after.completedLessons, 1);
    });

    test('a completed course has every lesson done', () {
      final course = Course.fromJsonData(id: 'local-1', data: _courseData());

      final after = course.withLessonProgress(
        lessonsProgress: {
          'L3': {'is_completed': true},
        },
        completedLessons: 3,
        isCompleted: true,
      );

      expect(_statuses(after), everyElement(LessonStatus.completed));
      expect(after.isCompleted, isTrue);
    });

    test('keeps free order on open_all_lessons courses', () {
      final course = Course.fromJsonData(
        id: 'local-1',
        data: _courseData(openAll: true),
      );

      final after = course.withLessonProgress(
        lessonsProgress: {
          'L2': {'is_completed': true},
        },
        completedLessons: 1,
      );

      expect(_statuses(after), [
        LessonStatus.inProgress,
        LessonStatus.completed,
        LessonStatus.inProgress,
      ]);
    });

    test('keeps everything but the statuses as the caller built it', () {
      final data = _courseData();
      // A caller-built course: local id and a cover the JSON does not carry.
      final course = Course(
        id: 'local-1',
        title: 'Co umí EDU AI asistent',
        subtitle: '',
        description: '',
        coverImageUrl: 'https://example.test/cover.png',
        iconEmoji: '🤖',
        iconBackgroundColor: Colors.white,
        badge: '',
        difficulty: 'ROOKIE',
        lessonCount: 3,
        durationHours: 1,
        completedLessons: 0,
        lessons: Course.fromJsonData(id: 'local-1', data: data).lessons,
        quizzes: const [],
        rawData: data,
      );

      final after = course.withLessonProgress(
        lessonsProgress: {
          'L1': {'is_completed': true},
        },
        completedLessons: 1,
      );

      expect(after.id, 'local-1', reason: 'not the course_id from the JSON');
      expect(after.coverImageUrl, 'https://example.test/cover.png');
      expect(after.iconEmoji, '🤖');
      expect(after.courseCode, 'C-RAIL');
      expect(after.getBlocksForLesson('L2').map((b) => b.blockId), ['B2']);
    });
  });

  group('lesson page rail', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      HttpOverrides.global = _SilentHttpOverrides();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.upsertUser(const UsersTableCompanion(
        id: Value(_userId),
        name: Value('Tester'),
        email: Value(''),
        isActive: Value(true),
      ));
      await db.upsertUserCourse(const UserCoursesTableCompanion(
        id: Value(_userCourseId),
        userId: Value(_userId),
        courseId: Value('local-1'),
        status: Value('in_progress'),
        totalLessons: Value(3),
      ));
    });

    // Not awaited: the page's drift watches close on zero-delay timers, and
    // once the container is disposed in teardown nothing pumps them any more,
    // so an awaited close never returns.
    tearDown(() {
      db.close();
    });

    Future<void> pumpFirstLesson(WidgetTester tester) async {
      // Wide enough for the rail beside the lesson column.
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // No token: XP writes stay local, nothing goes out.
        authTokenStorageProvider.overrideWithValue(
            AuthTokenStorage(prefs: prefs)),
        workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
        syncServiceProvider.overrideWithValue(_NoSync()),
        connectivityServiceProvider.overrideWithValue(_Offline()),
        gamificationConfigRepositoryProvider
            .overrideWithValue(_NoGamificationConfig()),
      ]);
      addTearDown(container.dispose);
      await tester.runAsync(() => container.read(activeUserProvider.future));

      final course = Course.fromJsonData(id: 'local-1', data: _courseData());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: LessonDetailPage(
              course: course,
              lesson: course.lessons.first,
              lessonIndex: 0,
              userCourseId: _userCourseId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> answerRight(WidgetTester tester) async {
      await tester.tap(find.text('ctyri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zkontrolovat'));
      await tester.pumpAndSettle();
      final continueButton = find.byIcon(Icons.check).last;
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
    }

    int lessonsDone(WidgetTester tester) =>
        tester.widget<ProgressRingCard>(find.byType(ProgressRingCard))
            .lessonsDone;

    testWidgets('counts the lesson just finished, here and in the next one',
        (tester) async {
      await pumpFirstLesson(tester);
      expect(lessonsDone(tester), 0);

      await answerRight(tester);
      expect(lessonsDone(tester), 1,
          reason: 'the lesson is done the moment its last block is');

      final next = find.text(AppStrings.lessonNextLesson);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();

      // Now on lesson 2, which is where the reporter looked.
      expect(find.text('${AppStrings.lessonFallbackName(2)}: Lekce 2'),
          findsOneWidget);
      expect(lessonsDone(tester), 1);
      expect(find.byIcon(Icons.check_circle), findsOneWidget,
          reason: 'lesson 1 is ticked off in the rail list');
    });
  });
}
