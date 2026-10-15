import 'dart:async';
import 'dart:typed_data';

import '../connectivity/connectivity_service.dart';
import '../util/silent_log.dart';
import 'lesson_image_backend.dart';
import 'lesson_image_backend_stub.dart'
    if (dart.library.io) 'lesson_image_backend_io.dart';

export 'lesson_image_backend.dart' show LessonImageBackend, LessonImageProgress;

/// Keeps lesson pictures on the device, so a course that was downloaded still
/// shows them offline (BR-BX9AA4).
///
/// The course text has always been stored locally, but its pictures are only
/// URLs — Cloudflare R2 mostly — and `Image.network` holds what it loads in
/// memory alone. Offline, every picture the app had not loaded since it last
/// started was gone: image blocks showed the broken-image box and markdown
/// pictures showed nothing.
///
/// Loading is network first: online, a lesson shows exactly what the server
/// has now (a file replaced under the same URL shows the new picture — see
/// BR-TBN2T6), and each download refreshes the copy on disk. Only when the
/// download fails does the copy on disk stand in. [prefetch] fills the disk
/// for a whole course up front, so lessons that were never opened have their
/// pictures too.
///
/// Without a backend — the web build — the cache is [isSupported] false and
/// lesson images load straight from the network as before.
class LessonImageCache {
  LessonImageCache({
    LessonImageBackend? backend,
    bool useDefaultBackend = true,
  }) : _backend =
            backend ?? (useDefaultBackend ? createLessonImageBackend() : null);

  /// The cache every lesson image goes through. Tests swap in one with a fake
  /// backend and put the old one back afterwards.
  static LessonImageCache instance = LessonImageCache();

  final LessonImageBackend? _backend;

  /// How many pictures [prefetch] downloads at a time.
  static const int _prefetchWorkers = 3;

  /// URLs a running [prefetch] is already on, so the course page and the
  /// lesson page opening one after the other do not fetch them twice.
  final Set<String> _prefetching = {};

  // Until the app hands over its ConnectivityService (see [useConnectivity])
  // nothing goes out on its own: prefetching stays off and no reconnect ever
  // fires. Unit and widget tests therefore never hit the network through the
  // cache unless they ask to.
  Future<bool> Function() _isOnline = () async => false;
  Stream<void> _reconnects = const Stream<void>.empty();

  /// Whether pictures are kept on this platform at all.
  bool get isSupported => _backend != null;

  /// Fires when the device comes back online. A picture that failed to load
  /// listens for it to try again — before, it stayed broken until something
  /// else in the lesson happened to rebuild it.
  Stream<void> get reconnects => _reconnects;

  /// Wires the cache to the app's connectivity: [prefetch] only runs online,
  /// and [reconnects] fires a moment after the connection is back — Android
  /// reports it a little before DNS actually answers.
  void useConnectivity(
    ConnectivityService connectivity, {
    Duration settle = const Duration(seconds: 2),
  }) {
    _isOnline = () => connectivity.isOnline;
    _reconnects = connectivity.onConnectivityChanged
        .where((state) => state.isOnline)
        .asyncMap((_) => Future<void>.delayed(settle));
  }

  /// For tests: what "online" and "back online" mean.
  void setConnectivityForTesting({
    required Future<bool> Function() isOnline,
    Stream<void>? reconnects,
  }) {
    _isOnline = isOnline;
    _reconnects = reconnects ?? const Stream<void>.empty();
  }

  /// The bytes of [url]: downloaded when possible — refreshing the copy on
  /// disk — or else the copy on disk. Throws the download error when there is
  /// no copy either.
  Future<Uint8List> load(String url, {LessonImageProgress? onProgress}) async {
    final backend = _backend;
    if (backend == null) {
      throw UnsupportedError('No lesson image cache on this platform');
    }
    try {
      final bytes = await backend.fetch(url, onProgress: onProgress);
      await _keep(backend, url, bytes);
      return bytes;
    } catch (_) {
      final kept = await _read(backend, url);
      if (kept != null) return kept;
      rethrow;
    }
  }

  /// Downloads every one of [urls] that has no copy on disk yet, a few at a
  /// time. Does nothing offline; a picture that fails is skipped — the lesson
  /// tries it again when it is shown.
  Future<void> prefetch(Iterable<String> urls) async {
    final backend = _backend;
    if (backend == null) return;
    final queue = urls.where((url) => !_prefetching.contains(url)).toSet().toList();
    if (queue.isEmpty) return;
    try {
      if (!await _isOnline()) return;
    } catch (e, st) {
      silentLog('lesson_image_cache', e, st);
      return;
    }
    _prefetching.addAll(queue);
    final claimed = List<String>.of(queue);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final url = queue.removeLast();
        try {
          if (await backend.contains(url)) continue;
          await _keep(backend, url, await backend.fetch(url));
        } catch (_) {
          // Skipped; the lesson tries it again when it shows the picture.
        }
      }
    }

    try {
      await Future.wait([
        for (var i = 0; i < _prefetchWorkers; i++) worker(),
      ]);
    } finally {
      _prefetching.removeAll(claimed);
    }
  }

  Future<void> _keep(LessonImageBackend backend, String url, Uint8List bytes) async {
    try {
      await backend.write(url, bytes);
    } catch (e, st) {
      // Showing the picture matters more than keeping it.
      silentLog('lesson_image_cache', e, st);
    }
  }

  Future<Uint8List?> _read(LessonImageBackend backend, String url) async {
    try {
      return await backend.read(url);
    } catch (e, st) {
      silentLog('lesson_image_cache', e, st);
      return null;
    }
  }
}
