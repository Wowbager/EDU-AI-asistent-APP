// Spec test for the course cover (BR-YKYXC6): admin's "Header Image (Course
// Cover)" landed in the course JSON but no card ever read it, so every course
// showed the emoji placeholder. Cards must paint the cover when there is one
// and keep the emoji when there isn't — including when the URL is dead.
//
// BR-MMAESQ: on web the cover kept dropping back to the emoji although the
// course JSON still carried it. Every cover went through the API image proxy,
// whose rate limit is one bucket shared by all web users; once it ran dry the
// load failed and the card fell back. Web now loads the cover straight from
// its URL (our R2 buckets answer CORS for the app) and keeps the proxy only
// as the second attempt.
//
// BR-NE9RTA: a course whose cover is an SVG (admin Files accepts them, and the
// admin preview shows them) still showed only the emoji, on web and Android
// alike. The cover went through Image.network, which cannot decode SVG, so
// every attempt failed into the fallback. SVG covers now go through
// flutter_svg, like SVG lesson pictures already do.
//
//   flutter test test/course_cover_image_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/sync/sync_status.dart';
import 'package:eduai/core/utils/image_url.dart';
import 'package:eduai/data/datasources/remote/course_remote_datasource.dart';
import 'package:eduai/data/repositories/user_course_repository.dart';
import 'package:eduai/models/course_card_view.dart';
import 'package:eduai/widgets/course_cover_image.dart';
import 'package:eduai/widgets/course_grid_card.dart';

UserCourse _course(Map<String, dynamic> courseData) {
  final now = DateTime(2026, 1, 1);
  return UserCourse(
    id: 'uc-1',
    userId: 'u-1',
    courseId: 'c-1',
    status: UserCourseStatus.downloaded,
    progressPercent: 0,
    completedLessons: 0,
    totalLessons: 0,
    currentLessonIndex: 0,
    timeSpentSeconds: 0,
    progressData: const {},
    downloadedVersion: 1,
    syncStatus: SyncStatus.synced,
    createdAt: now,
    updatedAt: now,
    courseName: 'Kurz',
    courseData: courseData,
  );
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 320, height: 420, child: child)),
    );

/// Keeps every HTTP request pending; see the SVG group below.
class _SilentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _SilentHttpClient();
}

