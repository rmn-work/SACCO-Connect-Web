class Config {
  static const String baseUrl = "https://sacco-connect-web.onrender.com";
  static String get loginUrl => "$baseUrl/auth/login";
  static String dashboardUrl(int id) => "$baseUrl/membres/$id/dashboard";
  static String getEndpoint(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return "$baseUrl$cleanPath";
  }
}