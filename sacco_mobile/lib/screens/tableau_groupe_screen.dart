import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TableauGroupeScreen extends StatefulWidget {
  final int groupId;

  const TableauGroupeScreen({Key? key, required this.groupId}) : super(key: key);

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
    try {
      // Simulation d'attente réseau
      await Future.delayed(const Duration(milliseconds: 800));

      final dataMock = [
        {"nom": "NKURUNZIZA", "prenom": "Raphael", "epargne": 0, "caisse": 0, "presence": "A", "actif": 1},
        {"nom": "PRESIDENT", "prenom": "Officiel", "epargne": 0, "caisse": 0, "presence": "A", "actif": 1},
        {"nom": "SECRETAIRE", "prenom": "Officiel", "epargne": 0, "caisse": 0, "presence": "A", "actif": 1},
      ];

      double total = 0;
      int actifs = 0;
      for (var m in dataMock) {
        // CORRECTION : Conversion explicite en num puis double, et gestion des valeurs nulles
        final epargneValeur = m['epargne'] as num? ?? 0;
        total += epargneValeur.toDouble();

        if (m['actif'] == 1) {
          actifs++;
        }
      }

      setState(() {
        _membres = dataMock;
        _epargneTotaleGroupe = total;
        _membresActifs = actifs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors du chargement du tableau : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF1A529B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('État des Membres', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _recupererDonneesGroupe();
            },
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
                          'Tableau du Groupe #${widget.groupId}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- Tableau des membres ---
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                            columns: const [
                              DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Prénom', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Épargne Totale', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Caisse Sociale', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Présence', style: TextStyle(fontWeight: FontWeight.bold))),
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

                  // --- Zone des deux KPI Cards du bas ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          "Épargne Totale Groupe",
                          "$_epargneTotaleGroupe BIF",
                          Icons.monetization_on,
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          "Membres Actifs",
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