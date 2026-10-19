import 'dart:convert';

/// Something a family member did, from the server's feed.
class Activity {
  const Activity({
    required this.id,
    required this.actorUserId,
    required this.actorName,
    required this.kind,
    required this.data,
    required this.createdAt,
  });

  final String id;
  final String? actorUserId;
  final String actorName;

  /// transaction_added, member_joined, member_added, plan_created,
  /// budget_set or transfer_added.
  final String kind;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  factory Activity.fromMap(Map<String, Object?> m) => Activity(
    id: m['id'] as String,
    actorUserId: m['actor_user_id'] as String?,
    actorName: m['actor_name'] as String,
    kind: m['kind'] as String,
    data: jsonDecode(m['data'] as String) as Map<String, dynamic>,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );
}
