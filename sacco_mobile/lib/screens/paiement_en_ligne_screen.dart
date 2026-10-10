import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PaiementEnLigneScreen extends StatefulWidget {
  final int membreId;
  const PaiementEnLigneScreen({super.key, required this.membreId});

  @override
  State<PaiementEnLigneScreen> createState() => _PaiementEnLigneScreenState();
}

class _PaiementEnLigneScreenState extends State<PaiementEnLigneScreen> {
  final Color primaryColor = const Color(0xFF1A56A3);
  final _formKey = GlobalKey<FormState>();

  String _selectedProvider = 'LUMICASH';
  String _selectedTypeOp = 'EPARGNE';
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _montantController = TextEditingController();
  bool _isProcessing = false;

  final Map<String, Map<String, dynamic>> _providers = {
    'LUMICASH': {
      'name': 'LumiCash',
      'color': Colors.red.shade700,
      'icon': Icons.phone_android,
      'hint': 'Numéro Lumitel (ex: 61XXXXXX)'
    },
    'ECOCASH': {
      'name': 'EcoCash',
      'color': Colors.blue.shade800,
      'icon': Icons.account_balance_wallet,
      'hint': 'Numéro Econet (ex: 79XXXXXX)'
    },
    'E_INOTI': {
      'name': 'e-Inoti (Bancobu)',
      'color': Colors.teal.shade700,
      'icon': Icons.account_balance,
      'hint': 'Identifiant / N° e-Inoti'
    },
  };

  Future<void> _effectuerPaiement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    double montant = double.tryParse(_montantController.text.trim()) ?? 0.0;

    final result = await ApiService.initierPaiementEnLigne(
      membreId: widget.membreId,
      provider: _selectedProvider,
      phoneNumber: _phoneController.text.trim(),
      montant: montant,
      typeOperation: _selectedTypeOp,
    );

    if (mounted) {
      setState(() => _isProcessing = false);

      if (result['success'] == true) {
        _montantController.clear();
        _phoneController.clear();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text("Paiement Réussi"),
              ],
            ),
            content: Text(result['message'] ?? "Operation effectuée."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Retour au dashboard
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Échec de la transaction"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paiement en Ligne", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Choisissez le mode de paiement",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Sélection du provider
              Row(
                children: _providers.entries.map((entry) {
                  bool isSelected = _selectedProvider == entry.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedProvider = entry.key),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? entry.value['color'] : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? entry.value['color'] : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              entry.value['icon'],
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.value['name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Type d'opération
              DropdownButtonFormField<String>(
                value: _selectedTypeOp,
                decoration: const InputDecoration(
                  labelText: "Type de versement",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'EPARGNE', child: Text("Dépôt Épargne")),
                  DropdownMenuItem(value: 'REMBOURSEMENT', child: Text("Remboursement de Prêt")),
                  DropdownMenuItem(value: 'COTISATION', child: Text("Cotisation Caisse Sociale")),
                ],
                onChanged: (val) => setState(() => _selectedTypeOp = val!),
              ),

              const SizedBox(height: 16),

              // Numéro de téléphone / Compte
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: _providers[_selectedProvider]!['hint'],
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Champ requis" : null,
              ),

              const SizedBox(height: 16),

              // Montant
              TextFormField(
                controller: _montantController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Montant (BIF)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Saisissez un montant";
                  if ((double.tryParse(val) ?? 0) <= 0) return "Montant invalide";
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _effectuerPaiement,
                        icon: const Icon(Icons.payment),
                        label: Text("Payer via ${_providers[_selectedProvider]!['name']}"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _providers[_selectedProvider]!['color'],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}