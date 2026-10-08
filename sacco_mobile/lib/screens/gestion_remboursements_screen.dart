import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class GestionRemboursementsScreen extends StatefulWidget {
  final int adminId;

  const GestionRemboursementsScreen({super.key, required this.adminId});

  @override
  State<GestionRemboursementsScreen> createState() => _GestionRemboursementsScreenState();
}

class _GestionRemboursementsScreenState extends State<GestionRemboursementsScreen> {
  final Color primaryColor = const Color(0xFF1A529B);
  bool _isLoading = true;
  List<Map<String, dynamic>> _creditsActifs = [];

  @override
  void initState() {
    super.initState();
    _chargerCreditsActifs();
  }

  Future<void> _chargerCreditsActifs() async {
    try {
      // Si getCreditsActifs nécessite un ID de membre, assurez-vous de l'adapter.
      // Si c'est pour tous les crédits actifs de l'administration, passez l'argument requis par votre service.
      final data = await ApiService.getCreditsActifs(widget.adminId);
      if (mounted) {
        setState(() {
          _creditsActifs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _ouvrirDialogueRemboursement(Map<String, dynamic> credit) {
    final TextEditingController montantController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('repay_loan'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${'member'.tr()} : ${credit['nom_membre']}"),
            Text("${'remaining_amount'.tr()} : ${credit['montant_restant']} BIF"),
            const SizedBox(height: 16),
            TextField(
              controller: montantController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'amount_to_pay'.tr(),
                border: const OutlineInputBorder(),
                suffixText: 'BIF',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              final montant = double.tryParse(montantController.text) ?? 0.0;
              if (montant <= 0) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              // Appel unique avec le nouveau type ApiResponse
              ApiResponse response = await ApiService.enregistrerRemboursement(
                creditId: credit['id'],
                montant: montant,
                reference: "REF-${DateTime.now().millisecondsSinceEpoch}",
                adminId: widget.adminId,
              );

              if (response.success) {
                _chargerCreditsActifs();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response.message.isNotEmpty ? response.message : 'repayment_success'.tr()),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response.message.isNotEmpty ? response.message : 'repayment_error'.tr()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('validate'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('loan_repayment_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _creditsActifs.isEmpty
              ? Center(child: Text('no_active_loans'.tr(), style: const TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _creditsActifs.length,
                  itemBuilder: (context, index) {
                    final credit = _creditsActifs[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(credit['nom_membre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text("${'initial_loan'.tr()} : ${credit['montant_total']} BIF", style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text("${'remaining_due'.tr()} : ${credit['montant_restant']} BIF", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              onPressed: () => _ouvrirDialogueRemboursement(credit),
                              child: Text('repay'.tr()),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}