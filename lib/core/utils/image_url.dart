import 'package:flutter/foundation.dart' show kIsWeb;
import '../network/api_endpoints.dart';

/// On Flutter web, rewrite external image URLs to go through
/// the Laravel API proxy, avoiding CORS blocks from CanvasKit's
/// fetch()-based image loading.
///
/// On native platforms CORS doesn't apply, so URLs are returned unchanged.
String resolveImageUrl(String url) {
  if (!kIsWeb) return url;
  return proxyImageUrl(url);
}

/// [url] routed through the Laravel API image proxy, on any platform.
/// Anything that isn't an http(s) URL is returned unchanged.
String proxyImageUrl(String url) {
  if (url.startsWith('https://') || url.startsWith('http://')) {
    return '${ApiEndpoints.baseUrl}${ApiEndpoints.proxyImage}?url=${Uri.encodeComponent(url)}';
  }
  return url;
}

/// Rewrite all external image URLs inside an HTML string so that
/// flutter_html's <img> tags also go through the API proxy.
/// Only active on web — returns the input unchanged on native.
String resolveHtmlImageUrls(String html) {
  if (!kIsWeb) return html;
  final prefix = '${ApiEndpoints.baseUrl}${ApiEndpoints.proxyImage}?url=';
  return html.replaceAllMapped(
    RegExp('(src\\s*=\\s*["\'])(https?://[^"\']+)(["\'])'),
    (m) => '${m.group(1)}$prefix${Uri.encodeComponent(m.group(2)!)}${m.group(3)}',
  );
}
