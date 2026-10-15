import 'package:eduai/core/elo/gpf_structure.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/widgets/global_quiz_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The entry dialog used to demand a checkbox in *every* section, so a student
/// who only cared about one axis — "just this course", "just these domains" —
/// found Start dead (BR-JTY4AJ). An emptied section now means "no filter on
/// that axis"; only an entirely empty dialog blocks Start.
///
/// The lessons carry domain codes because a course is listed next to a domain
/// pick only while it holds a task in a checked domain (BR-RQMMS5); the
/// single-axis rules under test are the same either way.
void main() {
  GlobalQuizEntryChoice? choice;

  Future<void> pump(WidgetTester tester) async {
    choice = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                choice = await showDialog<GlobalQuizEntryChoice>(
                  context: context,
                  builder: (_) => GlobalQuizEntryDialog(
                    domains: GpfStructure.domains.take(2).toList(),
                    domainNames: const {'N': 'Čísla', 'M': 'Míra'},
                    courses: const [
                      GlobalQuizCourseNode(
                        courseId: 'c1',
                        title: 'Gramatika II',
                        lessons: [
                          GlobalQuizLessonOption(
                            key: 'c1::l1',
                            title: 'Slova po M',
                            domainCodes: {'N'},
                          ),
                          GlobalQuizLessonOption(
                            key: 'c1::l2',
                            title: 'Slova po Z',
                            domainCodes: {'N'},
                          ),
                        ],
                      ),
                      GlobalQuizCourseNode(
                        courseId: 'c2',
                        title: 'Co umí EDU AI asistent',
                        lessons: [
                          GlobalQuizLessonOption(
                            key: 'c2::l1',
                            title: 'AI asistent',
                            domainCodes: {'M'},
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // A plain checkbox row keeps its box in the same Row as its label.
  Finder boxNextTo(Finder label) => find
      .descendant(
        of: find.ancestor(of: label, matching: find.byType(Row)).first,
        matching: find.byType(Checkbox),
      )
      .first;

  // A multi-lesson course sits behind an expander, headed by its own checkbox;
  // a single-lesson course collapses into a plain row.
  Finder courseBox(String title) => find
      .descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(ExpansionTile),
        ),
        matching: find.byType(Checkbox),
      )
      .first;

  Future<void> clearCourses(WidgetTester tester) async {
    await tester.tap(courseBox('Gramatika II'));
    await tester.pumpAndSettle();
    await tester.tap(boxNextTo(find.text('Co umí EDU AI asistent')));
    await tester.pumpAndSettle();
  }

  Future<void> clearDomains(WidgetTester tester) async {
    for (final name in ['Čísla', 'Míra']) {
      await tester.tap(boxNextTo(find.textContaining(name)));
      await tester.pumpAndSettle();
    }
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.globalQuizEntryStart));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on domains alone when no course is checked', (
    tester,
  ) async {
    await pump(tester);
    await clearCourses(tester);
    await start(tester);

    expect(choice, isNotNull);
    expect(choice!.domainCodes, {'N', 'M'});
    // No course filter — the draw keeps the whole pool.
    expect(choice!.lessonKeys, isEmpty);
  });

  testWidgets('starts on courses alone when no domain is checked', (
    tester,
  ) async {
    await pump(tester);
    await clearDomains(tester);
    await start(tester);

    expect(choice, isNotNull);
    expect(choice!.domainCodes, isEmpty);
    expect(choice!.lessonKeys, {'c1::l1', 'c1::l2', 'c2::l1'});
  });

  testWidgets('keeps Start dead when nothing at all is checked', (
    tester,
  ) async {
    await pump(tester);
    await clearDomains(tester);
    await clearCourses(tester);
    await start(tester);

    // The dialog is still up and returned nothing.
    expect(choice, isNull);
    expect(find.text(AppStrings.globalQuizEntryStart), findsOneWidget);
  });
}
