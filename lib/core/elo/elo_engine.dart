// EDU-AI Pilot 2: asymmetric bidirectional ELO engine + gaming helper.
//
// Main rules:
// - 35 GPF subconstructs.
// - relation_vector is discrete 0/1/2; only relation == 2 is updated.
// - Student and task use different expected-score curves:
//     * student: E_L = 0.50 when L == D;
//     * task:    E_D = 0.75 when L == D.
// - lambda = 0.5 by default.
// - Student K uses reciprocal decay with a non-zero lower asymptote.
// - Task K uses the original reciprocal decay converging to zero,
//   with K0 = 1.0 and alpha = 0.1.
// - Gaming/invalid attempts must not update ELO or ELO counters.
// - Gaming detection uses reaction time from TASK DISPLAY to ANSWER SUBMISSION.
// - Gaming threshold uses only previous VALID, NON-GAMING reaction times
//   for the same task.
// - For the first 10 valid non-gaming task interactions, the gaming threshold
//   is fixed at 2 seconds.
// - Afterwards the threshold is based on log-times, median and scaled MAD:
//       x_i = ln(t_i + 1)
//       M = median(x_i)
//       MAD = 1.4826 * median(|x_i - M|)
//       x_threshold = M - 3 * MAD
//       threshold = max(2 s, exp(x_threshold) - 1)
// - Task selection can rank candidates by mean squared ELO-vector distance
//   and sample without replacement from the top 20.
//
// IMPORTANT:
// Gaming detection belongs logically to the interaction-processing layer.
// GamingGuard is included here as a pure-Dart helper so the exact rule is
// implemented consistently. The caller must pass skipEloUpdate = true
// (or skip updateTask entirely) for gaming/invalid attempts.
//
// This file has no Flutter dependency and can be unit-tested as pure Dart.

import 'dart:math';

/// Number of GPF subconstructs.
const int kGpfDimensions = 35;

/// Default student rating used when no prior rating exists in a subconstruct.
const double kDefaultStudentRating = 6.0;

/// Version label for the default Pilot 2 ELO configuration.
/// Every logged interaction carries it as `elo_config_version` (via
/// [EloUpdateResult.configVersion]); the API's EloEngine::CONFIG_VERSION
/// must match it for the same parameters (BR-EBNMBF).
const String kPilot2EloConfigVersion = 'pilot2-elo-v1';

/// Configuration of the ELO model.
///
/// Keeping the tunable parameters in one object prevents duplicated sources
/// of truth (for example targetTask = 0.75 but a stale hard-coded bias).
class EloConfig {
  final String version;

  /// Sigmoid steepness.
  final double lambda;

  /// Expected student score when student rating equals task difficulty.
  final double targetStudentAtMatch;

  /// Expected score used to calibrate task difficulty when L == D.
  final double targetTaskAtMatch;

  /// Initial student K-factor.
  final double k0Student;

  /// Long-run lower asymptote of the student K-factor.
  final double kMinStudent;

  /// Student K-factor decay rate.
  final double alphaStudent;

  /// Initial task K-factor.
  final double k0Task;

  /// Task K-factor decay rate.
  final double alphaTask;

  const EloConfig({
    required this.version,
    required this.lambda,
    required this.targetStudentAtMatch,
    required this.targetTaskAtMatch,
    required this.k0Student,
    required this.kMinStudent,
    required this.alphaStudent,
    required this.k0Task,
    required this.alphaTask,
  });

  /// Bias is derived from the target; do not store a second independent value.
  double get studentBias => _logit(targetStudentAtMatch);

  /// Bias is derived from the target; do not store a second independent value.
  double get taskBias => _logit(targetTaskAtMatch);
}

/// Default Pilot 2 parameters.
const EloConfig kPilot2EloConfig = EloConfig(
  version: kPilot2EloConfigVersion,
  lambda: 0.5,
  targetStudentAtMatch: 0.50,
  targetTaskAtMatch: 0.75,
  k0Student: 1.0,
  kMinStudent: 0.3,
  alphaStudent: 0.1,
  k0Task: 1.0,
  alphaTask: 0.1,
);

double _logit(double p) => log(p / (1.0 - p));

