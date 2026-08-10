import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';
import 'gestion_penalites_screen.dart';

class RapportsFinanciersScreen extends StatefulWidget {
  final int membreId;

  const RapportsFinanciersScreen({super.key, required this.membreId});

  @override
  State<RapportsFinanciersScreen> createState() => _RapportsFinanciersScreenState();
}

class _RapportsFinanciersScreenState extends State<RapportsFinanciersScreen> {
  final Color primaryColor = const Color(0xFF1A529B);
  bool _isLoading = true;

  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _chargerRapports();
  }

  Future<void> _chargerRapports() async {
    try {
      final stats = await ApiService.getRapportsGlobaux();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String epargne = _stats?['total_epargne']?.toString() ?? '0.0';
    String credits = _stats?['total_credits_actifs']?.toString() ?? '0.0';
    String social = _stats?['total_social']?.toString() ?? '0.0';
    String penalites = _stats?['penalites_percues']?.toString() ?? '0.0';

    return Scaffold(
      appBar: AppBar(
        title: Text('reports_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('global_health'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                _buildRapportCard('total_savings_collected'.tr(), '$epargne FBU', Icons.account_balance, Colors.teal),
                _buildRapportCard('active_credits'.tr(), '$credits FBU', Icons.trending_up, Colors.orange),
                _buildRapportCard('social_fund_balance'.tr(), '$social FBU', Icons.volunteer_activism, Colors.blue),
                _buildRapportCard('penalties_collected'.tr(), '$penalites FBU', Icons.warning_amber_rounded, Colors.redAccent),

                const SizedBox(height: 24),
                Text('admin_actions'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.gavel, color: Colors.deepOrange),
                  title: Text('penalties_management'.tr()),
                  subtitle: Text('penalties_subtitle'.tr()),
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