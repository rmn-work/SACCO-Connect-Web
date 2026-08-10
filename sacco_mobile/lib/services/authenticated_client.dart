import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_notifier.dart';
import 'local_database.dart';

class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? token = authNotifier.token;

    if (token == null || token.isEmpty) {
      try {
        final cachedSession = await LocalDatabase.getCachedData('user_session');
        if (cachedSession != null && cachedSession is Map) {
          token = cachedSession['access_token'] ?? cachedSession['token'];
        }
      } catch (e) {
        print("⚠️ Erreur lors de la lecture du token de secours : $e");
      }
    }

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    } else {
      print("🚨 Aucun token d'authentification trouvé pour la requête : ${request.url}");
    }

    request.headers.putIfAbsent('Content-Type', () => 'application/json');
    request.headers.putIfAbsent('Accept', () => 'application/json');
    final response = await _inner.send(request);

    if (response.statusCode == 401 || response.statusCode == 403) {
      print("🚨 Session expirée ou non autorisée (${response.statusCode}). Déconnexion forcée...");
      Future.microtask(() => authNotifier.logout());
    }

    return response;
  }
}