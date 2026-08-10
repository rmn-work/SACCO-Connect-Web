import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class GestionPenalitesScreen extends StatefulWidget {
  final int membreId;
  const GestionPenalitesScreen({super.key, required this.membreId});

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
      final data = await ApiService.getCreditsEnRetard();
      setState(() {
        _creditsEnRetard = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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
    final tauxController = TextEditingController(text: "5");
    final moisController = TextEditingController(text: credit['mois_retard'].toString());
    final nomMembre = credit['nom'] ?? 'member'.tr();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${'penalize'.tr()} $nomMembre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tauxController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'penalty_rate'.tr(), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: moisController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'number_of_months'.tr(), border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              double taux = double.tryParse(tauxController.text) ?? 0.0;
              int mois = int.tryParse(moisController.text) ?? 1;
              Navigator.pop(context);
              _appliquerPenaliteBase(credit['id'], taux, mois);
            },
            child: Text('apply'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
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