class _SilentHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('CourseCoverImage.urlFrom', () {
    test('reads header_image.url out of the course JSON', () {
      expect(
        CourseCoverImage.urlFrom({
          'header_image': {'url': 'https://cdn.test/cover.png', 'alt': 'Cover'},
        }),
        'https://cdn.test/cover.png',
      );
    });

    test('is null without a cover, with a blank url, or on a bad shape', () {
      expect(CourseCoverImage.urlFrom(null), isNull);
      expect(CourseCoverImage.urlFrom(const {}), isNull);
      expect(CourseCoverImage.urlFrom({'header_image': {'alt': 'x'}}), isNull);
      expect(CourseCoverImage.urlFrom({'header_image': {'url': '  '}}), isNull);
      expect(CourseCoverImage.urlFrom({'header_image': 'nope'}), isNull);
    });
  });

  group('RemoteCourse.fromJson', () {
    Map<String, dynamic> listingJson(Map<String, dynamic> extra) => {
          'id': 1,
          'course_id': 'MAT_ROVNICE',
          'name': 'Rovnice',
          'version': 3,
          'status': 'published',
          'language': 'cs',
          'emoji': '🔢',
          'lesson_count': 4,
          'estimated_minutes': 60,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
          ...extra,
        };

    test('carries the listing cover into the local course data', () {
      final course = RemoteCourse.fromJson(listingJson({
        'header_image': {'url': 'https://cdn.test/cover.png', 'alt': 'Cover'},
      }));

      expect(
        CourseCoverImage.urlFrom(course.data),
        'https://cdn.test/cover.png',
      );
    });

    test('leaves the cover null when the listing has none', () {
      final course = RemoteCourse.fromJson(listingJson(const {}));

      expect(CourseCoverImage.urlFrom(course.data), isNull);
    });
  });

  group('CourseCardView.of', () {
    test('carries the cover through to the cards', () {
      final view = CourseCardView.of(_course({
        'name': 'Rovnice',
        'emoji': '🔢',
        'header_image': {'url': 'https://cdn.test/cover.png'},
      }));

      expect(view.coverImageUrl, 'https://cdn.test/cover.png');
    });

    test('leaves the cover null when the course has none', () {
      final view = CourseCardView.of(_course({'name': 'Rovnice'}));

      expect(view.coverImageUrl, isNull);
    });
  });

  group('CourseCoverImage', () {
    testWidgets('falls back to the emoji without a cover', (tester) async {
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: null, fallback: Text('🔢')),
      ));

      expect(find.text('🔢'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('loads the cover when there is one', (tester) async {
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(
          url: 'https://cdn.test/cover.png',
          fallback: Text('🔢'),
        ),
      ));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('keeps the emoji while the image has no frame yet',
        (tester) async {
      // The test HTTP client never returns an image, which is the same state
      // as a slow or dead URL: the card must stay filled, not blank.
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(
          url: 'https://cdn.test/cover.png',
          fallback: Text('🔢'),
        ),
      ));
      await tester.pump();

      expect(find.text('🔢'), findsOneWidget);
    });
  });

  group('CourseCoverImage.sourcesFor', () {
    const cover = 'https://pub-test.r2.dev/assets/MAT_ROVNICE/cover.jpg';

    test('on web, tries the cover URL itself before the API proxy', () {
      expect(
        CourseCoverImage.sourcesFor(cover, web: true),
        [cover, proxyImageUrl(cover)],
      );
    });

    test('off web, loads the cover URL only', () {
      expect(CourseCoverImage.sourcesFor(cover, web: false), [cover]);
    });

    test('never lists the same source twice', () {
      // Nothing to proxy for a non-http URL, so there is no second attempt.
      expect(
        CourseCoverImage.sourcesFor('assets/cover.png', web: true),
        ['assets/cover.png'],
      );
    });
  });

  group('CourseCoverImage on web', () {
    const cover = 'https://pub-test.r2.dev/assets/MAT_ROVNICE/cover.jpg';

    setUp(() => CourseCoverImage.debugWebOverride = true);
    tearDown(() => CourseCoverImage.debugWebOverride = null);

    // Every attempt so far, in order: a failed Image stays in the tree and
    // renders the next attempt from its errorBuilder.
    List<String> requested(WidgetTester tester) => tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as NetworkImage).url)
        .toList();

    testWidgets('loads the cover straight from its URL, not the proxy',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: cover, fallback: Text('🔢')),
      ));

      expect(requested(tester), [cover]);
    });

    testWidgets('retries through the API proxy when the direct load fails',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: cover, fallback: Text('🔢')),
      ));
      // The test HTTP client answers 400, so the direct load fails.
      await tester.pump();
      await tester.pump();

      expect(requested(tester), [cover, proxyImageUrl(cover)]);
      // Still filled while the proxy is working on it.
      expect(find.text('🔢'), findsOneWidget);
    });

    testWidgets('keeps the emoji once every source has failed',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: cover, fallback: Text('🔢')),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      // Two attempts and no more, and the card is never left blank.
      expect(requested(tester), [cover, proxyImageUrl(cover)]);
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('🔢'), findsOneWidget);
    });
  });

  group('CourseCoverImage with an SVG cover', () {
    // The shape of the cover in the report: an admin Files upload, served as
    // image/svg+xml from R2.
    const cover =
        'https://pub-test.r2.dev/assets/MAT_ZLOMKY_CVT/ikona_kurz_zlomku.svg';
    const artwork = '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 512 512"><circle cx="256" cy="256" r="244" '
        'fill="#2F80ED"/></svg>';

    // flutter_test's stub client answers 400 with an empty body. flutter_svg
    // reports that "Invalid SVG data" as an uncaught error, which fails the
    // test, so keep SVG loads pending instead, as a slow network would.
    late HttpOverrides? previousHttpOverrides;

    setUp(() {
      previousHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = _SilentHttpOverrides();
    });

    tearDown(() {
      HttpOverrides.global = previousHttpOverrides;
      CourseCoverImage.debugWebOverride = null;
      svg.cache.clear();
    });

    testWidgets('draws it with the SVG renderer, not Image', (tester) async {
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: cover, fallback: Text('🔢')),
      ));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('recognises it with a query string or an upper-case suffix',
        (tester) async {
      for (final url in ['$cover?v=3', cover.replaceAll('.svg', '.SVG')]) {
        await tester.pumpWidget(_wrap(
          CourseCoverImage(url: url, fallback: const Text('🔢')),
        ));

        expect(find.byType(SvgPicture), findsOneWidget, reason: url);
        expect(find.byType(Image), findsNothing, reason: url);
      }
    });

    testWidgets('keeps the emoji while the SVG is loading', (tester) async {
      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: cover, fallback: Text('🔢')),
      ));
      await tester.pump();

      expect(find.text('🔢'), findsOneWidget);
    });

    testWidgets('paints the SVG in place of the emoji once it has loaded',
        (tester) async {
      // A URL of its own: flutter_svg never lets go of a load that is still
      // pending, and the tests above leave theirs pending.
      const loaded = 'https://pub-test.r2.dev/assets/MAT_ZLOMKY_CVT/loaded.svg';

      // Seed flutter_svg's cache for the cover URL, as a finished download
      // would leave it.
      final bytes = await tester.runAsync(
        () => const SvgStringLoader(artwork).loadBytes(null),
      );
      svg.cache.putIfAbsent(
        const SvgNetworkLoader(loaded).cacheKey(null),
        () => Future.value(bytes!),
      );

      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: loaded, fallback: Text('🔢')),
      ));
      await tester.pump();

      expect(find.text('🔢'), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('on web, loads the SVG straight from its URL first',
        (tester) async {
      CourseCoverImage.debugWebOverride = true;

      await tester.pumpWidget(_wrap(
        const CourseCoverImage(url: cover, fallback: Text('🔢')),
      ));

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect((picture.bytesLoader as SvgNetworkLoader).url, cover);
    });
  });

  group('CourseGridCard', () {
    testWidgets('paints the cover over the header panel', (tester) async {
      await tester.pumpWidget(_wrap(const CourseGridCard(
        emoji: '🔢',
        coverImageUrl: 'https://cdn.test/cover.png',
        headerColor: Colors.purple,
        title: 'Rovnice',
        meta: '4 lekce · 25 min',
        footer: SizedBox.shrink(),
      )));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows the emoji panel when no cover is set', (tester) async {
      await tester.pumpWidget(_wrap(const CourseGridCard(
        emoji: '🔢',
        headerColor: Colors.purple,
        title: 'Rovnice',
        meta: '4 lekce · 25 min',
        footer: SizedBox.shrink(),
      )));

      expect(find.text('🔢'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
