// Server-side task difficulty calibration, app half (BR-697NCA).
//
// The server is the only writer of a task's difficulty D. The app answers
// with the D it last pulled (per dimension, where the server has one) and the
// course content's elo_vector elsewhere, never stores a D of its own, and
// sends what the server needs to apply the task half: an idempotency key, the
// student's rating before the answer and the D it used.
//
//   flutter test test/task_difficulty_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/elo/elo_engine.dart';
import 'package:eduai/core/elo/task_difficulty.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/data/repositories/elo_repository.dart';

/// A 35-slot vector: null everywhere except [comps].
List<double?> _vector(Map<int, double> comps) =>
    List<double?>.generate(kGpfDimensions, (i) => comps[i]);

/// Answers GET /api/blocks/stats from [respond] and records every request.
class _StatsAdapter implements HttpClientAdapter {
  _StatsAdapter(this.respond);

  final Map<String, dynamic> Function(Map<String, dynamic> query) respond;
  final List<Map<String, dynamic>> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(Map.of(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode(respond(options.queryParameters)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// `block_stats` exactly as schema 20 created it — no course_id.
const _v20BlockStats = '''
CREATE TABLE block_stats (
  block_id TEXT NOT NULL,
  item_pocet TEXT NOT NULL,
  elo_vector TEXT NOT NULL,
  updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
  PRIMARY KEY (block_id)
)''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effectiveTaskElo', () {
    test('takes the calibrated value per dimension, the content elsewhere', () {
      final effective = effectiveTaskElo(
        _vector(const {0: 5.0, 1: 6.0}),
        _vector(const {0: 4.25}),
      );
      expect(effective[0], 4.25);
      expect(effective[1], 6.0, reason: 'not calibrated yet — the prior applies');
      expect(effective[2], isNull);
      expect(effective, hasLength(kGpfDimensions));
    });

    test('a later author edit shows only where nothing is calibrated', () {
      // D2 as decided: no reset of a calibrated dimension.
      final effective = effectiveTaskElo(
        _vector(const {0: 8.0, 1: 8.0}),
        _vector(const {0: 4.25}),
      );
      expect(effective[0], 4.25);
      expect(effective[1], 8.0);
    });

    test('without a pull the content applies, fitted to 35 slots', () {
      expect(effectiveTaskElo([5.0, null, 7.0], null),
          [5.0, null, 7.0, ...List<double?>.filled(kGpfDimensions - 3, null)]);
    });
  });

  test('the interaction carries what the server calibrates with', () {
    final before = _vector(const {0: 5.0});
    final used = _vector(const {0: 4.25});
    final fields = taskCalibrationFields(
      clientUuid: 'f3c1a8de-6b3c-4a51-9d0e-6a1b2c3d4e5f',
      profilEloBefore: before,
      eloVectorUsed: used,
    );
    expect(fields, {
      'client_uuid': 'f3c1a8de-6b3c-4a51-9d0e-6a1b2c3d4e5f',
      'profil_elo_before': before,
      'elo_vector_used': used,
    });
    // The server writes the snapshot now; sending it would give the column
    // two meanings again.
    expect(fields.containsKey('elo_vector_snapshot'), isFalse);
  });

  group('with a database', () {
    late AppDatabase db;
    late ApiClient apiClient;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      apiClient = ApiClient(
        AuthTokenStorage(prefs: await SharedPreferences.getInstance()),
      );
    });

    tearDown(() => db.close());

    Future<void> seedCourse(String courseId, {required bool downloaded}) {
      return db.upsertCourse(CoursesTableCompanion(
        id: Value('local-$courseId'),
        courseId: Value(courseId),
        name: Value(courseId),
        // A catalog entry keeps '{}' until the course is downloaded.
        data: Value(downloaded ? '{"blocks":[]}' : '{}'),
      ));
    }

    SyncService syncService() => SyncService(
          db: db,
          apiClient: apiClient,
          connectivity: ConnectivityService(),
        );

    test('the repository answers with the cached server D', () async {
      final repo = EloRepository(db: db);
      final prior = _vector(const {0: 5.0, 1: 6.0});

      expect(await repo.effectiveTaskElo('blk_1', prior), prior);

      await db.upsertBlockStats(
        blockId: 'blk_1',
        courseId: 'MAT',
        itemPocet: jsonEncode(List<int>.filled(kGpfDimensions, 0)..[0] = 3),
        eloVector: jsonEncode(_vector(const {0: 4.369})),
        serverUpdatedAt: DateTime.utc(2026, 9, 29, 8),
      );

      final effective = await repo.effectiveTaskElo('blk_1', prior);
      expect(effective[0], 4.369);
      expect(effective[1], 6.0);
      expect(await repo.calibratedTaskElo(['blk_1', 'blk_2']),
          {'blk_1': _vector(const {0: 4.369})});
    });

    test('the pull caches each downloaded course and resumes from its cursor',
        () async {
      await seedCourse('MAT', downloaded: true);
      await seedCourse('CATALOG_ONLY', downloaded: false);

      final adapter = _StatsAdapter((query) => {
            'data': query.containsKey('updated_since')
                ? <Map<String, dynamic>>[]
                : [
                    {
                      'block_id': 'blk_1',
                      'elo_vector': _vector(const {0: 4.75}),
                      'item_pocet': List<int>.filled(kGpfDimensions, 0)..[0] = 1,
                      'updated_at': '2026-09-29T08:00:00+00:00',
                    },
                    {
                      // Counted before calibration existed, never calibrated.
                      'block_id': 'blk_2',
                      'elo_vector': null,
                      'item_pocet': null,
                      'updated_at': '2026-09-29T07:00:00+00:00',
                    },
                  ],
            'meta': {'task_calibration': true},
          });
      apiClient.dio.httpClientAdapter = adapter;

      await syncService().debugPullBlockStats();

      // Only the downloaded course is asked for; the catalog entry has no
      // blocks the student can answer.
      expect(adapter.requests, [
        {'course_id': 'MAT'},
      ]);
      final repo = EloRepository(db: db);
      expect((await repo.effectiveTaskElo('blk_1', _vector(const {0: 5.0})))[0], 4.75);
      expect((await repo.effectiveTaskElo('blk_2', _vector(const {0: 5.0})))[0], 5.0);

      await syncService().debugPullBlockStats();

      expect(adapter.requests.last, {
        'course_id': 'MAT',
        'updated_since': '2026-09-29T08:00:00.000Z',
      });
      expect((await repo.effectiveTaskElo('blk_1', _vector(const {0: 5.0})))[0], 4.75);
    });

    test('nothing published drops the cache so the content applies', () async {
      await seedCourse('MAT', downloaded: true);
      await db.upsertBlockStats(
        blockId: 'blk_1',
        courseId: 'MAT',
        itemPocet: '[]',
        eloVector: jsonEncode(_vector(const {0: 4.75})),
        serverUpdatedAt: DateTime.utc(2026, 9, 29, 8),
      );

      apiClient.dio.httpClientAdapter = _StatsAdapter((_) => {
            'data': <Map<String, dynamic>>[],
            'meta': {'task_calibration': false},
          });

      await syncService().debugPullBlockStats();

      expect(await db.getBlockStats('blk_1'), isNull);
      expect(
        (await EloRepository(db: db).effectiveTaskElo('blk_1', _vector(const {0: 5.0})))[0],
        5.0,
      );
    });

    test('schema 21 clears the D the app used to write for itself', () async {
      // Before, the lesson stored its own locally computed D here; read back
      // now, it would pass for a calibrated value.
      await db.customStatement('DROP TABLE IF EXISTS block_stats');
      await db.customStatement(_v20BlockStats);
      await db.customStatement(
        "INSERT INTO block_stats (block_id, item_pocet, elo_vector) "
        "VALUES ('blk_1', '[1]', '[4.75]')",
      );

      await db.customStatement('PRAGMA user_version = 20');
      await db.migration.onUpgrade(db.createMigrator(), 20, db.schemaVersion);

      expect(await db.getBlockStats('blk_1'), isNull);

      // And the cursor column is there and writable.
      await db.upsertBlockStats(
        blockId: 'blk_1',
        courseId: 'MAT',
        itemPocet: '[]',
        eloVector: '[]',
        serverUpdatedAt: DateTime.utc(2026, 9, 29, 8),
      );
      expect((await db.getBlockStatsCursor('MAT'))?.toUtc(), DateTime.utc(2026, 9, 29, 8));
    });
  });
}
