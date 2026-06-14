import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'demande_credit_screen.dart';

class CreditScreen extends StatefulWidget {
  final int membreId;

  const CreditScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _donneesCredit;
  final Color primaryColor = const Color(0xFF1A529B);

  @override
  void initState() {
    super.initState();
    _chargerDetailsCredit();
  }

  Future<void> _chargerDetailsCredit() async {
    try {
      final data = await ApiService.getPortefeuille(widget.membreId);
      if (mounted) {
        setState(() {
          _donneesCredit = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Erreur crédit: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double encours = _donneesCredit?['credit_en_cours']?.toDouble() ?? 0.0;
    double restant = _donneesCredit?['credit_restant']?.toDouble() ?? 0.0;
    double pretSocial = _donneesCredit?['solde_pret_social']?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Crédit & Prêts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _chargerDetailsCredit,
              color: primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Résumé des encours ---
                  _buildStatCard('Crédit En Cours', '$encours FBU', Colors.redAccent, Icons.money_off),
                  const SizedBox(height: 12),
                  _buildStatCard('Reste à Rembourser', '$restant FBU', Colors.orange, Icons.hourglass_empty),
                  const SizedBox(height: 12),
                  _buildStatCard('Prêt Social Actif', '$pretSocial FBU', Colors.blue, Icons.handshake),
                  const SizedBox(height: 30),

                  // --- Bouton d'action ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Nouvelle Demande de Crédit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DemandeCreditScreen(membreId: widget.membreId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}