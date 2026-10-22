import 'dart:io';

import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/data/photo_store.dart';
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
  /// A [photo] is copied into the app's folder and queued for upload.
  Future<void> insert(TransactionItem t, {File? photo}) async {
    final db = await AppDatabase.instance;
    final id = newId();
    final stored = photo ?? (t.photoPath == null ? null : File(t.photoPath!));
    final path = stored == null ? null : await PhotoStore.save(id, stored);
    await db.insert('transactions', {
      ...t.toMap(),
      'id': id,
      'photo_path': path,
      'photo_dirty': path == null ? 0 : 1,
    });
  }

  /// Sets, replaces or (with null) removes the photo; uploaded on next sync.
  Future<void> setPhoto(String id, File? photo) async {
    final db = await AppDatabase.instance;
    final row = (await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    )).firstOrNull;
    if (row == null) return;
    final path = photo == null ? null : await PhotoStore.save(id, photo);
    if (photo == null) await PhotoStore.delete(row['photo_path'] as String?);
    final onServer = row['has_photo'] == 1;
    await db.update(
      'transactions',
      {
        'photo_path': path,
        // Nothing to tell the server when a photo is removed that it never had.
        'photo_dirty': (path != null || onServer) ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final row = (await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    )).firstOrNull;
    // Keep the file while the delete is waiting to sync; the row goes later.
    if (row != null && row['synced'] == 0) {
      await PhotoStore.delete(row['photo_path'] as String?);
    }
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
