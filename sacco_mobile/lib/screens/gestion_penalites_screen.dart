import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Assure-toi que le chemin est correct

class GestionPenalitesScreen extends StatefulWidget {
  final int membreId;
  const GestionPenalitesScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<GestionPenalitesScreen> createState() => _GestionPenalitesScreenState();
}

class _GestionPenalitesScreenState extends State<GestionPenalitesScreen> {
  final Color primaryColor = const Color(0xFF1A529B);
  bool _isLoading = false;

  // Remplacer par l'ID de l'admin connecté dans ton application
  final int _adminId = 1;

  List<Map<String, dynamic>> _creditsEnRetard = [];

  @override
  void initState() {
    super.initState();
    _chargerCreditsEnRetard();
  }

  Future<void> _chargerCreditsEnRetard() async {
    setState(() => _isLoading = true);
    try {
      // Appel à ton API FastAPI pour récupérer les crédits en retard
      final data = await ApiService.getCreditsEnRetard();
      setState(() {
        _creditsEnRetard = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de chargement')));
    }
  }

  void _appliquerPenaliteBase(int creditId, double taux, int moisRetard) async {
    setState(() => _isLoading = true);

    try {
      bool success = await ApiService.appliquerPenalite(
        creditId,
        taux,
        _adminId,
        moisRetard,
      );

      if (success) {
        _chargerCreditsEnRetard(); // Recharger la liste
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pénalité appliquée avec succès !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'application'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _ouvrirDialoguePenalite(Map<String, dynamic> credit) {
    final tauxController = TextEditingController(text: "5");
    final moisController = TextEditingController(text: credit['mois_retard'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pénaliser ${credit['nom'] ?? 'Membre'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tauxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Taux pénalité (%)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: moisController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de mois', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              double taux = double.tryParse(tauxController.text) ?? 0.0;
              int mois = int.tryParse(moisController.text) ?? 1;
              Navigator.pop(context);
              _appliquerPenaliteBase(credit['id'], taux, mois);
            },
            child: const Text('Appliquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Pénalités', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _creditsEnRetard.length,
            itemBuilder: (context, index) {
              final credit = _creditsEnRetard[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: Text(credit['nom'] ?? 'Inconnu'),
                  subtitle: Text('Reste: ${credit['reste_a_payer']} FBU'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                    onPressed: () => _ouvrirDialoguePenalite(credit),
                    child: const Text('Sanctionner', style: TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          ),
    );
  }
}