// BR-M2EZY6 — on a desktop the course page's lesson list stopped after five
// lessons behind a "Zobrazit všechny lekce" toggle, and a longer lesson title
// was cut to one line with an ellipsis. The phone list shows every lesson and
// wraps its titles.
//
// The wide list now shows every lesson, and a title wraps onto a second line.
// The title also gets two thirds of the row's free width: before, it split that
// width evenly with the short "N otázek · M min" meta, whose unused half sat as
// dead space after the action button.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/main.dart' show routeObserver;
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/course_detail_page.dart' show CourseDetailPage;

/// The test-only Ahem font is far wider than the real one, so labels overflow
/// their rows. Cosmetic and test-only — same suppression the other shell tests
/// use.
void _ignoreOverflow() {
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);
}

const _lessonCount = 8;

/// Too long for one line of the title column at the reporter's width, short
/// enough for two.
const _longTitle = 'Lineární rovnice s neznámou ve jmenovateli';

String _titleOf(int i) => i == 2 ? _longTitle : 'Téma ${i + 1}';

Course _course() => Course.fromJsonData(
      id: 'c-1',
      data: {
        'name': '(Ne)rovnice ZŠ',
        'emoji': '🧪',
        'blocks': [
          for (var i = 0; i < _lessonCount; i++)
            {
              'block_id': 'b-$i',
              'type': 'question',
              'question': '$i + 1?',
              'options': ['$i', '${i + 1}'],
              'correct_answer': 1,
            },
        ],
        'lessons': [
          for (var i = 0; i < _lessonCount; i++)
            {
              'lesson_id': 'l-$i',
              'name': _titleOf(i),
              'blocks': [
                {'block_id': 'b-$i', 'order': 0},
              ],
            },
        ],
      },
    );

Future<Course> _pumpCourse(WidgetTester tester, double width) async {
  _ignoreOverflow();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2400);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  // The page reads course progress out of the database on the first frame; the
  // real one opens a file and leaves a timer pending in the test.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  final course = _course();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        navigatorObservers: [routeObserver],
        home: CourseDetailPage(course: course),
      ),
    ),
  );
  await tester.pump();
  return course;
}

void main() {
  // The reporter's viewport: Windows, Chrome, 1536px wide.
  const desktopWidth = 1536.0;

  testWidgets('lists every lesson without a "show all" toggle', (tester) async {
    await _pumpCourse(tester, desktopWidth);

    for (var i = 0; i < _lessonCount; i++) {
      expect(find.text(_titleOf(i)), findsOneWidget,
          reason: 'lesson ${i + 1} belongs in the list without expanding it');
    }
    expect(find.text(AppStrings.courseShowAllLessons(_lessonCount)),
        findsNothing);
    expect(find.text(AppStrings.courseShowFewerLessons), findsNothing);
  });

  testWidgets('wraps a long lesson title onto a second line', (tester) async {
    await _pumpCourse(tester, desktopWidth);

    final long = find.text(_longTitle);
    final short = find.text(_titleOf(0));
    final paragraph = tester.renderObject<RenderParagraph>(long);

    expect(paragraph.didExceedMaxLines, isFalse,
        reason: 'the whole title fits once it may wrap');
    expect(tester.getSize(long).height,
        closeTo(2 * tester.getSize(short).height, 1),
        reason: 'two lines, not one line with an ellipsis');
  });

  testWidgets('gives the title two thirds of the free row width',
      (tester) async {
    final course = await _pumpCourse(tester, desktopWidth);

    final lesson = course.lessons.first;
    final meta = find.text(
        '${AppStrings.courseQuestionsCount(lesson.questionCount)} · '
        '${AppStrings.courseDurationMin(lesson.durationMinutes)}');
    final title = tester.getRect(find.text(_longTitle));
    final metaRect = tester.getRect(meta.first);

    // A wrapped title fills its column, and the meta fills its slot, so their
    // widths are the two shares of the row.
    expect(title.width, closeTo(2 * metaRect.width, 1));
  });
}
