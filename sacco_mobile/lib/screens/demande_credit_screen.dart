import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // Importation easy_localization
import '../services/api_service.dart';

class DemandeCreditScreen extends StatefulWidget {
  final int membreId;

  const DemandeCreditScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<DemandeCreditScreen> createState() => _DemandeCreditScreenState();
}

class _DemandeCreditScreenState extends State<DemandeCreditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _motifController = TextEditingController();

  String _typeCredit = 'Standard';
  double _tauxInteret = 5.0; // Taux par défaut, sera écrasé par celui de l'admin
  bool _isLoading = false;
  bool _isLoadingTaux = true; // Pour charger le taux au démarrage
  final Color primaryColor = const Color(0xFF1A529B);

  final int dureeMois = 3;

  @override
  void initState() {
    super.initState();
    _chargerTauxAttribue();
  }

  // Charge le taux d'intérêt spécifique fixé par l'administration pour ce membre
  void _chargerTauxAttribue() async {
    try {
      final data = await ApiService.getPortefeuille(widget.membreId);
      if (data != null && mounted) {
        setState(() {
          _tauxInteret = (data['taux_interet_applique'] ?? 5.0).toDouble();
          _isLoadingTaux = false;
        });
      }
    } catch (e) {
      print("Erreur lors de la récupération du taux admin : $e");
      if (mounted) setState(() => _isLoadingTaux = false);
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  void _soumettreDemande() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      int montant = int.parse(_montantController.text.trim());
      String motif = _motifController.text.trim();
      bool success = false;

      try {
        if (_typeCredit == 'Standard') {
          success = await ApiService.demanderCredit(
            membreId: widget.membreId,
            montant: montant,
            motif: motif,
            tauxInteretApplique: _tauxInteret,
          );
        } else {
          success = await ApiService.demanderPretSocial(
            membreId: widget.membreId,
            montant: montant,
            motif: motif,
          );
        }

        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            _afficherMessage("loan_success_msg".tr(), Colors.green);

            _montantController.clear();
            _motifController.clear();

            Navigator.pop(context, true);
          } else {
            _afficherMessage("loan_fail_msg".tr(), Colors.red);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _afficherMessage("${"network_error_msg".tr()}$e", Colors.red);
        }
      }
    }
  }

  void _afficherMessage(String message, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur, duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildSimulationCard() {
    double montant = double.tryParse(_montantController.text) ?? 0.0;
    double taux = _typeCredit == 'Standard' ? (_tauxInteret / 100) : 0.0;
    double interets = montant * taux;
    double totalARembourser = montant + interets;
    double mensualite = totalARembourser / dureeMois;

    return Card(
      color: primaryColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('repayment_simulation'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _buildSimulationRow('requested_amount'.tr(), '$montant FBU'),
            _buildSimulationRow('${"interests".tr()} (${_typeCredit == 'Social' ? 0 : _tauxInteret}\%) :', '${interets.toStringAsFixed(0)} FBU'),
            _buildSimulationRow('duration'.tr(), '$dureeMois mois'),
            const Divider(),
            _buildSimulationRow('total_to_repay'.tr(), '${totalARembourser.toStringAsFixed(0)} FBU', isBold: true, color: primaryColor),
            const SizedBox(height: 8),
            _buildSimulationRow('estimated_monthly_payment'.tr(), '${mensualite.toStringAsFixed(0)} FBU / mois', isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('new_loan_request'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingTaux
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _typeCredit,
                      decoration: InputDecoration(labelText: 'credit_type'.tr(), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.category)),
                      items: ['Standard', 'Social'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value == 'Standard' ? 'credit_standard'.tr() : 'social_loan'.tr()),
                        );
                      }).toList(),
                      onChanged: (newValue) => setState(() => _typeCredit = newValue!),
                    ),
                    const SizedBox(height: 20),

                    if (_typeCredit == 'Standard') ...[
                      TextFormField(
                        key: ValueKey(_tauxInteret),
                        initialValue: '$_tauxInteret %',
                        readOnly: true,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        decoration: InputDecoration(
                          labelText: 'applied_interest_rate'.tr(),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.percent),
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    TextFormField(
                      controller: _montantController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'desired_amount'.tr(), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.attach_money)),
                      onChanged: (val) => setState(() {}),
                      validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? 'valid_amount_error'.tr() : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _motifController,
                      decoration: InputDecoration(labelText: 'loan_reason'.tr(), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.edit)),
                      validator: (value) => (value == null || value.isEmpty) ? 'reason_error'.tr() : null,
                    ),
                    const SizedBox(height: 24),

                    _buildSimulationCard(),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                        onPressed: _isLoading ? null : _soumettreDemande,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('send_request'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}