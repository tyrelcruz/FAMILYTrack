import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_tracker/features/account/models/session.dart';

/// Keeps the session and server address between launches.
class SessionStore {
  static const _sessionKey = 'session';
  static const _serverKey = 'server_url';

  Future<Session?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_sessionKey);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> save(Session? s) async {
    final prefs = await SharedPreferences.getInstance();
    s == null
        ? await prefs.remove(_sessionKey)
        : await prefs.setString(_sessionKey, jsonEncode(s.toJson()));
  }

  Future<String?> serverUrl() async =>
      (await SharedPreferences.getInstance()).getString(_serverKey);

  Future<void> saveServerUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    url == null
        ? await prefs.remove(_serverKey)
        : await prefs.setString(_serverKey, url);
  }
}
