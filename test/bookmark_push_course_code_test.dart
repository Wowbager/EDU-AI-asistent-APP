// Regression test for BR-952UKZ.
//
// In-app bookmarking passes the local Drift course row id (`local-<uuid>`,
// generated per device) as the course reference. Pushing that raw to the
// server fills `bookmarks.course_id` with ids nothing off the device can map
// back to a course — the admin's Procvičování panel then labels whole groups
// with the internal id instead of the course name.
//
// Practice cards already translate the row id to the server course code on
// push (BR-ZBJ99Z). Bookmarks must do the same, for creates *and* deletes —
// a delete keyed by the local id would never match the code-keyed row the
// server holds, leaving orphaned bookmarks behind forever.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/sync/sync_queue.dart';
import 'package:eduai/core/sync/sync_service.dart';

const _localCourseId = 'local-1111';
const _courseCode = 'LITPOJMY_CJ9';

/// Records every outgoing request so the test can assert on the wire payload.
class _CapturingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'id': 1, 'status': 'created'}),
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
  late _CapturingAdapter adapter;
  late SyncService sync;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = ApiClient(AuthTokenStorage(prefs: prefs));
    adapter = _CapturingAdapter();
    apiClient.dio.httpClientAdapter = adapter;
    sync = SyncService(
      db: db,
      apiClient: apiClient,
      connectivity: ConnectivityService(),
    );

    // The local catalog row a downloaded course gets: keyed by a per-device
    // row id, carrying the server course code in `courseId`.
    await db.upsertCourse(const CoursesTableCompanion(
      id: Value(_localCourseId),
      serverId: Value(42),
      courseId: Value(_courseCode),
      name: Value('Literární pojmy k přijímacím zkouškám (ČJ9)'),
    ));
  });

  tearDown(() => db.close());

  Map<String, dynamic> bodyOf(RequestOptions options) =>
      options.data as Map<String, dynamic>;

  test('a created bookmark is pushed under the server course code', () async {
    await sync.debugProcessBookmarkOperation(SyncOperation.create, {
      'course_id': _localCourseId,
      'block_id': 'L1_B5_uryvek_proza',
      'lesson_id': 'L1_DRUHY',
    });

    expect(adapter.requests, hasLength(1));
    final body = bodyOf(adapter.requests.single);
    expect(body['course_id'], _courseCode);
    expect(body['block_id'], 'L1_B5_uryvek_proza');
    expect(body['lesson_id'], 'L1_DRUHY');
  });

  test('a deleted bookmark is pushed under the server course code', () async {
    await sync.debugProcessBookmarkOperation(SyncOperation.delete, {
      'course_id': _localCourseId,
      'block_id': 'L1_B5_uryvek_proza',
    });

    expect(adapter.requests, hasLength(1));
    expect(bodyOf(adapter.requests.single)['course_id'], _courseCode);
  });

  test('a course id with no local row is pushed unchanged', () async {
    // Bookmarks pulled from the server already carry the code, and a course
    // created offline may have no code at all — neither must be mangled.
    await sync.debugProcessBookmarkOperation(SyncOperation.create, {
      'course_id': 'SOME_OTHER_CODE',
      'block_id': 'block-a',
      'lesson_id': '',
    });

    expect(bodyOf(adapter.requests.single)['course_id'], 'SOME_OTHER_CODE');
  });
}
