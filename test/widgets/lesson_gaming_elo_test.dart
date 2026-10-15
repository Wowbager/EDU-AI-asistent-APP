import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/data/repositories/elo_repository.dart';
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/lesson_detail_page.dart';

// Regression test for BR-3N79C3.
//
// Pilot 2: a guessed (gaming) attempt must not move ELO or its counters. The
// quiz honoured that since BR-RQQVP6; the lesson never checked, so a block
// answered within a second of appearing shifted the student's rating like any
// real attempt. The lesson now measures block shown → answer submitted and
// skips the update under the gaming floor.

const _userId = 'user-1';

/// One exercise block rated on GPF slot 0, in a one-lesson course.
Course _course() {
  final relation = List<int>.filled(35, 0)..[0] = 2;
  final elo = List<double?>.filled(35, null)..[0] = 6.0;
  return Course.fromJsonData(
    id: 'local-1',
    data: {
      'course_id': 'C-GAMING',
      'name': 'Gaming',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.upsertUser(const UsersTableCompanion(
      id: Value(_userId),
      name: Value('Tester'),
      email: Value(''),
      isActive: Value(true),
    ));
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
    // The app shell has the signed-in student loaded long before a lesson
    // opens, and the ELO update reads it synchronously — warm it up the same.
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

  Future<UserEloProfile?> profile(WidgetTester tester) =>
      tester.runAsync<UserEloProfile?>(
          () => EloRepository(db: db).getProfile(_userId));

  testWidgets('a block answered right after it appeared leaves ELO untouched',
      (tester) async {
    await pumpLesson(tester);

    // Straight to the answer — well under the two-second floor.
    await answerRight(tester);

    // The profile exists — the update ran and was told to skip, rather than
    // never running at all.
    final p = await profile(tester);
    expect(p, isNotNull);
    expect(p!.profilElo.every((v) => v == null), isTrue,
        reason: 'a guess must not seed or move any rating');
    expect(p.profilPocet.every((c) => c == 0), isTrue,
        reason: 'a guess must not bump any counter');
  });

  testWidgets('a block answered after two seconds moves ELO', (tester) async {
    await pumpLesson(tester);

    // Real wall-clock time: the filter measures DateTime.now().
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2100)));
    await answerRight(tester);

    final p = await profile(tester);
    expect(p, isNotNull);
    expect(p!.profilElo[0], isNotNull,
        reason: 'a real attempt rates the student on the block\'s slot');
  });
}