/// Result of a single bidirectional ELO update.
class EloUpdateResult {
  /// Updated student ELO profile (35 elements, nullable per subconstruct).
  final List<double?> profilElo;

  /// Number of prior ELO updates for the student per subconstruct.
  final List<int> profilPocet;

  /// Updated task ELO vector (35 elements, nullable per subconstruct).
  final List<double?> eloVector;

  /// Number of prior ELO updates for this task per subconstruct.
  final List<int> itemPocet;

  /// Indices of subconstructs whose student/task state was changed.
  final List<int> updatedIndices;

  /// [EloConfig.version] of the configuration that produced this result.
  /// Logged with every interaction as `elo_config_version` (BR-EBNMBF).
  final String configVersion;

  const EloUpdateResult({
    required this.profilElo,
    required this.profilPocet,
    required this.eloVector,
    required this.itemPocet,
    required this.updatedIndices,
    required this.configVersion,
  });
}

/// A candidate task for adaptive selection.
class TaskCandidate {
  final String blockId;

  /// Discrete vector with values 0/1/2.
  ///
  /// Kept as `List<double>` for compatibility with the existing JSON/model layer.
  final List<double> relationVector;

  /// Task ELO vector.
  final List<double?> eloVector;

  const TaskCandidate({
    required this.blockId,
    required this.relationVector,
    required this.eloVector,
  });
}

/// Candidate with its distance from the current student profile.
class RankedTaskCandidate {
  final int index;
  final TaskCandidate candidate;
  final double distance;

  const RankedTaskCandidate({
    required this.index,
    required this.candidate,
    required this.distance,
  });
}

/// Result of gaming-threshold evaluation.
class GamingCheckResult {
  final bool isGaming;

  /// Threshold in seconds used for this classification.
  final double thresholdSeconds;

  /// Number of valid non-gaming reference times used.
  final int referenceCount;

  /// True when the fixed 2-second startup threshold was used.
  final bool usedStartupThreshold;

  const GamingCheckResult({
    required this.isGaming,
    required this.thresholdSeconds,
    required this.referenceCount,
    required this.usedStartupThreshold,
  });
}

/// Pure-Dart implementation of the Pilot 2 gaming rule.
///
/// IMPORTANT:
/// - [responseTimeSeconds] is measured from DISPLAY OF THE TASK to SUBMISSION
///   OF THE ANSWER.
/// - [previousValidNonGamingReactionTimesSeconds] must contain only previous
///   valid, non-gaming reaction times for the same task.
/// - The current attempt is classified first. It may be added to the future
///   threshold reference set only if the result is NOT gaming.
/// - All attempts may still be stored in the interaction log; the restriction
///   above concerns only the data used to estimate future gaming thresholds.
class GamingGuard {
  const GamingGuard._();

  /// Startup period for each task.
  static const int minReferenceAttempts = 10;

  /// Absolute lower bound and startup threshold.
  static const double minimumThresholdSeconds = 2.0;

  /// Consistency factor making MAD comparable to SD under normality.
  static const double madConsistencyFactor = 1.4826;

  /// Conservative lower-outlier multiplier.
  static const double madMultiplier = 3.0;

  static GamingCheckResult classify({
    required double responseTimeSeconds,
    required List<double> previousValidNonGamingReactionTimesSeconds,
  }) {
    if (!responseTimeSeconds.isFinite || responseTimeSeconds < 0.0) {
      throw ArgumentError.value(
        responseTimeSeconds,
        'responseTimeSeconds',
        'Reaction time must be finite and non-negative.',
      );
    }

    final referenceTimes = <double>[];
    for (final t in previousValidNonGamingReactionTimesSeconds) {
      if (!t.isFinite || t < 0.0) {
        throw ArgumentError(
          'All reference reaction times must be finite and non-negative.',
        );
      }
      referenceTimes.add(t);
    }

    if (referenceTimes.length < minReferenceAttempts) {
      const threshold = minimumThresholdSeconds;
      return GamingCheckResult(
        isGaming: responseTimeSeconds < threshold,
        thresholdSeconds: threshold,
        referenceCount: referenceTimes.length,
        usedStartupThreshold: true,
      );
    }

    final logTimes = referenceTimes.map((t) => log(t + 1.0)).toList()
      ..sort();

    final medianLog = _medianOfSorted(logTimes);

    final absoluteDeviations = logTimes
        .map((x) => (x - medianLog).abs())
        .toList()
      ..sort();

    final rawMad = _medianOfSorted(absoluteDeviations);
    final scaledMad = madConsistencyFactor * rawMad;

    final xThreshold = medianLog - madMultiplier * scaledMad;
    final robustThresholdSeconds = exp(xThreshold) - 1.0;

    final threshold = max(
      minimumThresholdSeconds,
      robustThresholdSeconds,
    ).toDouble();

    return GamingCheckResult(
      isGaming: responseTimeSeconds < threshold,
      thresholdSeconds: threshold,
      referenceCount: referenceTimes.length,
      usedStartupThreshold: false,
    );
  }

