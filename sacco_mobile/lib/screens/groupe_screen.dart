import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GroupeScreen extends StatefulWidget {
  final int membreId;

  const GroupeScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<GroupeScreen> createState() => _GroupeScreenState();
}

class _GroupeScreenState extends State<GroupeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _donneesUser;
  final Color primaryColor = const Color(0xFF1A529B);

  @override
  void initState() {
    super.initState();
    _chargerInfosGroupe();
  }

  Future<void> _chargerInfosGroupe() async {
    try {
      final data = await ApiService.getPortefeuille(widget.membreId);
      if (mounted) {
        setState(() {
          _donneesUser = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Erreur groupe: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    int groupeId = _donneesUser?['groupe_id'] ?? 0;
    String presence = _donneesUser?['status_presence'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Groupe Sacco', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header du groupe ---
                  Card(
                    color: primaryColor.withOpacity(0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: primaryColor.withOpacity(0.2))),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.gite, size: 40, color: primaryColor),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Groupe Solidaire #$groupeId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Statut Présence Réunion : $presence', style: TextStyle(color: Colors.grey[700])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Règles du Groupe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildRuleTile('La présence aux réunions hebdomadaires est obligatoire.'),
                  _buildRuleTile('Les cotisations à la caisse sociale se font à chaque séance.'),
                  _buildRuleTile('La solidarité est la clé de la caution solidaire pour l\'obtention des crédits.'),
                ],
              ),
            ),
    );
  }

  Widget _buildRuleTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: primaryColor, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}