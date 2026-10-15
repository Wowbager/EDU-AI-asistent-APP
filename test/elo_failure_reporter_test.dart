import 'package:eduai/core/elo/elo_engine.dart';
import 'package:eduai/core/elo/elo_failure_reporter.dart';
import 'package:eduai/core/elo/gpf_vector_shape.dart';
import 'package:flutter_test/flutter_test.dart';

/// A failed ELO update becomes a debug report instead of vanishing into
/// silentLog (BR-S9SVNM).
void main() {
  late List<Map<String, dynamic>> sent;
  late bool accept;

  EloFailureReporter reporter() => EloFailureReporter(
        send: (payload) async {
          sent.add(payload);
          return accept;
        },
        appVersion: () async => (version: '1.0.24', buildNumber: '34'),
        platform: 'ios',
        now: () => DateTime.utc(2026, 9, 26, 12),
      );

  setUp(() {
    sent = [];
    accept = true;
  });

  /// What the answer paths do: fit the vectors, run the engine, and on
  /// failure hand the error to the reporter.
  Future<void> answerBlock(
    EloFailureReporter r,
    List<double?> relation, {
    String blockId = 'B1',
  }) async {
    final elo = List<double?>.filled(kGpfDimensions, 5.0);
    try {
      EloEngine.updateTask(
        profilElo: List<double?>.filled(kGpfDimensions, null),
        profilPocet: List<int>.filled(kGpfDimensions, 0),
        relationVector: fitGpfVector(
          relation.map((e) => e ?? 0.0).toList(),
          0.0,
        ),
        eloVector: elo,
        itemPocet: List<int>.filled(kGpfDimensions, 0),
        score: 1.0,
      );
    } catch (e, st) {
      await r.report(
        source: 'quiz',
        courseId: 'C1',
        blockId: blockId,
        error: e,
        stackTrace: st,
        relationVector: relation,
        eloVector: elo,
      );
    }
  }

  List<double?> relationWith(int index, double value) =>
      List<double?>.filled(kGpfDimensions, 0.0)..[index] = value;

  test('a relation value the engine rejects is reported with the block and vectors',
      () async {
    await answerBlock(reporter(), relationWith(3, 1.5));

    expect(sent, hasLength(1));
    final payload = sent.single;
    // The fields DebugReportController::store validates.
    expect(payload['app_version'], '1.0.24+34');
    expect(payload['platform'], 'ios');
    expect(payload['report_data'], isA<Map<String, dynamic>>());

    final data = payload['report_data'] as Map<String, dynamic>;
    expect(data['timestamp'], '2026-09-26T12:00:00.000Z');
    expect(data['app'], {'version': '1.0.24', 'build_number': '34'});

    final failure = data[kEloFailureReportKey] as Map<String, dynamic>;
    expect(failure['source'], 'quiz');
    expect(failure['course_id'], 'C1');
    expect(failure['block_id'], 'B1');
    expect(failure['error_type'], 'ArgumentError');
    expect(failure['error'], contains('relationVector[3] must be exactly 0, 1 or 2'));
    expect((failure['relation_vector'] as List)[3], 1.5);
    expect(failure['elo_vector'], hasLength(kGpfDimensions));
    expect(failure['stack'], isA<String>());
  });

  test('a valid block sends nothing', () async {
    await answerBlock(reporter(), relationWith(3, 2.0));
    expect(sent, isEmpty);
  });

  test('the same broken block is reported once per run', () async {
    final r = reporter();
    await answerBlock(r, relationWith(3, 1.5));
    await answerBlock(r, relationWith(3, 1.5));
    await answerBlock(r, relationWith(3, 1.5), blockId: 'B2');

    expect(
      sent.map((p) => (p['report_data'] as Map)[kEloFailureReportKey]['block_id']),
      ['B1', 'B2'],
    );
  });

  test('a report the server did not take is retried on the next failure',
      () async {
    final r = reporter();
    accept = false;
    await answerBlock(r, relationWith(3, 1.5));
    accept = true;
    await answerBlock(r, relationWith(3, 1.5));
    await answerBlock(r, relationWith(3, 1.5));

    expect(sent, hasLength(2));
  });

  test('a sender that throws does not escape and is retried later', () async {
    var calls = 0;
    final r = EloFailureReporter(
      send: (_) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return true;
      },
      appVersion: () async => (version: '1.0.24', buildNumber: '34'),
      platform: 'android',
    );

    await answerBlock(r, relationWith(3, 3.0));
    await answerBlock(r, relationWith(3, 3.0));

    expect(calls, 2);
  });

  test('an unknown app version still produces a valid report', () {
    final payload = reporter().buildPayload(
      source: 'lesson',
      courseId: 'C1',
      blockId: 'B1',
      error: ArgumentError('x'),
      appVersion: '',
      buildNumber: '',
    );
    expect(payload['app_version'], 'unknown');
    expect(
      ((payload['report_data'] as Map)[kEloFailureReportKey] as Map)
          .containsKey('stack'),
      isFalse,
    );
  });
}
