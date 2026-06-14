import 'package:flutter/material.dart';
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
          // On récupère le taux configuré par le secrétaire/président (ex: 'taux_interet_applique')
          // Ajustez la clé selon votre réponse API exacte du portefeuille
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
        // AIGUILLAGE API : On appelle la bonne méthode selon le type de crédit
        if (_typeCredit == 'Standard') {
          success = await ApiService.demanderCredit(
            membreId: widget.membreId,
            montant: montant,
            motif: motif,
            tauxInteretApplique: _tauxInteret, // Taux fixé par l'admin transmis
          );
        } else {
          // Prêt Social
          success = await ApiService.demanderPretSocial(
            membreId: widget.membreId,
            montant: montant,
            motif: motif,
          );
        }

        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            _afficherMessage("✅ Votre demande de crédit a été envoyée avec succès !", Colors.green);

            _montantController.clear();
            _motifController.clear();

            // On retourne "true" pour dire à l'écran précédent de rafraîchir l'historique
            Navigator.pop(context, true);
          } else {
            _afficherMessage("❌ Échec de l'envoi de la demande. Réessayez.", Colors.red);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _afficherMessage("❌ Erreur réseau: $e", Colors.red);
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
            const Text('Simulation du Remboursement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _buildSimulationRow('Montant demandé:', '$montant FBU'),
            _buildSimulationRow('Intérêts (${_typeCredit == 'Social' ? 0 : _tauxInteret}%):', '${interets.toStringAsFixed(0)} FBU'),
            _buildSimulationRow('Durée:', '$dureeMois mois'),
            const Divider(),
            _buildSimulationRow('Total à rembourser:', '${totalARembourser.toStringAsFixed(0)} FBU', isBold: true, color: primaryColor),
            const SizedBox(height: 8),
            _buildSimulationRow('Mensualité estimée:', '${mensualite.toStringAsFixed(0)} FBU / mois', isBold: true),
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
        title: const Text('Nouvelle Demande', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      decoration: const InputDecoration(labelText: 'Type de Crédit', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                      items: ['Standard', 'Social'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value == 'Standard' ? 'Crédit Standard' : 'Prêt Social'));
                      }).toList(),
                      onChanged: (newValue) => setState(() => _typeCredit = newValue!),
                    ),
                    const SizedBox(height: 20),

                    if (_typeCredit == 'Standard') ...[
                      TextFormField(
                        // On utilise un controller ou une clé unique pour refléter le taux reçu de l'API
                        key: ValueKey(_tauxInteret),
                        initialValue: '$_tauxInteret %',
                        readOnly: true, // IMPORTANT: Bloqué en lecture seule pour le membre !
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        decoration: const InputDecoration(
                          labelText: 'Taux d\'intérêt appliqué (Fixé par l\'Administration)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.percent),
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    TextFormField(
                      controller: _montantController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Montant Souhaité (FBU)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                      onChanged: (val) => setState(() {}),
                      validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? 'Entrez un montant valide' : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _motifController,
                      decoration: const InputDecoration(labelText: 'Motif du prêt', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit)),
                      validator: (value) => (value == null || value.isEmpty) ? 'Entrez un motif' : null,
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
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Envoyer la Demande'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}