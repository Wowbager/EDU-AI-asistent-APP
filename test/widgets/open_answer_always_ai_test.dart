import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/models/course_model.dart';
import 'package:eduai/models/open_answer_feedback.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/pages/lesson_detail_page.dart';
import 'package:eduai/widgets/block_step_engine.dart';
import 'package:eduai/widgets/open_answer_feedback_card.dart';

// Regression tests for BR-N26ACB.
//
// "Otevřená odpověď se vždy vyhodnocuje pomocí AI, pouze v případě offline
// nebo fallback že AI nevrací se vyhodnocuje pomocí porovnání odpovědi." Every
// open answer goes to the AI; the comparison with the expected answer is only
// the fallback. The `ai_evaluation` switch decides what the student is shown:
// on, the AI's feedback; off, a plain right/wrong and the solution. The
// expected answer is never shown either way.
//
// This reverses BR-WBY5AF, which read the switch as "the AI does not run".

const _expected = '4';
const _solution = 'Hodnota a se v datech vyskytuje čtyřikrát.';

const _feedback = FormativeFeedback(
  strengths: 'Čteš data správně.',
  improvements: 'Zapiš četnost číslem.',
  nextStep: 'Projdi řadu a zaznamenej výskyty.',
);

Map<String, dynamic> _question({
  required bool aiEvaluation,
  bool showSolution = true,
}) =>
    {
      'type': 'open',
      'correct_answer': _expected,
      'solution': _solution,
      'ai_evaluation': aiEvaluation,
      'show_answers': true,
      'show_solution': showSolution,
    };

ContentBlock _block({required bool aiEvaluation, bool showSolution = true}) {
  return ContentBlock.fromJson({
    'block_id': 'TEST_ALWAYS_AI',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': {'text': 'Jakou četnost má v datech hodnota a?'},
        'question':
            _question(aiEvaluation: aiEvaluation, showSolution: showSolution),
      },
    ],
  });
}

/// Grades every answer as right — "čtyři" against an expected "4" is the case
/// a comparison gets wrong — or reports the connection gone.
class _Evaluator implements AiAnswerEvaluator {
  _Evaluator({this.offline = false});

  final bool offline;
  int calls = 0;

  @override
  Future<AiEvaluationOutcome> evaluate({
    required String question,
    String studentAnswer = '',
    String? photoName,
    String? help,
    String? solution,
    String? correctAnswer,
    String? criteria,
    List<QuestionCriterion> criteriaList = const [],
    String? language,
  }) async {
    calls++;
    if (offline) {
      return const AiEvaluationOutcome.failed(AiEvaluationFailure.offline);
    }
    return AiEvaluationOutcome.success(AiEvaluationResult(
      score: 0.95,
      isCorrect: true,
      feedbackText: _feedback.strengths,
      feedback: _feedback,
      model: 'test/model',
    ));
  }

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      null;
}

