import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/mini_game_model.dart';
import '../datasources/remote/mini_games_remote_datasource.dart';

/// Repository for mini games ("Minihry").
///
/// The games themselves ship with the app build, so the listing is worth
/// showing offline — but *entitlement* (attempts left, cooldown, level) is
/// server-owned and cannot be recomputed on the device. So the cache stores
/// metadata only: entitlement is stripped on write, and everything read back
/// renders as [MiniGameLock.offline]. That also means the cache holds nothing
/// user-specific and survives an account switch harmlessly.
class MiniGamesRepository {
  static const String _cacheKey = 'mini_games_cache_v1';

  final MiniGamesRemoteDataSource _remoteDataSource;
  final SharedPreferences _prefs;

  MiniGamesRepository(this._remoteDataSource, this._prefs);

  /// Fetch the listing, falling back to the metadata cache when offline.
  ///
  /// Throws only when the network fails *and* there is nothing cached — a
  /// first run with no connection has genuinely nothing to show.
  Future<MiniGameList> fetchList() async {
    final result = await _remoteDataSource.getMiniGames();

    if (result.isFailure) {
      final cached = _readCache();
      if (cached.isNotEmpty) {
        return MiniGameList(items: cached, level: 1, fromCache: true);
      }
      throw Exception(result.error);
    }

    _writeCache(result.data!.items);
    return result.data!;
  }

  /// Spend an attempt. Throws when the server refuses (stale snapshot) or the
  /// device is offline — starting a run always needs the server's blessing.
  Future<MiniGameRun> play(String code) async {
    final result = await _remoteDataSource.play(code);
    if (result.isFailure) throw Exception(result.error);
    return result.data!;
  }

  /// Report a finished run's score and the EDUX coins it collected.
  ///
  /// Best effort by design: the run is over and the attempt is already paid
  /// for, so a lost score must not turn into an error the player has to deal
  /// with. Returns whether it landed.
  ///
  /// This is also what banks the coins (BR-HK9828) — the server credits the
  /// wallet, because only it can tell the run apart from a forged one. A
  /// report that never lands costs the player those coins; that is the same
  /// trade the score already makes, and it needs a connection either way.
  Future<bool> submitScore(int playId, int score, int coins) async {
    final result = await _remoteDataSource.submitScore(playId, score, coins);
    return result.isSuccess;
  }

  // ── Cache ───────────────────────────────────────────────────────────────

  List<MiniGame> _readCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((json) => MiniGame.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // A cache written by an older schema is not worth recovering.
      _prefs.remove(_cacheKey);
      return const [];
    }
  }

  void _writeCache(List<MiniGame> items) {
    final payload = items.map((item) => item.asOffline().toJson()).toList();
    _prefs.setString(_cacheKey, jsonEncode(payload));
  }
}
