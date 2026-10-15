// Makes a failed ELO update visible (BR-S9SVNM).
//
// The answer paths (quiz_page, lesson_detail_page) catch whatever the ELO
// update throws, so a broken block never breaks answering. That catch used to
// reach only silentLog — a no-op in release builds — so a block whose GPF
// vectors the engine rejects (a relation other than exactly 0/1/2, an ELO
// outside 0–10) simply stopped moving ELO and nobody knew. The failure now
// also goes out as a debug report: the same POST /api/debug-reports the About
// page sends, listed in the admin under Diagnostika.
library;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../util/silent_log.dart';

/// Sends one debug-report payload; true when the server accepted it.
typedef DebugReportSender = Future<bool> Function(Map<String, dynamic> payload);

/// The installed app's version and build number.
typedef AppVersionLoader = Future<({String version, String buildNumber})>
    Function();

/// Key under `report_data` that carries the ELO failure itself.
const String kEloFailureReportKey = 'elo_failure';

/// Stack frames kept in a report — enough to see where the engine threw.
const int _maxStackLines = 12;

class EloFailureReporter {
  EloFailureReporter({
    required DebugReportSender send,
    AppVersionLoader? appVersion,
    String? platform,
    DateTime Function()? now,
  })  : _send = send,
        _appVersion = appVersion ?? _packageVersion,
        _platform = platform ??
            (kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase()),
        _now = now ?? DateTime.now;

  final DebugReportSender _send;
  final AppVersionLoader _appVersion;
  final String _platform;
  final DateTime Function() _now;

  /// Blocks already reported in this app run. A broken block fails on every
  /// answer, and one report per block says all there is to say.
  final Set<String> _reported = {};

  /// Reports that the ELO update for [blockId] failed with [error].
  ///
  /// Never throws: reporting must not turn a swallowed failure into a crash.
  /// A report that could not be sent (offline, server error) is retried the
  /// next time the same block fails.
  Future<void> report({
    required String source,
    required String courseId,
    required String blockId,
    required Object error,
    StackTrace? stackTrace,
    List<double?>? relationVector,
    List<double?>? eloVector,
  }) async {
    final key = '$courseId/$blockId';
    if (!_reported.add(key)) return;

    try {
      final version = await _appVersion();
      final sent = await _send(buildPayload(
        source: source,
        courseId: courseId,
        blockId: blockId,
        error: error,
        stackTrace: stackTrace,
        relationVector: relationVector,
        eloVector: eloVector,
        appVersion: version.version,
        buildNumber: version.buildNumber,
      ));
      if (!sent) _reported.remove(key);
    } catch (e, st) {
      _reported.remove(key);
      silentLog('elo_failure_reporter', e, st);
    }
  }

  /// The /api/debug-reports body for one failure. The top-level fields match
  /// what DebugReportController validates; `app` and `device` mirror the
  /// About page report so the admin detail view renders them the same way.
  @visibleForTesting
  Map<String, dynamic> buildPayload({
    required String source,
    required String courseId,
    required String blockId,
    required Object error,
    StackTrace? stackTrace,
    List<double?>? relationVector,
    List<double?>? eloVector,
    required String appVersion,
    required String buildNumber,
  }) {
    return {
      'app_version':
          appVersion.isNotEmpty ? '$appVersion+$buildNumber' : 'unknown',
      'platform': _platform,
      'os_version': null,
      'device_model': null,
      'report_data': {
        'timestamp': _now().toIso8601String(),
        'app': {'version': appVersion, 'build_number': buildNumber},
        'device': {'platform': _platform, 'is_web': kIsWeb},
        kEloFailureReportKey: {
          'source': source,
          'course_id': courseId,
          'block_id': blockId,
          'error_type': error.runtimeType.toString(),
          'error': error.toString(),
          'relation_vector': relationVector,
          'elo_vector': eloVector,
          if (stackTrace != null)
            'stack': stackTrace
                .toString()
                .split('\n')
                .take(_maxStackLines)
                .join('\n'),
        },
      },
    };
  }

  static Future<({String version, String buildNumber})>
      _packageVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, buildNumber: info.buildNumber);
  }
}
