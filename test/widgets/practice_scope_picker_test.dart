// BR-K4KHJZ — the practice screen lets a student pick what to practise:
// subject → areas, multi-select across subjects, nothing selected = everything.
//
// Covers the wiring the pure tests can't: the picker renders the tree, a tap
// narrows the scope and persists it, and a scope with nothing due says so
// instead of looking like "you're done".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eduai/core/practice/practice_filter.dart';
import 'package:eduai/core/practice/practice_scope.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/providers/practice_providers.dart';
import 'package:eduai/core/services/practice_filter_store.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/practice_page.dart';

final _scope = [
  const PracticeSubject(
    id: 'row-A',
    title: 'Rovnice',
    courseIds: {'A'},
    areas: [
      PracticeArea(
        lessonId: 'L1',
        title: 'Lineární rovnice',
        keys: {'A|L1'},
        dueCount: 2,
        totalCount: 4,
      ),
      PracticeArea(
        lessonId: 'L2',
        title: 'Soustavy',
        keys: {'A|L2'},
        dueCount: 1,
        totalCount: 3,
      ),
    ],
  ),
  const PracticeSubject(
    id: 'row-B',
    title: 'Zlomky',
    courseIds: {'B'},
    areas: [
      PracticeArea(
        lessonId: 'L1',
        title: 'Krácení',
        keys: {'B|L1'},
        dueCount: 0,
        totalCount: 2,
      ),
    ],
  ),
];

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  int dueBlocks = 3,
  PracticeFilter stored = PracticeFilter.all,
  Future<List<PracticeSubject>> Function()? loadScope,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = PracticeFilterStore(prefs);
  await store.write(stored);

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    activeUserProvider.overrideWith((ref) async => null),
    practiceScopeProvider
        .overrideWith((ref) => loadScope?.call() ?? Future.value(_scope)),
    playablePracticeProvider.overrideWith(
      (ref) async => (
        blocks: List.generate(
          dueBlocks,
          (i) => ContentBlock(blockId: 'b$i', type: BlockType.question),
        ),
        courseId: 'A',
      ),
    ),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PracticePage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders subjects with their areas', (tester) async {
    await _pumpPage(tester);

    expect(find.text(AppStrings.practiceScopeTitle), findsOneWidget);
    expect(find.text('Rovnice'), findsOneWidget);
    expect(find.text('Zlomky'), findsOneWidget);
    // Areas live behind the subject's expander.
    await tester.tap(find.text('Rovnice'));
    await tester.pumpAndSettle();
    expect(find.text('Lineární rovnice'), findsOneWidget);
    expect(find.text('Soustavy'), findsOneWidget);
  });

  testWidgets('with nothing selected the whole deck is in scope',
      (tester) async {
    final container = await _pumpPage(tester);

    expect(container.read(practiceFilterProvider).isAll, isTrue);
    expect(find.text(AppStrings.practiceScopeAllHint), findsOneWidget);
  });

  testWidgets('unticking an area narrows the scope and persists it',
      (tester) async {
    final container = await _pumpPage(tester);

    await tester.tap(find.text('Rovnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lineární rovnice'));
    await tester.pumpAndSettle();

    final filter = container.read(practiceFilterProvider);
    expect(filter.allowsArea('A', 'L1'), isFalse);
    expect(filter.allowsArea('A', 'L2'), isTrue);
    expect(filter.allowsArea('B', 'L1'), isTrue);

    // Written through immediately — the selection has to survive a restart.
    final prefs = container.read(sharedPreferencesProvider);
    expect(PracticeFilterStore(prefs).read(), filter);
  });

  testWidgets('unticking a subject drops all of its areas', (tester) async {
    final container = await _pumpPage(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final filter = container.read(practiceFilterProvider);
    expect(filter.allowsArea('A', 'L1'), isFalse);
    expect(filter.allowsArea('A', 'L2'), isFalse);
    expect(filter.allowsArea('B', 'L1'), isTrue);
  });

  testWidgets('a scope with nothing due explains itself and can be reset',
      (tester) async {
    final container = await _pumpPage(
      tester,
      dueBlocks: 0,
      stored: const PracticeFilter(lessonKeys: {'B|L1'}),
    );

    expect(find.text(AppStrings.practiceScopeEmpty), findsOneWidget);

    await tester.tap(find.text(AppStrings.practiceScopeSelectAll).first);
    await tester.pumpAndSettle();

    expect(container.read(practiceFilterProvider).isAll, isTrue);
    expect(find.text(AppStrings.practiceScopeEmpty), findsNothing);
  });

  // BR-27AEMT: the scope is now invalidated whenever cards change, including
  // by a sync that lands while this page is open. That refresh must not blink
  // the picker away or fold up what the student had expanded.
  testWidgets('the picker stays put while the scope reloads', (tester) async {
    var loads = 0;
    final reload = Completer<List<PracticeSubject>>();
    final container = await _pumpPage(
      tester,
      loadScope: () => loads++ == 0 ? Future.value(_scope) : reload.future,
    );

    await tester.tap(find.text('Rovnice'));
    await tester.pumpAndSettle();
    expect(find.text('Lineární rovnice'), findsOneWidget);

    container.invalidate(practiceScopeProvider);
    // One frame for Riverpod to flush the invalidation, one to rebuild.
    await tester.pump();
    await tester.pump();

    expect(loads, 2, reason: 'precondition: the scope is reloading');
    expect(find.text(AppStrings.practiceScopeTitle), findsOneWidget);
    expect(find.text('Lineární rovnice'), findsOneWidget);

    reload.complete(_scope);
    await tester.pumpAndSettle();
    expect(find.text('Lineární rovnice'), findsOneWidget);
  });
}
