// BR-BCNXAP — in the course hero the action row (Lekce / Cvičení / Kvíz) sat
// in the text column beside the 160px icon, with "Uložit kurz" pinned to its
// right. On tablet widths that left the three buttons under ~340px between
// them; a Row does not clip, so their labels painted over each other and over
// the save button.
//
// The row now drops below the icon and takes the hero's full width as soon as
// the text column is too narrow for it.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/layout/breakpoints.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/main.dart' show routeObserver;
import 'package:eduai/models/course_model.dart';
import 'package:eduai/pages/course_detail_page.dart'
    show CourseDetailPage, courseHeroActionButtonsKey;

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

/// An emoji none of the generated lesson icons use, so it identifies the hero's
/// icon tile on its own.
const _courseEmoji = '🧪';

Course _course() => Course.fromJsonData(
      id: 'c-1',
      data: {
        'name': '(Ne)rovnice ZŠ',
        'emoji': _courseEmoji,
        'description': 'V tomto kurzu si projdeme rovnice a nerovnice.',
        'blocks': [
          {
            'block_id': 'b-1',
            'type': 'question',
            'question': '2 + 2?',
            'options': ['3', '4'],
            'correct_answer': 1,
          },
        ],
        'lessons': [
          {
            'lesson_id': 'l-1',
            'title': 'Rovnice',
            'blocks': [
              {'block_id': 'b-1', 'order': 0},
            ],
          },
        ],
      },
    );

Future<void> _pumpCourse(WidgetTester tester, double width) async {
  _ignoreOverflow();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 1400);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  // The page reads course progress out of the database on the first frame; the
  // real one opens a file and leaves a timer pending in the test.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

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
        home: CourseDetailPage(course: _course()),
      ),
    ),
  );
  await tester.pump();
}

Rect _rectOf(WidgetTester tester, Finder finder) =>
    tester.getRect(finder.first);

void main() {
  final saveButton = find.text(AppStrings.courseSaveButton);
  final buttons = find.byKey(courseHeroActionButtonsKey);
  final icon = find.text(_courseEmoji);

  group('course hero actions', () {
    testWidgets('drop below the icon on a tablet width', (tester) async {
      await _pumpCourse(tester, 1024);

      final iconRect = _rectOf(tester, icon);
      final group = _rectOf(tester, buttons);

      expect(group.top, greaterThan(iconRect.bottom),
          reason: 'the action row belongs under the course icon here');
      expect(group.left, lessThanOrEqualTo(iconRect.left),
          reason: 'and it starts at the hero edge, not beside the icon');
      // The bug in one number: squeezed between the icon and "Uložit kurz" the
      // group only had ~290px, and three labelled buttons need more than that.
      expect(group.width, closeTo(kHeroActionsMaxWidth, 1),
          reason: 'full width means the buttons get their designed size');
    });

    testWidgets('stay beside the icon on a desktop width', (tester) async {
      await _pumpCourse(tester, 1600);

      final iconRect = _rectOf(tester, icon);
      final group = _rectOf(tester, buttons);
      final save = _rectOf(tester, saveButton);

      expect(group.left, greaterThan(iconRect.right),
          reason: 'the desktop artboard keeps the row in the text column');
      expect(group.width, closeTo(kHeroActionsMaxWidth, 1));
      expect(save.center.dy, closeTo(group.center.dy, 8),
          reason: 'save stays on the same line as the actions');
      expect(save.left, greaterThan(group.right),
          reason: 'and to the right of them');
    });
  });

  group('heroActionRowFits', () {
    test('rejects the widths the text column has on a tablet', () {
      // 1024px viewport: 264px sidebar, 32px page padding, 24px card padding,
      // then the 160px icon and its 24px gap.
      expect(heroActionRowFits(1024 - 264 - 64 - 48 - 160 - 24), isFalse);
      expect(heroActionRowFits(kHeroActionsMinWidth), isFalse);
    });

    test('accepts a desktop text column', () {
      expect(heroActionRowFits(1440 - 264 - 64 - 48 - 160 - 24), isTrue);
      expect(
        heroActionRowFits(
            kHeroActionsMinWidth + kHeroActionsGap + kHeroSaveButtonWidth),
        isTrue,
      );
    });
  });
}