  static double _medianOfSorted(List<double> sorted) {
    if (sorted.isEmpty) {
      throw ArgumentError('Cannot calculate median of an empty list.');
    }
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }
}

/// Pure-Dart bidirectional ELO engine.
class EloEngine {
  const EloEngine._();

  /// Standard sigmoid function.
  static double sigmoid(double x) => 1.0 / (1.0 + exp(-x));

  /// Student expected score:
  /// E_L = sigmoid(lambda * (L - D) + b_L).
  static double expectedForStudent({
    required double studentRating,
    required double taskDifficulty,
    EloConfig config = kPilot2EloConfig,
  }) {
    _validateConfig(config);
    _validateSingleRating(studentRating, 'studentRating');
    _validateSingleRating(taskDifficulty, 'taskDifficulty');

    return sigmoid(
      config.lambda * (studentRating - taskDifficulty) + config.studentBias,
    );
  }

  /// Task-calibration expected score:
  /// E_D = sigmoid(lambda * (L - D) + b_D).
  static double expectedForTask({
    required double studentRating,
    required double taskDifficulty,
    EloConfig config = kPilot2EloConfig,
  }) {
    _validateConfig(config);
    _validateSingleRating(studentRating, 'studentRating');
    _validateSingleRating(taskDifficulty, 'taskDifficulty');

    return sigmoid(
      config.lambda * (studentRating - taskDifficulty) + config.taskBias,
    );
  }

  /// Student K-factor with a non-zero lower asymptote:
  ///
  /// K_L(n) = K_min + (K0 - K_min) / (1 + alpha * n).
  static double studentK(
    int previousUpdates, {
    EloConfig config = kPilot2EloConfig,
  }) {
    _validateConfig(config);
    if (previousUpdates < 0) {
      throw ArgumentError.value(
        previousUpdates,
        'previousUpdates',
        'Update count must be non-negative.',
      );
    }

    return config.kMinStudent +
        (config.k0Student - config.kMinStudent) /
            (1.0 + config.alphaStudent * previousUpdates);
  }

  /// Task K-factor using the original reciprocal form:
  ///
  /// K_D(m) = K0 / (1 + alpha * m).
  ///
  /// Unlike the student K-factor, this converges to zero.
  static double taskK(
    int previousUpdates, {
    EloConfig config = kPilot2EloConfig,
  }) {
    _validateConfig(config);
    if (previousUpdates < 0) {
      throw ArgumentError.value(
        previousUpdates,
        'previousUpdates',
        'Update count must be non-negative.',
      );
    }

    return config.k0Task /
        (1.0 + config.alphaTask * previousUpdates);
  }

