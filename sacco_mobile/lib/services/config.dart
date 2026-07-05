import 'dart:io';

class Config {
  // Configuration pour le développement local (Mac / Émulateur Android)
  static const String _localHost = "127.0.0.1";
  static const String _androidEmulatorHost = "10.0.2.2";
  static const String _serverPort = "8000";

  // URL du serveur distant sur Render
  static const String _renderUrl = "https://sacco-connect-nqyo.onrender.com";

  // URL finale en production
  static const String _productionUrl = "https://api.sacco-connect.bi";

  // PASSER À 'false' pour vos tests locaux sur l'émulateur (utilisera 10.0.2.2:8000)
  // PASSER À 'true' pour que l'application cible Render ou la production
  static bool isProduction = false;
  //static bool isProduction = true; la ligne a active avant de le deploiement et desactivé false

  static String get baseUrl {
    if (isProduction) {
      return _renderUrl; // pointera sur Render sur Internet
    }

    // En local : bascule automatiquement sur 10.0.2.2 (Android) ou 127.0.0.1 (macOS/iOS)
    final host = Platform.isAndroid ? _androidEmulatorHost : _localHost;
    return "http://$host:$_serverPort";
  }

  // En-points API unifiés
  static String get loginUrl => "$baseUrl/auth/login";

  static String dashboardUrl(int membreId) {
    return "$baseUrl/membres/$membreId/dashboard";
  }
}