import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'package:finance_tracker/core/api/api_client.dart';
import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/data/photo_store.dart';

/// The group was deleted or this user is no longer in it.
class GroupGoneException implements Exception {
  const GroupGoneException();
}

class SyncResult {
  const SyncResult({required this.serverTime, required this.group});

  /// Pass back as `since` next time.
  final int serverTime;

  /// Latest group details: name, invite code and active members.
  final Map<String, dynamic> group;
}

/// Two-way sync between the local database and one family group.
///
/// 1. Upload every row flagged `dirty` (members and plans, then transfers
///    and transactions, then budgets, so references exist before they're
///    used).
/// 2. Download everything changed on the server since the last sync and
///    apply it, skipping rows that changed locally in the meantime.
class SyncService {
  SyncService(this._api);

  final ApiClient _api;

  Future<SyncResult> sync(String groupId, {int? since}) async {
    final base = '/groups/$groupId';
    final Map<String, dynamic> group;
    try {
      group = await _api.get(base);
    } on ApiException catch (e) {
      if (e.status == 404) throw const GroupGoneException();
      rethrow;
    }

    final db = await AppDatabase.instance;
    final rejected = await _push(db, base);
    // A refused upload leaves the local row out of step with the server;
    // a full download puts it back.
    final res = await _api.get(
      '$base/sync',
      query: {'since': '${rejected ? 0 : (since ?? 0)}'},
    );
    await _pull(db, res);
    await _syncPhotoFiles(db, base);
    await _syncCoverFiles(db, base);
    return SyncResult(serverTime: res['serverTime'] as int, group: group);
  }

  /// Returns true if the server refused any change.
  Future<bool> _push(Database db, String base) async {
    var rejected = false;

    Future<void> upload(
      String table,
      String key,
      Object id, {
      required bool synced,
      required bool deleted,
      required Future<void> Function() send,
    }) async {
      try {
        await send();
        deleted
            ? await db.delete(table, where: '$key = ?', whereArgs: [id])
            : await db.update(
                table,
                {'dirty': 0, 'synced': 1},
                where: '$key = ?',
                whereArgs: [id],
              );
      } on ApiException catch (e) {
        if (e.isNetwork || e.status == 401 || e.status >= 500) rethrow;
        if (e.status == 409 && !deleted) {
          // Already uploaded by an earlier attempt; update it next time.
          await db.update(
            table,
            {'synced': 1},
            where: '$key = ?',
            whereArgs: [id],
          );
          return;
        }
        rejected = true;
        if (deleted || !synced || e.status == 404) {
          await db.delete(table, where: '$key = ?', whereArgs: [id]);
        } else {
          await db.update(
            table,
            {'dirty': 0},
            where: '$key = ?',
            whereArgs: [id],
          );
        }
      }
    }

    final members = await db.query('members', where: 'dirty = 1');
    for (final m in members.where((m) => m['deleted'] == 0)) {
      final id = m['id'] as String;
      final synced = m['synced'] == 1;
      final body = {'name': m['name'], 'color': m['color']};
      await upload(
        'members',
        'id',
        id,
        synced: synced,
        deleted: false,
        send: () => synced
            ? _api.patch('$base/members/$id', body)
            : _api.post('$base/members', {...body, 'id': id}),
      );
    }

    final plans = await db.query('plans', where: 'dirty = 1');
    for (final p in plans.where((p) => p['deleted'] == 0)) {
      final id = p['id'] as String;
      final synced = p['synced'] == 1;
      final body = {
        'name': p['name'],
        'kind': p['kind'],
        'startDate': p['start_date'],
        'endDate': p['end_date'],
        'funds': jsonDecode(p['funds'] as String),
        'shares': jsonDecode(p['shares'] as String),
        'split': p['split'],
        'destination': p['destination'],
        'description': p['description'],
      };
      await upload(
        'plans',
        'id',
        id,
        synced: synced,
        deleted: false,
        send: () => synced
            ? _api.patch('$base/plans/$id', body)
            : _api.post('$base/plans', {...body, 'id': id}),
      );
    }

    final transfers = await db.query('transfers', where: 'dirty = 1');
    for (final t in transfers) {
      final id = t['id'] as String;
      final synced = t['synced'] == 1;
      final deleted = t['deleted'] == 1;
      final body = {
        'kind': t['kind'],
        'amount': t['amount'],
        'fromMethod': t['from_method'],
        'toMethod': t['to_method'],
        'fromMemberId': t['from_member_id'],
        'toMemberId': t['to_member_id'],
        'planId': t['plan_id'],
        'note': t['note'],
        'date': t['date'],
      };
      await upload(
        'transfers',
        'id',
        id,
        synced: synced,
        deleted: deleted,
        send: () => deleted
            ? _api.delete('$base/transfers/$id')
            : synced
            ? _api.patch('$base/transfers/$id', body)
            : _api.post('$base/transfers', {...body, 'id': id}),
      );
    }

    final txns = await db.query('transactions', where: 'dirty = 1');
    for (final t in txns) {
      final id = t['id'] as String;
      final synced = t['synced'] == 1;
      final deleted = t['deleted'] == 1;
      final body = {
        'title': t['title'],
        'amount': t['amount'],
        'type': t['type'],
        'categoryId': t['category'],
        'date': t['date'],
        'note': t['note'],
        'memberId': t['member_id'],
        'planId': t['plan_id'],
        'paymentMethod': t['payment_method'],
      };
      await upload(
        'transactions',
        'id',
        id,
        synced: synced,
        deleted: deleted,
        send: () => deleted
            ? _api.delete('$base/transactions/$id')
            : synced
            ? _api.patch('$base/transactions/$id', body)
            : _api.post('$base/transactions', {...body, 'id': id}),
      );
    }

    await _pushPhotos(db, base);
    await _pushCovers(db, base);

    // Plan and member deletes go after transactions so none still point
    // at them.
    for (final p in plans.where((p) => p['deleted'] == 1)) {
      final id = p['id'] as String;
      await upload(
        'plans',
        'id',
        id,
        synced: true,
        deleted: true,
        send: () => _api.delete('$base/plans/$id'),
      );
    }
    for (final m in members.where((m) => m['deleted'] == 1)) {
      final id = m['id'] as String;
      await upload(
        'members',
        'id',
        id,
        synced: true,
        deleted: true,
        send: () => _api.delete('$base/members/$id'),
      );
    }

    final budgets = await db.query('budgets', where: 'dirty = 1');
    for (final b in budgets) {
      final category = b['category'] as String;
      final deleted = b['deleted'] == 1;
      await upload(
        'budgets',
        'category',
        category,
        synced: b['synced'] == 1,
        deleted: deleted,
        send: () => deleted
            ? _api.delete('$base/budgets/$category')
            : _api.put('$base/budgets/$category', {'limit': b['amount']}),
      );
    }
    return rejected;
  }

