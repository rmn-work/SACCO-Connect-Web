import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({Key? key}) : super(key: key);

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telController = TextEditingController();
  final _cniController = TextEditingController();
  final _ageController = TextEditingController(text: '18');
  final _collineController = TextEditingController();
  final _quartierController = TextEditingController();
  final _avenueController = TextEditingController();
  final _maisonController = TextEditingController();

  // Variables d'état pour le Sexe
  String? _sexeSelectionne;
  final List<String> _sexes = ['Masculin', 'Féminin'];

  @override
  void dispose() {
    // N'oublie pas de toujours disposer les contrôleurs
    _nomController.dispose();
    _prenomController.dispose();
    _telController.dispose();
    _cniController.dispose();
    _ageController.dispose();
    _collineController.dispose();
    _quartierController.dispose();
    _avenueController.dispose();
    _maisonController.dispose();
    super.dispose();
  }

  void _validerInscription() async {
    if (_formKey.currentState!.validate()) {
      // Appel au service avec les nouvelles données
      bool success = await ApiService.inscrireMembre(
        nom: _nomController.text,
        prenom: _prenomController.text,
        age: int.tryParse(_ageController.text) ?? 18,
        sexe: _sexeSelectionne ?? 'Masculin',
        telephone: _telController.text,
        cni: _cniController.text,
        colline: _collineController.text,
        quartier: _quartierController.text,
        avenue: _avenueController.text,
        maison: _maisonController.text,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscription réussie !')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Formulaire d'Adhésion")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nomController, decoration: const InputDecoration(labelText: 'Nom')),
              TextFormField(controller: _prenomController, decoration: const InputDecoration(labelText: 'Prénom')),
              TextFormField(controller: _telController, decoration: const InputDecoration(labelText: 'Téléphone')),
              TextFormField(controller: _cniController, decoration: const InputDecoration(labelText: 'N° CNI')),

              const SizedBox(height: 16),
              // --- Sélecteur de Sexe ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Sexe', border: OutlineInputBorder()),
                value: _sexeSelectionne,
                items: _sexes.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (val) => setState(() => _sexeSelectionne = val),
              ),

              const SizedBox(height: 16),
              // --- Sélecteur d'Âge avec + et - ---
              Row(
                children: [
                  const Text("Âge : "),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      int age = int.tryParse(_ageController.text) ?? 18;
                      if (age > 1) _ageController.text = (age - 1).toString();
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      int age = int.tryParse(_ageController.text) ?? 18;
                      _ageController.text = (age + 1).toString();
                    },
                  ),
                ],
              ),

              const Divider(height: 30),
              const Text("Localisation", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(controller: _collineController, decoration: const InputDecoration(labelText: 'Colline')),
              TextFormField(controller: _quartierController, decoration: const InputDecoration(labelText: 'Quartier')),
              TextFormField(controller: _avenueController, decoration: const InputDecoration(labelText: 'Avenue / Rue')),
              TextFormField(controller: _maisonController, decoration: const InputDecoration(labelText: 'N° Maison')),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _validerInscription,
                child: const Text('Valider l inscription')
              ),
            ],
          ),
        ),
      ),
    );
  }
}