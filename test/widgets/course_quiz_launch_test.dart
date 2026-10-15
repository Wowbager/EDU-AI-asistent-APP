// BR-WRMW7W: what a course's Kvíz button hands QuizPage. The course in the
// report asked all 48 of its questions ("Karta 1 z 48"); it now asks ten,
// drawn like the global quiz. QuizPage restores progress by question index
// in memory and by block id from user_courses.progressData, so the draw has
// to stay put while a run is unfinished.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/gamification/global_quiz.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/course_quiz_launch.dart';
import 'package:eduai/pages/quiz_page.dart';

const _userId = 'u1';
const _courseId = 'C1';
final _createdAt = DateTime.utc(2026, 10, 1);

UsersTableData _user() => UsersTableData(
      id: _userId,
      email: 'student@example.com',
      name: 'Student',
      avatarIndex: 0,
      selectedSubjects: '[0]',
      isEmailValidated: true,
      isActive: true,
      syncStatus: 0,
      createdAt: _createdAt,
      updatedAt: _createdAt,
    );

/// A course with 48 exercise blocks over four lessons, [flags] on top.
Map<String, dynamic> _courseData([Map<String, dynamic> flags = const {}]) {
  final template = ((jsonDecode(
    File('assets/courses/EDU_ONBOARDING_APP.json').readAsStringSync(),
  ) as Map<String, dynamic>)['blocks'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((b) => b['type'] == 'exercise');
  return {
    'name': 'Statistika',
    'blocks': [
      for (var i = 0; i < 48; i++)
        <String, dynamic>{...template, 'block_id': 'b$i'},
    ],
    'lessons': [
      for (var l = 0; l < 4; l++)
        {
          'id': 'L$l',
          'name': 'Lekce $l',
          'blocks': [
            for (var i = 0; i < 12; i++)
              {'block_id': 'b${l * 12 + i}', 'order': i},
          ],
        },
    ],
    ...flags,
  };
}

Course _course([Map<String, dynamic> flags = const {}]) =>
    Course.fromJsonData(id: _courseId, data: _courseData(flags));

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      activeUserProvider.overrideWith((ref) async => _user()),
    ]);
    await container.read(activeUserProvider.future);
    await db.into(db.coursesTable).insert(CoursesTableCompanion(
          id: const Value('local-c1'),
          courseId: const Value(_courseId),
          name: const Value('Statistika'),
          data: Value(jsonEncode(_courseData())),
        ));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A [WidgetRef] on [container], the way the course pages hold one.
  Future<WidgetRef> pumpRef(WidgetTester tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const SizedBox();
      }),
    ));
    return captured;
  }

  Future<void> storeResume(Map<String, dynamic> progressData) =>
      db.upsertUserCourse(UserCoursesTableCompanion(
        id: const Value('uc1'),
        userId: const Value(_userId),
        courseId: const Value('local-c1'),
        progressDataJson: Value(jsonEncode(progressData)),
      ));

  testWidgets('a regular course asks ten questions, not all 48',
      (tester) async {
    final ref = await pumpRef(tester);
    final progress = QuizProgress();

    final blocks = await tester.runAsync(
      () => courseQuizBlocks(ref, _course(), progress),
    );

    expect(blocks, hasLength(globalQuizLength));
    expect(blocks!.map((b) => b.blockId).toSet(), hasLength(globalQuizLength));
    expect(progress.questionBlocks, same(blocks));
  });

  testWidgets('an only_once test, an entry quiz and a quiz-only course keep '
      'every question', (tester) async {
    final ref = await pumpRef(tester);
    for (final flag in ['only_once', 'starts_with_quiz', 'only_quiz']) {
      final blocks = await tester.runAsync(
        () => courseQuizBlocks(ref, _course({flag: true}), QuizProgress()),
      );
      expect(blocks, hasLength(48), reason: flag);
    }
  });

  testWidgets('reopening mid-run asks the same questions again',
      (tester) async {
    final ref = await pumpRef(tester);
    final progress = QuizProgress();
    final first = await tester.runAsync(
      () => courseQuizBlocks(ref, _course(), progress),
    );
    // QuizPage saved two answers back into the in-memory progress.
    progress.answeredFlags.addAll({0: true, 3: true});

    final again = await tester.runAsync(
      () => courseQuizBlocks(ref, _course(), progress),
    );
    expect(again, same(first));
  });

  testWidgets('without answers a reopen draws anew and clears stale progress',
      (tester) async {
    final ref = await pumpRef(tester);
    final progress = QuizProgress()..currentIndex = 7;
    await tester.runAsync(() => courseQuizBlocks(ref, _course(), progress));
    expect(progress.currentIndex, 0);
  });

  testWidgets('a cold start keeps what the unfinished run answered',
      (tester) async {
    await tester.runAsync(() => storeResume({
          'quiz_in_progress': true,
          'quiz_answers': {
            'b40': {'is_answered': true, 'is_correct': true},
            'b13': {'is_answered': true, 'is_correct': false},
          },
        }));
    final ref = await pumpRef(tester);

    final blocks = await tester.runAsync(
      () => courseQuizBlocks(ref, _course(), QuizProgress()),
    );
    expect(blocks, hasLength(globalQuizLength));
    expect(blocks!.take(2).map((b) => b.blockId), ['b13', 'b40']);
  });

  testWidgets('a submitted run leaves nothing to keep', (tester) async {
    await tester.runAsync(() => storeResume({
          'quiz_in_progress': false,
          'quiz_completed': true,
          'quiz_answers': {
            for (var i = 0; i < 48; i++) 'b$i': {'is_answered': true},
          },
        }));
    final ref = await pumpRef(tester);

    final blocks = await tester.runAsync(
      () => courseQuizBlocks(ref, _course(), QuizProgress()),
    );
    expect(blocks, hasLength(globalQuizLength));
    // Kept answers would lead in course order: b0, b1, … b9.
    expect(blocks!.map((b) => b.blockId),
        isNot([for (var i = 0; i < globalQuizLength; i++) 'b$i']));
  });
}
