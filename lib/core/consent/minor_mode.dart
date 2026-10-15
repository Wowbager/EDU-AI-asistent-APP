import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// Whether the signed-in account is a minor.
///
/// Fed from `minor` on the `/api/resolve-code` login response and `is_minor`
/// on `/api/user`, then persisted so the restrictions still hold on an
/// offline cold start — the flag must never fail open. A device that never
/// reconnects has no other way to know a previously-adult-looking account
/// became (or stays) a minor account, so the last known value always wins
/// over defaulting to false.
class MinorModeNotifier extends StateNotifier<bool> {
  static const _prefsKey = 'is_minor';

  MinorModeNotifier() : super(false);

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> clear() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

final minorModeProvider =
    StateNotifierProvider<MinorModeNotifier, bool>((ref) => MinorModeNotifier());

/// Wipe every local table when the account behind this data is a minor.
///
/// Called from the 401 handling in `AuthWrapper` (`root_navigator.dart`).
/// Revoking consent deletes the server-side Sanctum tokens immediately, so
/// any authenticated call 401s right away — but a child's persistent-session
/// token was minted for 30 days and the app is offline-first over a local
/// Drift database, so a device that never reconnects would otherwise keep a
/// full local copy of content and progress forever. There is no remote-wipe
/// signal; the first reconnect (this 401) is the only moment this device can
/// still be reached (see decision 12,
/// docs/superpowers/plans/2026-08-13-minor-consent-onboarding.md).
///
/// `LogoutCoordinator.teardown` (`core_providers.dart`) already performs a
/// full, unconditional local wipe on every logout/401 for every account —
/// this function does not change that. It exists as an explicit, narrowly
/// testable guarantee scoped to minors, so the legal requirement this task
/// implements can't regress silently if that shared, general-purpose path is
/// ever changed for unrelated reasons (e.g. to skip the wipe on a normal
/// adult re-login).
Future<void> wipeLocalDataIfMinor({
  required bool isMinor,
  required AppDatabase db,
}) async {
  if (!isMinor) return;
  await db.clearAllData();
}
