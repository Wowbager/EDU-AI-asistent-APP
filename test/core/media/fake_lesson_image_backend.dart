import 'dart:io';
import 'dart:typed_data';

import 'package:eduai/core/media/lesson_image_cache.dart';

/// Disk and network for [LessonImageCache], in memory. [online] false makes
/// every download fail the way it does with no signal.
class FakeLessonImageBackend implements LessonImageBackend {
  final Map<String, Uint8List> server;
  final Map<String, Uint8List> disk = {};
  final List<String> fetched = [];
  bool online = true;

  FakeLessonImageBackend({Map<String, Uint8List>? server})
      : server = server ?? {};

  @override
  Future<Uint8List> fetch(String url, {LessonImageProgress? onProgress}) async {
    fetched.add(url);
    if (!online) throw const SocketException('Failed host lookup');
    final bytes = server[url];
    if (bytes == null) throw HttpException('HTTP 404', uri: Uri.parse(url));
    return bytes;
  }

  @override
  Future<Uint8List?> read(String url) async => disk[url];

  @override
  Future<bool> contains(String url) async => disk.containsKey(url);

  @override
  Future<void> write(String url, Uint8List bytes) async => disk[url] = bytes;
}
