import 'package:flutter/material.dart';
import '../services/api_service.dart'; // N'oublie pas cet import pour que l'API fonctionne
import 'gestion_penalites_screen.dart';

class RapportsFinanciersScreen extends StatefulWidget {
  final int membreId;

  const RapportsFinanciersScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<RapportsFinanciersScreen> createState() => _RapportsFinanciersScreenState();
}

class _RapportsFinanciersScreenState extends State<RapportsFinanciersScreen> {
  final Color primaryColor = const Color(0xFF1A529B);
  bool _isLoading = true;

  // Variable pour stocker les données réelles du backend
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _chargerRapports();
  }

  // Nouvelle fonction connectée à ton FastAPI
  Future<void> _chargerRapports() async {
    final stats = await ApiService.getRapportsGlobaux();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extraction sécurisée des valeurs (si null, on affiche 0.0)
    String epargne = _stats?['total_epargne']?.toString() ?? '0.0';
    String credits = _stats?['total_credits_actifs']?.toString() ?? '0.0';
    String social = _stats?['total_social']?.toString() ?? '0.0';
    String penalites = _stats?['penalites_percues']?.toString() ?? '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports & Analyses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Santé Globale de la Coopérative', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Les cartes utilisent maintenant les vraies données de l'API
                _buildRapportCard('Épargne Totale Collectée', '$epargne FBU', Icons.account_balance, Colors.teal),
                _buildRapportCard('Crédits Actifs (En cours)', '$credits FBU', Icons.trending_up, Colors.orange),
                _buildRapportCard('Fonds de la Caisse Sociale', '$social FBU', Icons.volunteer_activism, Colors.blue),
                _buildRapportCard('Pénalités de Retard Perçues', '$penalites FBU', Icons.warning_amber_rounded, Colors.redAccent),

                const SizedBox(height: 24),
                const Text('Actions Administrateur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.gavel, color: Colors.deepOrange),
                  title: const Text('Gestion des Pénalités'),
                  subtitle: const Text('Appliquer des pénalités sur les retards manuellement'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GestionPenalitesScreen(membreId: widget.membreId),
                      ),
                    );
                  },
                )
              ],
            ),
    );
  }

  Widget _buildRapportCard(String titre, String valeur, IconData icone, Color couleur) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: couleur.withOpacity(0.1), radius: 24, child: Icon(icone, color: couleur, size: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(valeur, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}