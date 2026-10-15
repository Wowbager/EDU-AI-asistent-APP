import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/pages/lesson_detail/network_image.dart';
import 'package:eduai/widgets/lesson_image.dart';
import 'package:eduai/widgets/step_content_renderer.dart';

/// BR-5VYB78 — lesson images were drawn with `width: double.infinity`, so a
/// small picture was blown up across the whole card. It must stop at its own
/// resolution (100 %) and only ever scale *down* when the card is narrower.
void main() {
  const url = 'https://cdn.example.test/schema.png';

  /// Parks a decoded [width]x[height] image under the key [LessonImage]
  /// resolves to, so the widget paints without touching the network.
  Future<void> primeImage(WidgetTester tester, int width, int height) async {
    late final ui.Image decoded;
    await tester.runAsync(() async {
      decoded = await createTestImage(width: width, height: height);
    });
    PaintingBinding.instance.imageCache.putIfAbsent(
      const LessonImageProvider(url),
      () => OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: decoded)),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget child,
      {double cardWidth = 900}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: cardWidth, child: child)),
      ),
    ));
    await tester.pump(); // let the primed completer deliver its frame
  }

  tearDown(() => PaintingBinding.instance.imageCache.clear());

  testWidgets('block image stops at its own resolution on a wide card',
      (tester) async {
    await primeImage(tester, 320, 160);

    await pump(
      tester,
      const LessonBlockImage(image: StepImage(url: url)),
    );

    expect(tester.getSize(find.byType(Image)), const Size(320, 160));
  });

  testWidgets('block image scales down when the card is narrower',
      (tester) async {
    await primeImage(tester, 320, 160);

    await pump(
      tester,
      const LessonBlockImage(image: StepImage(url: url)),
      cardWidth: 160,
    );

    expect(tester.getSize(find.byType(Image)), const Size(160, 80));
  });

  testWidgets('block image is centred once it no longer fills the card',
      (tester) async {
    await primeImage(tester, 320, 160);

    await pump(
      tester,
      const LessonBlockImage(image: StepImage(url: url)),
    );

    final picture = tester.getRect(find.byType(Image));
    final card = tester.getRect(find.byType(LessonBlockImage));
    expect(picture.center.dx, card.center.dx);
  });

  testWidgets('step renderer draws a step image at its own resolution',
      (tester) async {
    await primeImage(tester, 240, 120);

    await pump(
      tester,
      const StepContentRenderer(
        step: BlockStep(
          stepId: 's1',
          type: StepType.image,
          image: StepImage(url: url),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Image)), const Size(240, 120));
  });
}
