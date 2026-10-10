import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ContactSupportScreen extends StatefulWidget {
  final int membreId;
  const ContactSupportScreen({super.key, required this.membreId});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final Color primaryColor = const Color(0xFF1A56A3);
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _sujetController = TextEditingController();
  final TextEditingController _contenuController = TextEditingController();

  List<dynamic> _tickets = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chargerTickets();
  }

  Future<void> _chargerTickets() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getTicketsMembre(widget.membreId);
    if (mounted) {
      setState(() {
        _tickets = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _envoyerTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    bool success = await ApiService.creerTicketSupport(
      membreId: widget.membreId,
      sujet: _sujetController.text.trim(),
      contenu: _contenuController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _sujetController.clear();
        _contenuController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Votre ticket a été envoyé avec succès !"),
            backgroundColor: Colors.green,
          ),
        );
        _chargerTickets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Échec de l'envoi du message."),
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
        title: const Text("Support & Réclamations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Formulaire d'envoi
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.support_agent, color: primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            "Nous contacter",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sujetController,
                        decoration: const InputDecoration(
                          labelText: "Sujet de votre demande",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? "Veuillez préciser le sujet" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contenuController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: "Détail de votre message",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? "Veuillez entrer votre message" : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _isSending
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _envoyerTicket,
                                icon: const Icon(Icons.send),
                                label: const Text("Envoyer la réclamation"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Historique des tickets
            const Text(
              "Mes demandes précédentes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_tickets.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Aucune réclamation enregistrée pour le moment.",
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tickets.length,
                itemBuilder: (context, index) {
                  final ticket = _tickets[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                        child: Icon(Icons.confirmation_number, color: primaryColor),
                      ),
                      title: Text(
                        ticket['sujet'] ?? 'Sans sujet',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Créé le : ${ticket['date_creation'] ?? 'N/A'}"),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}