import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class ValidationPretsScreen extends StatefulWidget {
  final int membreId;

  const ValidationPretsScreen({super.key, required this.membreId});

  @override
  State<ValidationPretsScreen> createState() => _ValidationPretsScreenState();
}

class _ValidationPretsScreenState extends State<ValidationPretsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  final Color primaryColor = const Color(0xFF1A529B);
  List<Map<String, dynamic>> _tousLesPrets = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chargerPrets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerPrets() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getPretsEnAttente();
      if (mounted) {
        setState(() {
          _tousLesPrets = data.map((p) => {
            'id': p['id'],
            'membre': '${p['nom'] ?? ''} ${p['prenom'] ?? ''}'.trim(),
            'montant': p['montant'],
            'type': p['type_pret'] ?? 'CREDIT',
            'motif': p['motif'] ?? '',
            'date': p['date_demande'] ?? 'N/A',
            'statut': (p['statut'] ?? 'EN_ATTENTE').toUpperCase(),
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint("Erreur chargement prets: $e");
    }
  }

  void _validerDemande(int idDemande, String typeDemande, bool estApprouve) async {
    setState(() => _isLoading = true);

    try {
      bool success = await ApiService.validerPret(
        idDemande,
        estApprouve,
        widget.membreId,
        typeDemande,
      );

      if (success) {
        if (mounted) {
          // Mettre à jour localement le statut du prêt
          setState(() {
            for (var p in _tousLesPrets) {
              if (p['id'] == idDemande) {
                p['statut'] = estApprouve ? 'APPROUVE' : 'REJETE';
              }
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(estApprouve ? 'request_approved'.tr() : 'request_rejected'.tr()),
              backgroundColor: estApprouve ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        throw Exception('validation_failure'.tr());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('server_communication_error'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'APPROUVE':
      case 'ATTRIBUE':
        return Colors.green;
      case 'REJETE':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pretsEnAttente = _tousLesPrets.where((p) => p['statut'] == 'EN_ATTENTE').toList();
    final historiquePrets = _tousLesPrets.where((p) => p['statut'] != 'EN_ATTENTE').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'validation_prets_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: "En attente (${pretsEnAttente.length})"),
            Tab(text: "Historique (${historiquePrets.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                // ONGLET 1 : En attente de validation
                pretsEnAttente.isEmpty
                    ? Center(
                        child: Text(
                          'no_pending_requests'.tr(),
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pretsEnAttente.length,
                        itemBuilder: (context, index) {
                          final demande = pretsEnAttente[index];
                          return _buildCard(demande, showActions: true);
                        },
                      ),

                // ONGLET 2 : Historique (Approuvés, Rejetés, Attribués)
                historiquePrets.isEmpty
                    ? const Center(
                        child: Text(
                          "Aucun historique de prêt pour le moment.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: historiquePrets.length,
                        itemBuilder: (context, index) {
                          final demande = historiquePrets[index];
                          return _buildCard(demande, showActions: false);
                        },
                      ),
              ],
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> demande, {required bool showActions}) {
    Color statutColor = _getStatutColor(demande['statut']);

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
                Text(
                  demande['membre'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statutColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statutColor),
                  ),
                  child: Text(
                    demande['statut'],
                    style: TextStyle(color: statutColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${demande['montant']} BIF',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (demande['motif'].isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                "Motif : ${demande['motif']}",
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: demande['type'] == 'CREDIT' ? Colors.blue.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${'type_label'.tr()}: ${demande['type']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: demande['type'] == 'CREDIT' ? Colors.blue : Colors.orange,
                    ),
                  ),
                ),
                Text(
                  demande['date'],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            if (showActions) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: const Icon(Icons.close),
                    label: Text('reject'.tr()),
                    onPressed: () => _validerDemande(demande['id'], demande['type'], false),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: Text('approve'.tr()),
                    onPressed: () => _validerDemande(demande['id'], demande['type'], true),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}