import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/evaluation/quiz_feedback_comment.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/quiz_page.dart';

// Regression test for BR-RQQVP6.
//
// The gaming filter already reported a too-fast answer as "Tipováno" in the
// recap, but the score kept counting it: the same popup could say "Správně
// 1 z 1" over a breakdown listing that one answer as a guess. A guess carries
// no verdict — it scores as neither right nor wrong, even when it lands on the
// right option.

ContentBlock _block() => ContentBlock.fromJson({
      'block_id': 'TEST_GUESSED_SCORE',
      'type': 'question',
      'content': 'Kolik je 2 + 2?',
      'question': {
        'type': 'multiple_choice',
        'options': [
          {'id': 'a', 'text': '3', 'is_correct': false},
          {'id': 'b', 'text': '4', 'is_correct': true},
        ],
      },
    });

/// The recap's AI comment is online-only and best-effort; the test keeps it out
/// of the way so the popup renders without waiting on a network call.
class _NoComment implements QuizFeedbackCommentService {
  @override
  Future<String?> fetchComment({
    required List<QuizFeedbackTask> tasks,
    Map<String, double> domainDeltas = const {},
    String? language,
  }) async =>
      null;
}

/// Finishing a session kicks off a sync; nothing in this test needs it, and
/// the real one wants a signed-in API client.
class _NoSync implements SyncService {
  @override
  Future<void> sync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// A practice session: it reaches the same recap as the global quiz without
  /// submitting an attempt over the network.
  Future<void> pumpPractice(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
          quizFeedbackCommentProvider.overrideWithValue(_NoComment()),
          syncServiceProvider.overrideWithValue(_NoSync()),
        ],
        child: MaterialApp(
          home: QuizPage(
            questionBlocks: [_block()],
            courseTitle: AppStrings.practiceTitle,
            courseId: 'course-1',
            evaluate: true,
            isExercise: true,
            isFsrsPractice: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a right answer given instantly scores as a guess, not as correct',
      (tester) async {
    await pumpPractice(tester);

    // Straight to the correct option and on to the recap — well under the
    // filter's two-second floor.
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.quizCheck));
    await tester.pumpAndSettle();

    // The running count in the progress bar is a score readout too.
    expect(find.text(AppStrings.quizCorrectCount(0, 1)), findsOneWidget);
    expect(find.text(AppStrings.quizCorrectCount(1, 1)), findsNothing);

    await tester.tap(find.text(AppStrings.quizFinish));
    await tester.pumpAndSettle();

    // The recap counts it on the guessing row and nowhere else.
    expect(find.text(AppStrings.quizCorrectResult(0, 1)), findsOneWidget);
    expect(find.text(AppStrings.quizCorrectResult(1, 1)), findsNothing);
    expect(find.text(AppStrings.quizBreakdownGamed), findsOneWidget);
  });
}
