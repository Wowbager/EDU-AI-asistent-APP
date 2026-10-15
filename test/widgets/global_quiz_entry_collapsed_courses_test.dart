import 'package:eduai/widgets/global_quiz_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The global quiz entry dialog used to render every lesson of every course at
/// once, so a student with a handful of courses opened the popup onto a wall of
/// checkboxes (BR-9XFSMS). Lessons now hide behind a per-course expander,
/// collapsed unless the course is the only one offered — the same shape the
/// practice scope picker already uses.
void main() {
  Future<void> pump(WidgetTester tester, List<GlobalQuizCourseNode> courses) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlobalQuizEntryDialog(
          domains: const [],
          domainNames: const {},
          courses: courses,
        ),
      ),
    ));
  }

  GlobalQuizCourseNode course(String id, String title, List<String> lessons) {
    return GlobalQuizCourseNode(
      courseId: id,
      title: title,
      lessons: [
        for (final lesson in lessons)
          GlobalQuizLessonOption(key: '$id/$lesson', title: lesson),
      ],
    );
  }

  testWidgets('keeps a multi-course list collapsed to course titles',
      (tester) async {
    await pump(tester, [
      course('c1', 'Gramatika II', ['Slova po M', 'Slova po Z']),
      course('c2', 'Co umí EDU AI asistent', ['AI asistent', 'Odměny']),
    ]);

    expect(find.text('Gramatika II'), findsOneWidget);
    expect(find.text('Co umí EDU AI asistent'), findsOneWidget);
    expect(find.text('Slova po M'), findsNothing);
    expect(find.text('AI asistent'), findsNothing);
  });

  testWidgets('reveals the lessons once the course is expanded',
      (tester) async {
    await pump(tester, [
      course('c1', 'Gramatika II', ['Slova po M', 'Slova po Z']),
      course('c2', 'Co umí EDU AI asistent', ['AI asistent', 'Odměny']),
    ]);

    await tester.tap(find.text('Gramatika II'));
    await tester.pumpAndSettle();

    expect(find.text('Slova po M'), findsOneWidget);
    expect(find.text('Slova po Z'), findsOneWidget);
    // Expanding one course leaves the others alone.
    expect(find.text('AI asistent'), findsNothing);
  });

  testWidgets('opens the only course on offer up front', (tester) async {
    await pump(tester, [
      course('c1', 'Gramatika II', ['Slova po M', 'Slova po Z']),
    ]);

    expect(find.text('Slova po M'), findsOneWidget);
    expect(find.text('Slova po Z'), findsOneWidget);
  });

  testWidgets('course checkbox still clears and restores all of its lessons',
      (tester) async {
    await pump(tester, [
      course('c1', 'Gramatika II', ['Slova po M', 'Slova po Z']),
      course('c2', 'Co umí EDU AI asistent', ['AI asistent', 'Odměny']),
    ]);

    // Collapsed, a course's only checkbox is the one heading it.
    Finder courseBoxFinder(String title) => find
        .descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(ExpansionTile),
          ),
          matching: find.byType(Checkbox),
        )
        .first;

    Checkbox courseBox(String title) =>
        tester.widget<Checkbox>(courseBoxFinder(title));

    expect(courseBox('Gramatika II').value, isTrue);

    await tester.tap(courseBoxFinder('Gramatika II'));
    await tester.pumpAndSettle();
    expect(courseBox('Gramatika II').value, isFalse);
    expect(courseBox('Co umí EDU AI asistent').value, isTrue);

    await tester.tap(courseBoxFinder('Gramatika II'));
    await tester.pumpAndSettle();
    expect(courseBox('Gramatika II').value, isTrue);
  });
}
