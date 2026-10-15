import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/layout/breakpoints.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/news_repository.dart';
import 'package:eduai/models/news_model.dart';
import 'package:eduai/pages/news_detail_page.dart';
import 'package:eduai/pages/novinky_page.dart';

// Regression tests for BR-ZT56WM. On desktop the shell's `DesktopTopBar`
// already renders "Novinky", so the page rendering its own copy stacked two
// identical headings — and the feed sat in a 720px column with the rest of the
// monitor empty, because the page had no wide layout at all.

const _items = [
  _Item(1, 'První novinka'),
  _Item(2, 'Druhá novinka'),
];

class _Item {
  final int id;
  final String title;
  const _Item(this.id, this.title);

  NewsItem toModel({String? body}) => NewsItem(
        id: id,
        title: title,
        perex: 'perex $id',
        body: body,
        publishedAt: DateTime(2026, 8, 24),
        isRead: false,
      );
}

class _FakeNewsRepository implements NewsRepository {
  @override
  Future<NewsItem> fetchDetail(int id) async =>
      _items.firstWhere((i) => i.id == id).toModel(body: 'tělo článku $id');

  @override
  Future<int> markRead(int id) async => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        newsRepositoryProvider.overrideWithValue(_FakeNewsRepository()),
        newsListProvider.overrideWith(
          (ref) async => [for (final i in _items) i.toModel()],
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: NovinkyPage())),
    ),
  );
  await tester.pump(); // resolve the list future
  await tester.pump();
}

void main() {
  testWidgets('desktop drops the page heading — the top bar already has it',
      (tester) async {
    await _pumpAt(tester, 1440);

    expect(find.text(AppStrings.novinkyTitle), findsNothing);
  });

  testWidgets('phone keeps its own heading — there is no top bar there',
      (tester) async {
    await _pumpAt(tester, kCompactMaxWidth - 1);

    expect(find.text(AppStrings.novinkyTitle), findsOneWidget);
  });

  testWidgets('desktop shows the feed and an article pane side by side',
      (tester) async {
    await _pumpAt(tester, 1440);

    // Nothing picked yet: the feed plus a prompt, no article.
    expect(find.text('První novinka'), findsOneWidget);
    expect(find.text(AppStrings.novinkyPickArticle), findsOneWidget);
    expect(find.byType(NewsDetailPage), findsNothing);

    await tester.tap(find.text('První novinka'));
    await tester.pump();
    await tester.pump(); // resolve the detail future

    // The article opens beside the feed rather than covering it.
    expect(find.text('První novinka'), findsNWidgets(2)); // card + heading
    expect(find.text('Druhá novinka'), findsOneWidget);
    expect(find.text(AppStrings.novinkyPickArticle), findsNothing);

    final detail = tester.widget<NewsDetailPage>(find.byType(NewsDetailPage));
    expect(detail.id, 1);
    expect(detail.embedded, isTrue);
  });

  testWidgets('switching articles rebuilds the pane', (tester) async {
    await _pumpAt(tester, 1440);

    await tester.tap(find.text('První novinka'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Druhá novinka').first);
    await tester.pump();
    await tester.pump();

    // Keyed by id, so the second article replaces the first rather than
    // reusing its already-resolved future.
    expect(tester.widget<NewsDetailPage>(find.byType(NewsDetailPage)).id, 2);
    expect(find.text('tělo článku 2'), findsOneWidget);
  });

  testWidgets('phone opens an article as a route, not a pane', (tester) async {
    await _pumpAt(tester, kCompactMaxWidth - 1);

    await tester.tap(find.text('První novinka'));
    await tester.pumpAndSettle();

    final detail = tester.widget<NewsDetailPage>(find.byType(NewsDetailPage));
    expect(detail.embedded, isFalse);
    // The pushed route covers the feed.
    expect(find.text('Druhá novinka'), findsNothing);
  });
}
