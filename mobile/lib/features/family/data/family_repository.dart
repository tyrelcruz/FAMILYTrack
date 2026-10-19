import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/utils/ids.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';

class FamilyRepository {
  Future<List<FamilyMember>> members() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'members',
      where: 'deleted = 0',
      orderBy: 'is_owner DESC, rowid',
    );
    return rows.map(FamilyMember.fromMap).toList();
  }

  /// Returns the new member's id.
  Future<String> insertMember(FamilyMember m) async {
    final db = await AppDatabase.instance;
    final id = newId();
    await db.insert('members', {...m.toMap(), 'id': id});
    return id;
  }

  Future<void> updateMember(FamilyMember m) async {
    final db = await AppDatabase.instance;
    await db.update(
      'members',
      {'name': m.name, 'color': m.toMap()['color'], 'dirty': 1},
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  /// Removes the member; their transactions fall back to the owner.
  Future<void> deleteMember(String id) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'member_id': null, 'dirty': 1},
        where: 'member_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'members',
        where: 'id = ? AND synced = 0',
        whereArgs: [id],
      );
      await txn.update(
        'members',
        {'deleted': 1, 'dirty': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Budget>> budgets() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'budgets',
      where: 'deleted = 0',
      orderBy: 'rowid',
    );
    return rows.map(Budget.fromMap).toList();
  }

  /// Inserts or replaces the budget for its category.
  Future<void> saveBudget(Budget b) async {
    final db = await AppDatabase.instance;
    await db.rawInsert(
      '''
      INSERT INTO budgets (category, amount) VALUES (?, ?)
      ON CONFLICT (category)
      DO UPDATE SET amount = excluded.amount, dirty = 1, deleted = 0
      ''',
      [b.categoryId, b.limit],
    );
  }

  Future<void> deleteBudget(String categoryId) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'budgets',
      where: 'category = ? AND synced = 0',
      whereArgs: [categoryId],
    );
    await db.update(
      'budgets',
      {'deleted': 1, 'dirty': 1},
      where: 'category = ?',
      whereArgs: [categoryId],
    );
  }
}
