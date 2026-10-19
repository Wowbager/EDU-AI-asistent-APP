// Non-web fallback: no parent frame, so nothing is sent or received.
//
// The preview route exists on every platform so that a developer can open it
// locally, but only the web build is what the editor embeds.

import 'preview_channel.dart';

class _NoopChannel implements PreviewChannel {
  @override
  void listen(void Function(Map<String, dynamic> message) onMessage) {}

  @override
  void send(Map<String, dynamic> message) {}

  @override
  void dispose() {}
}

PreviewChannel buildPreviewChannel() => _NoopChannel();
