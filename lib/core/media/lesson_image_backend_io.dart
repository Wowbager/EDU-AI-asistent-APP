import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'lesson_image_backend.dart';

LessonImageBackend? createLessonImageBackend() => IoLessonImageBackend();

/// Downloads lesson pictures with the same [HttpClient] setup Flutter's own
/// `NetworkImage` uses, and keeps them as files under the app support
/// directory — not the cache directory, which Android and iOS may empty
/// whenever they run short of space, and with it the offline copy.
class IoLessonImageBackend implements LessonImageBackend {
  IoLessonImageBackend({
    HttpClient? client,
    Future<Directory> Function()? directory,
  })  : _client = client,
        _directory = directory ?? _defaultDirectory;

  final HttpClient? _client;
  final Future<Directory> Function() _directory;
  Future<Directory>? _dir;

  static final HttpClient _sharedClient = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15);

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'lesson_images'));
  }

  Future<Directory> get _root => _dir ??= () async {
        final dir = await _directory();
        await dir.create(recursive: true);
        return dir;
      }();

  Future<File> _file(String url) async =>
      File(p.join((await _root).path, _fileName(url)));

  @override
  Future<Uint8List> fetch(String url, {LessonImageProgress? onProgress}) async {
    final uri = Uri.parse(url);
    final request = await (_client ?? _sharedClient).getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().catchError((_) {});
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    // A Wi-Fi login page answers every URL with 200 and its own HTML. Taking
    // that for the picture would overwrite the good copy kept on disk.
    if (response.headers.contentType?.mimeType == 'text/html') {
      await response.drain<void>().catchError((_) {});
      throw HttpException('Not an image (text/html)', uri: uri);
    }
    final bytes = await consolidateHttpClientResponseBytes(
      response,
      onBytesReceived: onProgress,
    );
    if (bytes.lengthInBytes == 0) {
      throw HttpException('Empty image', uri: uri);
    }
    return bytes;
  }

  @override
  Future<Uint8List?> read(String url) async {
    final file = await _file(url);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  }

  @override
  Future<bool> contains(String url) async => (await _file(url)).exists();

  @override
  Future<void> write(String url, Uint8List bytes) async {
    final file = await _file(url);
    // Write beside and rename over, so a write cut short (app killed, disk
    // full) never leaves a half picture where the whole one used to be.
    final part = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file.path);
  }

  /// 64-bit FNV-1a of the URL as hex — a short, file-system-safe name that
  /// stays the same for the same URL.
  static String _fileName(String url) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(url)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    final high = (hash >>> 32).toRadixString(16).padLeft(8, '0');
    final low = (hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return '$high$low';
  }
}
