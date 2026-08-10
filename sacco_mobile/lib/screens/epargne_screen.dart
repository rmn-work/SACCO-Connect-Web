import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class EpargneScreen extends StatefulWidget {
  final int membreId;

  const EpargneScreen({super.key, required this.membreId});

  @override
  State<EpargneScreen> createState() => _EpargneScreenState();
}

class _EpargneScreenState extends State<EpargneScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _donneesEpargne;
  final Color primaryColor = const Color(0xFF1A529B);

  @override
  void initState() {
    super.initState();
    _chargerDetailsEpargne();
  }

  Future<void> _chargerDetailsEpargne() async {
    try {
      final data = await ApiService.getPortefeuille(widget.membreId);
      if (mounted) {
        setState(() {
          _donneesEpargne = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint("Erreur de chargement: $e");
    }
  }

  // Fonction utilitaire pour formater les nombres avec des espaces
  String _formaterMontant(double montant) {
    final format = NumberFormat('#,##0', context.locale.languageCode);
    return format.format(montant).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('savings_details_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _chargerDetailsEpargne,
              color: primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Carte Solde Principal ---
                  _buildBalanceCard(
                    titre: 'main_savings_balance'.tr(),
                    montant: _donneesEpargne?['solde_epargne']?.toDouble() ?? 0.0,
                    couleur: primaryColor,
                    icone: Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 16),

                  // --- Carte Caisse Sociale ---
                  _buildBalanceCard(
                    titre: 'social_fund'.tr(),
                    montant: _donneesEpargne?['caisse_sociale']?.toDouble() ?? 0.0,
                    couleur: Colors.blueAccent,
                    icone: Icons.volunteer_activism,
                  ),
                  const SizedBox(height: 32),

                  // --- Section Historique ---
                  Text(
                    'latest_transactions'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  _buildTransactionTile('weekly_deposit'.tr(), '+ ${_formaterMontant(5000.0)} FBU', '08 Juin 2026', Colors.green),
                  _buildTransactionTile('social_contribution'.tr(), '+ ${_formaterMontant(500.0)} FBU', '08 Juin 2026', Colors.blue),
                  _buildTransactionTile('savings_withdrawal'.tr(), '- ${_formaterMontant(15000.0)} FBU', '25 Mai 2026', Colors.red),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard({required String titre, required double montant, required Color couleur, required IconData icone}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: couleur.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icone, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  'amount_fbu'.tr(namedArgs: {'montant': _formaterMontant(montant)}),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(String titre, String montant, String date, Color colorMontant) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorMontant.withValues(alpha: 0.1),
          child: Icon(
            montant.startsWith('+') ? Icons.arrow_downward : Icons.arrow_upward,
            color: colorMontant,
            size: 20,
          ),
        ),
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date, style: const TextStyle(fontSize: 12)),
        trailing: Text(montant, style: TextStyle(color: colorMontant, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}