  /// Uploads or removes receipt photos for transactions the server knows.
  Future<void> _pushPhotos(Database db, String base) async {
    final rows = await db.query(
      'transactions',
      where: 'photo_dirty = 1 AND synced = 1 AND deleted = 0',
    );
    for (final r in rows) {
      final id = r['id'] as String;
      final path = r['photo_path'] as String?;
      try {
        if (path != null && File(path).existsSync()) {
          await _api.putBytes(
            '$base/transactions/$id/photo',
            await File(path).readAsBytes(),
          );
          await db.update(
            'transactions',
            {'photo_dirty': 0, 'has_photo': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await _api.delete('$base/transactions/$id/photo');
          await db.update(
            'transactions',
            {'photo_dirty': 0, 'has_photo': 0, 'photo_path': null},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } on ApiException catch (e) {
        if (e.isNetwork || e.status == 401 || e.status >= 500) rethrow;
        // Refused (too big, not an image, row gone): stop retrying.
        await db.update(
          'transactions',
          {'photo_dirty': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  /// Uploads or removes plan covers for plans the server knows.
  Future<void> _pushCovers(Database db, String base) async {
    final rows = await db.query(
      'plans',
      where: 'cover_dirty = 1 AND synced = 1 AND deleted = 0',
    );
    for (final r in rows) {
      final id = r['id'] as String;
      final path = r['cover_path'] as String?;
      try {
        if (path != null && File(path).existsSync()) {
          await _api.putBytes(
            '$base/plans/$id/cover',
            await File(path).readAsBytes(),
          );
          await db.update(
            'plans',
            {'cover_dirty': 0, 'has_cover': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await _api.delete('$base/plans/$id/cover');
          await db.update(
            'plans',
            {'cover_dirty': 0, 'has_cover': 0, 'cover_path': null},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } on ApiException catch (e) {
        if (e.isNetwork || e.status == 401 || e.status >= 500) rethrow;
        // Refused (too big, not an image, plan gone): stop retrying.
        await db.update(
          'plans',
          {'cover_dirty': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  /// Downloads covers other people set, removes ones they deleted, and
  /// deletes files no plan points at any more.
  Future<void> _syncCoverFiles(Database db, String base) async {
    final missing = await db.query(
      'plans',
      where:
          'has_cover = 1 AND cover_path IS NULL AND cover_dirty = 0 '
          'AND deleted = 0',
    );
    for (final r in missing) {
      final id = r['id'] as String;
      try {
        final bytes = await _api.getBytes('$base/plans/$id/cover');
        final path = await PhotoStore.saveBytes(id, bytes, folder: 'covers');
        await db.update(
          'plans',
          {'cover_path': path},
          where: 'id = ?',
          whereArgs: [id],
        );
      } on ApiException catch (e) {
        if (e.isNetwork || e.status == 401 || e.status >= 500) rethrow;
      }
    }
    final gone = await db.query(
      'plans',
      where: 'has_cover = 0 AND cover_path IS NOT NULL AND cover_dirty = 0',
    );
    for (final r in gone) {
      await PhotoStore.delete(r['cover_path'] as String?);
      await db.update(
        'plans',
        {'cover_path': null},
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }
    final keep = {
      for (final r in await db.query(
        'plans',
        columns: ['cover_path'],
        where: 'cover_path IS NOT NULL',
      ))
        r['cover_path'] as String,
    };
    await PhotoStore.prune(keep, folder: 'covers');
  }

  /// Downloads photos other people added, removes ones they deleted, and
  /// deletes files no transaction points at any more.
  Future<void> _syncPhotoFiles(Database db, String base) async {
    final missing = await db.query(
      'transactions',
      where:
          'has_photo = 1 AND photo_path IS NULL AND photo_dirty = 0 '
          'AND deleted = 0',
    );
    for (final r in missing) {
      final id = r['id'] as String;
      try {
        final bytes = await _api.getBytes('$base/transactions/$id/photo');
        final path = await PhotoStore.saveBytes(id, bytes);
        await db.update(
          'transactions',
          {'photo_path': path},
          where: 'id = ?',
          whereArgs: [id],
        );
      } on ApiException catch (e) {
        if (e.isNetwork || e.status == 401 || e.status >= 500) rethrow;
      }
    }
    final gone = await db.query(
      'transactions',
      where: 'has_photo = 0 AND photo_path IS NOT NULL AND photo_dirty = 0',
    );
    for (final r in gone) {
      await PhotoStore.delete(r['photo_path'] as String?);
      await db.update(
        'transactions',
        {'photo_path': null},
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }
    final keep = {
      for (final r in await db.query(
        'transactions',
        columns: ['photo_path'],
        where: 'photo_path IS NOT NULL',
      ))
        r['photo_path'] as String,
    };
    await PhotoStore.prune(keep);
  }

  Future<void> _pull(Database db, Map<String, dynamic> res) async {
    List<Map<String, dynamic>> rows(String key) =>
        (res[key] as List).cast<Map<String, dynamic>>();

    await db.transaction((txn) async {
      for (final m in rows('members')) {
        if (m['deleted'] == true) {
          await txn.delete(
            'members',
            where: 'id = ? AND dirty = 0',
            whereArgs: [m['id']],
          );
          continue;
        }
        await txn.rawInsert(
          '''
          INSERT INTO members (id, name, color, is_owner, user_id, dirty, synced)
          VALUES (?, ?, ?, ?, ?, 0, 1)
          ON CONFLICT (id) DO UPDATE SET
            name = excluded.name, color = excluded.color,
            is_owner = excluded.is_owner, user_id = excluded.user_id,
            synced = 1, deleted = 0
          WHERE members.dirty = 0
          ''',
          [
            m['id'],
            m['name'],
            m['color'],
            m['isOwner'] == true ? 1 : 0,
            m['userId'],
          ],
        );
      }

      for (final p in rows('plans')) {
        if (p['deleted'] == true) {
          await txn.delete(
            'plans',
            where: 'id = ? AND dirty = 0',
            whereArgs: [p['id']],
          );
          continue;
        }
        await txn.rawInsert(
          '''
          INSERT INTO plans
            (id, name, kind, start_date, end_date, funds, shares, split,
             created_by, destination, description, dirty, synced)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1)
          ON CONFLICT (id) DO UPDATE SET
            name = excluded.name, kind = excluded.kind,
            start_date = excluded.start_date, end_date = excluded.end_date,
            funds = excluded.funds, shares = excluded.shares,
            split = excluded.split, created_by = excluded.created_by,
            destination = excluded.destination,
            description = excluded.description,
            synced = 1, deleted = 0
          WHERE plans.dirty = 0
          ''',
          [
            p['id'],
            p['name'],
            p['kind'],
            p['startDate'],
            p['endDate'],
            jsonEncode(p['funds']),
            jsonEncode(p['shares']),
            p['split'],
            p['createdBy'],
            p['destination'] ?? '',
            p['description'] ?? '',
          ],
        );
        // Whether the server has a cover; a local change not yet uploaded wins.
        await txn.update(
          'plans',
          {'has_cover': p['hasCover'] == true ? 1 : 0},
          where: 'id = ? AND cover_dirty = 0',
          whereArgs: [p['id']],
        );
      }

      for (final t in rows('transactions')) {
        if (t['deleted'] == true) {
          await txn.delete(
            'transactions',
            where: 'id = ? AND dirty = 0',
            whereArgs: [t['id']],
          );
          continue;
        }
        await txn.rawInsert(
          '''
          INSERT INTO transactions
            (id, title, amount, type, category, date, note, member_id,
             plan_id, payment_method, has_photo, dirty, synced)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1)
          ON CONFLICT (id) DO UPDATE SET
            title = excluded.title, amount = excluded.amount,
            type = excluded.type, category = excluded.category,
            date = excluded.date, note = excluded.note,
            member_id = excluded.member_id, plan_id = excluded.plan_id,
            payment_method = excluded.payment_method,
            has_photo = excluded.has_photo, synced = 1, deleted = 0
          WHERE transactions.dirty = 0
          ''',
          [
            t['id'],
            t['title'],
            t['amount'],
            t['type'],
            t['categoryId'],
            t['date'],
            t['note'],
            t['memberId'],
            t['planId'],
            t['paymentMethod'],
            t['hasPhoto'] == true ? 1 : 0,
          ],
        );
      }

      for (final t in rows('transfers')) {
        if (t['deleted'] == true) {
          await txn.delete(
            'transfers',
            where: 'id = ? AND dirty = 0',
            whereArgs: [t['id']],
          );
          continue;
        }
        await txn.rawInsert(
          '''
          INSERT INTO transfers
            (id, kind, amount, from_method, to_method, from_member_id,
             to_member_id, plan_id, note, date, dirty, synced)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1)
          ON CONFLICT (id) DO UPDATE SET
            kind = excluded.kind, amount = excluded.amount,
            from_method = excluded.from_method, to_method = excluded.to_method,
            from_member_id = excluded.from_member_id,
            to_member_id = excluded.to_member_id, plan_id = excluded.plan_id,
            note = excluded.note, date = excluded.date, synced = 1, deleted = 0
          WHERE transfers.dirty = 0
          ''',
          [
            t['id'],
            t['kind'],
            t['amount'],
            t['fromMethod'],
            t['toMethod'],
            t['fromMemberId'],
            t['toMemberId'],
            t['planId'],
            t['note'],
            t['date'],
          ],
        );
      }

      // Feed entries never change, so existing ones are left alone.
      for (final a
          in (res['activity'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        await txn.insert('activity', {
          'id': a['id'],
          'actor_user_id': a['actorUserId'],
          'actor_name': a['actorName'],
          'kind': a['kind'],
          'data': jsonEncode(a['data']),
          'created_at': a['createdAt'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final b in rows('budgets')) {
        if (b['deleted'] == true) {
          await txn.delete(
            'budgets',
            where: 'category = ? AND dirty = 0',
            whereArgs: [b['categoryId']],
          );
          continue;
        }
        await txn.rawInsert(
          '''
          INSERT INTO budgets (category, amount, dirty, synced)
          VALUES (?, ?, 0, 1)
          ON CONFLICT (category) DO UPDATE SET
            amount = excluded.amount, synced = 1, deleted = 0
          WHERE budgets.dirty = 0
          ''',
          [b['categoryId'], b['limit']],
        );
      }
    });
  }
}
