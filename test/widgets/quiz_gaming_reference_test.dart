import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/evaluation/quiz_feedback_comment.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/gaming_reference_service.dart';
import 'package:eduai/core/services/work_time_tracker.dart';
import 'package:eduai/core/sync/sync_service.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/quiz_page.dart';

// Regression test for BR-H3TCRE.
//
// GamingGuard.classify was never called: the quiz held every task to the fixed
// 2 s floor forever, even once other students' answers showed the task takes
// ten seconds. With ten or more of those reference times the Pilot 2 robust
// threshold applies — here the flat 10 s history puts it at 10 s, so an answer
// after ~2 s is a guess, while the same answer without history still counts.

const _blockId = 'TEST_GAMING_REFERENCE';

ContentBlock _block() => ContentBlock.fromJson({
      'block_id': _blockId,
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

class _FixedReference implements GamingReferenceService {
  _FixedReference(this.reference);

  final Map<String, List<double>> reference;

  @override
  Future<Map<String, List<double>>> fetch(Iterable<String> blockIds) async =>
      reference;
}

class _NoComment implements QuizFeedbackCommentService {
  @override
  Future<String?> fetchComment({
    required List<QuizFeedbackTask> tasks,
    Map<String, double> domainDeltas = const {},
    String? language,
  }) async =>
      null;
}

/// google_fonts fetches the app's fonts over HTTP. Fake-async widget tests
/// never let that request finish; the real-clock wait below would, and
/// flutter_test's stub client answers 400, which google_fonts reports as a
/// test failure. A client that never answers keeps the fonts as pending here
/// as they are in every other widget test.
class _SilentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _SilentHttpClient();
}

class _SilentHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoSync implements SyncService {
  @override
  Future<void> sync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  late HttpOverrides? previousHttpOverrides;

  setUp(() async {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _SilentHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    HttpOverrides.global = previousHttpOverrides;
    await db.close();
  });

  Future<void> answerAfterTwoSeconds(
    WidgetTester tester,
    Map<String, List<double>> reference,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          workTimeTrackerProvider.overrideWithValue(WorkTimeTracker(db)),
          quizFeedbackCommentProvider.overrideWithValue(_NoComment()),
          syncServiceProvider.overrideWithValue(_NoSync()),
          gamingReferenceServiceProvider
              .overrideWithValue(_FixedReference(reference)),
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

    // The quiz times answers on the wall clock, so wait for real: past the
    // fixed 2 s floor, well under the 10 s robust threshold.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2100)));

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.quizCheck));
    await tester.pumpAndSettle();
  }

  testWidgets('without history the fixed 2 s floor applies', (tester) async {
    await answerAfterTwoSeconds(tester, const {});

    expect(find.text(AppStrings.quizCorrectCount(1, 1)), findsOneWidget);
  });

  testWidgets('with ten reference times the robust threshold flags a guess',
      (tester) async {
    await answerAfterTwoSeconds(tester, {
      _blockId: List<double>.filled(12, 10.0),
    });

    expect(find.text(AppStrings.quizCorrectCount(0, 1)), findsOneWidget);
    expect(find.text(AppStrings.quizCorrectCount(1, 1)), findsNothing);
  });
}
