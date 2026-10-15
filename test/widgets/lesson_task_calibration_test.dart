import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/elo/elo_engine.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/data/repositories/elo_repository.dart';
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/lesson_detail_page.dart';

// BR-697NCA — the server is the only writer of task difficulty D.
//
// Before, the lesson read D from the course content on every answer, wrote
// its own updated D into the local block_stats cache and never read it back,
// so D never moved anywhere. Now the lesson answers with the D the server last
// published (the content's where there is none), leaves the cache alone, and
// logs what the server needs to apply the task half itself.

const _userId = 'user-1';

/// One exercise block rated on GPF slot 0 at 6.0, in a one-lesson course.
Course _course() {
  final relation = List<int>.filled(35, 0)..[0] = 2;
  final elo = List<double?>.filled(35, null)..[0] = 6.0;
  return Course.fromJsonData(
    id: 'local-1',
    data: {
      'course_id': 'C-CAL',
      'name': 'Calibration',
      'language': 'cs',
      'lessons': [
        {
          'lesson_id': 'L1',
          'name': 'Lekce 1',
          'order': 1,
          'blocks': [
            {'block_id': 'B-ELO', 'order': 1},
          ],
        },
      ],
      'blocks': [
        {
          'block_id': 'B-ELO',
          'type': 'exercise',
          'gpf': {'relation_vector': relation, 'elo_vector': elo},
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
    },
  );
}

/// Completing a block kicks off a sync; the real one wants a signed-in client.
class _NoSync implements SyncService {
  @override
  Future<void> sync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// google_fonts fetches its fonts over HTTP. The test binding answers every
/// request with 400, and inside the real-async windows below that failure
/// lands as a test error; a request that never answers stays silent.
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

List<double?> _slot0(double? value) =>
    List<double?>.filled(kGpfDimensions, null)..[0] = value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    // A rated student, and a block the server has calibrated down to 3.0.
    await EloRepository(db: db).saveProfile(
      _userId,
      _slot0(6.0),
      List<int>.filled(kGpfDimensions, 0),
    );
    await db.upsertBlockStats(
      blockId: 'B-ELO',
      courseId: 'C-CAL',
      itemPocet: jsonEncode(List<int>.filled(kGpfDimensions, 0)..[0] = 12),
      eloVector: jsonEncode(_slot0(3.0)),
      serverUpdatedAt: DateTime.utc(2026, 9, 29, 8),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpLesson(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
      syncServiceProvider.overrideWithValue(_NoSync()),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(activeUserProvider.future));

    final course = _course();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: LessonDetailPage(
            course: course,
            lesson: course.lessons.first,
            lessonIndex: 0,
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

  testWidgets('an answer runs on the server D and logs what calibrates it',
      (tester) async {
    await pumpLesson(tester);
    // Past the two-second gaming floor, so the answer counts (BR-3N79C3).
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2100)));
    await answerRight(tester);

    // One real-async window for every read: google_fonts' network fetch fails
    // in tests, and each extra window gives it a chance to surface.
    final (queued, profile, cached) = (await tester.runAsync(() async => (
          await (db.select(db.syncQueueTable)
                ..where((q) => q.tableName_.equals('elo_interactions')))
              .get(),
          await EloRepository(db: db).getProfile(_userId),
          await db.getBlockStats('B-ELO'),
        )))!;
    expect(queued, hasLength(1));
    final op = queued.single;
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;

    // The queue id is the idempotency key the server dedupes on.
    expect(payload['client_uuid'], op.recordId);
    expect(op.recordId, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-')));
    expect((payload['profil_elo_before'] as List)[0], 6.0);
    expect((payload['elo_vector_used'] as List)[0], 3.0,
        reason: 'the cached server D, not the content\'s 6.0');
    expect(payload.containsKey('elo_vector_snapshot'), isFalse,
        reason: 'the server writes the snapshot');

    // The student half ran on D = 3.0.
    final expected = EloEngine.updateTask(
      profilElo: _slot0(6.0),
      profilPocet: List<int>.filled(kGpfDimensions, 0),
      relationVector: List<double>.filled(kGpfDimensions, 0)..[0] = 2,
      eloVector: _slot0(3.0),
      itemPocet: List<int>.filled(kGpfDimensions, 0),
      score: 1.0,
    );
    expect(profile!.profilElo[0], closeTo(expected.profilElo[0]!, 1e-12));

    // The cache still holds exactly what the server published.
    expect(jsonDecode(cached!.eloVector)[0], 3.0);
    expect(jsonDecode(cached.itemPocet)[0], 12);
  });
}
