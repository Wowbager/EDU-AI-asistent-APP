// Regression test for BR-V72RWM: "Kurz se nepodařilo načíst" on the intro
// course right after onboarding.
//
// Cause: a fresh account gets a metadata-only catalog row for the onboarding
// course (`data = '{}'`, seeded by the sync engine's _mergeServerCourse). The
// Přehled guide card opens that course straight from local data and, when the
// server's onboarding version is higher than the bundled asset, the bundled
// full content was never applied — the row stayed empty and CourseDetailPage
// rendered its "corrupted course" screen (0 lekcí).
//
// Fix: _importBundledCourse restores bundled content whenever the existing row
// has no lessons, regardless of version — an empty row is worse than slightly
// stale content. The higher server version is preserved so a later R2 download
// still fetches the authoritative newer content.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/data/datasources/local/course_local_datasource.dart';
import 'package:eduai/data/datasources/remote/course_remote_datasource.dart';
import 'package:eduai/data/repositories/course_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CourseRepository repo;

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
  });

  tearDown(() => db.close());

  Future<void> insertOnboarding({
    required String data,
    required int version,
  }) {
    return db.into(db.coursesTable).insert(CoursesTableCompanion(
          id: const Value('onboarding-local'),
          courseId: const Value('EDU_ONBOARDING_APP'),
          name: const Value('Co umí EDU AI asistent'),
          serverId: const Value(500),
          version: Value(version),
          data: Value(data),
        ));
  }

  test('restores bundled content over an empty higher-version catalog row',
      () async {
    // The exact corrupt state a fresh account lands in: metadata-only row whose
    // version (from the server catalog) is higher than the bundled asset (v8).
    await insertOnboarding(data: '{}', version: 99);

    await repo.ensureBundledCoursesLoaded();

    final row = await db.getCourseByFieldCourseId('EDU_ONBOARDING_APP');
    expect(row, isNotNull);
    final data = jsonDecode(row!.data) as Map<String, dynamic>;
    final lessons = data['lessons'] as List<dynamic>?;

    expect(lessons, isNotNull, reason: 'empty row must be repaired');
    expect(lessons, isNotEmpty);
    expect((lessons!.first as Map<String, dynamic>)['name'], 'Úvod');
    expect(row.version, 99,
        reason: 'keep the higher server version so a later R2 download still '
            'fetches the authoritative newer content');
  });

  test('does not overwrite a populated higher-version row with stale bundled',
      () async {
    // A row that already has real (newer) content must be preserved — bundled
    // (v8) must not clobber a v99 API download.
    final newer = jsonEncode({
      'blocks': [
        {'block_id': 'b1', 'block_type': 'text', 'content': 'x'}
      ],
      'lessons': [
        {
          'lesson_id': 'l1',
          'name': 'NEWER CONTENT',
          'blocks': [
            {'block_id': 'b1', 'order': 1}
          ],
        }
      ],
    });
    await insertOnboarding(data: newer, version: 99);

    await repo.ensureBundledCoursesLoaded();

    final row = await db.getCourseByFieldCourseId('EDU_ONBOARDING_APP');
    final data = jsonDecode(row!.data) as Map<String, dynamic>;
    final lessons = data['lessons'] as List<dynamic>;

    expect((lessons.first as Map<String, dynamic>)['name'], 'NEWER CONTENT',
        reason: 'populated higher-version content must not be downgraded');
    expect(row.version, 99);
  });
}
