import 'dart:async';

import 'package:eduai/core/elo/gpf_structure.dart';
import 'package:eduai/core/theme/app_colors.dart';
import 'package:eduai/widgets/global_quiz_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The global quiz entry dialog offered its two sections independently: a
/// course stayed on the list whatever domains were checked, even one with no
/// task in them at all, so the student could pick a course + domain pair that
/// held nothing (BR-RQMMS5). The course list now follows the checked domains
/// — only lessons with a task in one of them are offered — and Start reflects
/// that real intersection.
void main() {
  const geometry = GpfDomain(code: 'G', emoji: '📐', indices: [22, 23, 24]);
  const statistics =
      GpfDomain(code: 'S', emoji: '📊', indices: [25, 26, 27, 28]);
  const names = {'G': 'Geometrie', 'S': 'Statistika'};

  GlobalQuizCourseNode course(
    String id,
    String title,
    Map<String, Set<String>> lessons,
  ) {
    return GlobalQuizCourseNode(
      courseId: id,
      title: title,
      lessons: [
        for (final entry in lessons.entries)
          GlobalQuizLessonOption(
            key: '$id/${entry.key}',
            title: entry.key,
            domainCodes: entry.value,
          ),
      ],
    );
  }

  /// Pumps the dialog through a real route, so Start can pop with its
  /// choice; the returned future completes with it once the dialog closes.
  Future<Future<GlobalQuizEntryChoice?>> openDialog(
    WidgetTester tester, {
    required List<GpfDomain> domains,
    required List<GlobalQuizCourseNode> courses,
  }) async {
    final completer = Completer<GlobalQuizEntryChoice?>();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            completer.complete(await showDialog<GlobalQuizEntryChoice>(
              context: context,
              builder: (_) => GlobalQuizEntryDialog(
                domains: domains,
                domainNames: names,
                courses: courses,
              ),
            ));
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return completer.future;
  }

  /// The domain checkbox row by its exact label — a substring search would
  /// also hit course titles such as "Statistika pro ZŠ".
  Finder domainRow(GpfDomain domain) =>
      find.text('${domain.emoji}  ${names[domain.code]}');

  /// A longer course list pushes Start below the dialog's scroll viewport,
  /// where a tap would silently miss and leave the dialog open.
  Future<void> tapStart(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Spustit kvíz'));
    await tester.tap(find.text('Spustit kvíz'));
    await tester.pumpAndSettle();
  }

  bool startEnabled(WidgetTester tester) {
    final container = tester.widget<Container>(find.ancestor(
      of: find.text('Spustit kvíz'),
      matching: find.byType(Container),
    ).first);
    return (container.decoration as BoxDecoration).color ==
        AppColors.primaryDark;
  }

  testWidgets('hides a course whose tasks touch no offered domain',
      (tester) async {
    await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Statistika pro ZŠ', {
          'Průměr': {'S'},
        }),
        course('c2', 'Gramatika II', {
          'Slova po M': const {},
        }),
        course('c3', 'Geometrie ZŠ', {
          'Úhly': {'G'},
        }),
      ],
    );

    expect(find.text('Statistika pro ZŠ'), findsOneWidget);
    expect(find.text('Geometrie ZŠ'), findsOneWidget);
    expect(find.text('Gramatika II'), findsNothing);
  });

  testWidgets('does not count a vector-less course as a choice',
      (tester) async {
    await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Statistika pro ZŠ', {
          'Průměr': {'S'},
        }),
        course('c2', 'Gramatika II', {
          'Slova po M': const {},
        }),
      ],
    );

    // One real course = no course choice: the section stays hidden, the
    // domain pick alone decides, and Start is ready.
    expect(find.text('Statistika pro ZŠ'), findsNothing);
    expect(find.text('Gramatika II'), findsNothing);
    expect(startEnabled(tester), isTrue);
  });

  testWidgets('drops courses with nothing left in the checked domains',
      (tester) async {
    await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Statistika pro ZŠ', {
          'Průměr': {'S'},
          'Medián': {'S'},
        }),
        course('c2', 'Geometrie ZŠ', {
          'Úhly': {'G'},
        }),
      ],
    );

    expect(find.text('Statistika pro ZŠ'), findsOneWidget);
    expect(find.text('Geometrie ZŠ'), findsOneWidget);

    await tester.tap(domainRow(statistics));
    await tester.pumpAndSettle();

    expect(find.text('Statistika pro ZŠ'), findsNothing);
    expect(find.text('Geometrie ZŠ'), findsOneWidget);
    expect(startEnabled(tester), isTrue);

    // Re-checking brings the course back, still selected.
    await tester.tap(domainRow(statistics));
    await tester.pumpAndSettle();
    expect(find.text('Statistika pro ZŠ'), findsOneWidget);
    expect(startEnabled(tester), isTrue);
  });

  testWidgets('keeps a lesson only while one of its domains is checked',
      (tester) async {
    await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Matematika ZŠ', {
          'Úhly': {'G'},
          'Průměr': {'S'},
          'Grafy': {'G', 'S'},
        }),
      ],
    );

    // The only course opens up front; all three lessons are on offer.
    expect(find.text('Úhly'), findsOneWidget);
    expect(find.text('Průměr'), findsOneWidget);
    expect(find.text('Grafy'), findsOneWidget);

    await tester.tap(domainRow(geometry));
    await tester.pumpAndSettle();

    expect(find.text('Úhly'), findsNothing);
    expect(find.text('Průměr'), findsOneWidget);
    expect(find.text('Grafy'), findsOneWidget);
  });

  testWidgets('reports only the offered lessons', (tester) async {
    final choice = await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Statistika pro ZŠ', {
          'Průměr': {'S'},
        }),
        course('c2', 'Geometrie ZŠ', {
          'Úhly': {'G'},
        }),
      ],
    );

    await tester.tap(domainRow(statistics));
    await tester.pumpAndSettle();
    expect(find.text('Statistika pro ZŠ'), findsNothing);
    expect(startEnabled(tester), isTrue);

    await tapStart(tester);

    final result = await choice;
    expect(result, isNotNull);
    expect(result!.domainCodes, {'G'});
    // The statistics lesson is still "checked" underneath, but it is not on
    // offer for the chosen domain, so it must not leak into the quiz.
    expect(result.lessonKeys, {'c2/Úhly'});
  });

  testWidgets('clearing every domain drops the domain filter and brings '
      'every course back, vector-less ones included (BR-JTY4AJ)',
      (tester) async {
    final choice = await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Statistika pro ZŠ', {
          'Průměr': {'S'},
        }),
        course('c2', 'Gramatika II', {
          'Slova po M': const {},
        }),
        course('c3', 'Geometrie ZŠ', {
          'Úhly': {'G'},
        }),
      ],
    );
    expect(find.text('Gramatika II'), findsNothing);

    await tester.tap(domainRow(statistics));
    await tester.tap(domainRow(geometry));
    await tester.pumpAndSettle();

    expect(find.text('Statistika pro ZŠ'), findsOneWidget);
    expect(find.text('Gramatika II'), findsOneWidget);
    expect(find.text('Geometrie ZŠ'), findsOneWidget);
    expect(startEnabled(tester), isTrue);

    await tapStart(tester);

    final result = await choice;
    expect(result, isNotNull);
    expect(result!.domainCodes, isEmpty);
    expect(result.lessonKeys, {'c1/Průměr', 'c2/Slova po M', 'c3/Úhly'});
  });

  testWidgets('a checked lesson hidden by the domain pick is not a choice',
      (tester) async {
    final choice = await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Statistika pro ZŠ', {
          'Průměr': {'S'},
        }),
        course('c2', 'Geometrie ZŠ', {
          'Úhly': {'G'},
        }),
      ],
    );

    // Uncheck the one geometry course, then narrow to geometry: the checked
    // statistics course is off the list, so nothing on offer is checked —
    // yet the domain pick alone still carries the quiz (BR-JTY4AJ).
    await tester.tap(find.text('Geometrie ZŠ'));
    await tester.tap(domainRow(statistics));
    await tester.pumpAndSettle();
    expect(find.text('Statistika pro ZŠ'), findsNothing);
    expect(startEnabled(tester), isTrue);

    await tapStart(tester);
    final result = await choice;
    expect(result!.domainCodes, {'G'});
    expect(result.lessonKeys, isEmpty);
  });

  testWidgets('Start stays dead only with nothing checked anywhere',
      (tester) async {
    await openDialog(
      tester,
      domains: const [geometry, statistics],
      courses: [
        course('c1', 'Statistika pro ZŠ', {
          'Průměr': {'S'},
        }),
        course('c2', 'Geometrie ZŠ', {
          'Úhly': {'G'},
        }),
      ],
    );

    await tester.tap(domainRow(statistics));
    await tester.tap(domainRow(geometry));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistika pro ZŠ'));
    await tester.tap(find.text('Geometrie ZŠ'));
    await tester.pumpAndSettle();
    expect(startEnabled(tester), isFalse);

    await tapStart(tester);
    expect(find.text('Spustit kvíz'), findsOneWidget); // still open
  });

  testWidgets('offers every lesson when the pool carries no domains',
      (tester) async {
    await openDialog(
      tester,
      domains: const [],
      courses: [
        course('c1', 'Gramatika II', {
          'Slova po M': const {},
          'Slova po Z': const {},
        }),
        course('c2', 'Co umí EDU AI asistent', {
          'Odměny': const {},
        }),
      ],
    );

    expect(find.text('Gramatika II'), findsOneWidget);
    expect(find.text('Co umí EDU AI asistent'), findsOneWidget);
    expect(startEnabled(tester), isTrue);
  });
}
