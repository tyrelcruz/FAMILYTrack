import 'dart:io';

import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/data/photo_store.dart';
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

  /// Keeps [photo] as the plan's cover and flags it for upload.
  Future<void> setCover(String planId, File photo) async {
    final db = await AppDatabase.instance;
    final path = await PhotoStore.save(planId, photo, folder: 'covers');
    await db.update(
      'plans',
      {'cover_path': path, 'cover_dirty': 1},
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  Future<void> removeCover(String planId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'plans',
      columns: ['cover_path'],
      where: 'id = ?',
      whereArgs: [planId],
    );
    if (rows.isEmpty) return;
    await PhotoStore.delete(rows.first['cover_path'] as String?);
    await db.update(
      'plans',
      {'cover_path': null, 'cover_dirty': 1},
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  /// Covers picked before they synced sat in their own folder; adopt them
  /// once, then remove it.
  Future<void> importLegacyCovers() async {
    final files = await PhotoStore.legacyPlanCovers();
    if (files.isEmpty) return;
    final db = await AppDatabase.instance;
    for (final f in files) {
      final id = f.uri.pathSegments.last.split('.').first;
      final has = await db.query(
        'plans',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (has.isNotEmpty) await setCover(id, f);
    }
    await PhotoStore.deleteLegacyPlanCovers();
  }

  /// Removes the plan; its expenses stay as normal transactions.
  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'plans',
      columns: ['cover_path'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      await PhotoStore.delete(rows.first['cover_path'] as String?);
    }
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
