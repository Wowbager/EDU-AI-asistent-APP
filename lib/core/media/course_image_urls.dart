/// Every picture a course's content points at — what [LessonImageCache]
/// downloads ahead so the course still has its pictures offline (BR-BX9AA4).
///
/// Walks the whole course JSON rather than the parsed blocks, because
/// pictures turn up in many places: `image.url` on blocks and steps,
/// `solution_image` / `feedback_image` on questions, `image_url` on legacy
/// steps, `url` on V2 image steps, and `![](…)` or `<img src>` inside text.
Set<String> courseImageUrls(Map<String, dynamic>? courseData) {
  final urls = <String>{};
  if (courseData != null) _visit(courseData, null, urls);
  return urls;
}

/// Keys whose object value is a picture with its address under `url`.
const _imageObjectKeys = {'image', 'solution_image', 'feedback_image'};

final _imageExtension =
    RegExp(r'\.(png|jpe?g|gif|webp|svg|bmp)$', caseSensitive: false);
final _videoExtension =
    RegExp(r'\.(mp4|webm|mov|m4v|ogv)$', caseSensitive: false);
final _markdownImage = RegExp(r'!\[[^\]]*\]\(\s*<?(https?://[^\s)>]+)');
final _htmlImage = RegExp(
  r'''<img\b[^>]*?\bsrc\s*=\s*["'](https?://[^"']+)["']''',
  caseSensitive: false,
);

void _visit(Object? node, String? key, Set<String> urls) {
  if (node is Map) {
    final isImageObject = _imageObjectKeys.contains(key) || node['type'] == 'image';
    node.forEach((k, v) {
      // The course cover is drawn by CourseCoverImage, which does not read
      // from this cache — downloading it here would be wasted data.
      if (k == 'header_image') return;
      if (v is String &&
          (k == 'image_url' || (k == 'url' && isImageObject) || _looksLikeImage(v))) {
        _add(v, urls);
      } else {
        _visit(v, k is String ? k : null, urls);
      }
    });
  } else if (node is List) {
    for (final item in node) {
      _visit(item, key, urls);
    }
  } else if (node is String) {
    for (final m in _markdownImage.allMatches(node)) {
      _add(m.group(1)!, urls);
    }
    for (final m in _htmlImage.allMatches(node)) {
      _add(m.group(1)!, urls);
    }
  }
}

bool _looksLikeImage(String value) {
  final uri = _httpUri(value);
  return uri != null && _imageExtension.hasMatch(uri.path);
}

void _add(String value, Set<String> urls) {
  final url = value.trim();
  final uri = _httpUri(url);
  if (uri == null) return;
  // Videos share the image syntax in markdown (BR-8JA266) and YouTube links
  // sit in `image.url`; neither is a picture to keep.
  if (_videoExtension.hasMatch(uri.path)) return;
  if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) return;
  urls.add(url);
}

Uri? _httpUri(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  return uri != null && uri.host.isNotEmpty ? uri : null;
}
