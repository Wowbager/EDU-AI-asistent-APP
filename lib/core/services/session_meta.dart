import 'package:shared_preferences/shared_preferences.dart';

/// Session-scoped metadata for the current login.
///
/// shared_device sessions get a 30-minute access token with rotation, an
/// 8-hour server-side hard cap, and a 15-minute inactivity logout enforced
/// on-device. Persistent sessions (opt-out) use a 30-day token and ignore
/// inactivity.
///
/// The fields here are written from auth response payloads and consumed by:
/// - api_client (rotate-before-expiry decision)
/// - InactivityWatcher (idle logout for shared sessions)
/// - root_navigator (start-up expiry check)
class SessionMeta {
  static const String _sharedKey = 'session_shared_device';
  static const String _expiresAtKey = 'session_token_expires_at';
  static const String _sessionStartedAtKey = 'session_started_at';
  static const String _lastActiveAtKey = 'session_last_active_at';

  /// User's choice on the auth screen, read by login/register/verify calls
  /// before a session exists. Default true = shared (auto-logout).
  static const String _pendingSharedKey = 'session_pending_shared_device';

  /// Inactivity logout threshold for shared-device sessions.
  static const Duration inactivityLimit = Duration(minutes: 15);

  /// Refresh access token when within this margin of expiration.
  static const Duration rotateMargin = Duration(minutes: 5);

  /// Server-side hard cap on shared-device sessions. Enforced server-side
  /// in /api/auth/refresh; mirrored here for early-out checks.
  static const Duration sharedHardCap = Duration(hours: 8);

  final SharedPreferences _prefs;

  SessionMeta(this._prefs);

  bool get sharedDevice => _prefs.getBool(_sharedKey) ?? false;

  /// Pre-login choice from the auth screen. Defaults to true (shared) so
  /// new logins on a fresh device are secured by default.
  bool get pendingSharedDevice => _prefs.getBool(_pendingSharedKey) ?? true;

  Future<void> setPendingSharedDevice(bool shared) async {
    await _prefs.setBool(_pendingSharedKey, shared);
  }

  DateTime? get expiresAt {
    final ms = _prefs.getInt(_expiresAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  DateTime? get sessionStartedAt {
    final ms = _prefs.getInt(_sessionStartedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  DateTime? get lastActiveAt {
    final ms = _prefs.getInt(_lastActiveAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Apply session metadata from a login/rotate response.
  ///
  /// [markActive] records this as user activity (resets the idle clock). Pass
  /// true for genuine logins; false for automated token rotation, which must
  /// not keep a shared-device session alive on its own (BR-9SAH2R).
  Future<void> applyFromAuthResponse(
    Map<String, dynamic> data, {
    bool markActive = true,
  }) async {
    final shared = data['shared_device'] == true;
    await _prefs.setBool(_sharedKey, shared);

    final expires = _parseIso(data['expires_at']);
    if (expires != null) {
      await _prefs.setInt(_expiresAtKey, expires.millisecondsSinceEpoch);
    } else {
      await _prefs.remove(_expiresAtKey);
    }

    final started = _parseIso(data['session_started_at']);
    if (started != null) {
      await _prefs.setInt(_sessionStartedAtKey, started.millisecondsSinceEpoch);
    } else {
      await _prefs.remove(_sessionStartedAtKey);
    }

    if (shared) {
      if (markActive) await touchActivity();
    } else {
      await _prefs.remove(_lastActiveAtKey);
    }
  }

  /// Coalesce activity writes: keyboard/scroll events fire many times per
  /// second, so skip the disk write when the last one is this recent. Well
  /// under [inactivityLimit], so the logout decision is unaffected.
  static const Duration _touchThrottle = Duration(seconds: 10);

  /// Update the last-active timestamp. No-op when not in shared mode.
  Future<void> touchActivity() async {
    if (!sharedDevice) return;
    final last = lastActiveAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _touchThrottle) return;
    await _prefs.setInt(_lastActiveAtKey, now.millisecondsSinceEpoch);
  }

  /// True when the access token is past its expiration or within rotateMargin.
  bool needsRotation({Duration? margin}) {
    final exp = expiresAt;
    if (exp == null) return false;
    final cutoff = DateTime.now().add(margin ?? rotateMargin);
    return cutoff.isAfter(exp);
  }

  /// True when shared session exceeded inactivity limit.
  bool isInactivityExpired() {
    if (!sharedDevice) return false;
    final last = lastActiveAt;
    if (last == null) return false;
    return DateTime.now().difference(last) >= inactivityLimit;
  }

  /// Time left before the shared-session idle logout fires, clamped to zero.
  ///
  /// Resets whenever [touchActivity] moves [lastActiveAt] forward, so a caller
  /// polling this each second renders a live countdown that restarts on every
  /// user action. Returns null for non-shared sessions (no countdown to show).
  Duration? inactivityRemaining() {
    if (!sharedDevice) return null;
    final base = lastActiveAt ?? DateTime.now();
    final remaining = inactivityLimit - DateTime.now().difference(base);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// True when shared session exceeded the hard cap from session start.
  bool isHardCapExceeded() {
    if (!sharedDevice) return false;
    final started = sessionStartedAt;
    if (started == null) return false;
    return DateTime.now().difference(started) >= sharedHardCap;
  }

  Future<void> clear() async {
    await _prefs.remove(_sharedKey);
    await _prefs.remove(_expiresAtKey);
    await _prefs.remove(_sessionStartedAtKey);
    await _prefs.remove(_lastActiveAtKey);
    // Reset the pre-login choice to the secure default (shared) as well.
    // On web these prefs live in localStorage, shared by everyone using the
    // browser profile, so a leftover opt-out would pre-tick "stay logged in
    // permanently" for the next person on a classroom PC (BR-4TASK2). Shared
    // devices lose nothing: shared IS the default this falls back to.
    await _prefs.remove(_pendingSharedKey);
  }

  static DateTime? _parseIso(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
