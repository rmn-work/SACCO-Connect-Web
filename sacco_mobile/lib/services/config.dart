class Config {
  static const String baseUrl = "https://sacco-connect.onrender.com";
  static String get loginUrl => "$baseUrl/auth/login";
  static String dashboardUrl(int id) => "$baseUrl/membres/$id/dashboard";
  static String getEndpoint(String path) {
    return "$baseUrl$path";
  }
}