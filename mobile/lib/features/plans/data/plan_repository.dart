import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/utils/ids.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';

class PlanRepository {
  Future<List<Plan>> all() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'plans',
      where: 'deleted = 0',
      orderBy: 'start_date DESC',
    );
    return rows.map(Plan.fromMap).toList();
  }

  Future<void> insert(Plan p) async {
    final db = await AppDatabase.instance;
    await db.insert('plans', {...p.toMap(), 'id': newId()});
  }

  Future<void> update(Plan p) async {
    final db = await AppDatabase.instance;
    await db.update(
      'plans',
      {...p.toMap(), 'dirty': 1},
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  /// Removes the plan; its expenses stay as normal transactions.
  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'plan_id': null, 'dirty': 1},
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'plans',
        where: 'id = ? AND synced = 0',
        whereArgs: [id],
      );
      await txn.update(
        'plans',
        {'deleted': 1, 'dirty': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
