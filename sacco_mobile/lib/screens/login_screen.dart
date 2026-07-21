import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
//import 'package:http/http.dart' as http;
//import 'dart:convert';
import '../providers/auth_notifier.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _cniController = TextEditingController();
  final TextEditingController _ageController = TextEditingController(text: '18');
  final TextEditingController _telephoneInsController = TextEditingController();
  final TextEditingController _collineController = TextEditingController();
  final TextEditingController _quartierController = TextEditingController();
  final TextEditingController _avenueController = TextEditingController();
  final TextEditingController _maisonController = TextEditingController();
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
        const SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      return;
    }

    await authNotifier.login(phone, pin);

    if (!mounted) return;

    if (authNotifier.isAuthenticated) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Échec de connexion : Identifiants incorrects"),
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

    if (nom.isEmpty || prenom.isEmpty || telephone.isEmpty || cni.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir les champs obligatoires")),
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
    );

    if (!mounted) return;
    setState(() => _isLoadingInscription = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Inscription réussie ! PIN par défaut : 1234"),
          backgroundColor: Colors.green,
        ),
      );
      _tabController.index = 0;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de l'inscription (vérifiez que le numéro n'existe pas déjà)"),
          backgroundColor: Colors.red
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SACCO Connect"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.lock_open), text: "Connexion Sécurisée"),
            Tab(icon: Icon(Icons.person_add), text: "Devenir Membre"),
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
                  decoration: const InputDecoration(
                    labelText: "Numéro de Téléphone (Identifiant)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    labelText: "Code PIN",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
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
                            child: const Text("Accéder au Système", style: TextStyle(color: Colors.white)),
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
                const Text("📝 Formulaire d'Adhésion Officiel", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A529B))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _nomController, decoration: const InputDecoration(labelText: "Nom", border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _prenomController, decoration: const InputDecoration(labelText: "Prénom", border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: _cniController, decoration: const InputDecoration(labelText: "Numéro de Carte d'Identité (CNI)", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _ageController, decoration: const InputDecoration(labelText: "Âge", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sexeSelected,
                        decoration: const InputDecoration(labelText: "Sexe", border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'M', child: Text("Masculin")),
                          DropdownMenuItem(value: 'F', child: Text("Féminin")),
                        ],
                        onChanged: (val) => setState(() => _sexeSelected = val ?? 'M'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: _telephoneInsController, decoration: const InputDecoration(labelText: "Téléphone (Identifiant)", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 20),
                const Text("📍 Localisation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A529B))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _collineController, decoration: const InputDecoration(labelText: "Colline", border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _quartierController, decoration: const InputDecoration(labelText: "Quartier", border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _avenueController, decoration: const InputDecoration(labelText: "Avenue / Rue", border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _maisonController, decoration: const InputDecoration(labelText: "N° Maison", border: OutlineInputBorder()))),
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
                        child: const Text("Valider mon Inscription", style: TextStyle(color: Colors.white)),
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