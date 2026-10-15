import 'package:eduai/core/elo/domain_elo_delta.dart';
import 'package:eduai/core/elo/gpf_structure.dart';
import 'package:eduai/core/evaluation/quiz_block_summary.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/widgets/quiz_feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The end-of-quiz feedback popup (BR-JCUJVR). Before this the quiz simply
/// popped back to the course list and the student saw nothing at all.
void main() {
  Future<void> pump(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
    await tester.pump();
  }

  QuizFeedbackDialog build({
    QuizBlockSummary? summary,
    List<DomainEloDelta> domainDeltas = const [],
    Map<String, String> domainNames = const {},
    int? successPercent,
    int? xpEarned,
    VoidCallback? onRetry,
  }) {
    return QuizFeedbackDialog(
      title: 'Kvíz dokončen!',
      headline: '3 z 4 správně',
      icon: Icons.thumb_up,
      iconColor: const Color(0xFF4CAF50),
      summary: summary,
      domainDeltas: domainDeltas,
      domainNames: domainNames,
      successPercent: successPercent,
      xpEarned: xpEarned,
      onDone: () {},
      onRetry: onRetry,
    );
  }

  testWidgets('renders the outcome breakdown with its counts', (tester) async {
    await pump(
      tester,
      build(
        summary: const QuizBlockSummary(
          correctNoHint: 2,
          correctWithHint: 1,
          wrong: 1,
        ),
      ),
    );

    expect(find.text(AppStrings.quizBreakdownHeading), findsOneWidget);
    expect(find.text(AppStrings.quizBreakdownCorrectNoHint), findsOneWidget);
    expect(find.text(AppStrings.quizBreakdownCorrectWithHint), findsOneWidget);
    expect(find.text(AppStrings.quizBreakdownWrong), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('hides the unanswered row when everything was answered',
      (tester) async {
    await pump(
      tester,
      build(summary: const QuizBlockSummary(correctNoHint: 4)),
    );

    expect(find.text(AppStrings.quizBreakdownUnanswered), findsNothing);
  });

  testWidgets('shows the unanswered row when the quiz was cut short',
      (tester) async {
    await pump(
      tester,
      build(summary: const QuizBlockSummary(correctNoHint: 2, unanswered: 2)),
    );

    expect(find.text(AppStrings.quizBreakdownUnanswered), findsOneWidget);
  });

  testWidgets('a null summary hides the counts but keeps the popup',
      (tester) async {
    // The shape used by courses with quiz_evaluate off: acknowledged, but no
    // score disclosed.
    await pump(tester, build(summary: null));

    expect(find.text(AppStrings.quizBreakdownHeading), findsNothing);
    expect(find.text('3 z 4 správně'), findsOneWidget);
    expect(find.text(AppStrings.quizDone), findsOneWidget);
  });

  testWidgets('an empty block renders no breakdown panel', (tester) async {
    await pump(tester, build(summary: const QuizBlockSummary()));

    expect(find.text(AppStrings.quizBreakdownHeading), findsNothing);
  });

  testWidgets('renders domain deltas with sign and Czech name',
      (tester) async {
    final m = GpfStructure.domainByCode('M')!;
    final g = GpfStructure.domainByCode('G')!;

    await pump(
      tester,
      build(
        summary: const QuizBlockSummary(correctNoHint: 1),
        domainDeltas: [
          DomainEloDelta(domain: m, delta: 0.34, dimensionCount: 5),
          DomainEloDelta(domain: g, delta: -0.2, dimensionCount: 3),
        ],
        domainNames: const {'M': 'Míra v geometrii', 'G': 'Geometrie'},
      ),
    );

    expect(find.text(AppStrings.quizEloHeading), findsOneWidget);
    expect(find.text('Míra v geometrii'), findsOneWidget);
    expect(find.text('Geometrie'), findsOneWidget);
    // Czech locale: decimal comma, explicit plus on an improvement.
    expect(find.text('+0,3'), findsOneWidget);
    expect(find.text('-0,2'), findsOneWidget);
  });

  testWidgets('falls back to the domain code when no label is available',
      (tester) async {
    final m = GpfStructure.domainByCode('M')!;

    await pump(
      tester,
      build(
        domainDeltas: [
          DomainEloDelta(domain: m, delta: 0.5, dimensionCount: 5),
        ],
      ),
    );

    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('no deltas means no ELO section at all', (tester) async {
    await pump(tester, build(summary: const QuizBlockSummary(wrong: 1)));

    expect(find.text(AppStrings.quizEloHeading), findsNothing);
  });

  testWidgets('the retry action only appears when a retry is allowed',
      (tester) async {
    await pump(tester, build(summary: const QuizBlockSummary(wrong: 1)));
    expect(find.text(AppStrings.quizRetry), findsNothing);

    await pump(
      tester,
      build(summary: const QuizBlockSummary(wrong: 1), onRetry: () {}),
    );
    expect(find.text(AppStrings.quizRetry), findsOneWidget);
  });

  testWidgets('Hotovo fires the done callback', (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuizFeedbackDialog(
          title: 'Kvíz odeslán',
          headline: 'Díky',
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF3C315B),
          onDone: () => done = true,
        ),
      ),
    ));

    await tester.tap(find.text(AppStrings.quizDone));
    expect(done, isTrue);
  });

  // ── The success panel, now shared with the quiz (BR-9SCMRQ) ──────────────

  testWidgets('a quiz shows the success rate without an XP line',
      (tester) async {
    await pump(
      tester,
      build(
        summary: const QuizBlockSummary(correctNoHint: 3, wrong: 1),
        successPercent: 75,
      ),
    );

    expect(find.text(AppStrings.practiceSummarySuccess(75)), findsOneWidget);
    // A course quiz banks no XP, so the line must stay out rather than
    // announce "+0 XP".
    expect(find.text(AppStrings.practiceSummaryXp(0)), findsNothing);
  });

  testWidgets('practice still shows both the success rate and the XP',
      (tester) async {
    await pump(
      tester,
      build(
        summary: const QuizBlockSummary(correctNoHint: 4),
        successPercent: 100,
        xpEarned: 35,
      ),
    );

    expect(find.text(AppStrings.practiceSummarySuccess(100)), findsOneWidget);
    expect(find.text(AppStrings.practiceSummaryXp(35)), findsOneWidget);
  });

  testWidgets('no success rate means no panel — the quiz_evaluate off shape',
      (tester) async {
    await pump(tester, build(summary: null));

    expect(find.textContaining('Úspěšnost'), findsNothing);
  });

  // ── Closing the popup (BR-9SCMRQ) ────────────────────────────────────────

  testWidgets('the scroll view keeps its scrollbar thumb permanently visible',
      (tester) async {
    // The client could not tell how to close the popup: "Hotovo" is the last
    // widget in the scroll view, so on a short screen it sits below the fold
    // and a thumb that only appears mid-drag never hints that it is there.
    await pump(
      tester,
      build(
        summary: const QuizBlockSummary(correctNoHint: 2, wrong: 2),
        successPercent: 50,
      ),
    );

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollbar.controller, isNotNull);
  });
}
