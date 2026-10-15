// Regression test for BR-SNUYF7: after logout (`clearAllData` wipes the local
// catalog) and re-login, private courses the user is enrolled in vanished from
// the list. Root cause: SyncService._pullUserCourseUpdates dropped any
// enrollment whose local `courses` row was missing (`continue`), and private
// courses are hidden from the student `/courses` catalog, so their row was
// never created. The fix materializes the course from the embedded `course`
// payload that `/user/courses` always returns.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/sync/sync_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ApiClient apiClient;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = ApiClient(AuthTokenStorage(prefs: prefs));
  });

  tearDown(() => db.close());

  /// Builds a `/user/courses` payload for one enrollment whose local catalog
  /// row does NOT exist yet (the private-course scenario).
  Map<String, dynamic> userCoursesPayload() => {
        'user_courses': [
          {
            'id': 501,
            'server_id': 42,
            'course_id': 'PRIV_MAT_9',
            'status': 'in_progress',
            'progress_percent': 30,
            'completed_lessons': 3,
            'total_lessons': 10,
            'current_lesson_index': 2,
            'time_spent_seconds': 600,
            'progress_data': {'foo': 'bar'},
            'course': {
              'id': 42,
              'course_id': 'PRIV_MAT_9',
              'name': 'Privátní Matematika 9',
              'version': 2,
              'status': 'private',
              'language': 'cs',
              'data': {'lessons': []},
            },
          },
        ],
        'meta': {'total': 1},
      };

  test(
      'private enrolled course with no local catalog row is materialized, not dropped',
      () async {
    apiClient.dio.httpClientAdapter = _CannedAdapter(userCoursesPayload());

    final userId = await db.createGuestUser();

    final sync = SyncService(
      db: db,
      apiClient: apiClient,
      connectivity: ConnectivityService(),
    );

    // Pre-condition: nothing local yet.
    expect(await db.getCourseByServerId(42), isNull);
    expect(await db.getUserCourses(userId), isEmpty);

    await sync.debugPullUserCourseUpdates();

    // The catalog row was created from the embedded payload…
    final course = await db.getCourseByServerId(42);
    expect(course, isNotNull);
    expect(course!.courseId, 'PRIV_MAT_9');
    expect(course.name, 'Privátní Matematika 9');
    expect(course.status, 'private');

    // …and the enrollment now shows up in the user's course list with progress.
    final enrollments = await db.getUserCourses(userId);
    expect(enrollments, hasLength(1));
    expect(enrollments.single.serverId, 501);
    expect(enrollments.single.progressPercent, 30);
    expect(enrollments.single.courseId, course.id);
  });
}
