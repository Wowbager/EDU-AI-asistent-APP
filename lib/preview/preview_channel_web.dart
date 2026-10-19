// The web implementation of the preview channel.
//
// Messages are exchanged as JSON strings rather than structured-cloned objects:
// a string crosses the JS/Dart boundary with no conversion surprises, and it is
// what the editor's own bridge sends and accepts.

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'preview_channel.dart';

class WebPreviewChannel implements PreviewChannel {
  JSFunction? _listener;

  @override
  void listen(void Function(Map<String, dynamic> message) onMessage) {
    void handle(web.MessageEvent event) {
      // The editor and the player share an origin (§6.4 of the editor plan), so
      // anything from elsewhere is not ours and is ignored rather than parsed.
      if (event.origin.isNotEmpty && event.origin != web.window.location.origin) {
        return;
      }

      final decoded = _decode(event.data);
      if (decoded != null) onMessage(decoded);
    }

    _listener = handle.toJS;
    web.window.addEventListener('message', _listener);
  }

  Map<String, dynamic>? _decode(JSAny? data) {
    try {
      if (data.isA<JSString>()) {
        final parsed = jsonDecode((data! as JSString).toDart);
        return parsed is Map<String, dynamic> ? parsed : null;
      }
      final dartified = data.dartify();
      if (dartified is Map) {
        return dartified.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (error) {
      debugPrint('Preview: could not read a message from the editor: $error');
    }
    return null;
  }

  @override
  void send(Map<String, dynamic> message) {
    final parent = web.window.parent;
    if (parent == null) return;
    parent.postMessage(jsonEncode(message).toJS, web.window.location.origin.toJS);
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) web.window.removeEventListener('message', listener);
    _listener = null;
  }
}

PreviewChannel buildPreviewChannel() => WebPreviewChannel();
