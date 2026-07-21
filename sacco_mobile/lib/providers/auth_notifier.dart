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
    if (token != null) {
      _token = token;
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

      if (response != null && response.containsKey('access_token')) {
        final token = response['access_token'];
        _token = token;

        final payload = _parseJwt(token);
        final String userId = payload['sub']?.toString() ?? '0';
        final String userRole = payload['role']?.toString() ?? 'membre';

        try {
          await _storage.write(key: 'auth_token', value: token);
          await _storage.write(key: 'user_id', value: userId);
          await _storage.write(key: 'user_role', value: userRole);
        } catch (e) {
          debugPrint("Erreur d'écriture sécurisée (Keychain) : $e");
        }

        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
      } else {
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Erreur globale login : $e");
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
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