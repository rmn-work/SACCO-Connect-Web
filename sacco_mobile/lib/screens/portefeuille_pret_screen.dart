import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class PortefeuillePretScreen extends StatefulWidget {
  final int membreId;

  const PortefeuillePretScreen({super.key, required this.membreId});

  @override
  State<PortefeuillePretScreen> createState() => _PortefeuillePretScreenState();
}

class _PortefeuillePretScreenState extends State<PortefeuillePretScreen> {
  bool _isLoading = true;
  bool _voirToutesLesDemandes = false; // Variable d'état pour filtrer ou afficher toutes les demandes
  Map<String, dynamic>? _accountData;
  List<dynamic> _mesDemandes = [];
  List<dynamic> _historiqueEpargne = [];

  final _formSocialKey = GlobalKey<FormState>();
  final _formCreditKey = GlobalKey<FormState>();
  final _montantSocialController = TextEditingController();
  final _motifSocialController = TextEditingController();
  final _montantCreditController = TextEditingController();
  final _motifCreditController = TextEditingController();

  final Color primaryColor = const Color(0xFF1A529B);

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

  void _soumettrePretSocial() async {
    if (_formSocialKey.currentState!.validate()) {
      int montant = int.parse(_montantSocialController.text.trim());
      String motif = _motifSocialController.text.trim();

      bool success = await ApiService.demanderPretSocial(
        membreId: widget.membreId,
        montant: montant,
        motif: motif,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Demande de prêt social envoyée !" : "Échec de la demande"),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _montantSocialController.clear();
          _motifSocialController.clear();
          _chargerDonnees();
        }
      }
    }
  }

  void _soumettreDemandeCredit() async {
    if (_formCreditKey.currentState!.validate()) {
      int montant = int.parse(_montantCreditController.text.trim());
      String motif = _motifCreditController.text.trim();

      bool success = await ApiService.demanderCredit(
        membreId: widget.membreId,
        montant: montant,
        motif: motif,
        tauxInteretApplique: 5.0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Demande de crédit envoyée !" : "Échec de l'envoi"),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _montantCreditController.clear();
          _motifCreditController.clear();
          _chargerDonnees();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }
    final Map<String, dynamic> user = Map<String, dynamic>.from(_accountData ?? {});
    final num soldeEpargne = user['solde_epargne'] ?? 0;
    final double maxLoan = (soldeEpargne * 3).toDouble();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("space_responsible".tr()),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: const Icon(Icons.monetization_on), text: "tab_credit".tr()),
              Tab(icon: const Icon(Icons.history), text: "tab_historique".tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDemandeCreditTab(user, maxLoan),
            _buildHistoriqueTab(),
          ],
        ),
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
    return RefreshIndicator(
      onRefresh: () async => _chargerDonnees(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                      onPressed: _soumettreDemandeCredit,
                      child: Text("send_request".tr(), style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),

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

            const Text("État de mes demandes de crédit et social", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _mesDemandes.isEmpty
                ? Text("no_ongoing_loan_request".tr(), style: const TextStyle(color: Colors.grey))
                : Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _voirToutesLesDemandes
                            ? _mesDemandes.length
                            : (_mesDemandes.length > 5 ? 5 : _mesDemandes.length),
                        itemBuilder: (context, index) {
                          final d = _mesDemandes[index];

                          // Gestion robuste de la date pour ne plus l'avoir vide
                          final rawDate = d['date_demande'] ?? d['created_at'] ?? d['date'] ?? '';
                          String formattedDate = rawDate;
                          if (rawDate.toString().isNotEmpty) {
                            try {
                              final parsedDate = DateTime.parse(rawDate);
                              formattedDate = "${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}";
                            } catch (_) {
                              formattedDate = rawDate.toString();
                            }
                          }

                          return Card(
                            child: ListTile(
                              title: Text("${d['montant'] ?? d['montant_demande'] ?? 0} BIF", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("${"requested_on".tr()} $formattedDate\nMotif : ${d['motif'] ?? 'N/A'}"),
                              isThreeLine: true,
                              trailing: _buildStatusBadge(d['status'] ?? d['statut'] ?? ''),
                            ),
                          );
                        },
                      ),
                      if (_mesDemandes.length > 5) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _voirToutesLesDemandes = !_voirToutesLesDemandes;
                            });
                          },
                          child: Text(_voirToutesLesDemandes ? "Voir moins" : "Voir toutes les anciennes demandes (${_mesDemandes.length})"),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoriqueTab() {
    if (_historiqueEpargne.isEmpty) {
      return Center(child: Text("no_history_available".tr()));
    }

    return RefreshIndicator(
      onRefresh: () async => _chargerDonnees(),
      child: ListView.builder(
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
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    String upperStatus = status.toUpperCase();

    if (upperStatus == 'VALIDE' || upperStatus == 'APPROUVE' || upperStatus == 'APPROUVÉ') {
      color = Colors.green;
    } else if (upperStatus == 'REFUSE' || upperStatus == 'REJETE' || upperStatus == 'REJETÉ') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.isEmpty ? 'EN ATTENTE' : status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}