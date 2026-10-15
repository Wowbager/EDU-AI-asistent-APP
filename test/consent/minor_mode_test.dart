import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('minorModeProvider', () {
    test('defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(minorModeProvider), isFalse);
    });

    test('set() persists the flag so it survives an offline restart', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(minorModeProvider.notifier).set(true);
      expect(container.read(minorModeProvider), isTrue);

      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      await restored.read(minorModeProvider.notifier).restore();

      expect(restored.read(minorModeProvider), isTrue);
    });

    test('clear() wipes the flag on logout', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(minorModeProvider.notifier).set(true);
      await container.read(minorModeProvider.notifier).clear();

      expect(container.read(minorModeProvider), isFalse);
    });
  });

  // The extra requirement layered onto this task (decision 12): a 401 on a
  // minor's account must wipe local data on the first reconnect after
  // revocation, not just log out — an offline device otherwise keeps a full
  // local copy of content and progress with no remote-wipe signal.
  group('wipeLocalDataIfMinor', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    Future<void> seedLocalUser() async {
      final id = await db.createGuestUser();
      await db.updateUserProfile(userId: id, name: 'Test User');
    }

    test('wipes local user data for a minor account', () async {
      await seedLocalUser();
      expect(await db.getActiveUser(), isNotNull);

      await wipeLocalDataIfMinor(isMinor: true, db: db);

      expect(await db.getActiveUser(), isNull,
          reason: 'a minor whose consent was revoked must have their local '
              'data wiped on the first reconnect (401)');
    });

    test('does not touch local user data for an adult account', () async {
      await seedLocalUser();
      expect(await db.getActiveUser(), isNotNull);

      await wipeLocalDataIfMinor(isMinor: false, db: db);

      expect(await db.getActiveUser(), isNotNull,
          reason: 'this minor-specific guarantee must not itself alter the '
              'adult 401 path — the ordinary adult logout/401 wipe (if any) '
              'is LogoutCoordinator.teardown\'s job, unchanged by this task');
    });
  });
}