  /// Perform a bidirectional ELO update for one interaction.
  ///
  /// [profilElo] is the student's current rating vector.
  /// [profilPocet] contains prior student updates per subconstruct.
  /// [relationVector] contains discrete values 0/1/2; only exact value 2 is
  /// active for ELO.
  /// [eloVector] is the task's current difficulty vector.
  /// [itemPocet] contains prior task updates per subconstruct.
  /// [score] must be finite and in the closed interval 0..1.
  ///
  /// GAMING / INVALID ATTEMPTS:
  /// [skipEloUpdate] must be true for gaming or otherwise invalid attempts.
  /// Gaming is determined OUTSIDE this method from reaction time measured
  /// from task display to answer submission. If true, all ratings and counters
  /// are returned unchanged.
  ///
  /// Pilot 2 first-contact rule:
  /// If a student's active subconstruct is still unrated, then:
  ///   - score >= targetStudentAtMatch -> initialize student to task difficulty;
  ///   - score <  targetStudentAtMatch -> initialize student to 6.0.
  /// No regular student update, no task update and no counter increment is
  /// performed for that subconstruct on this first contact. This deliberately
  /// preserves the existing production initialization rule.
  static EloUpdateResult updateTask({
    required List<double?> profilElo,
    required List<int> profilPocet,
    required List<double> relationVector,
    required List<double?> eloVector,
    required List<int> itemPocet,
    required double score,
    bool skipEloUpdate = false,
    EloConfig config = kPilot2EloConfig,
  }) {
    _validateConfig(config);
    _validateScore(score);
    _validateUpdateVectors(
      profilElo: profilElo,
      profilPocet: profilPocet,
      relationVector: relationVector,
      eloVector: eloVector,
      itemPocet: itemPocet,
    );

    // Mutable copies: callers retain their original vectors.
    final newProfilElo = List<double?>.from(profilElo);
    final newProfilPocet = List<int>.from(profilPocet);
    final newEloVector = List<double?>.from(eloVector);
    final newItemPocet = List<int>.from(itemPocet);
    final updatedIndices = <int>[];

    if (skipEloUpdate) {
      return EloUpdateResult(
        profilElo: newProfilElo,
        profilPocet: newProfilPocet,
        eloVector: newEloVector,
        itemPocet: newItemPocet,
        updatedIndices: updatedIndices,
        configVersion: config.version,
      );
    }

    for (int k = 0; k < kGpfDimensions; k++) {
      // Relation is deliberately unweighted: only the main relation (2)
      // triggers an update, and every active subconstruct gets the same rule.
      if (relationVector[k] != 2.0) continue;

      final dValue = newEloVector[k];

      // A null task ELO in an active dimension means the dimension cannot
      // be updated. Non-null values have already been range-validated.
      if (dValue == null) continue;

      final d = dValue;
      final rValue = newProfilElo[k];

      // First-contact initialization, preserved from production.
      if (rValue == null) {
        newProfilElo[k] = score >= config.targetStudentAtMatch
            ? d
            : kDefaultStudentRating;
        updatedIndices.add(k);
        continue;
      }

      final r = rValue;

      // Student update.
      final expectedStudent = sigmoid(
        config.lambda * (r - d) + config.studentBias,
      );
      final studentDelta =
          studentK(newProfilPocet[k], config: config) *
              (score - expectedStudent);
      final newR = (r + studentDelta).clamp(0.0, 10.0).toDouble();

      // Task update.
      final expectedTask = sigmoid(
        config.lambda * (r - d) + config.taskBias,
      );
      final taskDelta =
          taskK(newItemPocet[k], config: config) *
              (expectedTask - score);
      final newD = (d + taskDelta).clamp(0.0, 10.0).toDouble();

      newProfilElo[k] = newR;
      newProfilPocet[k] += 1;
      newEloVector[k] = newD;
      newItemPocet[k] += 1;
      updatedIndices.add(k);
    }

    return EloUpdateResult(
      profilElo: newProfilElo,
      profilPocet: newProfilPocet,
      eloVector: newEloVector,
      itemPocet: newItemPocet,
      updatedIndices: updatedIndices,
      configVersion: config.version,
    );
  }

  /// Mean squared distance across active relation == 2 subconstructs:
  ///
  /// distance = mean((L_k - D_k)^2), over active dimensions only.
  ///
  /// A mean, rather than a sum, prevents tasks with more active dimensions
  /// from being automatically penalized solely because they have more terms.
  static double? candidateDistance({
    required List<double?> profilElo,
    required TaskCandidate candidate,
  }) {
    _validateProfileForSelection(profilElo);
    _validateCandidate(candidate);

    double squaredDifferenceSum = 0.0;
    int activeCount = 0;

    for (int k = 0; k < kGpfDimensions; k++) {
      if (candidate.relationVector[k] != 2.0) continue;

      final taskRating = candidate.eloVector[k];
      if (taskRating == null) continue;

      final studentRating = profilElo[k] ?? kDefaultStudentRating;
      final difference = taskRating - studentRating;
      squaredDifferenceSum += difference * difference;
      activeCount += 1;
    }

    if (activeCount == 0) return null;
    return squaredDifferenceSum / activeCount;
  }

