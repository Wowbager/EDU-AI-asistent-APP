import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Log an exception that we're intentionally swallowing.
///
/// Replaces `catch (_) {}` blocks so failures are visible in debug builds
/// (and ready to be wired into Sentry / Crashlytics when those are
/// integrated).
///
/// In release builds this is a no-op so we don't pay for I/O on hot paths.
/// Once an error reporter is wired in, route through it here in one place.
void silentLog(String tag, Object error, [StackTrace? stack]) {
  if (kReleaseMode) return;
  debugPrint('SILENTLOG[$tag] $error');
  developer.log(
    error.toString(),
    name: 'silent.$tag',
    error: error,
    stackTrace: stack,
  );
}
