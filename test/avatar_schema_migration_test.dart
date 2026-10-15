// Drift migration for the avatar content bounds (BR-7JRBCN).
//
// Schema 16 shipped to stage with `avatar_items` but without the four bounds
// columns. Adding them to the table definition without bumping the version
// would leave every one of those devices with a table the queries no longer
// match — every avatar read would fail with "no such column".
//
//   flutter test test/avatar_schema_migration_test.dart
import 'dart:ui' show Rect;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/database/app_database.dart';

/// The `avatar_items` table exactly as version 16 created it — no bounds.
const _v16AvatarItems = '''
CREATE TABLE avatar_items (
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  slot TEXT NOT NULL,
  layer INTEGER NOT NULL,
  url TEXT NOT NULL,
  rarity TEXT NOT NULL DEFAULT 'common',
  price INTEGER NOT NULL DEFAULT 0,
  is_default INTEGER NOT NULL DEFAULT 0,
  svg_source TEXT,
  server_updated_at INTEGER,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (code)
)''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bounds columns arrive in their own schema version', () async {
    // Adding them to the table definition without bumping the version would
    // mean no migration ever runs for a device already on 16 — the columns
    // would exist only for fresh installs.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(
      db.schemaVersion,
      greaterThan(16),
      reason: 'version 16 shipped to stage without the bounds columns',
    );
    await db.close();
  });

  test('a version 16 database gains the bounds columns', () async {
    final executor = NativeDatabase.memory();
    final db = AppDatabase.forTesting(executor);

    // Stand up the v16 shape, then let the migrator take it to current.
    await db.customStatement('DROP TABLE IF EXISTS avatar_items');
    await db.customStatement(_v16AvatarItems);
    await db.customStatement(
      "INSERT INTO avatar_items (code, name, slot, layer, url, updated_at) "
      "VALUES ('head_crown', 'Koruna', 'head', 40, 'https://r2/x.svg', 0)",
    );

    await db.customStatement('PRAGMA user_version = 16');
    await db.migration.onUpgrade(db.createMigrator(), 16, db.schemaVersion);

    // The read path that would have thrown "no such column".
    final items = await db.getAvatarItems();
    expect(items, hasLength(1));
    expect(items.single.boundsLeft, isNull);

    // And the column is writable, not just present.
    await db.setAvatarItemBounds(
      'head_crown',
      const Rect.fromLTRB(0.1, 0.2, 0.3, 0.4),
    );
    expect((await db.getAvatarItem('head_crown'))!.boundsLeft, closeTo(0.1, 1e-9));

    await db.close();
  });

  test('a fresh install already has them', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await db.upsertAvatarItem(
      const AvatarItemsTableCompanion(
        code: Value('head_crown'),
        name: Value('Koruna'),
        slot: Value('head'),
        layer: Value(40),
        url: Value('https://r2/x.svg'),
        boundsLeft: Value(0.25),
      ),
    );

    expect((await db.getAvatarItem('head_crown'))!.boundsLeft, closeTo(0.25, 1e-9));

    await db.close();
  });
}
