import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class TableauGroupeScreen extends StatefulWidget {
  final int groupId;

  const TableauGroupeScreen({super.key, required this.groupId});

  @override
  State<TableauGroupeScreen> createState() => _TableauGroupeScreenState();
}

class _TableauGroupeScreenState extends State<TableauGroupeScreen> {
  bool _isLoading = true;
  List<dynamic> _membres = [];
  double _epargneTotaleGroupe = 0.0;
  int _membresActifs = 0;

  @override
  void initState() {
    super.initState();
    _recupererDonneesGroupe();
  }

  Future<void> _recupererDonneesGroupe() async {
    setState(() => _isLoading = true);

    try {
      // Synchronisation avec l'API Django du groupe
      final uri = Uri.parse("${ApiService.baseUrl}/groupes/${widget.groupId}/membres/");
      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> listRaw = [];

        if (decoded is List) {
          listRaw = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          listRaw = decoded['data'];
        }

        double totalEpargne = 0;
        int actifs = 0;

        List<Map<String, dynamic>> membresFormates = listRaw.map((m) {
          String nomComplet = "${m['nom'] ?? ''} ${m['prenom'] ?? ''}".trim();
          if (nomComplet.isEmpty) {
            nomComplet = m['nom_complet'] ?? m['username'] ?? "Membre #${m['id']}";
          }

          double epargne = (m['epargne'] ?? m['solde_epargne'] ?? 0.0).toDouble();
          double caisse = (m['caisse'] ?? m['solde_caisse_sociale'] ?? 0.0).toDouble();
          String presence = m['presence'] ?? 'P';
          int estActif = (m['actif'] ?? 1);

          totalEpargne += epargne;
          if (estActif == 1) {
            actifs++;
          }

          return {
            "nom": m['nom'] ?? 'N/A',
            "prenom": m['prenom'] ?? 'N/A',
            "epargne": epargne,
            "caisse": caisse,
            "presence": presence,
            "actif": estActif,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _membres = membresFormates;
            _epargneTotaleGroupe = totalEpargne;
            _membresActifs = actifs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur de chargement du tableau (${response.statusCode})")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${'error_loading_table'.tr()} : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF1A529B);

    return Scaffold(
      appBar: AppBar(
        title: Text('members_status'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recupererDonneesGroupe,
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.analytics, color: primaryColor, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '${'group_table'.tr()} #${widget.groupId}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                            columns: [
                              DataColumn(label: Text('lastname'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('firstname'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('total_savings'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('social_fund'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('presence'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _membres.map((membre) {
                              return DataRow(cells: [
                                DataCell(Text(membre['nom'].toString())),
                                DataCell(Text(membre['prenom'].toString())),
                                DataCell(Text('${membre['epargne']} BIF')),
                                DataCell(Text('${membre['caisse']} BIF')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: membre['presence'] == 'P' ? Colors.green[100] : Colors.red[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      membre['presence'],
                                      style: TextStyle(
                                        color: membre['presence'] == 'P' ? Colors.green[800] : Colors.red[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          'group_total_savings'.tr(),
                          "$_epargneTotaleGroupe BIF",
                          Icons.monetization_on,
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          'active_members'.tr(),
                          "$_membresActifs",
                          Icons.person_outline,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}