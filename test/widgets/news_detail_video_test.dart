import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/data/repositories/news_repository.dart';
import 'package:eduai/models/news_model.dart';
import 'package:eduai/pages/news_detail_page.dart';
import 'package:eduai/widgets/video_embed.dart';

// Regression test for BR-8JA266: a video pasted into a news body as markdown
// (![](https://…/clip.mp4)) rendered as a broken image, because the detail page
// handed the whole body to the markdown renderer, which decodes ![] as a
// picture. The detail page must render it as a player instead.

class _FakeNewsRepository implements NewsRepository {
  final String body;
  _FakeNewsRepository(this.body);

  @override
  Future<NewsItem> fetchDetail(int id) async => NewsItem(
        id: id,
        title: 'Novinka',
        perex: 'perex',
        body: body,
        publishedAt: DateTime(2026, 8, 5),
        isRead: false,
      );

  @override
  Future<int> markRead(int id) async => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpDetail(WidgetTester tester, String body) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        newsRepositoryProvider.overrideWithValue(_FakeNewsRepository(body)),
      ],
      child: const MaterialApp(home: NewsDetailPage(id: 1)),
    ),
  );
  await tester.pump(); // resolve the detail future
  await tester.pump();
}

void main() {
  testWidgets('news body with a markdown video renders a player',
      (tester) async {
    await _pumpDetail(
      tester,
      'Máme novou lekci!\n\n![](https://cdn/clip.mp4)\n\nMrkni na to.',
    );

    expect(find.byType(AppVideoEmbed), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Novinka'), findsOneWidget);
  });

  testWidgets('news body without a video renders no player', (tester) async {
    await _pumpDetail(tester, 'Jen text bez média.');

    expect(find.byType(AppVideoEmbed), findsNothing);
  });
}
