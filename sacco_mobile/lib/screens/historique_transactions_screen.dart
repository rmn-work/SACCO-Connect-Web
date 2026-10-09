import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class HistoriqueTransactionsScreen extends StatefulWidget {
  final int membreId;

  const HistoriqueTransactionsScreen({super.key, required this.membreId});

  @override
  State<HistoriqueTransactionsScreen> createState() => _HistoriqueTransactionsScreenState();
}

class _HistoriqueTransactionsScreenState extends State<HistoriqueTransactionsScreen> {
  final Color primaryColor = const Color(0xFF1A529B);
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _chargerTransactions();
  }

  Future<void> _chargerTransactions() async {
    try {
      final data = await ApiService.getHistoriqueMembre(widget.membreId);
      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${'error_loading_history'.tr()} : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('transaction_history'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('no_transactions_found'.tr(), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final type = tx['type'] ?? tx['libelle'] ?? 'COTISATION';

                    final dynamic rawMontant = tx['montant'] ?? tx['valeur'] ?? tx['amount'] ?? tx['montant_verse'] ?? 0;
                    final montant = num.tryParse(rawMontant.toString()) ?? 0;

                    final date = tx['date'] ?? tx['created_at'] ?? tx['date_creation'] ?? 'N/A';
                    final statut = tx['statut'] ?? tx['status'] ?? 'VALIDE';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getIconColor(type.toString()).withValues(alpha: 0.15),
                          child: Icon(_getIconData(type.toString()), color: _getIconColor(type.toString())),
                        ),
                        title: Text(type.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(date.toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "$montant BIF",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statut.toString().toUpperCase() == 'VALIDE' ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statut.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statut.toString().toUpperCase() == 'VALIDE' ? Colors.green.shade800 : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getIconColor(String type) {
    switch (type.toUpperCase()) {
      case 'CREDIT':
        return Colors.orange;
      case 'SOCIAL':
        return Colors.blue;
      case 'REMBOURSEMENT':
        return Colors.teal;
      default:
        return Colors.green;
    }
  }

  IconData _getIconData(String type) {
    switch (type.toUpperCase()) {
      case 'CREDIT':
        return Icons.trending_up;
      case 'SOCIAL':
        return Icons.volunteer_activism;
      case 'REMBOURSEMENT':
        return Icons.assignment_returned;
      default:
        return Icons.savings;
    }
  }
}