  /// Rank valid candidates from closest to farthest.
  ///
  /// IMPORTANT:
  /// Domain filtering, rough ELO interval, "new/due" eligibility, previous
  /// block exclusion and other application-level filters must be applied by
  /// the higher-level practice algorithm before calling this method.
  static List<RankedTaskCandidate> rankCandidates({
    required List<double?> profilElo,
    required List<TaskCandidate> candidates,
  }) {
    _validateProfileForSelection(profilElo);

    final ranked = <RankedTaskCandidate>[];

    for (int i = 0; i < candidates.length; i++) {
      final distance = candidateDistance(
        profilElo: profilElo,
        candidate: candidates[i],
      );
      if (distance == null) continue;

      ranked.add(
        RankedTaskCandidate(
          index: i,
          candidate: candidates[i],
          distance: distance,
        ),
      );
    }

    ranked.sort((a, b) => a.distance.compareTo(b.distance));
    return ranked;
  }

  /// Select one candidate randomly from the top [topN] closest tasks.
  ///
  /// This helper is valid for selecting a single task.
  /// For a complete Pilot 2 block use [selectRandomSubsetFromTopCandidates]
  /// so multiple tasks are sampled WITHOUT replacement.
  static int? selectRandomFromTopCandidates({
    required List<double?> profilElo,
    required List<TaskCandidate> candidates,
    int topN = 20,
    Random? random,
  }) {
    if (topN <= 0) {
      throw ArgumentError.value(topN, 'topN', 'topN must be positive.');
    }

    final ranked = rankCandidates(
      profilElo: profilElo,
      candidates: candidates,
    );
    if (ranked.isEmpty) return null;

    final limit = min(topN, ranked.length);
    final rng = random ?? Random();
    return ranked[rng.nextInt(limit)].index;
  }

