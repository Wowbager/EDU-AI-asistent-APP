import 'package:shared_preferences/shared_preferences.dart';

import '../practice/practice_filter.dart';

/// Persists the student's practice scope (subjects → areas) across sessions.
///
/// Backed by SharedPreferences rather than Drift: the selection is a device
/// preference, not synced content, and it has to be readable synchronously
/// when the dashboard builds its practice tile — an async read would flash the
/// unfiltered card count first.
///
/// Because it lives outside Drift, `db.clearAllData()` on logout does not
/// touch it; [clear] is called from the logout teardown so the next student on
/// a shared device does not inherit this one's selection (same trap as the
/// palette in BR-P4JUDT).
class PracticeFilterStore {
  static const String _key = 'practice_filter_v1';

  final SharedPreferences _prefs;

  PracticeFilterStore(this._prefs);

  PracticeFilter read() => PracticeFilter.decode(_prefs.getString(_key));

  Future<void> write(PracticeFilter filter) async {
    if (filter.isAll) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, filter.encode());
  }

  Future<void> clear() => _prefs.remove(_key);
}
