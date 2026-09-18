// The message channel between the editor and the embedded player.
//
//   editor → player: setBlock, setLesson, highlight, reset
//   player → editor: ready, stepChanged, clicked, completed
//
// The interface lives here so that both implementations can see it; the
// conditional import picks which one `buildPreviewChannel` comes from. Web is the
// only platform with a parent frame to talk to — the stub keeps the app compiling
// on mobile and desktop.

import 'preview_channel_stub.dart'
    if (dart.library.js_interop) 'preview_channel_web.dart';

abstract class PreviewChannel {
  /// Start listening for messages from the editor.
  void listen(void Function(Map<String, dynamic> message) onMessage);

  /// Send a message to the editor.
  void send(Map<String, dynamic> message);

  void dispose();
}

/// The channel for this platform.
PreviewChannel createPreviewChannel() => buildPreviewChannel();
