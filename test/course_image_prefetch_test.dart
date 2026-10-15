// BR-BX9AA4 — "ani v nově otevíraných": offline, even lessons never opened
// before had no pictures, although the course itself was downloaded. The
// course JSON only carries picture URLs; downloading a course now also keeps
// its pictures on the device.
//
//   flutter test test/course_image_prefetch_test.dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/media/lesson_image_cache.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/data/datasources/local/course_local_datasource.dart';
import 'package:eduai/data/datasources/remote/course_remote_datasource.dart';
import 'package:eduai/data/repositories/course_repository.dart';

import 'core/media/fake_lesson_image_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CourseRepository repo;
  late LessonImageCache previous;
  late FakeLessonImageBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(AuthTokenStorage(prefs: prefs));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CourseRepository(
      localDataSource: CourseLocalDataSource(db),
      remoteDataSource: CourseRemoteDataSource(api),
      connectivity: ConnectivityService(),
      syncQueue: SyncQueue(db),
    );

    previous = LessonImageCache.instance;
    backend = FakeLessonImageBackend();
    LessonImageCache.instance = LessonImageCache(backend: backend)
      ..setConnectivityForTesting(isOnline: () async => true);
  });

  tearDown(() async {
    LessonImageCache.instance = previous;
    await db.close();
  });

  test('downloading a course also downloads the pictures in its lessons',
      () async {
    // Catalog row without content; the bundled onboarding course fills it.
    await db.into(db.coursesTable).insert(const CoursesTableCompanion(
          id: Value('onboarding-local'),
          courseId: Value('EDU_ONBOARDING_APP'),
          name: Value('Co umí EDU AI asistent'),
          version: Value(1),
          data: Value('{}'),
        ));

    expect(await repo.downloadFullCourseJson('onboarding-local'), isTrue);
    await pumpEventQueue();

    // The onboarding course carries lesson pictures on edu-ai.eu and R2.
    expect(
      backend.fetched,
      contains(
        'https://pub-7a82ccbfca9a4f4aa1e25276ad59c86a.r2.dev/assets/EDU_ONBOARDING_APP/where-is-help.jpeg',
      ),
    );
    expect(backend.fetched, contains('https://edu-ai.eu/wp-content/uploads/2026/02/where-is-library.jpeg'));
  });
}
