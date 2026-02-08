// lib/core/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';

class ApiClient {
  ApiClient({required this.baseUrl, TokenStore? tokenStore})
      : _tokenStore = tokenStore ?? TokenStore();

  final String baseUrl;
  final TokenStore _tokenStore;

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final uri = Uri.parse('$baseUrl$path');
    if (q == null || q.isEmpty) return uri;

    final qp = <String, String>{};
    q.forEach((k, v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty) return;
      qp[k] = s;
    });

    return uri.replace(queryParameters: qp);
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = await _tokenStore.getToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }


  Future<T> getJson<T>(
      String path, {
        Map<String, dynamic>? query,
        bool auth = false,
      }) async {
    final res = await http.get(_u(path, query), headers: await _headers(auth: auth));
    return _decode<T>(res);
  }

  Future<T> postJson<T>(
      String path,
      Object body, {
        bool auth = false,
      }) async {
    final res = await http.post(
      _u(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode<T>(res);
  }

  Future<T> putJson<T>(
      String path,
      Object body, {
        bool auth = false,
      }) async {
    final res = await http.put(
      _u(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode<T>(res);
  }


  // ProductsApi espera get(...) y post(...)
  // =========================
  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? query,
        bool auth = true,
      }) async {
    return getJson<dynamic>(path, query: query, auth: auth);
  }

  Future<dynamic> post(
      String path, {
        required Object data,
        bool auth = true,
      }) async {
    return postJson<dynamic>(path, data, auth: auth);
  }

  // =========================

  T _decode<T>(http.Response res) {
    final code = res.statusCode;

    if (code >= 200 && code < 300) {
      if (res.body.isEmpty) return ({} as T);
      return jsonDecode(res.body) as T;
    }

    String msg = 'HTTP $code';
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] != null) msg = '${j['error']}';
      else if (res.body.isNotEmpty) msg = res.body;
    } catch (_) {
      if (res.body.isNotEmpty) msg = res.body;
    }
    throw ApiException(code, msg);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
