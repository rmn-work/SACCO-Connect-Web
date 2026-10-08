import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'authenticated_client.dart';
import 'config.dart';
import 'local_database.dart';

class ApiResponse {
  final bool success;
  final String message;
  ApiResponse({required this.success, required this.message});
}

class ApiService {
  static final AuthenticatedClient _client = AuthenticatedClient();

  /// Obtenir l'URL de base dynamique à partir de la classe Config
  static String get baseUrl => Config.getEndpoint('');

  static Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest",
      };

  static String _url(String endpoint) {
    return Config.getEndpoint(endpoint);
  }

  // ==========================================
  // AUTHENTICATION
  // ==========================================
  static Future<Map<String, dynamic>?> login(String telephone, String pin) async {
    final Uri url = Uri.parse(Config.loginUrl);
    debugPrint("🔍 [LOGIN] Tentative de connexion vers : $url");

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'username': telephone,
          'telephone': telephone,
          'pin': pin,
          'password': pin,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint("------------------- DEBOGAGE LOGIN -------------------");
      debugPrint("STATUS CODE  : ${response.statusCode}");
      debugPrint("HEADERS      : ${response.headers}");
      debugPrint("RESPONSE BODY: ${response.body}");
      debugPrint("-------------------------------------------------------");

      // Vérification et décodage sécurisé pour éviter le crash en cas de page HTML (404/500)
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        return {
          'success': false,
          'message': 'Erreur serveur (${response.statusCode}) : La route de connexion est introuvable.',
        };
      }

      if (response.statusCode == 200) {
        // Extraction et sauvegarde des cookies de session Django le cas échéant
        String? rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          String cleanCookies = "";
          final sessionMatch = RegExp(r'sessionid=([^;]+)').firstMatch(rawCookie);
          if (sessionMatch != null) cleanCookies += "${sessionMatch.group(0)}; ";

          final csrfMatch = RegExp(r'csrftoken=([^;]+)').firstMatch(rawCookie);
          if (csrfMatch != null) cleanCookies += "${csrfMatch.group(0)};";

          if (cleanCookies.isNotEmpty) {
            await const FlutterSecureStorage().write(key: 'django_cookies', value: cleanCookies);
            debugPrint("✅ Cookies extraits : $cleanCookies");
          }
        }

        bool isSuccess = data['success'] == true ||
            data['status'] == 'success' ||
            data.containsKey('user_id') ||
            data.containsKey('membre_id');

        if (isSuccess) {
          data['success'] = true;
          await LocalDatabase.cacheData('user_session', data);
          return data;
        } else {
          debugPrint("❌ Erreur applicative (200 OK mais données invalides) : $data");
          return data;
        }
      } else {
        debugPrint("❌ Erreur serveur Django (${response.statusCode}) : ${response.body}");
        return data;
      }
    } on TimeoutException catch (e) {
      debugPrint("⏳ TIMEOUT LOGIN : Le serveur met trop de temps à répondre ($e)");
      final cachedSession = await LocalDatabase.getCachedData('user_session') as Map<String, dynamic>?;
      if (cachedSession != null) {
        return cachedSession;
      }
      return {
        'success': false,
        'error_type': 'timeout',
        'message': 'Le serveur met du temps à démarrer. Veuillez réessayer dans quelques secondes.',
      };
    } catch (e, stackTrace) {
      debugPrint("Erreur réseau ApiService.login : $e");
      debugPrint("🚨 StackTrace : $stackTrace");
      final cachedSession = await LocalDatabase.getCachedData('user_session') as Map<String, dynamic>?;
      return cachedSession;
    }
  }

  static Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String fullName,
    required String pin,
  }) async {
    final url = Uri.parse(_url('/api/auth/register/'));

    try {
      final response = await _client.post(
        url,
        headers: _headers,
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
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de la création du compte.'
        };
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

    const endpoint = '/api/auth/inscription/';

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

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
      await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
      return ApiResponse(
        success: true,
        message: 'Mode hors-ligne : Inscription enregistrée localement.',
      );
    }
  }

  // ==========================================
  // MEMBRE & PORTFEUILLE
  // ==========================================
  static Future<Map<String, dynamic>?> getPortefeuille(int membreId) async {
    final String cacheKey = 'portefeuille_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/membres/$membreId/portefeuille/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic> data = {};
        if (decoded is Map && decoded.containsKey('data') && decoded['data'] is Map) {
          data = Map<String, dynamic>.from(decoded['data']);
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
        await LocalDatabase.cacheData(cacheKey, data);
        return data;
      }
    } catch (e) {
      debugPrint("Mode Hors-ligne : Récupération portefeuille depuis cache ($e)");
    }
    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getDashboardData(int membreId) async {
    final String cacheKey = 'dashboard_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/membres/$membreId/dashboard/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic> data = {};
        if (decoded is Map && decoded.containsKey('data') && decoded['data'] is Map) {
          data = Map<String, dynamic>.from(decoded['data']);
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
        await LocalDatabase.cacheData(cacheKey, data);
        return data;
      }
    } catch (e) {
      debugPrint("Mode Hors-ligne : Récupération dashboard depuis cache ($e)");
    }
    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getProfilComplet(int membreId) async {
    final String cacheKey = 'profil_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/membres/$membreId/profil/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic> result = {};

        if (decoded is Map && decoded.containsKey('data') && decoded['data'] is Map) {
          result = Map<String, dynamic>.from(decoded['data']);
        } else if (decoded is Map) {
          result = Map<String, dynamic>.from(decoded);
        }

        await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      debugPrint("🚨 Exception réseau getProfilComplet : $e");
    }

    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<bool> uploadRecu({
    required int membreId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      var uri = Uri.parse(_url('/api/membres/$membreId/upload-recu/'));
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

  // ==========================================
  // DEMANDES DE CREDITS ET PRÊTS
  // ==========================================
  static Future<bool> demanderCredit({
    required int membreId,
    required int montant,
    required String motif,
    required double tauxInteretApplique,
  }) async {
    final endpoint = '/api/membres/$membreId/demande-credit/';
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Hors-ligne : Demande de crédit enregistrée localement");
      await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
      return true;
    }
  }

  static Future<bool> demanderPretSocial({
    required int membreId,
    required int montant,
    required String motif,
  }) async {
    final endpoint = '/api/membres/$membreId/demande-sociale/';
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Hors-ligne : Demande sociale enregistrée localement");
      await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
      return true;
    }
  }

  static Future<List<dynamic>> getMesDemandesPrets(int membreId) async {
    final String cacheKey = 'demandes_prets_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/membres/$membreId/mes-demandes-prets/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

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
      debugPrint("Hors-ligne : Chargement historique prêts local");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<List<dynamic>> getHistoriqueMembre(int membreId) async {
    final String cacheKey = 'historique_membre_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/membres/$membreId/historique/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

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
      debugPrint("Erreur API getHistoriqueMembre: $e");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<List<dynamic>> getHistoriqueEpargne(int membreId) => getHistoriqueMembre(membreId);

  // ==========================================
  // ADMINISTRATION
  // ==========================================
  static Future<List<dynamic>> getPretsEnAttente() async {
    final String cacheKey = 'prets_en_attente';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/admin/prets-en-attente/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> result = (decoded is Map && decoded.containsKey('data'))
            ? List<dynamic>.from(decoded['data'])
            : (decoded is List ? decoded : []);
        await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      debugPrint("Hors-ligne : Chargement prêts en attente depuis cache");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<bool> validerPret(int idDemande, bool approuver, int adminId, String type) async {
    const endpoint = "/api/admin/valider-demande/";
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      debugPrint("Hors-ligne : Validation enregistrée localement");
      await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
      return true;
    }
  }

  static Future<ApiResponse> validerPresenceQr({
    required String qrToken,
    required int adminId,
  }) async {
    const endpoint = '/api/admin/valider-presence-qr/';
    final payload = {
      "qr_token": qrToken,
      "admin_id": adminId,
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

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
        Uri.parse(_url('/api/admin/rapports/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = (decoded is Map) ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
        if (result != null) await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      debugPrint("Hors-ligne : Chargement rapports locaux");
    }
    return await LocalDatabase.getCachedData(cacheKey) as Map<String, dynamic>?;
  }

  static Future<List<dynamic>> getCreditsEnRetard() async {
    final String cacheKey = 'credits_en_retard';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/admin/credits-en-retard/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> result = (decoded is Map && decoded.containsKey('data'))
            ? List<dynamic>.from(decoded['data'])
            : (decoded is List ? decoded : []);
        await LocalDatabase.cacheData(cacheKey, result);
        return result;
      }
    } catch (e) {
      debugPrint("Hors-ligne : Chargement crédits en retard depuis cache");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<bool> appliquerPenalite(int creditId, double taux, int adminId, int moisRetard) async {
    final endpoint = '/api/credits/$creditId/appliquer-penalite/';
    final payload = {
      "taux_penalite_mensuel": taux,
      "admin_id": adminId,
      "mois_retard": moisRetard,
      "applied_at_offline": DateTime.now().toIso8601String()
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      debugPrint("Hors-ligne : Pénalité mise en file d'attente");
      await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
      return true;
    }
  }

  // ==========================================
  // GESTION DES REMBOURSEMENTS
  // ==========================================
  static Future<List<dynamic>> getCreditsActifs(int membreId) async {
    final String cacheKey = 'credits_actifs_$membreId';
    try {
      final response = await _client.get(
        Uri.parse(_url('/api/membres/$membreId/credits-actifs/')),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

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
      debugPrint("Hors-ligne : Chargement des crédits actifs depuis le cache ($e)");
    }
    final cached = await LocalDatabase.getCachedData(cacheKey);
    return cached is List ? cached : [];
  }

  static Future<ApiResponse> enregistrerRemboursement({
    required int creditId,
    required double montant,
    required String reference,
    int? adminId,
  }) async {
    const endpoint = '/api/admin/enregistrer-remboursement/';
    final payload = {
      "credit_id": creditId,
      "montant": montant,
      "reference": reference,
      if (adminId != null) "admin_id": adminId,
      "created_at_offline": DateTime.now().toIso8601String(),
    };

    try {
      final response = await _client.post(
        Uri.parse(_url(endpoint)),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(success: true, message: 'Remboursement enregistré avec succès !');
      } else {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(response.body);
        } catch (_) {}
        String errorMsg = data['detail'] ?? data['message'] ?? 'Erreur lors du remboursement.';
        return ApiResponse(success: false, message: errorMsg);
      }
    } catch (e) {
      await LocalDatabase.addToSyncQueue(endpoint, 'POST', payload);
      return ApiResponse(
        success: true,
        message: 'Mode hors-ligne : Remboursement enregistré localement.',
      );
    }
  }

  // ==========================================
  // SYNCHRONISATION DESCENDANTE & ASCENDANTE
  // ==========================================
  static Future<void> refreshAllData(int membreId) async {
    debugPrint("🔄 Lancement de la synchronisation complète (Serveur -> Mobile)...");
    try {
      await syncPendingRequests();

      await getDashboardData(membreId);
      await getPortefeuille(membreId);
      await getProfilComplet(membreId);
      await getMesDemandesPrets(membreId);
      await getHistoriqueMembre(membreId);

      debugPrint("✅ Synchronisation complète terminée avec succès !");
    } catch (e) {
      debugPrint("⚠ Erreur lors de la synchronisation complète : $e");
    }
  }

  static Future<int> syncPendingRequests() async {
    final pendingQueue = await LocalDatabase.getPendingSyncQueue();
    if (pendingQueue.isEmpty) return 0;

    int syncedCount = 0;
    debugPrint("Début synchro : ${pendingQueue.length} opérations en attente...");

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
          debugPrint("Requête #$queueId synchronisée !");
        }
      } catch (e) {
        debugPrint("Erreur réseau pendant la synchronisation de #$queueId. Arrêt.");
        break;
      }
    }
    return syncedCount;
  }
}