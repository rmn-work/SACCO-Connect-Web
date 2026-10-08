class Config {
  static const String baseUrl = "https://sacco-connect.onrender.com";
  static String get loginUrl => "$baseUrl/api/login/";
  static String dashboardUrl(int id) => "$baseUrl/api/membres/$id/dashboard/";

  static String getEndpoint(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return "$baseUrl$cleanPath";
  }
}