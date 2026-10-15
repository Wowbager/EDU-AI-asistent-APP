// The EDUX coin wallet (BR-HK9828).
//
// Coins reach the Achievements screen from two places: the server banks what a
// mini-game run collected, and the device credits achievement rewards itself so
// they show up offline. These pin the local half — the schema that survives an
// upgrade, and the award path that must not lose a coin.
//
//   flutter test test/coin_wallet_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';

/// The `user_stats` table exactly as version 19 left it — no wallet.
const _v19UserStats = '''
CREATE TABLE user_stats (
  id TEXT NOT NULL,
  server_id INTEGER,
  user_id TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  xp_points INTEGER NOT NULL DEFAULT 0,
  courses_count INTEGER NOT NULL DEFAULT 0,
  streak_days INTEGER NOT NULL DEFAULT 0,
  achievements_count INTEGER NOT NULL DEFAULT 0,
  last_streak_date INTEGER,
  daily_xp_date INTEGER,
  daily_xp_amount INTEGER NOT NULL DEFAULT 0,
  sync_status INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  server_updated_at INTEGER,
  PRIMARY KEY (id)
)''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the wallet arrives in its own schema version', () async {
    // Adding the columns to the table definition without bumping the version
    // would leave every device already on 19 with a table the queries no longer
    // match — every stats read would fail with "no such column".
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(
      db.schemaVersion,
      greaterThan(19),
      reason: 'version 19 shipped without the coin columns',
    );
    await db.close();
  });

  test('a version 19 database gains the wallet, keeping its stats', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await db.customStatement('DROP TABLE IF EXISTS user_stats');
    await db.customStatement(_v19UserStats);
    await db.customStatement(
      'INSERT INTO user_stats (id, user_id, level, xp_points, created_at, updated_at) '
      "VALUES ('local-1', 'user-1', 4, 1700, 0, 0)",
    );

    await db.customStatement('PRAGMA user_version = 19');
    await db.migration.onUpgrade(db.createMigrator(), 19, db.schemaVersion);

    // The read path that would otherwise have thrown "no such column".
    final stats = await db.getUserStats('user-1');
    expect(stats, isNotNull);
    expect(stats!.xpPoints, 1700, reason: 'the upgrade must not lose progress');
    expect(stats.coinsEarned, 0);
    expect(stats.coinsBalance, 0);

    await db.close();
  });

  test('the wallet columns are writable, not just present', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await _seedStats(db, 'local-1', 'user-1');
    await db.updateUserStats(id: 'local-1', coinsEarned: 42, coinsBalance: 30);

    final stats = await db.getUserStats('user-1');
    expect(stats!.coinsEarned, 42);
    expect(stats.coinsBalance, 30);

    await db.close();
  });

  test('spending does not shrink what was earned', () async {
    // The whole reason for two columns: the Achievements screen reads
    // `coinsEarned`, so buying something must leave that number alone.
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await _seedStats(db, 'local-1', 'user-1');
    await db.updateUserStats(id: 'local-1', coinsEarned: 100, coinsBalance: 100);
    await db.updateUserStats(id: 'local-1', coinsBalance: 60);

    final stats = await db.getUserStats('user-1');
    expect(stats!.coinsEarned, 100);
    expect(stats.coinsBalance, 60);

    await db.close();
  });
}

Future<void> _seedStats(AppDatabase db, String localId, String userId) {
  return db.upsertUserStats(UserStatsTableCompanion(
    id: Value(localId),
    userId: Value(userId),
  ));
}
