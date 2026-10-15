import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/evaluation/ai_answer_evaluator.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/auth_token_storage.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/quiz_page.dart';
import 'package:eduai/widgets/block_step_engine.dart';

// Regression tests for BR-4AT4CC: grading an open answer with AI is a network
// round trip (25 s, 55 s with a photo), and in practice/quiz the page's own
// bottom bar is the only button on screen — the engine hides its spinner
// whenever a controller drives it. Nothing rendered the in-flight state, so
// tapping "Zkontrolovat" looked like a dead tap for seconds on end.
//
// Both answer paths must show progress: V2 question steps report through the
// engine controller, atomic open questions through the page's own flag. These
// pump the real QuizPage, not a stand-in bar — a harness mirroring the
// intended branch logic would pass with the bug still in place.

/// An evaluator that never answers until the test says so, so the in-flight
/// state can be inspected instead of raced.
class _GatedEvaluator extends AiAnswerEvaluator {
  _GatedEvaluator(super.api, super.connectivity);

  /// Created on first use rather than in setUp: a Completer schedules its
  /// continuation in the zone it was built in, and setUp runs outside the
  /// test's fake-async zone — completing it there would never be flushed by
  /// tester.pump(), leaving the evaluation permanently in flight.
  Completer<AiEvaluationOutcome>? _gate;

  Completer<AiEvaluationOutcome> get gate =>
      _gate ??= Completer<AiEvaluationOutcome>();

  bool get isPending => _gate != null && !_gate!.isCompleted;

  @override
  Future<UploadedPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    String? courseId,
  }) async =>
      null;

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
  }) =>
      gate.future;
}

/// V2 step block — the shape in the bug report's screenshot.
ContentBlock _v2Block() => ContentBlock.fromJson({
      'block_id': 'TEST_AI_V2',
      'type': 'question',
      'steps': [
        {
          'id': 's1',
          'type': 'question',
          'order': 1,
          'question': {
            'type': 'open',
            'question': 'Co znamena "jablko nepada daleko od stromu"?',
            'ai_evaluation': true,
            'show_answers': true,
          },
        },
      ],
    });

/// Atomic block — the same question authored in the non-step format.
ContentBlock _atomicBlock() => ContentBlock.fromJson({
      'block_id': 'TEST_AI_ATOMIC',
      'type': 'question',
      'content': 'Co znamena "jablko nepada daleko od stromu"?',
      'question': {
        'type': 'open',
        'ai_evaluation': true,
        'show_answers': true,
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _GatedEvaluator evaluator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Never reached — every network method is overridden — but the superclass
    // needs something to hold.
    evaluator = _GatedEvaluator(
      ApiClient(AuthTokenStorage(prefs: prefs)),
      ConnectivityService(),
    );
  });

  tearDown(() async {
    if (evaluator.isPending) {
      evaluator.gate
          .complete(const AiEvaluationOutcome.failed(AiEvaluationFailure.unavailable));
    }
    await db.close();
  });

  Future<void> pumpQuiz(WidgetTester tester, ContentBlock block) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiAnswerEvaluatorProvider.overrideWithValue(evaluator),
          // QuizPage only calls setLocation/clearLocation on it, which never
          // touch the database — but the provider still has to resolve.
          workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
        ],
        child: MaterialApp(
          home: QuizPage(
            questionBlocks: [block],
            courseTitle: 'Procvicovani',
            courseId: 'course-1',
            evaluate: true,
            isExercise: true,
            // The reported path. It also keeps initState off the DB: FSRS
            // practice skips the per-course quiz-resume hydration.
            isFsrsPractice: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Type an answer and submit it, leaving the evaluation in flight.
  Future<void> submitAnswer(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Deti se podobaji rodicum');
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.quizCheck));
    // Not pumpAndSettle: the progress indicator animates forever, and the
    // gate is deliberately still open.
    await tester.pump();
  }

  void expectBusyBar() {
    expect(
      find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
      reason: 'the bottom bar must show that grading is running',
    );
    expect(find.text(AppStrings.openFeedbackEvaluating), findsOneWidget);
    expect(
      find.text(AppStrings.quizCheck),
      findsNothing,
      reason: 'a live "Zkontrolovat" invites the dead tap the report describes',
    );
    expect(
      find.byIcon(Icons.arrow_back),
      findsNothing,
      reason: 'leaving the question mid-call would strand the evaluating flag',
    );
  }

  testWidgets('V2 open step shows progress while the AI grades it',
      (tester) async {
    await pumpQuiz(tester, _v2Block());
    await submitAnswer(tester);

    expectBusyBar();
  });

  testWidgets('atomic open question shows progress while the AI grades it',
      (tester) async {
    await pumpQuiz(tester, _atomicBlock());
    await submitAnswer(tester);

    expectBusyBar();
  });

  testWidgets('a failed evaluation clears the busy bar', (tester) async {
    await pumpQuiz(tester, _v2Block());
    await submitAnswer(tester);
    expectBusyBar();

    evaluator.gate
        .complete(const AiEvaluationOutcome.failed(AiEvaluationFailure.unavailable));
    // Discrete pumps, not pumpAndSettle: the feedback the engine renders has
    // animations of its own that never settle.
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Nothing usable came back, so the answer is graded by comparison instead
    // (BR-N26ACB) — the busy bar has to clear and hand over to the next step.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(AppStrings.openFeedbackEvaluating), findsNothing);
    expect(find.text(AppStrings.quizCheck), findsNothing);
    expect(find.text(AppStrings.actionContinue), findsOneWidget);
  });

  testWidgets('an engine torn down mid-evaluation does not strand the flag',
      (tester) async {
    await pumpQuiz(tester, _v2Block());
    await submitAnswer(tester);

    final controller = tester
        .widget<BlockStepEngine>(find.byType(BlockStepEngine))
        .controller!;
    expect(controller.isEvaluating, isTrue);

    // The controller outlives the engine. Without the clear in the engine's
    // dispose, the flag would survive the teardown and the next question's
    // bottom bar would open already spinning.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(controller.isEvaluating, isFalse);
  });
}
