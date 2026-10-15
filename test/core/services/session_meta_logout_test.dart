import 'package:eduai/core/services/session_meta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers SessionMeta.clear(), which runs on every logout path (logout button,
/// idle auto-logout, 401 teardown). The pre-login shared-device choice must not
/// survive it: on a shared browser profile a leftover opt-out would pre-tick
/// "stay logged in permanently" for the next person to use the machine
/// (BR-4TASK2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SessionMeta> sessionWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    return SessionMeta(await SharedPreferences.getInstance());
  }

  test('defaults to shared before any choice is made', () async {
    final session = await sessionWith({});
    expect(session.pendingSharedDevice, true);
  });

  test('clear() resets the opt-out back to the secure default', () async {
    final session = await sessionWith({});
    await session.setPendingSharedDevice(false);
    expect(session.pendingSharedDevice, false);

    await session.clear();

    expect(session.pendingSharedDevice, true);
  });

  test('clear() leaves a shared device on the same default', () async {
    final session = await sessionWith({});
    await session.setPendingSharedDevice(true);

    await session.clear();

    expect(session.pendingSharedDevice, true);
  });

  test('clear() wipes the live session metadata too', () async {
    final session = await sessionWith({
      'session_shared_device': true,
      'session_token_expires_at': DateTime.now().millisecondsSinceEpoch,
      'session_started_at': DateTime.now().millisecondsSinceEpoch,
      'session_last_active_at': DateTime.now().millisecondsSinceEpoch,
    });

    await session.clear();

    expect(session.sharedDevice, false);
    expect(session.expiresAt, isNull);
    expect(session.sessionStartedAt, isNull);
    expect(session.lastActiveAt, isNull);
  });
}
