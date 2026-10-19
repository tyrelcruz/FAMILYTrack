import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/utils/ids.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';

class TransferRepository {
  Future<List<Transfer>> all() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'transfers',
      where: 'deleted = 0',
      orderBy: 'date DESC, rowid DESC',
    );
    return rows.map(Transfer.fromMap).toList();
  }

  Future<void> insert(Transfer t) async {
    final db = await AppDatabase.instance;
    await db.insert('transfers', {...t.toMap(), 'id': newId()});
  }

  Future<void> update(Transfer t) async {
    final db = await AppDatabase.instance;
    await db.update(
      'transfers',
      {...t.toMap(), 'dirty': 1},
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  /// Never-uploaded rows go right away; others wait for the delete to sync.
  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'transfers',
      where: 'id = ? AND synced = 0',
      whereArgs: [id],
    );
    await db.update(
      'transfers',
      {'deleted': 1, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
