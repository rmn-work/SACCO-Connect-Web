import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PortefeuillePretScreen extends StatefulWidget {
  final int membreId;

  const PortefeuillePretScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<PortefeuillePretScreen> createState() => _PortefeuillePretScreenState();
}

class _PortefeuillePretScreenState extends State<PortefeuillePretScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _accountData;
  List<dynamic> _mesDemandes = [];
  List<dynamic> _historiqueEpargne = [];

  // Formulaires controllers
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
    final data = await ApiService.getPortefeuille(widget.membreId);
    final demandes = await ApiService.getMesDemandesPrets(widget.membreId);
    final historique = await ApiService.getHistoriqueEpargne(widget.membreId);

    setState(() {
      _accountData = data;
      _mesDemandes = demandes;
      _historiqueEpargne = historique;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
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
          title: const Text("💰 Espace Responsable"),
          backgroundColor: const Color(0xFF009688),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.account_balance_wallet), text: "Portefeuille"),
              Tab(icon: Icon(Icons.monetization_on), text: "Crédit"),
              Tab(icon: Icon(Icons.history), text: "Historique"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMonPortefeuilleTab(user, context), // Ajout du context ici
            _buildDemandeCreditTab(user, maxLoan),
            _buildHistoriqueTab(),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ONGLET 1 : MON PORTEFEUILLE
  // =========================================================================
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
              _buildMetricCard("Épargne Totale", "${user['solde_epargne'] ?? 0} BIF", Colors.teal),
              _buildMetricCard("Prêt à Rembourser", "${user['solde_pret'] ?? 0} BIF", Colors.red),
              _buildMetricCard("Status Présence", "${user['status_presence'] ?? '-'}", Colors.blue),
              _buildMetricCard("Cotisation Fixée", "5,000 BIF", Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          const Text("🛡️ Solidarité & Prêts Sociaux", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                const Text("Ma Caisse Sociale", style: TextStyle(color: Color(0xFF01579B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("${user['caisse_sociale'] ?? 0} BIF", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("Fonds d'entraide communautaire", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 🔥 LE BLOC CORRIGÉ EST ICI
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
                title: const Text("Demande de Prêt Social"),
                subtitle: const Text("Besoin d'un coup de pouce urgent ?"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF8BC34A)), // Petite flèche pour indiquer l'action
                onTap: () {
                  _afficherFormulairePretSocial(context); // Ouvre le formulaire modal !
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text("📉 Suivi de mon Crédit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildCreditRow("Crédit en cours", "${user['credit_en_cours'] ?? 0} BIF", Colors.black87),
          _buildCreditRow("Déjà remboursé", "${user['credit_rembourse'] ?? 0} BIF", Colors.green),
          _buildCreditRow("Reste à payer", "${user['credit_restant'] ?? 0} BIF", Colors.orange.shade800),

          const SizedBox(height: 24),
          const Divider(),
          const Text("📎 Mes Documents (Reçus)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Module d'importation PDF activé.")));
            },
            icon: const Icon(Icons.upload_file),
            label: const Text("Associer un reçu de banque (PDF)"),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FENÊTRE MODALE : FORMULAIRE PRÊT SOCIAL
  // =========================================================================
  void _afficherFormulairePretSocial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet au clavier de ne pas cacher le formulaire
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Gère la hauteur du clavier
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
                const Row(
                  children: [
                    Icon(Icons.health_and_safety, color: Color(0xFF8BC34A)),
                    SizedBox(width: 8),
                    Text("Nouveau Prêt Social", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montantSocialController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Montant souhaité (BIF)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Entrez un montant";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motifSocialController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Motif (Maladie, Naissance, Décès...)",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? "Précisez votre motif" : null,
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
                      Navigator.pop(context); // Ferme la modale d'abord
                      _soumettrePretSocial(); // Envoie les données à l'API
                    },
                    child: const Text("Soumettre la demande", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24), // Espace en bas
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // ONGLET 2 : DEMANDE DE CRÉDIT & HISTORIQUE
  // =========================================================================
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
              "🛡️ Votre plafond de prêt (3x votre épargne) :\n${maxLoan.toStringAsFixed(0)} BIF",
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
                  decoration: const InputDecoration(labelText: "Montant souhaité (BIF)", border: OutlineInputBorder()),
                  validator: (val) {
                    if (val!.isEmpty) return "Entrez un montant";
                    if (double.parse(val) > maxLoan) return "Dépasse le plafond autorisé";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motifCreditController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Motif détaillé du prêt (Projet, Santé...)", border: OutlineInputBorder()),
                  validator: (val) => val!.isEmpty ? "Précisez votre motif" : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009688), foregroundColor: Colors.white),
                    onPressed: _soumettreDemandeCredit,
                    child: const Text("🚀 Envoyer la Demande", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Divider(),

          const Text("📋 État de mes demandes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _mesDemandes.isEmpty
              ? const Text("Vous n'avez aucune demande de prêt en cours.", style: TextStyle(color: Colors.grey))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mesDemandes.length,
                  itemBuilder: (context, index) {
                    final d = _mesDemandes[index];
                    return Card(
                      child: ListTile(
                        title: Text("${d['montant']} BIF", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Demandé le : ${d['date_demande']}"),
                        trailing: _buildStatusBadge(d['status']),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // =========================================================================
  // ONGLET 3 : HISTORIQUE
  // =========================================================================
  Widget _buildHistoriqueTab() {
    if (_historiqueEpargne.isEmpty) {
      return const Center(child: Text("Aucun historique disponible."));
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
            subtitle: Text("Date : ${item['date_reunion']}"),
            trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ),
        );
      },
    );
  }

  // =========================================================================
  // WIDGETS ET FONCTIONS UTILES
  // =========================================================================
  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
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
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: badgeColor)),
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
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Demande sociale envoyée au comité !")));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Veuillez entrer un montant valide supérieur à 0")),
      );
      return;
    }

    if (_formCreditKey.currentState!.validate()) {
      bool success = await ApiService.demanderCredit(
        membreId: widget.membreId,
        montant: parsedMontant.toInt(),
        motif: _motifCreditController.text,
        tauxInteretApplique: 0.0,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Votre demande a été transmise aux administrateurs.")),
        );
        _montantCreditController.clear();
        _motifCreditController.clear();
        _chargerDonnees();
      }
    }
  }
}