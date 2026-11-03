import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Error returned by the API, with a stable code and a message safe to show.
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status = 0});
  final String code;
  final String message;
  final int status;

  @override
  String toString() => message;
}

/// Talks to the Laravel API. Responses are { success, data, meta } or
/// { success: false, error: { code, message } }.
class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _http = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _http;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'abvp.token';
  String? _token;

  Future<bool> restoreToken() async {
    _token = await _storage.read(key: _tokenKey);
    return _token != null;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<String?> readCache(String key) => _storage.read(key: 'cache.$key');
  Future<void> writeCache(String key, String value) => _storage.write(key: 'cache.$key', value: value);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path) => _send(() => _http.get(_uri(path), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(() => _http.post(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body ?? {}),
      ));

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _send(() => _http.patch(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ));

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send(() => _http.put(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ));

  Future<dynamic> upload(String path, String field, File file) => _send(() async {
        final req = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers)
          ..files.add(await http.MultipartFile.fromPath(field, file.path));
        return http.Response.fromStream(await _http.send(req));
      });

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('NETWORK', 'No internet connection. Check your network and try again.');
    } on Exception {
      throw ApiException('NETWORK', 'Could not reach the server. Try again in a moment.');
    }

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true) {
      return json!['data'];
    }

    final error = (json?['error'] as Map<String, dynamic>?) ?? {};
    throw ApiException(
      error['code'] as String? ?? 'HTTP_${res.statusCode}',
      error['message'] as String? ?? 'Something went wrong. Try again.',
      status: res.statusCode,
    );
  }
}
