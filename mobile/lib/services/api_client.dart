import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Error returned by the Grandvoice API (wrong password, not allowed...).
class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around the FastAPI backend.
///
/// Network problems throw normal exceptions (timeout, socket error) so the
/// caller can switch to offline mode; API errors throw [ApiException].
class ApiClient {
  ApiClient(this.baseUrl);

  String baseUrl;
  String? token;

  /// Where the backend usually is while developing:
  /// - web build and iOS simulator: the same computer (localhost)
  /// - Android emulator: 10.0.2.2 is the computer running the emulator
  /// A real phone needs the laptop's Wi-Fi IP, set from the demo menu or with
  /// `flutter run --dart-define=API_URL=http://192.168.1.20:8000`.
  static String defaultUrl() {
    const fromBuild = String.fromEnvironment('API_URL');
    if (fromBuild.isNotEmpty) return fromBuild;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  Future<dynamic> send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response res;
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      case 'POST':
        res = await http.post(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 40));
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 8));
      case 'DELETE':
        res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 8));
      default:
        throw ArgumentError(method);
    }
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final detail = data is Map && data['detail'] is String ? data['detail'] as String : 'Something went wrong.';
      throw ApiException(res.statusCode, detail);
    }
    return data;
  }

  Future<dynamic> get(String path) => send('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => send('POST', path, body ?? {});
}
