import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/features/notifications/models/activity.dart';

/// The family's activity feed (filled by sync) and what's been seen.
class ActivityProvider extends ChangeNotifier {
  ActivityProvider() {
    load();
  }

  static const _seenKey = 'activity_seen_at';

  List<Activity> _items = [];
  DateTime _seenAt = DateTime.fromMillisecondsSinceEpoch(0);

  List<Activity> get items => _items;

  /// New things other people did since the bell was last opened.
  int unreadFor(String? myUserId) => _items
      .where((a) => a.actorUserId != myUserId && a.createdAt.isAfter(_seenAt))
      .length;

  Future<void> load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'activity',
      orderBy: 'created_at DESC',
      limit: 200,
    );
    _items = rows.map(Activity.fromMap).toList();
    final prefs = await SharedPreferences.getInstance();
    _seenAt = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_seenKey) ?? 0);
    notifyListeners();
  }

  Future<void> markSeen() async {
    _seenAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenKey, _seenAt.millisecondsSinceEpoch);
    notifyListeners();
  }
}
