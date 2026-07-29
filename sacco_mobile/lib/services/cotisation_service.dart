import 'local_database.dart'
import 'api_service.dart'

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
            action: "AJOUT_COTISATION",
            endpoint: "/cotisations",
            method: "POST",
            payload: payload,
        );

        ApiService.syncPendingRequests();

        return true;
    } catch (e) {
        print("Erreur lors de l'enregistrement local de la cotisation : $e");
        return false;
        }
    }
}