import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:finance_tracker/core/constants/user_profile.dart';
import 'package:finance_tracker/core/data/photo_store.dart';
import 'package:finance_tracker/core/utils/ids.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';

/// One shared connection so every feature reads and writes the same data.
///
/// Rows carry three sync flags: `dirty` (changed here, not uploaded yet),
/// `synced` (exists on the server) and `deleted` (removed here; kept until
/// the delete is uploaded).
class AppDatabase {
  AppDatabase._();

  static Future<Database>? _db;

  /// Set before first use to open somewhere else, e.g. in tests.
  static String? pathOverride;

  static Future<Database> get instance => _db ??= _open();

  /// Forgets the open connection and points at [path] (tests only).
  @visibleForTesting
  static void resetForTests(String path) {
    _db = null;
    pathOverride = path;
  }

  static Future<Database> _open() async {
    final path =
        pathOverride ?? p.join(await getDatabasesPath(), 'finance_tracker.db');
    return openDatabase(
      path,
      version: 8,
      onCreate: (db, _) async {
        await _createTables(db);
        await seedOwner(db);
      },
      onUpgrade: (db, from, _) async {
        // The UUID migration rebuilds every table at the latest shape.
        if (from < 3) {
          await _migrateToUuids(db, from);
          return;
        }
        if (from < 4) {
          await db.execute('ALTER TABLE transactions ADD COLUMN plan_id TEXT');
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN payment_method TEXT',
          );
          await _createPlans(db);
        }
        if (from < 5) await _createTransfersAndActivity(db);
        // Plans made by v4's table need the creator column; newer ones have it.
        if (from >= 4 && from < 6) {
          await db.execute('ALTER TABLE plans ADD COLUMN created_by TEXT');
        }
        if (from < 8) {
          // photo_path: the image on this phone; has_photo: the server has
          // one; photo_dirty: a change here still has to be uploaded.
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN photo_path TEXT',
          );
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN has_photo INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN photo_dirty INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from >= 4 && from < 7) {
          await db.execute(
            "ALTER TABLE plans ADD COLUMN destination TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE plans ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  static Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        member_id TEXT,
        plan_id TEXT,
        payment_method TEXT,
        photo_path TEXT,
        has_photo INTEGER NOT NULL DEFAULT 0,
        photo_dirty INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 1,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        is_owner INTEGER NOT NULL DEFAULT 0,
        user_id TEXT,
        dirty INTEGER NOT NULL DEFAULT 1,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        category TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 1,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createPlans(db);
    await _createTransfersAndActivity(db);
  }

  /// Trip and monthly budgets; `funds` and `shares` are JSON maps.
  static Future<void> _createPlans(DatabaseExecutor db) => db.execute('''
    CREATE TABLE plans (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      kind TEXT NOT NULL,
      start_date INTEGER NOT NULL,
      end_date INTEGER NOT NULL,
      funds TEXT NOT NULL,
      shares TEXT NOT NULL,
      split TEXT NOT NULL,
      created_by TEXT,
      destination TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      dirty INTEGER NOT NULL DEFAULT 1,
      synced INTEGER NOT NULL DEFAULT 0,
      deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');

  /// Money moved between wallets or people, and the family's activity
  /// feed (downloaded only, for notifications).
  static Future<void> _createTransfersAndActivity(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        amount REAL NOT NULL,
        from_method TEXT,
        to_method TEXT,
        from_member_id TEXT,
        to_member_id TEXT,
        plan_id TEXT,
        note TEXT NOT NULL DEFAULT '',
        date INTEGER NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 1,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE activity (
        id TEXT PRIMARY KEY,
        actor_user_id TEXT,
        actor_name TEXT NOT NULL,
        kind TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  /// The local "me" used until the phone joins a synced family.
  static Future<void> seedOwner(DatabaseExecutor db) => db.insert(
    'members',
    FamilyMember(
      id: newId(),
      name: UserProfile.firstName,
      color: FamilyMember.palette.first,
      isOwner: true,
    ).toMap(),
  );

  /// Wipes everything, e.g. before downloading a family's data.
  static Future<void> clear({bool keepOwner = false}) async {
    final db = await instance;
    await PhotoStore.deleteAll();
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('members');
      await txn.delete('budgets');
      await txn.delete('plans');
      await txn.delete('transfers');
      await txn.delete('activity');
      if (keepOwner) await seedOwner(txn);
    });
  }

  /// v1/v2 used integer ids; the sync API needs UUIDs.
  static Future<void> _migrateToUuids(Database db, int from) async {
    final txns = await db.query('transactions');
    final members = from >= 2
        ? await db.query('members')
        : const <Map<String, Object?>>[];
    final budgets = from >= 2
        ? await db.query('budgets')
        : const <Map<String, Object?>>[];
    await db.execute('DROP TABLE transactions');
    if (from >= 2) {
      await db.execute('DROP TABLE members');
      await db.execute('DROP TABLE budgets');
    }
    await _createTables(db);

    final memberIds = <int, String>{};
    for (final m in members) {
      final id = newId();
      memberIds[m['id'] as int] = id;
      await db.insert('members', {
        'id': id,
        'name': m['name'],
        'color': m['color'],
        'is_owner': m['is_owner'],
      });
    }
    if (members.isEmpty) await seedOwner(db);

    for (final t in txns) {
      await db.insert('transactions', {
        'id': newId(),
        'title': t['title'],
        'amount': t['amount'],
        'type': t['type'],
        'category': t['category'],
        'date': t['date'],
        'note': t['note'],
        'member_id': memberIds[t['member_id']],
      });
    }
    for (final b in budgets) {
      await db.insert('budgets', {
        'category': b['category'],
        'amount': b['amount'],
      });
    }
  }
}
