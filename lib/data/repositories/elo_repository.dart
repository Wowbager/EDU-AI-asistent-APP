import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/elo/elo_engine.dart';
import '../../core/elo/task_difficulty.dart' as task_difficulty;
import '../../core/sync/sync_status.dart';

/// User ELO profile model for use in the UI / engine layer.
class UserEloProfile {
  final String id;
  final String userId;
  final List<double?> profilElo;
  final List<int> profilPocet;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserEloProfile({
    required this.id,
    required this.userId,
    required this.profilElo,
    required this.profilPocet,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Repository for user ELO profile operations.
///
/// Handles local persistence of the student's 35-element ELO vector and
/// task-count vector.  Sync-to-server will be added in a later phase.
class EloRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  EloRepository({required AppDatabase db}) : _db = db;

  // ═══════════════════════════════════════════════════════════════════════════
  // Serialisation helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Encode a nullable-double list to a JSON string.
  static String _encodeEloVector(List<double?> vector) {
    return jsonEncode(vector);
  }

  /// Decode a JSON string into a nullable-double list (35 elements).
  static List<double?> _decodeEloVector(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.map((e) {
      if (e == null) return null;
      return (e as num).toDouble();
    }).toList();
  }

  /// Encode an int list to a JSON string.
  static String _encodePocetVector(List<int> vector) {
    return jsonEncode(vector);
  }

  /// Decode a JSON string into an int list (35 elements).
  static List<int> _decodePocetVector(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.map((e) => (e as num).toInt()).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Read Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Retrieve the ELO profile for [userId], or `null` if none exists.
  Future<UserEloProfile?> getProfile(String userId) async {
    final rows = await (_db.select(_db.userEloProfileTable)
          ..where((t) => t.userId.equals(userId)))
        .get();
    if (rows.isEmpty) return null;
    return _rowToProfile(rows.first);
  }

  /// Create a fresh profile filled with nulls / zeros.
  Future<UserEloProfile> createDefaultProfile(String userId) async {
    final localId = _uuid.v4();
    final now = DateTime.now();
    final emptyElo = List<double?>.filled(kGpfDimensions, null);
    final emptyPocet = List<int>.filled(kGpfDimensions, 0);

    await _db.into(_db.userEloProfileTable).insert(
      UserEloProfileTableCompanion(
        id: Value(localId),
        userId: Value(userId),
        profilElo: Value(_encodeEloVector(emptyElo)),
        profilPocet: Value(_encodePocetVector(emptyPocet)),
        syncStatus: Value(SyncStatus.synced.toInt()),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return UserEloProfile(
      id: localId,
      userId: userId,
      profilElo: emptyElo,
      profilPocet: emptyPocet,
      syncStatus: SyncStatus.synced,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get or create the ELO profile for [userId].
  Future<UserEloProfile> getOrCreateProfile(String userId) async {
    final existing = await getProfile(userId);
    if (existing != null) return existing;
    return createDefaultProfile(userId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Write Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Persist updated ELO vectors after an engine run.
  ///
  /// Marks the record as [SyncStatus.pending] so the sync service will
  /// push it to the server on the next sync cycle.
  Future<void> saveProfile(
    String userId,
    List<double?> profilElo,
    List<int> profilPocet,
  ) async {
    final profile = await getOrCreateProfile(userId);
    final now = DateTime.now();

    await (_db.update(_db.userEloProfileTable)
          ..where((t) => t.id.equals(profile.id)))
        .write(
      UserEloProfileTableCompanion(
        profilElo: Value(_encodeEloVector(profilElo)),
        profilPocet: Value(_encodePocetVector(profilPocet)),
        syncStatus: Value(SyncStatus.pending.toInt()),
        updatedAt: Value(now),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  UserEloProfile _rowToProfile(UserEloProfileTableData row) {
    return UserEloProfile(
      id: row.id,
      userId: row.userId,
      profilElo: _decodeEloVector(row.profilElo),
      profilPocet: _decodePocetVector(row.profilPocet),
      syncStatus: SyncStatusExtension.fromInt(row.syncStatus),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Task difficulty (read cache of the server's calibration, BR-697NCA)
  // ═══════════════════════════════════════════════════════════════════════════

  /// The difficulty D to answer [blockId] with: the server's calibrated value
  /// per dimension where the last pull brought one, [contentElo] elsewhere.
  /// The server is the only writer of D — nothing here stores it.
  Future<List<double?>> effectiveTaskElo(
    String blockId,
    List<double?> contentElo,
  ) async {
    final row = await _db.getBlockStats(blockId);
    return task_difficulty.effectiveTaskElo(
      contentElo,
      row == null ? null : _decodeEloVector(row.eloVector),
    );
  }

  /// Cached calibrated D per block for [blockIds]; blocks the server has not
  /// calibrated are absent.
  Future<Map<String, List<double?>>> calibratedTaskElo(
    Iterable<String> blockIds,
  ) async {
    final rows = await _db.getBlockStatsFor(blockIds);
    return {
      for (final row in rows) row.blockId: _decodeEloVector(row.eloVector),
    };
  }
}
