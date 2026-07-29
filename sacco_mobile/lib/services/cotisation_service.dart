import 'local_database.dart';
import 'api_service.dart';

class CotisationService {
  static Future<bool> enregistrerCotisation({
    required int membreId,
    required double montant,
    required String date,
  }) async {
    try {
      await LocalDatabase.insertCotisationLocal(
        membreId: membreId,
        montant: montant,
        date: date,
      );

      final payload = {
        "membre_id": membreId,
        "montant": montant,
        "date_cotisation": date,
      };

      await LocalDatabase.addToSyncQueue(
        '/cotisations',
        'POST',
        payload,
        action: 'AJOUT_COTISATION',
      );

      ApiService.syncPendingRequests();

      return true;
    } catch (e) {
      print("Erreur lors de l'enregistrement de la cotisation : $e");
      return false;
    }
  }
}