import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/utils/ids.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

class TransactionRepository {
  Future<List<TransactionItem>> all() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'transactions',
      where: 'deleted = 0',
      orderBy: 'date DESC, rowid DESC',
    );
    return rows.map(TransactionItem.fromMap).toList();
  }

  /// Always stores under a new id, so re-adding (e.g. undo) is a new record.
  Future<void> insert(TransactionItem t) async {
    final db = await AppDatabase.instance;
    await db.insert('transactions', {...t.toMap(), 'id': newId()});
  }

  Future<void> update(TransactionItem t) async {
    final db = await AppDatabase.instance;
    await db.update(
      'transactions',
      {...t.toMap(), 'dirty': 1},
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  /// Never-uploaded rows go right away; others wait for the delete to sync.
  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'transactions',
      where: 'id = ? AND synced = 0',
      whereArgs: [id],
    );
    await db.update(
      'transactions',
      {'deleted': 1, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
