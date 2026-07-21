import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_notifier.dart';

class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = authNotifier.token;

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.headers.putIfAbsent('Content-Type', () => 'application/json');
    request.headers.putIfAbsent('Accept', () => 'application/json');

    final response = await _inner.send(request);

    if (response.statusCode == 401) {
      print("🚨 Session expirée ou invalide (401). Déconnexion forcée...");
      Future.microtask(() => authNotifier.logout());
    }

    return response;
  }
}