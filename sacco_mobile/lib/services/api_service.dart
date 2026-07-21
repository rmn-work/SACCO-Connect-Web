import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../services/config.dart';
import 'authenticated_client.dart';

class ApiService {
  static const String productionUrl = "https://sacco-connect.onrender.com";
  static final AuthenticatedClient _client = AuthenticatedClient();
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  static Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

  static Uri get loginUri => Uri.parse('$baseUrl/auth/login');
  static Uri get membresUri => Uri.parse('$baseUrl/membres');
  static Uri get groupesUri => Uri.parse('$baseUrl/groupes');

  static String _url(String endpoint) {
    return "$baseUrl$endpoint";
  }

  static Future<Map<String, dynamic>?> login(String telephone, String pin) async {
    print("Tentative de connexion vers : $loginUri");
    try {
      final response = await http.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
        },
        body: {
          "username": telephone,
          "password": pin,
        },
      ).timeout(const Duration(seconds: 10));

      print("Status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Erreur lors de la connexion: $e");
      return null;
    }
  }

  static Future<bool> inscrireMembre({
    required String nom,
    required String prenom,
    required int age,
    required String sexe,
    required String telephone,
    required String cni,
    required String colline,
    required String quartier,
    required String avenue,
    required String maison,
  }) async {
    try {
      String sexeCode = (sexe == 'Masculin') ? 'M' : 'F';

      final response = await _client.post(
        Uri.parse(_url('/auth/inscription')),
        headers: _headers,
        body: jsonEncode({
          "nom": nom,
          "prenom": prenom,
          "age": age,
          "sexe": sexeCode,
          "telephone": telephone,
          "cni": cni,
          "colline": colline,
          "quartier": quartier,
          "avenue": avenue,
          "maison": maison
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPortefeuille(dynamic membreId) async {
    try {
      final int idConforme = int.parse(membreId.toString());
      final response = await _client.get(
        Uri.parse('$baseUrl/membres/$idConforme/portefeuille'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Erreur réseau portefeuille : $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getDashboardData(int membreId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/membres/$membreId/dashboard'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print("Erreur serveur: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Erreur réseau lors de la récupération du dashboard: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProfilComplet(int membreId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/membres/$membreId/profil-complet'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Erreur lors de la récupération du profil : $e");
      return null;
    }
  }

  static Future<bool> demanderCredit({
    required int membreId,
    required int montant,
    required String motif,
    required double tauxInteretApplique,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/membres/$membreId/demande-credit'),
        headers: _headers,
        body: jsonEncode({
          'montant': montant,
          'motif': motif,
          'taux_interet_applique': tauxInteretApplique,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Erreur demanderCredit: $e");
      return false;
    }
  }

  static Future<bool> demanderPretSocial({
    required int membreId,
    required int montant,
    required String motif,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/membres/$membreId/demande-sociale'),
        headers: _headers,
        body: jsonEncode({
          'montant_demande': montant,
          'motif': motif,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Erreur demanderPretSocial: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getMesDemandesPrets(int membreId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/membres/$membreId/mes-demandes-prets'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) {
          return List<dynamic>.from(decoded['data']);
        } else if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      print("Erreur getMesDemandesPrets: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getHistoriqueEpargne(int membreId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/membres/$membreId/historique/'),
        headers: _headers
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) return List<dynamic>.from(decoded['data']);
        if (decoded is List) return decoded;
      }
    } catch (e) {
      print("Erreur historique : $e");
    }
    return [];
  }

  static Future<List<dynamic>> getPretsEnAttente() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/prets-en-attente'),
        headers: _headers
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return (decoded is Map && decoded.containsKey('data'))
            ? List<dynamic>.from(decoded['data'])
            : (decoded is List ? decoded : []);
      }
    } catch (e) {
      print("Erreur getPretsEnAttente: $e");
    }
    return [];
  }

  static Future<bool> validerPret(int idDemande, bool approuver, int adminId, String type) async {
    try {
      final response = await _client.post(
        Uri.parse("$baseUrl/admin/valider-demande"),
        headers: _headers,
        body: jsonEncode({
          "id": idDemande,
          "type": type,
          "approuver": approuver,
          "admin_id": adminId
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Erreur API : $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRapportsGlobaux() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/rapports'),
        headers: _headers
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return (decoded is Map) ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
      }
    } catch (e) {
      print("Erreur getRapports: $e");
    }
    return null;
  }

  static Future<List<dynamic>> getCreditsEnRetard() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/credits-en-retard'),
        headers: _headers
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return (decoded is Map && decoded.containsKey('data'))
            ? List<dynamic>.from(decoded['data'])
            : (decoded is List ? decoded : []);
      }
    } catch (e) {
      print("Erreur getCreditsEnRetard: $e");
    }
    return [];
  }

  static Future<bool> appliquerPenalite(int creditId, double taux, int adminId, int moisRetard) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/credits/$creditId/appliquer-penalite'),
        headers: _headers,
        body: jsonEncode({
          "taux_penalite_mensuel": taux,
          "admin_id": adminId,
          "mois_retard": moisRetard
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Erreur appliquerPenalite: $e");
      return false;
    }
  }
}