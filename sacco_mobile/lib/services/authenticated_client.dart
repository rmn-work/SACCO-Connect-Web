import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_notifier.dart';

class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _storage.read(key: 'auth_token');
    final cookies = await _storage.read(key: 'django_cookies');

    if (token != null && !token.startsWith('session_active_')) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    else if (cookies != null) {
      request.headers['Cookie'] = cookies;
      // Injection du header CSRF requis par Django
      final csrfMatch = RegExp(r'csrftoken=([^;]+)').firstMatch(cookies);
      if (csrfMatch != null) {
        request.headers['X-CSRFToken'] = csrfMatch.group(1)!;
      }
    }

    request.headers.putIfAbsent('Content-Type', () => 'application/json');
    request.headers.putIfAbsent('Accept', () => 'application/json');
    request.headers.putIfAbsent('X-Requested-With', () => 'XMLHttpRequest');

    debugPrint("🌐 ENVOI -> ${request.method} ${request.url}");

    final response = await _inner.send(request);

    debugPrint("📥 REÇU <- HTTP ${response.statusCode} | URL: ${request.url}");

    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint("🚨 Session expirée (${response.statusCode}). Déconnexion...");
      Future.microtask(() => authNotifier.logout());
    }

    return response;
  }
}