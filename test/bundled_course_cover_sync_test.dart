// Regression test for BR-NZ7JUN: in a child profile on a shared device the
// onboarding course ("Co umí EDU AI asistent") showed its emoji instead of the
// cover set in admin — on the Kurzy/Přehled cards and on the course page.
//
// Every logout wipes the local database, so each login starts from the bundled
// EDU_ONBOARDING_APP.json, which carries no cover. That row is created
// `pending` with `updatedAt = now`, so _mergeServerCourse never touches it (the
// server's `updated_at` is never after "now") and the metadata repair in
// _pullUserCourseUpdates skips pending rows. Only Knihovna's refreshCourses()
// ever brought the cover over, and a child who never opens Knihovna never got
// it. On the next start the bundled re-import overwrote the data again.
//
// Fix: _pullUserCourseUpdates carries `header_image` from the embedded course
// JSON regardless of the pending flag, and _importBundledCourse keeps a cover
// the server already delivered when it lays the bundled JSON back down.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/data/datasources/local/course_local_datasource.dart';
import 'package:eduai/data/datasources/remote/course_remote_datasource.dart';
import 'package:eduai/data/repositories/course_repository.dart';
import 'package:eduai/widgets/course_cover_image.dart';

/// Answers every request with a single canned JSON body, regardless of path.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _onboardingId = 'EDU_ONBOARDING_APP';
const _coverUrl =
    'https://pub-4e0c94219f454e70a63b7f41b436f85f.r2.dev/assets/EDU_ONBOARDING_APP/edu-intro.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ApiClient apiClient;
  late CourseRepository repo;
  late SyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = ApiClient(AuthTokenStorage(prefs: prefs));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CourseRepository(
      localDataSource: CourseLocalDataSource(db),
      remoteDataSource: CourseRemoteDataSource(apiClient),
      connectivity: ConnectivityService(),
      syncQueue: SyncQueue(db),
    );
    sync = SyncService(
      db: db,
      apiClient: apiClient,
      connectivity: ConnectivityService(),
    );
  });

  tearDown(() => db.close());

  /// `/user/courses` as the server answers it for an account enrolled in the
  /// onboarding course: the embedded `course.data` is the stored course JSON,
  /// cover included.
  Map<String, dynamic> userCoursesPayload() => {
        'user_courses': [
          {
            'id': 701,
            'server_id': 12,
            'course_id': _onboardingId,
            'status': 'downloaded',
            'progress_percent': 0,
            'completed_lessons': 0,
            'total_lessons': 4,
            'current_lesson_index': 0,
            'time_spent_seconds': 0,
            'progress_data': <String, dynamic>{},
            'course': {
              'id': 12,
              'course_id': _onboardingId,
              'name': 'Co umí EDU AI asistent',
              'version': 12,
              'status': 'published',
              'language': 'cs',
              'data': {
                'course_id': _onboardingId,
                'version': 12,
                'header_image': {'url': _coverUrl, 'alt': null},
                'lessons': [
                  {'lesson_id': 'L1', 'name': 'SERVER LESSON'},
                ],
              },
            },
          },
        ],
        'meta': {'total': 1},
      };

  Future<Map<String, dynamic>> onboardingData() async {
    final row = await db.getCourseByFieldCourseId(_onboardingId);
    expect(row, isNotNull);
    return jsonDecode(row!.data) as Map<String, dynamic>;
  }

  test('a fresh login picks up the onboarding cover from /user/courses',
      () async {
    // What every shared-device login starts from after the logout wipe.
    await repo.ensureBundledCoursesLoaded();
    expect(CourseCoverImage.urlFrom(await onboardingData()), isNull,
        reason: 'the bundled JSON carries no cover');

    await db.createGuestUser();
    apiClient.dio.httpClientAdapter = _CannedAdapter(userCoursesPayload());
    await sync.debugPullUserCourseUpdates();

    final data = await onboardingData();
    expect(CourseCoverImage.urlFrom(data), _coverUrl);
    // Only the cover is carried — the lessons stay the bundled ones until a
    // real download replaces them.
    final lessons = data['lessons'] as List<dynamic>;
    expect((lessons.first as Map<String, dynamic>)['name'], 'Úvod');
  });

  test('the next start keeps the cover when it re-imports the bundled course',
      () async {
    await repo.ensureBundledCoursesLoaded();
    await db.createGuestUser();
    apiClient.dio.httpClientAdapter = _CannedAdapter(userCoursesPayload());
    await sync.debugPullUserCourseUpdates();

    // Cold start: MainScreen seeds bundled courses again before any sync.
    await repo.ensureBundledCoursesLoaded();

    expect(CourseCoverImage.urlFrom(await onboardingData()), _coverUrl);
  });

  test('re-importing bundled content over an empty row keeps its listing cover',
      () async {
    // A metadata-only catalog row that Knihovna's listing already gave a
    // cover, at a server version above the bundled asset (v8).
    await db.into(db.coursesTable).insert(CoursesTableCompanion(
          id: const Value('onboarding-local'),
          courseId: const Value(_onboardingId),
          name: const Value('Co umí EDU AI asistent'),
          serverId: const Value(12),
          version: const Value(12),
          data: Value(jsonEncode({
            'header_image': {'url': _coverUrl, 'alt': null},
          })),
        ));

    await repo.ensureBundledCoursesLoaded();

    final data = await onboardingData();
    expect(data['lessons'], isNotEmpty, reason: 'bundled content restored');
    expect(CourseCoverImage.urlFrom(data), _coverUrl);
  });
}
