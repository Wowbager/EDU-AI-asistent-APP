import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The stale-logo trap behind BR-EK9P6J.
///
/// Flutter web content-hashes none of its asset URLs: /favicon.ico,
/// /icons/*.png and everything under /assets/ keep the same path build after
/// build while their bytes change. Serving those with `immutable` promised the
/// opposite, so a rebrand deploy could not displace the logo already sitting in
/// Cloudflare and in every visitor's browser — `immutable` tells browsers to
/// skip revalidation even on a reload, so the user could not flush it either.
///
/// Two things keep that from coming back, and each is one careless edit away
/// from being undone silently, which is why they are pinned here: the asset
/// location must revalidate, and index.html must keep the icon hrefs in the
/// literal shape the Dockerfile's cache-busting sed matches.
void main() {
  final nginxConf = File('nginx.conf').readAsStringSync();
  final indexHtml = File('web/index.html').readAsStringSync();
  final dockerfile = File('Dockerfile').readAsStringSync();

  /// The body of the `location ~* \.(png|...)$` block.
  String staticAssetBlock() {
    final start = nginxConf.indexOf(RegExp(r'location\s+~\*\s+\\\.\(png'));
    expect(
      start,
      isNot(-1),
      reason: 'nginx.conf no longer has a location block for static assets',
    );
    final end = nginxConf.indexOf('}', start);
    return nginxConf.substring(start, end);
  }

  test('static assets are not served as immutable', () {
    // `immutable` is a promise the bytes at this URL never change. Flutter web
    // reuses every asset path across builds, so the promise is always false and
    // the cost of breaking it is a year of the wrong logo.
    expect(staticAssetBlock(), isNot(contains('immutable')));
  });

  test('static assets revalidate rather than being pinned for months', () {
    final block = staticAssetBlock();
    expect(block, contains('must-revalidate'));
    // `expires 1y` was what put the year on the clock; anything beyond minutes
    // leaves a redeploy unable to reach clients that already cached the asset.
    expect(block, isNot(contains(RegExp(r'expires\s+\d+[dMy]'))));
  });

  test('index.html keeps the icon hrefs the Dockerfile cache-busts', () {
    // The Dockerfile rewrites these exact literals to append ?v=<build>. That
    // fresh cache key is the only thing that reaches a browser still holding an
    // `immutable` copy from before the header was corrected, so a reformat here
    // silently strands those users.
    for (final href in const [
      'apple-touch-icon.png',
      'favicon-96x96.png',
      'favicon.svg',
      'favicon.ico',
      'manifest.json',
    ]) {
      expect(
        indexHtml,
        contains('href="$href"'),
        reason: 'Dockerfile cache-busts href="$href"; index.html must match',
      );
      expect(dockerfile, contains(href.replaceAll('.', r'\.')));
    }
  });
}
