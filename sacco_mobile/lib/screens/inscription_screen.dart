import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telController = TextEditingController();
  final _cniController = TextEditingController();
  final _ageController = TextEditingController(text: '18');
  final _collineController = TextEditingController();
  final _quartierController = TextEditingController();
  final _avenueController = TextEditingController();
  final _maisonController = TextEditingController();
  final _pinController = TextEditingController();

  String? _sexeSelectionneKey;
  final List<String> _sexesKeys = ['male', 'female'];

  bool _isLoading = false;

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
    _pinController.dispose();
    super.dispose();
  }

  void _validerInscription() async {
  FocusScope.of(context).unfocus();

  if (_formKey.currentState!.validate()) {
    if (_sexeSelectionneKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un genre'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String sexeApi = (_sexeSelectionneKey == 'female') ? 'Féminin' : 'Masculin';

    // Appel du service
    final result = await ApiService.inscrireMembre(
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
      pin: _pinController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('registration_success'.tr()), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      // Affiche la raison EXACTE donnée par le backend sur le téléphone du testeur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nomController,
              decoration: InputDecoration(labelText: 'last_name'.tr(), border: const OutlineInputBorder()),
              validator: (value) => value == null || value.trim().isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _prenomController,
              decoration: InputDecoration(labelText: 'first_name'.tr(), border: const OutlineInputBorder()),
              validator: (value) => value == null || value.trim().isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'phone_number'.tr(), border: const OutlineInputBorder()),
              validator: (value) => value == null || value.trim().isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cniController,
              decoration: InputDecoration(labelText: 'cni_number'.tr(), border: const OutlineInputBorder()),
            ),

            const SizedBox(height: 16),
            TextFormField(
              controller: _pinController,
              decoration: InputDecoration(
                labelText: 'pin_code'.tr(),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              validator: (value) => (value == null || value.isEmpty) ? 'pin_error'.tr() : null,
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'gender'.tr(), border: const OutlineInputBorder()),
              value: _sexeSelectionneKey,
              items: _sexesKeys.map((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text(key.tr()),
                );
              }).toList(),
              onChanged: (val) => setState(() => _sexeSelectionneKey = val),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Text('age_label'.tr(), style: const TextStyle(fontSize: 16)),
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
            Text('location'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _collineController,
              decoration: InputDecoration(labelText: 'colline_label'.tr(), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quartierController,
              decoration: InputDecoration(labelText: 'quartier_label'.tr(), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _avenueController,
              decoration: InputDecoration(labelText: 'avenue_label'.tr(), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maisonController,
              decoration: InputDecoration(labelText: 'house_number'.tr(), border: const OutlineInputBorder()),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A529B), foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _validerInscription,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      )
                    : Text('validate_registration'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}