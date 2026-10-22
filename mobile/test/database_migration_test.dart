import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finance_tracker/core/data/app_database.dart';

void main() {
  test('v2 data (integer ids) upgrades to UUIDs with links intact', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ft_migration');
    final path = '${dir.path}/finance_tracker.db';

    final old = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
            amount REAL NOT NULL, type TEXT NOT NULL, category TEXT NOT NULL,
            date INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '',
            member_id INTEGER)
        ''');
        await db.execute('''
          CREATE TABLE members (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
            color INTEGER NOT NULL, is_owner INTEGER NOT NULL DEFAULT 0)
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL UNIQUE, amount REAL NOT NULL)
        ''');
      },
    );
    await old.insert('members', {'name': 'Me', 'color': 1, 'is_owner': 1});
    final kid = await old.insert('members', {'name': 'Kid', 'color': 2});
    await old.insert('transactions', {
      'title': 'Toy',
      'amount': 10,
      'type': 'expense',
      'category': 'shopping',
      'date': 0,
      'member_id': kid,
    });
    await old.insert('budgets', {'category': 'food', 'amount': 500});
    await old.close();

    AppDatabase.pathOverride = path;
    final db = await AppDatabase.instance;
    final members = await db.query('members');
    final txn = (await db.query('transactions')).single;
    final kidRow = members.firstWhere((m) => m['name'] == 'Kid');

    expect(members, hasLength(2));
    expect(kidRow['id'], isA<String>());
    expect(txn['member_id'], kidRow['id']);
    expect(txn['dirty'], 1);
    expect((await db.query('budgets')).single['amount'], 500);
    // v4 additions exist too.
    expect(txn.containsKey('plan_id'), isTrue);
    expect(await db.query('plans'), isEmpty);
    await db.close();
    await dir.delete(recursive: true);
  });

  test('v3 (current installs) gains plans without losing data', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ft_migration_v3');
    final path = '${dir.path}/finance_tracker.db';
    final old = await openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, amount REAL NOT NULL,
            type TEXT NOT NULL, category TEXT NOT NULL, date INTEGER NOT NULL,
            note TEXT NOT NULL DEFAULT '', member_id TEXT,
            dirty INTEGER NOT NULL DEFAULT 1,
            synced INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0)
        ''');
        await db.execute('''
          CREATE TABLE members (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, color INTEGER NOT NULL,
            is_owner INTEGER NOT NULL DEFAULT 0, user_id TEXT,
            dirty INTEGER NOT NULL DEFAULT 1,
            synced INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0)
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            category TEXT PRIMARY KEY, amount REAL NOT NULL,
            dirty INTEGER NOT NULL DEFAULT 1,
            synced INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0)
        ''');
      },
    );
    await old.insert('transactions', {
      'id': 'abc',
      'title': 'Lunch',
      'amount': 120,
      'type': 'expense',
      'category': 'food',
      'date': 0,
      'synced': 1,
      'dirty': 0,
    });
    await old.close();

    AppDatabase.resetForTests(path);
    final db = await AppDatabase.instance;
    final txn = (await db.query('transactions')).single;
    expect(txn['id'], 'abc');
    expect(txn['synced'], 1);
    expect(txn['plan_id'], isNull);
    expect(await db.query('plans'), isEmpty);
    // v5: transfers and the activity feed.
    expect(await db.query('transfers'), isEmpty);
    expect(await db.query('activity'), isEmpty);
    await db.close();
    await dir.delete(recursive: true);
  });

  test('v5 plans gain a creator column', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ft_migration_v5');
    final path = '${dir.path}/finance_tracker.db';
    final old = await openDatabase(
      path,
      version: 5,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, amount REAL NOT NULL,
            type TEXT NOT NULL, category TEXT NOT NULL, date INTEGER NOT NULL,
            note TEXT NOT NULL DEFAULT '', member_id TEXT, plan_id TEXT,
            payment_method TEXT, dirty INTEGER NOT NULL DEFAULT 1,
            synced INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0)
        ''');
        await db.execute('''
        CREATE TABLE plans (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL,
          start_date INTEGER NOT NULL, end_date INTEGER NOT NULL,
          funds TEXT NOT NULL, shares TEXT NOT NULL, split TEXT NOT NULL,
          dirty INTEGER NOT NULL DEFAULT 1,
          synced INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0)
      ''');
      },
    );
    await old.insert('plans', {
      'id': 'p1',
      'name': 'Trip',
      'kind': 'trip',
      'start_date': 0,
      'end_date': 0,
      'funds': '{}',
      'shares': '{}',
      'split': 'equal',
    });
    await old.close();

    AppDatabase.resetForTests(path);
    final db = await AppDatabase.instance;
    final plan = (await db.query('plans')).single;
    expect(plan['name'], 'Trip');
    expect(plan.containsKey('created_by'), isTrue);
    // v7: where it is and what it's about.
    expect(plan['destination'], '');
    expect(plan['description'], '');
    // v8: receipt photos on transactions.
    final cols = (await db.rawQuery(
      'PRAGMA table_info(transactions)',
    )).map((c) => c['name']).toSet();
    expect(cols, containsAll(['photo_path', 'has_photo', 'photo_dirty']));
    await db.close();
    await dir.delete(recursive: true);
  });
}