  /// Select up to [count] DISTINCT candidates randomly from the top [topN]
  /// closest tasks.
  ///
  /// Default Pilot 2 use:
  ///   count = 5
  ///   topN = 20
  ///
  /// The returned indices refer to the original [candidates] list.
  /// If fewer than [count] valid candidates are available, all available
  /// candidates are returned and the higher-level practice algorithm must
  /// fill the missing slots according to its fallback rules.
  static List<int> selectRandomSubsetFromTopCandidates({
    required List<double?> profilElo,
    required List<TaskCandidate> candidates,
    int count = 5,
    int topN = 20,
    Random? random,
  }) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'count must be positive.');
    }
    if (topN <= 0) {
      throw ArgumentError.value(topN, 'topN', 'topN must be positive.');
    }

    final ranked = rankCandidates(
      profilElo: profilElo,
      candidates: candidates,
    );
    if (ranked.isEmpty) return const <int>[];

    final limit = min(topN, ranked.length);
    final pool = ranked.take(limit).toList();
    final rng = random ?? Random();

    // Fisher-Yates shuffle of the top-N pool.
    for (int i = pool.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }

    final takeCount = min(count, pool.length);
    return pool.take(takeCount).map((e) => e.index).toList();
  }

  /// LEGACY deterministic selector: returns the single closest task.
  ///
  /// WARNING:
  /// This method is kept only for backward compatibility with existing code.
  /// It does NOT implement the Pilot 2 "random from top 20" selection rule.
  /// Pilot 2 call-sites must use selectRandomFromTopCandidates() for one task
  /// or selectRandomSubsetFromTopCandidates() for multiple tasks.
  static int? selectTask({
    required List<double?> profilElo,
    required List<TaskCandidate> candidates,
  }) {
    final ranked = rankCandidates(
      profilElo: profilElo,
      candidates: candidates,
    );
    return ranked.isEmpty ? null : ranked.first.index;
  }

  // ─── Validation helpers ───────────────────────────────────────────────────

  static void _validateConfig(EloConfig config) {
    if (!config.lambda.isFinite || config.lambda <= 0.0) {
      throw ArgumentError('EloConfig.lambda must be finite and > 0.');
    }

    for (final entry in <MapEntry<String, double>>[
      MapEntry('targetStudentAtMatch', config.targetStudentAtMatch),
      MapEntry('targetTaskAtMatch', config.targetTaskAtMatch),
    ]) {
      if (!entry.value.isFinite ||
          entry.value <= 0.0 ||
          entry.value >= 1.0) {
        throw ArgumentError(
          'EloConfig.${entry.key} must be finite and strictly between 0 and 1.',
        );
      }
    }

    for (final entry in <MapEntry<String, double>>[
      MapEntry('k0Student', config.k0Student),
      MapEntry('kMinStudent', config.kMinStudent),
      MapEntry('alphaStudent', config.alphaStudent),
      MapEntry('k0Task', config.k0Task),
      MapEntry('alphaTask', config.alphaTask),
    ]) {
      if (!entry.value.isFinite || entry.value < 0.0) {
        throw ArgumentError(
          'EloConfig.${entry.key} must be finite and non-negative.',
        );
      }
    }

    if (config.kMinStudent > config.k0Student) {
      throw ArgumentError(
        'EloConfig.kMinStudent must not exceed k0Student.',
      );
    }
  }

  static void _validateScore(double score) {
    if (!score.isFinite || score < 0.0 || score > 1.0) {
      throw ArgumentError.value(
        score,
        'score',
        'Score must be finite and in the interval 0..1.',
      );
    }
  }

  static void _validateSingleRating(double value, String name) {
    if (!value.isFinite || value < 0.0 || value > 10.0) {
      throw ArgumentError.value(
        value,
        name,
        '$name must be finite and in the interval 0..10.',
      );
    }
  }

  static void _validateUpdateVectors({
    required List<double?> profilElo,
    required List<int> profilPocet,
    required List<double> relationVector,
    required List<double?> eloVector,
    required List<int> itemPocet,
  }) {
    _requireLength(profilElo, 'profilElo');
    _requireLength(profilPocet, 'profilPocet');
    _requireLength(relationVector, 'relationVector');
    _requireLength(eloVector, 'eloVector');
    _requireLength(itemPocet, 'itemPocet');

    for (int k = 0; k < kGpfDimensions; k++) {
      final relation = relationVector[k];
      if (!relation.isFinite ||
          (relation != 0.0 && relation != 1.0 && relation != 2.0)) {
        throw ArgumentError(
          'relationVector[$k] must be exactly 0, 1 or 2.',
        );
      }

      final studentRating = profilElo[k];
      if (studentRating != null) {
        _validateSingleRating(studentRating, 'profilElo[$k]');
      }

      final taskRating = eloVector[k];
      if (taskRating != null) {
        _validateSingleRating(taskRating, 'eloVector[$k]');
      }

      if (profilPocet[k] < 0) {
        throw ArgumentError('profilPocet[$k] must be non-negative.');
      }
      if (itemPocet[k] < 0) {
        throw ArgumentError('itemPocet[$k] must be non-negative.');
      }
    }
  }

  static void _validateProfileForSelection(List<double?> profilElo) {
    _requireLength(profilElo, 'profilElo');
    for (int k = 0; k < kGpfDimensions; k++) {
      final value = profilElo[k];
      if (value != null) {
        _validateSingleRating(value, 'profilElo[$k]');
      }
    }
  }

  static void _validateCandidate(TaskCandidate candidate) {
    _requireLength(candidate.relationVector, 'candidate.relationVector');
    _requireLength(candidate.eloVector, 'candidate.eloVector');

    for (int k = 0; k < kGpfDimensions; k++) {
      final relation = candidate.relationVector[k];
      if (!relation.isFinite ||
          (relation != 0.0 && relation != 1.0 && relation != 2.0)) {
        throw ArgumentError(
          'candidate.relationVector[$k] must be exactly 0, 1 or 2.',
        );
      }

      final taskRating = candidate.eloVector[k];
      if (taskRating != null) {
        _validateSingleRating(
          taskRating,
          'candidate.eloVector[$k]',
        );
      }
    }
  }

  static void _requireLength(List<Object?> list, String name) {
    if (list.length != kGpfDimensions) {
      throw ArgumentError(
        '$name must contain exactly $kGpfDimensions elements; '
        'got ${list.length}.',
      );
    }
  }
}
