import 'dart:typed_data';

/// Reports download progress: bytes so far, and the total when the server
/// sent a length.
typedef LessonImageProgress = void Function(int received, int? total);

/// Where [LessonImageCache] gets picture bytes from and keeps them.
///
/// Only native platforms have one (see `lesson_image_backend_io.dart`). The
/// web build has no file system to keep pictures on, so it has none and
/// lesson images there load exactly as before.
abstract class LessonImageBackend {
  /// Downloads [url]. Throws when the network, or the server, fails.
  Future<Uint8List> fetch(String url, {LessonImageProgress? onProgress});

  /// The copy of [url] kept on disk, or null when there is none.
  Future<Uint8List?> read(String url);

  /// Whether a copy of [url] is kept on disk.
  Future<bool> contains(String url);

  /// Keeps [bytes] on disk as the copy of [url].
  Future<void> write(String url, Uint8List bytes);
}
