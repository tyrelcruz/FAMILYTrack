import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Where the FamilyTrack API lives. Override with
/// `flutter run --dart-define=API_URL=http://192.168.1.10:3000/api`
/// or from the Profile tab.
String defaultApiUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  // The Android emulator reaches the host machine at 10.0.2.2.
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000/api';
  return 'http://localhost:3000/api';
}

class ApiException implements Exception {
  const ApiException(this.status, this.message);

  /// HTTP status, or 0 when the server couldn't be reached.
  final int status;
  final String message;

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// Thin JSON-over-HTTP client; every error becomes an [ApiException].
class ApiClient {
  ApiClient({required this.baseUrl, this.token, http.Client? client})
    : _http = client ?? http.Client();

  String baseUrl;
  String? token;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<Map<String, dynamic>> post(String path, [Object? body]) =>
      _send('POST', path, body: body ?? const {});
  Future<Map<String, dynamic>> patch(String path, Object body) =>
      _send('PATCH', path, body: body);
  Future<Map<String, dynamic>> put(String path, Object body) =>
      _send('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException(0, 'The server took too long to answer');
    } on SocketException {
      throw const ApiException(0, 'Can’t reach the server');
    } on http.ClientException {
      throw const ApiException(0, 'Can’t reach the server');
    }

    final decoded = res.body.isEmpty ? null : _tryDecode(res.body);
    if (res.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed (${res.statusCode})';
      throw ApiException(res.statusCode, message);
    }
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
