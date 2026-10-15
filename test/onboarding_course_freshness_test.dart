// Regression test for BR-6CEUUB: right after install the intro course opened
// from the bundled asset (v8) without asking the server whether the library
// had a newer version — prod serves v18. The update only turned up later, as
// the course-detail "update" banner once sync had bumped the row's version.
//
// Cause: the dashboard opens its courses straight from local data and only
// went to the network when the row had no lessons at all. A bundled row always
// has lessons, so a stale one was opened as-is. Worse, when sync ran before
// the bundle was seeded, the BR-V72RWM repair put the v8 lessons under the
// server's v18 version number, so nothing ever saw the content as stale.
//
// Fix: CourseRepository.refreshOutdatedContent compares the version of the
// content actually stored against the server's and downloads the newer one
// before the course is opened.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/data/datasources/local/course_local_datasource.dart';
import 'package:eduai/data/datasources/remote/course_remote_datasource.dart';
import 'package:eduai/data/repositories/course_repository.dart';

const _onboarding = 'EDU_ONBOARDING_APP';
const _serverId = 17;

class _Conn implements ConnectivityService {
  _Conn({required this.online});
  final bool online;

  @override
  Future<bool> get isOnline async => online;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The server's copy of the onboarding course, at [version].
class _FakeRemote implements CourseRemoteDataSource {
  _FakeRemote({required this.version, this.downloadFails = false});

  final int version;
  final bool downloadFails;
  int metadataCalls = 0;
  int downloadCalls = 0;

  RemoteCourse get _course => RemoteCourse(
        id: _serverId,
        courseId: _onboarding,
        name: 'Co umí EDU AI asistent',
        version: version,
        status: 'published',
        language: 'cs',
        data: const {},
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 9, 24),
      );

  @override
  Future<ApiResult<RemoteCourse>> getCourse(int id) async {
    metadataCalls++;
    return id == _serverId
        ? ApiResult.success(_course)
        : ApiResult.failure('not found', statusCode: 404);
  }

  @override
  Future<ApiResult<List<RemoteCourse>>> getAllCourses() async {
    metadataCalls++;
    return ApiResult.success([_course]);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> downloadCourseJson(
      int serverId) async {
    downloadCalls++;
    if (downloadFails) return ApiResult.failure('R2 unreachable');
    return ApiResult.success(_content(version, 'Server v$version'));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Course JSON as R2 serves it: the version travels inside the content.
Map<String, dynamic> _content(int version, String firstLessonName) => {
      'course_id': _onboarding,
      'version': version,
      'name': 'Co umí EDU AI asistent',
      'blocks': [
        {'block_id': 'b1', 'block_type': 'text', 'content': 'x'}
      ],
      'lessons': [
        {
          'lesson_id': 'L01',
          'name': firstLessonName,
          'blocks': [
            {'block_id': 'b1', 'order': 1}
          ],
        }
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeRemote remote;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  CourseRepository repoWith(_FakeRemote r, {bool online = true}) {
    remote = r;
    return CourseRepository(
      localDataSource: CourseLocalDataSource(db),
      remoteDataSource: r,
      connectivity: _Conn(online: online),
      syncQueue: SyncQueue(db),
    );
  }

  Future<CoursesTableData> onboardingRow() async =>
      (await db.getCourseByFieldCourseId(_onboarding))!;

  String firstLessonName(CoursesTableData row) {
    final data = jsonDecode(row.data) as Map<String, dynamic>;
    final lessons = data['lessons'] as List<dynamic>;
    return (lessons.first as Map<String, dynamic>)['name'] as String;
  }

  test('fresh install: bundled row the first sync has not linked yet is '
      'replaced by the newer server content', () async {
    final repo = repoWith(_FakeRemote(version: 18));
    // Exactly what MainScreen seeds on first launch: the bundled asset (v8),
    // no server id.
    await repo.ensureBundledCoursesLoaded();
    final seeded = await onboardingRow();
    expect(seeded.serverId, isNull);
    expect(seeded.version, 8);

    final refreshed = await repo.refreshOutdatedContent(seeded.id);

    expect(refreshed, isTrue);
    final row = await onboardingRow();
    expect(firstLessonName(row), 'Server v18');
    expect(row.version, 18);
    expect(row.serverId, _serverId,
        reason: 'the row is linked to the server course it was matched to');
  });

  test('sync ran first: the server version is on the row but the lessons are '
      'still the bundled ones', () async {
    final repo = repoWith(_FakeRemote(version: 18));
    // Metadata-only catalog row from sync, then MainScreen's bundle seeding
    // repairs it with the v8 lessons under the v18 number (BR-V72RWM).
    await db.into(db.coursesTable).insert(const CoursesTableCompanion(
          id: Value('onboarding-local'),
          courseId: Value(_onboarding),
          name: Value('Co umí EDU AI asistent'),
          serverId: Value(_serverId),
          version: Value(18),
          data: Value('{}'),
        ));
    await repo.ensureBundledCoursesLoaded();
    expect(firstLessonName(await onboardingRow()), 'Úvod',
        reason: 'precondition: bundled lessons under the server version');

    final refreshed = await repo.refreshOutdatedContent('onboarding-local');

    expect(refreshed, isTrue);
    final row = await onboardingRow();
    expect(firstLessonName(row), 'Server v18');
    expect(row.version, 18);
  });

  test('content already at the server version is left alone', () async {
    final repo = repoWith(_FakeRemote(version: 18));
    await db.into(db.coursesTable).insert(CoursesTableCompanion(
          id: const Value('onboarding-local'),
          courseId: const Value(_onboarding),
          name: const Value('Co umí EDU AI asistent'),
          serverId: const Value(_serverId),
          version: const Value(18),
          data: Value(jsonEncode(_content(18, 'Local v18'))),
        ));

    final refreshed = await repo.refreshOutdatedContent('onboarding-local');

    expect(refreshed, isFalse);
    expect(remote.metadataCalls, 1, reason: 'the version was still checked');
    expect(remote.downloadCalls, 0);
    expect(firstLessonName(await onboardingRow()), 'Local v18');
  });

  test('offline: opens what is on the device without touching the network',
      () async {
    final repo = repoWith(_FakeRemote(version: 18), online: false);
    await repo.ensureBundledCoursesLoaded();
    final seeded = await onboardingRow();

    final refreshed = await repo.refreshOutdatedContent(seeded.id);

    expect(refreshed, isFalse);
    expect(remote.metadataCalls, 0);
    expect(remote.downloadCalls, 0);
    expect(firstLessonName(await onboardingRow()), 'Úvod');
  });

  test('a failed download keeps the bundled content openable', () async {
    final repo = repoWith(_FakeRemote(version: 18, downloadFails: true));
    await repo.ensureBundledCoursesLoaded();
    final seeded = await onboardingRow();

    final refreshed = await repo.refreshOutdatedContent(seeded.id);

    expect(refreshed, isFalse);
    final row = await onboardingRow();
    expect(firstLessonName(row), 'Úvod');
    expect(row.version, 8,
        reason: 'no version bump without the content to go with it');
  });
}