Widget _harness(
  ContentBlock block, {
  required AiAnswerEvaluator evaluator,
  required void Function(OpenAnswerEvent) onOpenAnswer,
}) {
  return ProviderScope(
    overrides: [
      aiAnswerEvaluatorProvider.overrideWithValue(evaluator),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockStepEngine(
            block: block,
            exportMode: ExportMode.courseV2,
            onOpenAnswerEvaluated: onOpenAnswer,
            onBlockCompleted: ({
              int earnedXp = 0,
              double scoreKoef = 1.0,
              String? mark,
              DateTime? tsBubbleOpen,
              DateTime? tsAnswerClick,
              DateTime? tsAnswerSubmit,
              int attemptCount = 0,
            }) {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _answer(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.engineCheck));
  await tester.pumpAndSettle();
}

/// Completing a block kicks off a sync; the real one wants a signed-in client.
class _NoSync implements SyncService {
  @override
  Future<void> sync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A one-lesson course holding a single atomic open question — the lesson
/// page grades those itself, outside the step engine.
Course _atomicCourse({required bool aiEvaluation}) {
  return Course.fromJsonData(
    id: 'local-1',
    data: {
      'course_id': 'C-ALWAYS-AI',
      'name': 'Četnost',
      'language': 'cs',
      // The atomic card reports right/wrong only in a course that evaluates.
      'quiz_evaluate': true,
      'lessons': [
        {
          'lesson_id': 'L1',
          'name': 'Lekce 1',
          'order': 1,
          'blocks': [
            {'block_id': 'B-OPEN', 'order': 1},
          ],
        },
      ],
      'blocks': [
        {
          'block_id': 'B-OPEN',
          'type': 'question',
          'content': 'Jakou četnost má v datech hodnota a?',
          'question': _question(aiEvaluation: aiEvaluation),
        },
      ],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lesson step, ai_evaluation off', () {
    testWidgets('the AI grades it, and the verdict is shown the classic way',
        (tester) async {
      final evaluator = _Evaluator();
      final events = <OpenAnswerEvent>[];
      await tester.pumpWidget(_harness(
        _block(aiEvaluation: false),
        evaluator: evaluator,
        onOpenAnswer: events.add,
      ));

      // Right in substance, wrong to a string comparison.
      await _answer(tester, 'čtyři');

      expect(evaluator.calls, 1, reason: 'every open answer goes to the AI');
      expect(events.single.evaluatedByAi, isTrue);
      expect(events.single.isCorrect, isTrue);

      // Right/wrong and the solution — not the AI's words, not the expected
      // answer.
      expect(find.text(AppStrings.lessonCorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
      expect(find.byType(OpenAnswerFeedbackCard), findsNothing);
      expect(find.text(_feedback.strengths), findsNothing);
      expect(find.text(AppStrings.stepAiFeedback), findsNothing);
    });

    testWidgets('offline, the comparison grades it', (tester) async {
      final evaluator = _Evaluator(offline: true);
      final events = <OpenAnswerEvent>[];
      await tester.pumpWidget(_harness(
        _block(aiEvaluation: false),
        evaluator: evaluator,
        onOpenAnswer: events.add,
      ));

      await _answer(tester, 'čtyři');

      expect(evaluator.calls, 1);
      expect(events.single.evaluatedByAi, isFalse);
      expect(events.single.isCorrect, isFalse);
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
      expect(find.byType(OpenAnswerRetryNotice), findsNothing);
    });

    testWidgets('offline, a matching answer is right', (tester) async {
      final events = <OpenAnswerEvent>[];
      await tester.pumpWidget(_harness(
        _block(aiEvaluation: false),
        evaluator: _Evaluator(offline: true),
        onOpenAnswer: events.add,
      ));

      await _answer(tester, _expected);

      expect(events.single.isCorrect, isTrue);
      expect(find.text(AppStrings.lessonCorrect), findsOneWidget);
    });

    testWidgets('a hidden solution stays hidden, and the AI still grades',
        (tester) async {
      final evaluator = _Evaluator();
      await tester.pumpWidget(_harness(
        _block(aiEvaluation: false, showSolution: false),
        evaluator: evaluator,
        onOpenAnswer: (_) {},
      ));

      await _answer(tester, 'čtyři');

      expect(evaluator.calls, 1);
      expect(find.text(_solution), findsNothing);
      expect(find.text(_feedback.strengths), findsNothing);
    });
  });

  group('lesson step, ai_evaluation on', () {
    testWidgets('the AI grades it, and its feedback is shown', (tester) async {
      final evaluator = _Evaluator();
      final events = <OpenAnswerEvent>[];
      await tester.pumpWidget(_harness(
        _block(aiEvaluation: true),
        evaluator: evaluator,
        onOpenAnswer: events.add,
      ));

      await _answer(tester, 'čtyři');

      expect(evaluator.calls, 1, reason: 'the grading call, and only that');
      expect(events.single.evaluatedByAi, isTrue);
      expect(find.byType(OpenAnswerFeedbackCard), findsOneWidget);
      expect(find.text(_feedback.strengths), findsOneWidget);
    });

    testWidgets('offline, the comparison grades it instead of a retry',
        (tester) async {
      final evaluator = _Evaluator(offline: true);
      final events = <OpenAnswerEvent>[];
      await tester.pumpWidget(_harness(
        _block(aiEvaluation: true),
        evaluator: evaluator,
        onOpenAnswer: events.add,
      ));

      await _answer(tester, 'čtyři');

      // BR-P745Q8 left the student behind a retry here; now the comparison
      // stands in, and with no feedback to read the status says how it went.
      expect(events.single.evaluatedByAi, isFalse);
      expect(events.single.failed, isFalse);
      expect(events.single.isCorrect, isFalse);
      expect(find.byType(OpenAnswerRetryNotice), findsNothing);
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
    });
  });

  group('lesson atomic question', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.upsertUser(const UsersTableCompanion(
        id: Value('user-1'),
        name: Value('Tester'),
        email: Value(''),
        isActive: Value(true),
      ));
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpLesson(
      WidgetTester tester, {
      required bool aiEvaluation,
      required _Evaluator evaluator,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
        syncServiceProvider.overrideWithValue(_NoSync()),
        aiAnswerEvaluatorProvider.overrideWithValue(evaluator),
      ]);
      addTearDown(container.dispose);
      await tester.runAsync(() => container.read(activeUserProvider.future));

      final course = _atomicCourse(aiEvaluation: aiEvaluation);
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

    Future<void> answerInLesson(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.lessonCheckAnswer));
      await tester.pumpAndSettle();
    }

    testWidgets('ai_evaluation off: graded by AI, no AI feedback shown',
        (tester) async {
      final evaluator = _Evaluator();
      await pumpLesson(tester, aiEvaluation: false, evaluator: evaluator);

      await answerInLesson(tester, 'čtyři');

      expect(evaluator.calls, 1, reason: 'every open answer goes to the AI');
      expect(find.text(AppStrings.lessonCorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
      expect(find.byType(OpenAnswerFeedbackCard), findsNothing);
      expect(find.text(_feedback.strengths), findsNothing);
    });

    testWidgets('offline: graded by comparison instead of a retry',
        (tester) async {
      final evaluator = _Evaluator(offline: true);
      await pumpLesson(tester, aiEvaluation: true, evaluator: evaluator);

      await answerInLesson(tester, 'čtyři');

      expect(evaluator.calls, 1);
      expect(find.byType(OpenAnswerRetryNotice), findsNothing);
      expect(find.text(AppStrings.lessonIncorrect), findsOneWidget);
      expect(find.text(_solution), findsOneWidget);
    });
  });
}
