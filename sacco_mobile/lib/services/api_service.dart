import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiService {
  // En-têtes par défaut
  static Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

  // ==========================================
  // --- AUTHENTIFICATION ET PROFIL ---
  // ==========================================
  static Future<Map<String, dynamic>?> login(String telephone, String pin) async {
    try {
      final response = await http.post(
        Uri.parse(Config.loginUrl),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "username": telephone,
          "password": pin,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Échec de connexion. Code: ${response.statusCode}, Réponse: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Erreur réseau lors du login : $e");
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

      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/inscription'),
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
      print("Erreur inscription: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPortefeuille(dynamic membreId) async {
    try {
      final int idConforme = int.parse(membreId.toString());
      final response = await http.get(
        Uri.parse(Config.dashboardUrl(idConforme)),
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

  static Future<Map<String, dynamic>?> getProfilComplet(int membreId) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/membres/$membreId/profil-complet'),
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

  // ==========================================
  // --- GESTION DES CRÉDITS ET HISTORIQUE ---
  // ==========================================

  static Future<bool> demanderCredit({
    required int membreId,
    required int montant,
    required String motif,
    required double tauxInteretApplique,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/membres/$membreId/demande-credit'),
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
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/membres/$membreId/demande-sociale'),
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
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/membres/$membreId/mes-demandes-prets'),
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
      final response = await http.get(Uri.parse('${Config.baseUrl}/membres/$membreId/historique/'), headers: _headers);
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

  // ==========================================
  // --- ADMINISTRATION BUREAU EXECUTIF ---
  // ==========================================

  static Future<List<dynamic>> getPretsEnAttente() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/admin/prets-en-attente'), headers: _headers);
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
      final response = await http.post(
        // On utilise la configuration globale Config.baseUrl ici aussi !
        Uri.parse("${Config.baseUrl}/admin/valider-demande"),
        headers: _headers,
        body: jsonEncode({
          "id": idDemande,
          "type": type, // 'CREDIT' ou 'SOCIAL'
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
      final response = await http.get(Uri.parse('${Config.baseUrl}/admin/rapports'), headers: _headers);
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
      final response = await http.get(Uri.parse('${Config.baseUrl}/admin/credits-en-retard'), headers: _headers);
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
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/credits/$creditId/appliquer-penalite'),
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