import 'dart:io';

class Config {
  // Définition des environnements
  static const String _localHost = "127.0.0.1";
  static const String _androidEmulatorHost = "10.0.2.2";
  static const String _serverPort = "8000";

  // Tu pourras facilement ajouter une URL de production ici plus tard
  static const String _productionUrl = "https://api.sacco-connect.bi";

  static bool isProduction = false; // Bascule cette variable pour la mise en ligne

  static String get baseUrl {
    if (isProduction) {
      return _productionUrl;
    }

    final host = Platform.isAndroid ? _androidEmulatorHost : _localHost;
    return "http://$host:$_serverPort";
  }

  // Optionnel : Ajout d'un helper pour les endpoints API
  static String get loginUrl => "$baseUrl/auth/login";
  static String dashboardUrl(int membreId) => "$baseUrl/membres/$membreId/dashboard";
}