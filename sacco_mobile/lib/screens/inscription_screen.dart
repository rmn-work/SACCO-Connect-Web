import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // Importation de easy_localization
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
  final _pinController = TextEditingController(); // 🟢 AJOUT : Contrôleur pour le PIN

  // Variables d'état pour le Sexe (Utilisation des clés de traduction)
  String? _sexeSelectionneKey;
  final List<String> _sexesKeys = ['male', 'female'];

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telController.dispose();
    _cniController.dispose();
    _ageController.dispose();
    _collineController.dispose();
    _quartierController.dispose();
    _avenueController.dispose();
    _maisonController.dispose();
    _pinController.dispose(); // 🟢 AJOUT : Libération de la mémoire du PIN
    super.dispose();
  }

  void _validerInscription() async {
    if (_formKey.currentState!.validate()) {

      // On s'assure que l'API reçoit toujours 'Masculin' ou 'Féminin' peu importe la langue
      String sexeApi = (_sexeSelectionneKey == 'female') ? 'Féminin' : 'Masculin';

      // Appel au service avec les nouvelles données incluant le PIN
      bool success = await ApiService.inscrireMembre(
        nom: _nomController.text,
        prenom: _prenomController.text,
        age: int.tryParse(_ageController.text) ?? 18,
        sexe: sexeApi,
        telephone: _telController.text,
        cni: _cniController.text,
        colline: _collineController.text,
        quartier: _quartierController.text,
        avenue: _avenueController.text,
        maison: _maisonController.text,
        pin: _pinController.text, // 🟢 AJOUT : Transmission du PIN à l'API
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('registration_success'.tr())),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('register_title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nomController, decoration: InputDecoration(labelText: 'last_name'.tr())),
              TextFormField(controller: _prenomController, decoration: InputDecoration(labelText: 'first_name'.tr())),
              TextFormField(controller: _telController, decoration: InputDecoration(labelText: 'phone_number'.tr())),
              TextFormField(controller: _cniController, decoration: InputDecoration(labelText: 'cni_number'.tr())),

              const SizedBox(height: 16),
              // 🟢 AJOUT : Champ de saisie pour le Code PIN
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'Code PIN',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.isEmpty ? 'Veuillez définir un PIN' : null,
              ),

              const SizedBox(height: 16),
              // --- Sélecteur de Sexe ---
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'gender'.tr(), border: const OutlineInputBorder()),
                value: _sexeSelectionneKey,
                items: _sexesKeys.map((String key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(key.tr()) // Affiche 'Masculin/Féminin'
                  );
                }).toList(),
                onChanged: (val) => setState(() => _sexeSelectionneKey = val),
              ),

              const SizedBox(height: 16),
              // --- Sélecteur d'Âge avec + et - ---
              Row(
                children: [
                  Text('age_label'.tr()),
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
              Text('location'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(controller: _collineController, decoration: InputDecoration(labelText: 'colline_label'.tr())),
              TextFormField(controller: _quartierController, decoration: InputDecoration(labelText: 'quartier_label'.tr())),
              TextFormField(controller: _avenueController, decoration: InputDecoration(labelText: 'avenue_label'.tr())),
              TextFormField(controller: _maisonController, decoration: InputDecoration(labelText: 'house_number'.tr())),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _validerInscription,
                child: Text('validate_registration'.tr())
              ),
            ],
          ),
        ),
      ),
    );
  }
}