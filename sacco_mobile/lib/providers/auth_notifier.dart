import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Map<String, dynamic> _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = parts[1];
      final String normalized = base64Url.normalize(payload);
      final String resp = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(resp);
    } catch (e) {
      debugPrint("Erreur décodage JWT: $e");
      return {};
    }
  }

  Future<void> checkAuthStatus() async {
    final token = await _storage.read(key: 'auth_token');
    final userId = await _storage.read(key: 'user_id');

    if (token != null || userId != null) {
      _token = token ?? 'session_active_$userId';
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<void> login(String telephone, String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      try {
        await _storage.deleteAll();
      } catch (e) {
        debugPrint("Erreur nettoyage Keychain avant login: $e");
      }

      final response = await ApiService.login(telephone, pin);

      if (response != null) {
        // CAS 1 : Authentification basée sur Token JWT
        if (response.containsKey('access_token') || response.containsKey('token')) {
          final token = response['access_token'] ?? response['token'];
          _token = token;

          final payload = _parseJwt(token);
          final String userId = payload['sub']?.toString() ?? response['membre_id']?.toString() ?? '0';
          final String userRole = payload['role']?.toString() ?? response['role']?.toString() ?? 'membre';

          await _storage.write(key: 'auth_token', value: token);
          await _storage.write(key: 'user_id', value: userId);
          await _storage.write(key: 'user_role', value: userRole);

          _isAuthenticated = true;
        }
        // CAS 2 : Authentification basée sur la Session Django (success: true / membre_id)
        else if (response['success'] == true || response.containsKey('membre_id') || response.containsKey('user_id')) {
          final String userId = (response['membre_id'] ?? response['user_id'] ?? '0').toString();
          final String userRole = (response['role'] ?? 'membre').toString();
          final String sessionToken = 'session_active_$userId';

          _token = sessionToken;

          // FIX CRUCIAL : Écriture d'un identifiant dans auth_token pour débloquer AuthenticatedClient
          await _storage.write(key: 'auth_token', value: sessionToken);
          await _storage.write(key: 'user_id', value: userId);
          await _storage.write(key: 'user_role', value: userRole);

          _isAuthenticated = true;
        } else {
          _isAuthenticated = false;
        }
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      debugPrint("Erreur globale login : $e");
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners(); // Notifie GoRouter du changement d'état
    }
  }

  Future<void> logout() async {
    try {
      // Nettoie toutes les clés : 'auth_token', 'user_id', 'user_role' ET 'django_cookies'
      await _storage.deleteAll();
    } catch (e) {
      debugPrint("Erreur lors de la suppression du Keychain au logout: $e");
    }

    _token = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

final authNotifier = AuthNotifier();