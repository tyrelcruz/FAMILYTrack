import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:finance_tracker/features/transactions/data/demo_data.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

class TransactionRepository {
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'finance_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          date INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )
      ''');
        for (final t in demoTransactions(DateTime.now())) {
          await db.insert('transactions', t.toMap()..remove('id'));
        }
      },
    );
  }

  Future<List<TransactionItem>> all() async {
    final db = await _database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(TransactionItem.fromMap).toList();
  }

  Future<void> insert(TransactionItem t) async {
    final db = await _database;
    await db.insert('transactions', t.toMap()..remove('id'));
  }

  Future<void> update(TransactionItem t) async {
    final db = await _database;
    await db.update(
      'transactions',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}
