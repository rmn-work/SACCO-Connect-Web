import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'authenticated_client.dart';
import 'local_database.dart';

class ApiResponse {
  final bool success;
  final String message;
  ApiResponse({required this.success, required this.message});
}

class ApiService {
  static const String productionUrl = "https://sacco-connect-web.onrender.com";

  static const bool isLocalEnvironment = false;

  static final AuthenticatedClient _client = AuthenticatedClient();

  static String get baseUrl {
    if (isLocalEnvironment) {
      if (kIsWeb) return 'http://localhost:8000';
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      return 'http://127.0.0.1:8000';
    } else {
      return productionUrl;
    }
  }

  static Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

  static String _url(String endpoint) {
    return endpoint.startsWith('/') ? "$baseUrl$endpoint" : "$baseUrl/$endpoint";
  }

  static Uri get loginUri => Uri.parse(_url('/auth/login'));

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
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await LocalDatabase.cacheData('user_session', data);
        return data;
      }
      return null;
    } catch (e) {
      print("Erreur réseau, chargement de la session locale: $e");
      final cachedSession = await LocalDatabase.getCachedData('user_session');
      return cachedSession as Map<String, dynamic>?;
    }
  }

  static Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String fullName,
    required String pin,
  }) async {
    final url = Uri.parse(_url('/auth/register'));

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phoneNumber,
          'fullName': fullName,
          'pin': pin,
        }),
      ).timeout(const Duration(seconds: 45));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Compte créé avec succès !'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Erreur lors de la création du compte.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau ou délai d\'attente dépassé.'};
    }
  }

  static Future<ApiResponse> inscrireMembre({
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
    required String pin,
  }) async {
    String sexeCode = (sexe == 'Masculin') ? 'M' : 'F';
    final payload = {
      "nom": nom,
      "prenom": prenom,
      "age": age,
      "sexe": sexeCode,
      "telephone": telephone,
      "pin": pin,
      "cni": cni,
      "colline": colline,
      "quartier": quartier,
      "avenue": avenue,
      "maison": maison,
      "created_at_offline": DateTime.now().toIso8601String()
    };

    const endpoint = '/auth/inscription';

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      debugPrint("STATUS API: ${response.statusCode}");
      debugPrint("REPONSE API: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(success: true, message: 'Inscription réussie !');
      } else {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(response.body);
        } catch (_) {}

        String errorDetails = data['detail'] ??
            data['message'] ??
            data['error'] ??
            'Erreur serveur (${response.statusCode}) : ${response.body}';

        return ApiResponse(success: false, message: errorDetails);
      }
    } catch (e) {
      debugPrint("Mode hors-ligne : Inscription mise en file d'attente. Erreur: $e");
      await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
      return ApiResponse(
        success: true,
        message: 'Mode hors-ligne : Inscription enregistrée localement.',
      );
    }
  }

  static Future<Map<String, dynamic>?> getPortefeuille(dynamic membreId) async {
    final String cacheKey = 'portefeuille_$membreId';
    try {
      final int idConforme = int.parse(membreId.toString());
      final response = await _client.get(
        Uri.parse(_url('/membres/$idConforme/portefeuille/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await LocalDatabase.cacheData(cacheKey, data);
        return data;
      }
    } catch (e) {
      print("Mode Hors-ligne : Récupération portefeuille depuis cache");
    }
    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getDashboardData(int membreId) async {
    final String cacheKey = 'dashboard_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/membres/$membreId/dashboard')),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await LocalDatabase.cacheData(cacheKey, data);
        return data;
      }
    } catch (e) {
      print("Mode Hors-ligne : Récupération dashboard depuis cache");
    }
    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getProfilComplet(int membreId) async {
    final String cacheKey = 'profil_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/membres/$membreId/profil')),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await LocalDatabase.cacheData(cacheKey, data);
        return data;
      }
    } catch (e) {
      print("Mode Hors-ligne : Récupération profil depuis cache");
    }
    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<bool> uploadRecu({
    required int membreId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      var uri = Uri.parse(_url('/membres/$membreId/upload-recu/'));
      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('recu', filePath, filename: fileName),
      );
      var streamedResponse = await _client.send(request).timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Erreur lors de l'upload du reçu : $e");
      return false;
    }
  }

  static Future<bool> demanderCredit({
    required int membreId,
    required int montant,
    required String motif,
    required double tauxInteretApplique,
  }) async {
    final endpoint = '/membres/$membreId/demande-credit';
    final payload = {
      'montant': montant,
      'motif': motif,
      'taux_interet_applique': tauxInteretApplique,
      'created_at_offline': DateTime.now().toIso8601String()
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) return true;
    } catch (e) {
      print("Hors-ligne : Demande de crédit enregistrée localement");
    }

    await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
    return true;
  }

  static Future<bool> demanderPretSocial({
    required int membreId,
    required int montant,
    required String motif,
  }) async {
    final endpoint = '/membres/$membreId/demande-sociale';
    final payload = {
      'montant_demande': montant,
      'motif': motif,
      'created_at_offline': DateTime.now().toIso8601String()
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) return true;
    } catch (e) {
      print("Hors-ligne : Demande sociale enregistrée localement");
    }

    await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
    return true;
  }

  static Future<List<dynamic>> getMesDemandesPrets(int membreId) async {
    final String cacheKey = 'demandes_prets_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/membres/$membreId/mes-demandes-prets')),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> result = [];
        if (decoded is Map && decoded.containsKey('data')) {
          result = List<dynamic>.from(decoded['data']);
        } else if (decoded is List) {
          result = decoded;
        }
        await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      print("Hors-ligne : Chargement historique prêts local");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<List<dynamic>> getHistoriqueEpargne(int membreId) async {
    final String cacheKey = 'historique_epargne_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/membres/$membreId/historique')),
        headers: _headers
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> result = [];
        if (decoded is Map && decoded.containsKey('data')) result = List<dynamic>.from(decoded['data']);
        if (decoded is List) result = decoded;
        await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      print("Hors-ligne : Chargement épargne local");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<List<dynamic>> getPretsEnAttente() async {
    final String cacheKey = 'prets_en_attente';
    try {
      final response = await _client.get(
        Uri.parse(_url('/admin/prets-en-attente')),
        headers: _headers
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> result = (decoded is Map && decoded.containsKey('data'))
            ? List<dynamic>.from(decoded['data'])
            : (decoded is List ? decoded : []);
        await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      print("Hors-ligne : Chargement prêts en attente depuis cache");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<bool> validerPret(int idDemande, bool approuver, int adminId, String type) async {
    const endpoint = "/admin/valider-demande";
    final payload = {
      "id": idDemande,
      "type": type,
      "approuver": approuver,
      "admin_id": adminId,
      "validated_at_offline": DateTime.now().toIso8601String()
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) return true;
    } catch (e) {
      print("Hors-ligne : Validation enregistrée localement");
    }

    await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
    return true;
  }

  static Future<ApiResponse> validerPresenceQr({
    required String qrToken,
    required int adminId,
  }) async {
    const endpoint = '/admin/valider-presence-qr';
    final payload = {
      "qr_token": qrToken,
      "admin_id": adminId,
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: data['message'] ?? 'Présence enregistrée avec succès !',
        );
      } else {
        return ApiResponse(
          success: false,
          message: data['detail'] ?? data['message'] ?? 'QR code invalide ou expiré.',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Erreur réseau lors de la validation du QR code.',
      );
    }
  }

  static Future<Map<String, dynamic>?> getRapportsGlobaux() async {
    final String cacheKey = 'rapports_globaux';
    try {
      final response = await _client.get(
        Uri.parse(_url('/admin/rapports')),
        headers: _headers
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = (decoded is Map) ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
        if (result != null) await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      print("Hors-ligne : Chargement rapports locaux");
    }
    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<List<dynamic>> getCreditsEnRetard() async {
    final String cacheKey = 'credits_en_retard';
    try {
      final response = await _client.get(
        Uri.parse(_url('/admin/credits-en-retard')),
        headers: _headers
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> result = (decoded is Map && decoded.containsKey('data'))
            ? List<dynamic>.from(decoded['data'])
            : (decoded is List ? decoded : []);
        await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      print("Hors-ligne : Chargement crédits en retard depuis cache");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<bool> appliquerPenalite(int creditId, double taux, int adminId, int moisRetard) async {
    final endpoint = '/api/credits/$creditId/appliquer-penalite';
    final payload = {
      "tau_penalite_mensuel": taux,
      "admin_id": adminId,
      "mois_retard": moisRetard,
      "applied_at_offline": DateTime.now().toIso8601String()
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) return true;
    } catch (e) {
      print("Hors-ligne : Pénalité mise en file d'attente");
    }

    await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
    return true;
  }

  static Future<int> syncPendingRequests() async {
    final pendingQueue = await LocalDatabase.getPendingSyncQueue();
    if (pendingQueue.isEmpty) return 0;

    int syncedCount = 0;
    print("Début synchro : ${pendingQueue.length} opérations en attente...");

    for (var item in pendingQueue) {
      final int queueId = item['id'];
      final String endpoint = item['endpoint'];
      final String method = item['method'];
      final Map<String, dynamic> payload = jsonDecode(item['payload']);

      try {
        http.Response response;
        final uri = Uri.parse(_url(endpoint));

        if (method == 'POST') {
          response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
        } else if (method == 'PUT') {
          response = await _client.put(uri, headers: _headers, body: jsonEncode(payload));
        } else {
          continue;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await LocalDatabase.deleteFromSyncQueue(queueId);
          syncedCount++;
          print("Requête #$queueId synchronisée !");
        }
      } catch (e) {
        print("Erreur réseau pendant la synchronisation de #$queueId. Arrêt.");
        break;
      }
    }
    return syncedCount;
  }
}