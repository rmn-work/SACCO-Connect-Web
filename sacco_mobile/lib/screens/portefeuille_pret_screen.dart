import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class PortefeuillePretScreen extends StatefulWidget {
  final int membreId;

  const PortefeuillePretScreen({super.key, required this.membreId});

  @override
  State<PortefeuillePretScreen> createState() => _PortefeuillePretScreenState();
}

class _PortefeuillePretScreenState extends State<PortefeuillePretScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _accountData;
  List<dynamic> _mesDemandes = [];
  List<dynamic> _historiqueEpargne = [];

  final _formSocialKey = GlobalKey<FormState>();
  final _formCreditKey = GlobalKey<FormState>();
  final _montantSocialController = TextEditingController();
  final _motifSocialController = TextEditingController();
  final _montantCreditController = TextEditingController();
  final _motifCreditController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  void _chargerDonnees() async {
    try {
      final data = await ApiService.getPortefeuille(widget.membreId);
      final demandes = await ApiService.getMesDemandesPrets(widget.membreId);
      final historique = await ApiService.getHistoriqueEpargne(widget.membreId);

      if (mounted) {
        setState(() {
          _accountData = data;
          _mesDemandes = demandes;
          _historiqueEpargne = historique;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- MÉTHODE POUR SÉLECTIONNER ET UPLOADER LE REÇU ---
  Future<void> _associerRecu() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        setState(() => _isUploading = true);

        // Appel à la méthode d'upload dans ApiService
        bool success = await ApiService.uploadRecu(
          membreId: widget.membreId,
          filePath: filePath,
          fileName: fileName,
        );

        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? "Reçu uploadé avec succès !" : "Échec de l'upload du reçu"),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          if (success) _chargerDonnees();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la sélection du fichier"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: const Color(0xFF009688)),
        ),
      );
    }
    final Map<String, dynamic> user = Map<String, dynamic>.from(_accountData ?? {});
    final num soldeEpargne = user['solde_epargne'] ?? 0;
    final double maxLoan = (soldeEpargne * 3).toDouble();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("space_responsible".tr()),
          backgroundColor: const Color(0xFF009688),
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: const Icon(Icons.account_balance_wallet), text: "tab_portefeuille".tr()),
              Tab(icon: const Icon(Icons.monetization_on), text: "tab_credit".tr()),
              Tab(icon: const Icon(Icons.history), text: "tab_historique".tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMonPortefeuilleTab(user, context),
            _buildDemandeCreditTab(user, maxLoan),
            _buildHistoriqueTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonPortefeuilleTab(Map<String, dynamic> user, BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard("total_savings".tr(), "${user['solde_epargne'] ?? 0} BIF", Colors.teal),
              _buildMetricCard("loan_to_repay".tr(), "${user['solde_pret'] ?? 0} BIF", Colors.red),
              _buildMetricCard("status_presence".tr(), "${user['status_presence'] ?? '-'}", Colors.blue),
              _buildMetricCard("fixed_contribution".tr(), "5,000 BIF", Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          Text("solidarity_social_loans".tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5FE),
              borderRadius: BorderRadius.circular(10),
              border: const Border(left: BorderSide(color: Color(0xFF03A9F4), width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("my_social_fund".tr(), style: const TextStyle(color: Color(0xFF01579B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("${user['caisse_sociale'] ?? 0} BIF", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("community_mutual_aid_fund".tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                left: BorderSide(color: Color(0xFF8BC34A), width: 5),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                title: Text("social_loan_request".tr()),
                subtitle: Text("urgent_boost_need".tr()),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF8BC34A)),
                onTap: () {
                  _afficherFormulairePretSocial(context);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text("credit_tracking".tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildCreditRow("ongoing_credit".tr(), "${user['credit_en_cours'] ?? 0} BIF", Colors.black87),
          _buildCreditRow("already_repaid".tr(), "${user['credit_rembourse'] ?? 0} BIF", Colors.green),
          _buildCreditRow("remaining_to_pay".tr(), "${user['credit_restant'] ?? 0} BIF", Colors.orange.shade800),

          const SizedBox(height: 24),
          const Divider(),
          Text("my_documents".tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _isUploading
              ? const Center(child: CircularProgressIndicator())
              : OutlinedButton.icon(
                  onPressed: _associerRecu,
                  icon: const Icon(Icons.upload_file),
                  label: Text("associate_bank_receipt".tr()),
                ),
        ],
      ),
    );
  }

  void _afficherFormulairePretSocial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Form(
            key: _formSocialKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.health_and_safety, color: Color(0xFF8BC34A)),
                    const SizedBox(width: 8),
                    Text("new_social_loan".tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montantSocialController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "desired_amount".tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.money),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return "enter_amount".tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motifSocialController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "reason_social".tr(),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? "specify_reason".tr() : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8BC34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _soumettrePretSocial();
                    },
                    child: Text("submit_request".tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDemandeCreditTab(Map<String, dynamic> user, double maxLoan) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber)),
            child: Text(
              "${"loan_ceiling".tr()}\n${maxLoan.toStringAsFixed(0)} BIF",
              style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          Form(
            key: _formCreditKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _montantCreditController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "desired_amount".tr(), border: const OutlineInputBorder()),
                  validator: (val) {
                    if (val == null || val.isEmpty) return "enter_amount".tr();
                    double? parsed = double.tryParse(val);
                    if (parsed == null || parsed > maxLoan) return "exceeds_authorized_ceiling".tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motifCreditController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: "detailed_credit_reason".tr(), border: const OutlineInputBorder()),
                  validator: (val) => val == null || val.isEmpty ? "specify_reason".tr() : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009688), foregroundColor: Colors.white),
                    onPressed: _soumettreDemandeCredit,
                    child: Text("send_request".tr(), style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Divider(),

          Text("state_of_my_requests".tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _mesDemandes.isEmpty
              ? Text("no_ongoing_loan_request".tr(), style: const TextStyle(color: Colors.grey))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mesDemandes.length,
                  itemBuilder: (context, index) {
                    final d = _mesDemandes[index];
                    return Card(
                      child: ListTile(
                        title: Text("${d['montant']} BIF", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${"requested_on".tr()}${d['date_demande'] ?? ''}"),
                        trailing: _buildStatusBadge(d['status'] ?? ''),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildHistoriqueTab() {
    if (_historiqueEpargne.isEmpty) {
      return Center(child: Text("no_history_available".tr()));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historiqueEpargne.length,
      itemBuilder: (context, index) {
        final item = _historiqueEpargne[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history, color: Colors.teal),
            title: Text("${item['montant']} BIF", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${"date_label".tr()}${item['date_reunion'] ?? ''}"),
            trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCreditRow(String title, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor = Colors.orange;
    if (status == 'APPROUVÉ') badgeColor = Colors.green;
    if (status == 'REJETÉ') badgeColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Text(status, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  void _soumettrePretSocial() async {
    if (_formSocialKey.currentState!.validate()) {
      bool success = await ApiService.demanderPretSocial(
        membreId: widget.membreId,
        montant: int.parse(_montantSocialController.text),
        motif: _motifSocialController.text,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("social_request_sent".tr())));
        _montantSocialController.clear();
        _motifSocialController.clear();
        _chargerDonnees();
      }
    }
  }

  void _soumettreDemandeCredit() async {
    String rawMontant = _montantCreditController.text.replaceAll(' ', '');
    double parsedMontant = double.tryParse(rawMontant) ?? 0.0;

    if (parsedMontant <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("enter_valid_amount".tr())),
        );
      }
      return;
    }

    if (_formCreditKey.currentState!.validate()) {
      bool success = await ApiService.demanderCredit(
        membreId: widget.membreId,
        montant: parsedMontant.toInt(),
        motif: _motifCreditController.text,
        tauxInteretApplique: 0.0,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("credit_request_sent".tr())),
        );
        _montantCreditController.clear();
        _motifCreditController.clear();
        _chargerDonnees();
      }
    }
  }
}