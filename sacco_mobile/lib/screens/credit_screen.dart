import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'demande_credit_screen.dart';

class CreditScreen extends StatefulWidget {
  final int membreId;

  const CreditScreen({super.key, required this.membreId});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _donneesCredit;
  final Color primaryColor = const Color(0xFF1A529B);

  @override
  void initState() {
    super.initState();
    _chargerDetailsCredit();
  }

  Future<void> _chargerDetailsCredit() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final data = await ApiService.getPortefeuille(widget.membreId);
      if (mounted) {
        setState(() {
          _donneesCredit = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      debugPrint("Erreur crédit: $e");
    }
  }

  String _formaterMontant(double montant) {
    final format = NumberFormat('#,##0', context.locale.languageCode);
    return format.format(montant).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    double encours = _donneesCredit?['credit_en_cours']?.toDouble() ?? 0.0;
    double restant = _donneesCredit?['credit_restant']?.toDouble() ?? 0.0;
    double pretSocial = _donneesCredit?['solde_pret_social']?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('credit_space_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(encours, restant, pretSocial),
    );
  }

  Widget _buildBody(double encours, double restant, double pretSocial) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'network_error'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _chargerDetailsCredit,
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              )
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerDetailsCredit,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatCard(
            'ongoing_credit'.tr(),
            'ongoing_credit_value'.tr(namedArgs: {'montant': _formaterMontant(encours)}),
            Colors.redAccent,
            Icons.money_off
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'remaining_to_pay'.tr(),
            'remaining_to_pay_value'.tr(namedArgs: {'montant': _formaterMontant(restant)}),
            Colors.orange,
            Icons.hourglass_empty
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'active_social_loan'.tr(),
            'active_social_loan_value'.tr(namedArgs: {'montant': _formaterMontant(pretSocial)}),
            Colors.blue,
            Icons.handshake
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: Text('new_credit_request'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DemandeCreditScreen(membreId: widget.membreId),
                  ),
                );
                if (result == true) {
                  _chargerDetailsCredit(); // Actualise si une demande a été soumise
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}