// Task difficulty D the app answers with (BR-697NCA).
//
// The server is the only writer of D: it applies the task half of every
// answer and publishes the calibrated values through GET /api/blocks/stats,
// which the sync pull caches in `block_stats`. The app only reads D — the
// cached server value per dimension where one exists, the course content's
// elo_vector (the author's prior) elsewhere. An author's later edit of an
// already calibrated dimension therefore does not show; that is the editor's
// call (BR-QF2N45, D2).
//
// Pure Dart — unit-tested directly.
library;

import 'elo_engine.dart';
import 'gpf_vector_shape.dart';

/// Effective difficulty of a task: [calibrated] per dimension where it is
/// set, [contentElo] elsewhere, fitted to the engine's 35 slots.
List<double?> effectiveTaskElo(
  List<double?> contentElo,
  List<double?>? calibrated,
) {
  final prior = fitGpfVector(contentElo, null);
  if (calibrated == null) return prior;
  final server = fitGpfVector(calibrated, null);
  return [
    for (var k = 0; k < kGpfDimensions; k++) server[k] ?? prior[k],
  ];
}

/// The fields every ELO interaction carries for the server's calibration:
/// an idempotency key (a re-sent answer never moves D twice), the student's
/// rating before the answer (the task update runs on it; the existing
/// `profil_elo_snapshot` is the rating after) and the D the student update
/// used. The server writes `elo_vector_snapshot` itself, so the app no
/// longer sends it.
Map<String, dynamic> taskCalibrationFields({
  required String clientUuid,
  required List<double?> profilEloBefore,
  required List<double?> eloVectorUsed,
}) =>
    {
      'client_uuid': clientUuid,
      'profil_elo_before': profilEloBefore,
      'elo_vector_used': eloVectorUsed,
    };
