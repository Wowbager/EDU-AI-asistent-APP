// BR-BX9AA4 — lesson pictures were gone offline: `Image.network` only keeps
// what it loads in memory, so a downloaded course had its text but none of its
// pictures once the phone lost signal. LessonImageCache keeps them on disk.
//
//   flutter test test/core/media/lesson_image_cache_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/media/course_image_urls.dart';
import 'package:eduai/core/media/lesson_image_backend_io.dart';
import 'package:eduai/core/media/lesson_image_cache.dart';

import 'fake_lesson_image_backend.dart';

Uint8List bytesOf(List<int> values) => Uint8List.fromList(values);

void main() {
  const a = 'https://pub-x.r2.dev/assets/a.png';
  const b = 'https://pub-x.r2.dev/assets/b.jpg';

  group('LessonImageCache.load', () {
    test('online: downloads and keeps a copy on disk', () async {
      final backend = FakeLessonImageBackend(server: {a: bytesOf([1, 2, 3])});
      final cache = LessonImageCache(backend: backend);

      expect(await cache.load(a), [1, 2, 3]);
      expect(backend.disk[a], [1, 2, 3]);
    });

    test('offline: the copy on disk stands in', () async {
      final backend = FakeLessonImageBackend(server: {a: bytesOf([1, 2, 3])});
      final cache = LessonImageCache(backend: backend);
      await cache.load(a);

      backend.online = false;
      expect(await cache.load(a), [1, 2, 3]);
    });

    test('online again: a picture replaced under the same URL is fresh',
        () async {
      final backend = FakeLessonImageBackend(server: {a: bytesOf([1])});
      final cache = LessonImageCache(backend: backend);
      await cache.load(a);

      backend.server[a] = bytesOf([2]);
      expect(await cache.load(a), [2]);
      expect(backend.disk[a], [2]);
    });

    test('offline with no copy: the download error comes through', () async {
      final backend = FakeLessonImageBackend()..online = false;
      final cache = LessonImageCache(backend: backend);

      await expectLater(cache.load(a), throwsA(isA<SocketException>()));
    });
  });

  group('LessonImageCache.prefetch', () {
    test('downloads what is not on disk yet, a failure does not stop it',
        () async {
      final backend = FakeLessonImageBackend(server: {a: bytesOf([1]), b: bytesOf([2])});
      backend.disk[a] = bytesOf([9]);
      final cache = LessonImageCache(backend: backend)
        ..setConnectivityForTesting(isOnline: () async => true);

      await cache.prefetch([a, b, 'https://pub-x.r2.dev/assets/missing.png']);

      expect(backend.fetched, isNot(contains(a)), reason: 'already on disk');
      expect(backend.disk[a], [9]);
      expect(backend.disk[b], [2]);
    });

    test('does nothing offline', () async {
      final backend = FakeLessonImageBackend(server: {a: bytesOf([1])});
      final cache = LessonImageCache(backend: backend)
        ..setConnectivityForTesting(isOnline: () async => false);

      await cache.prefetch([a]);

      expect(backend.fetched, isEmpty);
    });

    test('stays off until the app hands over its connectivity', () async {
      final backend = FakeLessonImageBackend(server: {a: bytesOf([1])});

      await LessonImageCache(backend: backend).prefetch([a]);

      expect(backend.fetched, isEmpty);
    });

    test('no backend (web): nothing to do', () async {
      final cache = LessonImageCache(useDefaultBackend: false)
        ..setConnectivityForTesting(isOnline: () async => true);

      expect(cache.isSupported, isFalse);
      await cache.prefetch([a]);
    });
  });

  group('IoLessonImageBackend', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('lesson_images_test');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('keeps pictures as files and reads them back', () async {
      final backend = IoLessonImageBackend(directory: () async => temp);

      expect(await backend.contains(a), isFalse);
      expect(await backend.read(a), isNull);

      await backend.write(a, bytesOf([1, 2]));
      await backend.write(b, bytesOf([3]));
      await backend.write(a, bytesOf([4, 5, 6]));

      expect(await backend.contains(a), isTrue);
      expect(await backend.read(a), [4, 5, 6]);
      expect(await backend.read(b), [3]);
      expect(temp.listSync().whereType<File>(), hasLength(2),
          reason: 'one file per URL, no leftover .part files');
    });
  });

  group('courseImageUrls', () {
    test('finds pictures wherever the course JSON keeps them', () {
      final urls = courseImageUrls({
        'course_id': 'C1',
        'header_image': {'url': 'https://cdn.test/cover.png'},
        'lessons': [
          {
            'id': 'l1',
            'blocks': [
              {
                'type': 'text',
                'image': {'url': 'https://cdn.test/block', 'alt': 'x'},
                'steps': [
                  {'type': 'image', 'url': 'https://cdn.test/step-v2'},
                  {
                    'type': 'text',
                    'output_text':
                        'Viz obrázek:\n\n![graf](https://cdn.test/md.png "titulek")\n'
                            'a video ![](https://cdn.test/clip.mp4)',
                  },
                  {
                    'type': 'text',
                    'html': '<p><img class="x" src="https://cdn.test/html.webp"></p>',
                  },
                  {'static': {'image_url': 'https://cdn.test/legacy'}},
                  {
                    'question': {
                      'solution_image': {'url': 'https://cdn.test/solution'},
                      'options': [
                        {'feedback_image': {'url': 'https://cdn.test/feedback'}},
                      ],
                    },
                  },
                  {'type': 'video', 'url': 'https://cdn.test/lecture'},
                  {'type': 'image', 'url': 'https://www.youtube.com/watch?v=1'},
                  {'link': 'https://edu-ai.eu/wp-content/uploads/diagram.SVG'},
                ],
              },
            ],
          },
        ],
      });

      expect(urls, {
        'https://cdn.test/block',
        'https://cdn.test/step-v2',
        'https://cdn.test/md.png',
        'https://cdn.test/html.webp',
        'https://cdn.test/legacy',
        'https://cdn.test/solution',
        'https://cdn.test/feedback',
        'https://edu-ai.eu/wp-content/uploads/diagram.SVG',
      });
    });

    test('no data, no pictures', () {
      expect(courseImageUrls(null), isEmpty);
      expect(courseImageUrls({'lessons': []}), isEmpty);
    });
  });

  test('reconnects is quiet until connectivity is wired', () async {
    final cache = LessonImageCache(backend: FakeLessonImageBackend());
    final events = <void>[];
    final sub = cache.reconnects.listen(events.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, isEmpty);
  });
}
