// BR-BX9AA4 — "Nefunguje grafika v off-line režimu lekcí": offline, image
// blocks showed a broken grey box and markdown pictures showed nothing, even
// for lessons already gone through. After reconnecting they stayed broken
// until some other action in the lesson rebuilt them.
//
// Lesson pictures now load through LessonImageCache: the copy kept on the
// device stands in when the download fails, and a picture that failed loads
// again as soon as the device is back online.
//
//   flutter test test/widgets/lesson_image_offline_test.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/media/lesson_image_cache.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/lesson_detail/network_image.dart';
import 'package:eduai/widgets/lesson_image.dart';
import 'package:eduai/widgets/markdown_latex_widget.dart';

import '../core/media/fake_lesson_image_backend.dart';

void main() {
  const url = 'https://pub-x.r2.dev/assets/COURSE/graf.png';

  late LessonImageCache previous;
  late FakeLessonImageBackend backend;
  late StreamController<void> reconnects;

  setUp(() {
    previous = LessonImageCache.instance;
    backend = FakeLessonImageBackend();
    reconnects = StreamController<void>.broadcast();
    LessonImageCache.instance = LessonImageCache(backend: backend)
      ..setConnectivityForTesting(
        isOnline: () async => backend.online,
        reconnects: reconnects.stream,
      );
  });

  tearDown(() {
    LessonImageCache.instance = previous;
    PaintingBinding.instance.imageCache.clear();
    reconnects.close();
  });

  Future<Uint8List> png(int width, int height) async {
    final image = await createTestImage(width: width, height: height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Loads [provider] for real (decoding needs real async), which also leaves
  /// the decoded picture in the image cache for the widget to find.
  Future<ImageInfo> resolve(ImageProvider provider) {
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info);
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// The phone saw the lesson (or prefetched the course) while online, then
  /// lost signal.
  Future<void> keptThenOffline(WidgetTester tester) async {
    await tester.runAsync(() async {
      backend.disk[url] = await png(40, 20);
      backend.online = false;
      final info = await resolve(const LessonImageProvider(url));
      expect(info.image.width, 40);
    });
  }

  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))),
        ),
      );

  testWidgets('offline, an image block shows the kept picture, not the '
      'broken-image box', (tester) async {
    await keptThenOffline(tester);

    await tester.pumpWidget(host(const LessonBlockImage(image: StepImage(url: url))));
    await tester.pump();

    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(tester.getSize(find.byType(Image)), const Size(40, 20));
    expect(backend.fetched, [url], reason: 'the download was tried first');
  });

  testWidgets('offline, a markdown picture shows the kept picture instead of '
      'vanishing', (tester) async {
    await keptThenOffline(tester);

    await tester.pumpWidget(host(
      const MarkdownLatexWidget(content: 'Graf funkce:\n\n![graf]($url)'),
    ));
    await tester.pump();

    expect(find.byType(LessonImage), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(40, 20));
  });

  testWidgets('an <img> in lesson HTML goes through the lesson image cache',
      (tester) async {
    await tester.pumpWidget(host(Html(
      data: '<p>Graf:</p><img src="$url">',
      extensions: lessonHtmlImageExtensions(),
    )));
    await tester.pump();

    expect(find.byType(LessonImage), findsOneWidget);
  });

  testWidgets('a picture that failed offline loads again once the device is '
      'back online', (tester) async {
    backend.online = false;

    await tester.pumpWidget(host(const LessonBlockImage(image: StepImage(url: url))));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(backend.fetched, hasLength(1));

    // Back online. Before, nothing happened here until some other action in
    // the lesson rebuilt the picture.
    await tester.runAsync(() async {
      backend.server[url] = await png(40, 20);
    });
    backend.online = true;
    reconnects.add(null);
    await tester.pump(); // the event reaches the picture
    await tester.pump(); // which rebuilds and loads again

    expect(backend.fetched, hasLength(2), reason: 'loaded again on reconnect');
    expect(find.byIcon(Icons.broken_image), findsNothing);
  });

  testWidgets('without a cache (web) the picture loads from its URL as before',
      (tester) async {
    LessonImageCache.instance = LessonImageCache(useDefaultBackend: false);

    await tester.pumpWidget(host(const LessonNetworkImage(rawUrl: url)));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, const NetworkImage(url));
    expect(backend.fetched, isEmpty);
  });
}
