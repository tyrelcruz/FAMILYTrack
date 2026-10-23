/// Signed-in account plus the family group this phone syncs with.
class Session {
  const Session({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    this.group,
    this.lastSync,
  });

  final String token;
  final String userId;
  final String name;
  final String email;
  final LinkedGroup? group;

  /// Server time of the last successful sync (ms), sent back as `since`.
  final int? lastSync;

  Session copyWith({
    String? name,
    LinkedGroup? group,
    bool clearGroup = false,
    int? lastSync,
    bool clearLastSync = false,
  }) => Session(
    token: token,
    userId: userId,
    name: name ?? this.name,
    email: email,
    group: clearGroup ? null : (group ?? this.group),
    lastSync: clearLastSync ? null : (lastSync ?? this.lastSync),
  );

  Map<String, Object?> toJson() => {
    'token': token,
    'userId': userId,
    'name': name,
    'email': email,
    'group': group?.toJson(),
    'lastSync': lastSync,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    token: j['token'] as String,
    userId: j['userId'] as String,
    name: j['name'] as String,
    email: j['email'] as String,
    group: j['group'] == null
        ? null
        : LinkedGroup.fromJson(j['group'] as Map<String, dynamic>),
    lastSync: j['lastSync'] as int?,
  );
}

class LinkedGroup {
  const LinkedGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.isOwner,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String inviteCode;

  /// Whether the signed-in user owns the group.
  final bool isOwner;
  final int memberCount;

  /// From `GET /groups/:id`, which includes the active members.
  factory LinkedGroup.fromApi(Map<String, dynamic> res, String userId) {
    final g = res['group'] as Map<String, dynamic>;
    final members = (res['members'] as List?) ?? const [];
    return LinkedGroup(
      id: g['id'] as String,
      name: g['name'] as String,
      inviteCode: g['inviteCode'] as String,
      isOwner: g['ownerId'] == userId,
      memberCount: members.length,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'inviteCode': inviteCode,
    'isOwner': isOwner,
    'memberCount': memberCount,
  };

  factory LinkedGroup.fromJson(Map<String, dynamic> j) => LinkedGroup(
    id: j['id'] as String,
    name: j['name'] as String,
    inviteCode: j['inviteCode'] as String,
    isOwner: j['isOwner'] as bool,
    memberCount: j['memberCount'] as int,
  );
}
