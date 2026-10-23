import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:finance_tracker/core/api/api_client.dart';
import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/features/account/data/session_store.dart';
import 'package:finance_tracker/features/account/models/session.dart';
import 'package:finance_tracker/features/sync/sync_service.dart';

/// Account, family link and background sync.
///
/// The app works fully offline without an account. Once signed in and in a
/// family, every local change is uploaded shortly after it happens, and the
/// family's changes are downloaded on launch, on resume, every minute and on
/// pull-to-refresh.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._store, {required this.onDataChanged})
    : _api = ApiClient(baseUrl: defaultApiUrl());

  final SessionStore _store;
  final ApiClient _api;
  late final SyncService _sync = SyncService(_api);

  /// Reloads the screens after downloaded data lands in the database.
  final Future<void> Function() onDataChanged;

  Session? _session;
  bool ready = false;
  bool syncing = false;
  DateTime? lastSyncedAt;

  /// Last sync problem, shown on the Family and Profile tabs.
  String? syncError;

  Timer? _debounce;
  Timer? _periodic;
  AppLifecycleListener? _lifecycle;
  bool _syncAgain = false;

  Session? get session => _session;
  bool get signedIn => _session != null;
  LinkedGroup? get group => _session?.group;
  bool get linked => group != null;
  String get serverUrl => _api.baseUrl;

  /// One-line sync state for the UI.
  String get syncStatus {
    if (syncing) return 'Syncing…';
    if (syncError != null) return syncError!;
    final at = lastSyncedAt;
    if (at == null) return 'Waiting to sync';
    final mins = DateTime.now().difference(at).inMinutes;
    if (mins < 1) return 'Synced just now';
    if (mins < 60) return 'Synced $mins min ago';
    return 'Synced ${DateTime.now().difference(at).inHours} h ago';
  }

  Future<void> init() async {
    _api.baseUrl = await _store.serverUrl() ?? defaultApiUrl();
    _session = await _store.load();
    _api.token = _session?.token;
    ready = true;
    notifyListeners();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(sync()));
    _periodic = Timer.periodic(const Duration(minutes: 1), (_) {
      if (linked) unawaited(sync());
    });
    if (linked) unawaited(sync());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> setServerUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    _api.baseUrl = clean.isEmpty ? defaultApiUrl() : clean;
    await _store.saveServerUrl(clean.isEmpty ? null : clean);
    notifyListeners();
  }

  // ── Account ──────────────────────────────────────────────────────────

  Future<void> register(String name, String email, String password) => _signIn(
    _api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    }),
  );

  Future<void> login(String email, String password) =>
      _signIn(_api.post('/auth/login', {'email': email, 'password': password}));

  Future<void> _signIn(Future<Map<String, dynamic>> request) async {
    final res = await request;
    final user = res['user'] as Map<String, dynamic>;
    _api.token = res['token'] as String;
    var s = Session(
      token: _api.token!,
      userId: user['id'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
    );
    // Reconnect to the family this account already belongs to.
    final me = await _api.get('/me');
    final groups = (me['groups'] as List).cast<Map<String, dynamic>>();
    if (groups.isNotEmpty) {
      final g = await _api.get('/groups/${groups.first['id']}');
      s = s.copyWith(group: LinkedGroup.fromApi(g, s.userId));
      await AppDatabase.clear();
    }
    await _setSession(s);
    if (linked) await sync();
  }

  Future<void> logout() async {
    _api.token = null;
    await _setSession(null);
    await AppDatabase.clear(keepOwner: true);
    syncError = null;
    lastSyncedAt = null;
    await onDataChanged();
    notifyListeners();
  }

  // ── Profile ──────────────────────────────────────────────────────────

  /// Renames the account; the server renames its family member too.
  Future<void> updateName(String name) async {
    final res = await _api.patch('/me', {'name': name.trim()});
    final user = res['user'] as Map<String, dynamic>;
    await _setSession(_session!.copyWith(name: user['name'] as String));
    if (linked) await sync();
  }

  Future<void> changePassword(String current, String next) =>
      _api.post('/me/password', {'current': current, 'next': next});

  /// Owner only.
  Future<void> renameGroup(String name) async {
    await _api.patch('/groups/${group!.id}', {'name': name.trim()});
    await _refreshGroup();
  }

  // ── Family ───────────────────────────────────────────────────────────

  /// Creates a family; with [keepLocalData] what's already on this phone
  /// is uploaded into it, otherwise the family starts empty.
  Future<void> createGroup(String name, {bool keepLocalData = true}) async {
    final s = _session!;
    final res = await _api.post('/groups', {'name': name});
    if (!keepLocalData) await AppDatabase.clear(keepOwner: true);
    final g = await _api.get(
      '/groups/${(res['group'] as Map<String, dynamic>)['id']}',
    );
    await _adoptLocalData(
      ((res['member'] as Map<String, dynamic>)['id']) as String,
    );
    await _setSession(
      s.copyWith(group: LinkedGroup.fromApi(g, s.userId), clearLastSync: true),
    );
    await sync();
  }

  /// Joins with an invite code; this phone switches to the family's data.
  Future<void> joinGroup(String code) async {
    final s = _session!;
    final res = await _api.post('/groups/join', {'inviteCode': code.trim()});
    final g = await _api.get(
      '/groups/${(res['group'] as Map<String, dynamic>)['id']}',
    );
    await AppDatabase.clear();
    await _setSession(
      s.copyWith(group: LinkedGroup.fromApi(g, s.userId), clearLastSync: true),
    );
    await sync();
  }

  Future<void> leaveGroup() async {
    await _api.post('/groups/${group!.id}/leave');
    await _unlink();
  }

  Future<void> newInviteCode() async {
    await _api.post('/groups/${group!.id}/invite-code');
    await _refreshGroup();
  }

  /// The server's owner member ([ownerId]) replaces the phone's local "me".
  Future<void> _adoptLocalData(String ownerId) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final owners = await txn.query(
        'members',
        where: 'is_owner = 1 AND synced = 0',
      );
      for (final o in owners) {
        await txn.update(
          'transactions',
          {'member_id': null},
          where: 'member_id = ?',
          whereArgs: [o['id']],
        );
        await txn.delete('members', where: 'id = ?', whereArgs: [o['id']]);
        // Transfers between people name both sides explicitly.
        for (final col in ['from_member_id', 'to_member_id']) {
          await txn.update(
            'transfers',
            {col: ownerId},
            where: '$col = ?',
            whereArgs: [o['id']],
          );
        }
        // Plan shares are keyed by member id, so move "me"'s share across.
        for (final p in await txn.query('plans')) {
          final shares = jsonDecode(p['shares'] as String) as Map;
          if (!shares.containsKey(o['id'])) continue;
          shares[ownerId] = shares.remove(o['id']);
          await txn.update(
            'plans',
            {'shares': jsonEncode(shares), 'dirty': 1},
            where: 'id = ?',
            whereArgs: [p['id']],
          );
        }
      }
    });
  }

  Future<void> _refreshGroup() async {
    final s = _session!;
    final g = await _api.get('/groups/${s.group!.id}');
    await _setSession(s.copyWith(group: LinkedGroup.fromApi(g, s.userId)));
  }

  Future<void> _unlink() async {
    await _setSession(
      _session!.copyWith(clearGroup: true, clearLastSync: true),
    );
    await AppDatabase.clear(keepOwner: true);
    await onDataChanged();
  }

  // ── Sync ─────────────────────────────────────────────────────────────

  /// Uploads local changes soon, batching quick successive edits.
  void scheduleSync() {
    if (!linked) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () => unawaited(sync()));
  }

  Future<void> sync() async {
    final s = _session;
    if (s == null || s.group == null) return;
    if (syncing) {
      _syncAgain = true;
      return;
    }
    syncing = true;
    notifyListeners();
    try {
      final result = await _sync.sync(s.group!.id, since: s.lastSync);
      await _setSession(
        _session!.copyWith(
          lastSync: result.serverTime,
          group: LinkedGroup.fromApi(result.group, s.userId),
        ),
      );
      lastSyncedAt = DateTime.now();
      syncError = null;
      await onDataChanged();
    } on GroupGoneException {
      syncError = 'You’re no longer in ${s.group!.name}.';
      await _unlink();
    } on ApiException catch (e) {
      if (e.status == 401) {
        syncError = 'Your session expired. Sign in again.';
        await logout();
        syncError = 'Your session expired. Sign in again.';
      } else {
        syncError = e.isNetwork
            ? 'Offline — changes will sync later'
            : e.message;
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
    if (_syncAgain) {
      _syncAgain = false;
      await sync();
    }
  }

  Future<void> _setSession(Session? s) async {
    _session = s;
    await _store.save(s);
    notifyListeners();
  }
}
