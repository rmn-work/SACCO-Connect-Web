import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/auth_notifier.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contrôleurs pour la connexion
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  // Contrôleurs pour l'inscription
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _cniController = TextEditingController();
  final TextEditingController _ageController = TextEditingController(text: '18');
  final TextEditingController _telephoneInsController = TextEditingController();
  final TextEditingController _collineController = TextEditingController();
  final TextEditingController _quartierController = TextEditingController();
  final TextEditingController _avenueController = TextEditingController();
  final TextEditingController _maisonController = TextEditingController();
  // 🟢 AJOUT : Contrôleur pour le PIN d'inscription
  final TextEditingController _pinInsController = TextEditingController();

  String _sexeSelected = 'M';
  bool _isLoadingInscription = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("fill_all_fields".tr())),
      );
      return;
    }

    await authNotifier.login(phone, pin);

    if (!mounted) return;

    if (authNotifier.isAuthenticated) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("login_failed".tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleInscription() async {
    final nom = _nomController.text.trim();
    final prenom = _prenomController.text.trim();
    final telephone = _telephoneInsController.text.trim();
    final cni = _cniController.text.trim();
    final pin = _pinInsController.text.trim(); // 🟢 Récupération du PIN

    // 🟢 Vérification que le PIN n'est pas vide
    if (nom.isEmpty || prenom.isEmpty || telephone.isEmpty || cni.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("fill_mandatory_fields".tr())),
      );
      return;
    }

    setState(() => _isLoadingInscription = true);

    bool success = await ApiService.inscrireMembre(
      nom: nom,
      prenom: prenom,
      age: int.tryParse(_ageController.text) ?? 18,
      sexe: _sexeSelected == 'M' ? 'Masculin' : 'Féminin',
      telephone: telephone,
      cni: cni,
      colline: _collineController.text.trim(),
      quartier: _quartierController.text.trim(),
      avenue: _avenueController.text.trim(),
      maison: _maisonController.text.trim(),
      pin: pin, // 🟢 Envoi du PIN à l'API
    );

    if (!mounted) return;
    setState(() => _isLoadingInscription = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("registration_success".tr()),
          backgroundColor: Colors.green,
        ),
      );
      // Nettoyage des champs après succès (optionnel mais recommandé)
      _pinInsController.clear();
      _telephoneInsController.clear();
      _tabController.index = 0; // Basculer vers l'onglet Connexion
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("registration_error".tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _cniController.dispose();
    _ageController.dispose();
    _telephoneInsController.dispose();
    _collineController.dispose();
    _quartierController.dispose();
    _avenueController.dispose();
    _maisonController.dispose();
    _pinInsController.dispose(); // 🟢 Libération de la mémoire
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("app_title".tr()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: const Icon(Icons.lock_open), text: "secure_login".tr()),
            Tab(icon: const Icon(Icons.person_add), text: "become_member".tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- ONGLET 1 : CONNEXION ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.account_balance, size: 80, color: Color(0xFF1A529B)),
                const SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: "phone_identifier".tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: "pin_code".tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: authNotifier,
                  builder: (context, child) {
                    return authNotifier.isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: const Color(0xFF1A529B),
                            ),
                            child: Text("access_system".tr(), style: const TextStyle(color: Colors.white)),
                          );
                  },
                ),
              ],
            ),
          ),

          // --- ONGLET 2 : INSCRIPTION ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("official_membership_form".tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A529B))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _nomController, decoration: InputDecoration(labelText: "lastname".tr(), border: const OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _prenomController, decoration: InputDecoration(labelText: "firstname".tr(), border: const OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: _cniController, decoration: InputDecoration(labelText: "cni_number".tr(), border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _ageController, decoration: InputDecoration(labelText: "age".tr(), border: const OutlineInputBorder()), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sexeSelected,
                        decoration: InputDecoration(labelText: "sexe".tr(), border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'M', child: Text("male".tr())),
                          DropdownMenuItem(value: 'F', child: Text("female".tr())),
                        ],
                        onChanged: (val) => setState(() => _sexeSelected = val ?? 'M'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: _telephoneInsController, decoration: InputDecoration(labelText: "phone_label".tr(), border: const OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                // 🟢 AJOUT : Champ pour le Code PIN
                TextField(
                  controller: _pinInsController,
                  decoration: const InputDecoration(labelText: "Définir un Code PIN", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                Text("localization".tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A529B))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _collineController, decoration: InputDecoration(labelText: "colline".tr(), border: const OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _quartierController, decoration: InputDecoration(labelText: "quartier".tr(), border: const OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _avenueController, decoration: InputDecoration(labelText: "avenue_street".tr(), border: const OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _maisonController, decoration: InputDecoration(labelText: "house_number".tr(), border: const OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 24),
                _isLoadingInscription
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleInscription,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF1A529B),
                        ),
                        child: Text("validate_registration".tr(), style: const TextStyle(color: Colors.white)),
                      ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}