import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class GestionPenalitesScreen extends StatefulWidget {
  final int membreId;
  final int? groupId; // Ajout du paramètre

  const GestionPenalitesScreen({
    super.key,
    required this.membreId,
    this.groupId,
  });

  @override
  State<GestionPenalitesScreen> createState() => _GestionPenalitesScreenState();
}

class _GestionPenalitesScreenState extends State<GestionPenalitesScreen> {
  final Color primaryColor = const Color(0xFF1A529B);
  bool _isLoading = false;

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
      // Passer le groupId à l'API
      final data = await ApiService.getCreditsEnRetard(groupId: widget.groupId);
      if (mounted) {
        setState(() {
          _creditsEnRetard = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('load_error'.tr())),
        );
      }
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

      if (success && mounted) {
        _chargerCreditsEnRetard();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('penalty_success'.tr()), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('apply_error'.tr()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _ouvrirDialoguePenalite(Map<String, dynamic> credit) {
    final valeurController = TextEditingController(text: "5");
    final moisController = TextEditingController(text: (credit['mois_retard'] ?? 1).toString());
    final nomMembre = credit['nom'] ?? 'member'.tr();
    bool estPourcentage = true; // Par défaut en %

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('${'penalize'.tr()} $nomMembre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sélecteur du type de saisie (Pourcentage ou Montant fixe)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text("Taux (%)"),
                    selected: estPourcentage,
                    onSelected: (val) => setStateDialog(() => estPourcentage = true),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("Montant (FBU)"),
                    selected: !estPourcentage,
                    onSelected: (val) => setStateDialog(() => estPourcentage = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valeurController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: estPourcentage ? 'penalty_rate'.tr() : 'Montant de la pénalité (FBU)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: moisController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'number_of_months'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () {
                double valeurSaisie = double.tryParse(valeurController.text) ?? 0.0;
                int mois = int.tryParse(moisController.text) ?? 1;

                Navigator.pop(context);

                // Si l'utilisateur choisit un montant fixe, on bascule la valeur en négatif pour l'interprétation backend
                double tauxFinal = estPourcentage ? valeurSaisie : -valeurSaisie;

                _appliquerPenaliteBase(credit['id'], tauxFinal, mois);
              },
              child: Text('apply'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formaterMontant(double montant) {
    final format = NumberFormat('#,##0', context.locale.languageCode);
    return format.format(montant).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('penalties_management'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : _creditsEnRetard.isEmpty
            ? Center(child: Text('no_data'.tr(), style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _creditsEnRetard.length,
                itemBuilder: (context, index) {
                  final credit = _creditsEnRetard[index];
                  double resteAPayer = (credit['reste_a_payer'] ?? 0.0).toDouble();

                  return Card(
                    elevation: 0.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      title: Text(credit['nom'] ?? 'unknown'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${'remaining'.tr()}: ${_formaterMontant(resteAPayer)} FBU',
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: () => _ouvrirDialoguePenalite(credit),
                        child: Text('sanction'.tr(), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}