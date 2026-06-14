import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ValidationPretsScreen extends StatefulWidget {
  final int membreId;

  const ValidationPretsScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<ValidationPretsScreen> createState() => _ValidationPretsScreenState();
}

class _ValidationPretsScreenState extends State<ValidationPretsScreen> {
  bool _isLoading = true;
  final Color primaryColor = const Color(0xFF1A529B);
  List<Map<String, dynamic>> _demandesEnAttente = [];

  @override
  void initState() {
    super.initState();
    _chargerDemandes();
  }

  Future<void> _chargerDemandes() async {
    final data = await ApiService.getPretsEnAttente();
    if (mounted) {
      setState(() {
        _demandesEnAttente = data.map((p) => {
          'id': p['id'],
          'membre': '${p['nom']} ${p['prenom']}',
          'montant': p['montant'],
          'type': p['type_pret'],
          'date': p['date_demande'] ?? 'N/A'
        }).toList();
        _isLoading = false;
      });
    }
  }

  // Fonction mise à jour utilisant ApiService
  void _validerDemande(int idDemande, String typeDemande, bool estApprouve) async {
    setState(() => _isLoading = true);

    try {
      // Appel via votre Service au lieu de http direct
      bool success = await ApiService.validerPret(
        idDemande,
        estApprouve,
        widget.membreId,
        typeDemande
      );

      if (success) {
        if (mounted) {
          setState(() => _demandesEnAttente.removeWhere((d) => d['id'] == idDemande));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(estApprouve ? "Demande approuvée" : "Demande rejetée"),
              backgroundColor: estApprouve ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        throw Exception("Échec de la validation");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la communication avec le serveur")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des Prêts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _demandesEnAttente.isEmpty
              ? const Center(child: Text("Aucune demande en attente.", style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _demandesEnAttente.length,
                  itemBuilder: (context, index) {
                    final demande = _demandesEnAttente[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(demande['membre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(demande['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${demande['montant']} FBU', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: demande['type'] == 'CREDIT' ? Colors.blue.shade100 : Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('Type: ${demande['type']}', style: TextStyle(fontSize: 12, color: demande['type'] == 'CREDIT' ? Colors.blue : Colors.orange)),
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Rejeter'),
                                  onPressed: () => _validerDemande(demande['id'], demande['type'], false),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Approuver'),
                                  onPressed: () => _validerDemande(demande['id'], demande['type'], true),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}