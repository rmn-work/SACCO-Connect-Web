import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'inscription_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _telephoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;

  // Définition de la couleur bleue officielle du logo (remplace l'ancien primaryColor)
  final Color logoBlue = const Color(0xFF1A529B);

  @override
  void dispose() {
    _telephoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _validerConnexion() async {
    String tel = _telephoneController.text.trim();
    String pin = _pinController.text.trim();

    if (tel.isEmpty || pin.isEmpty) {
      _afficherMessage("Veuillez remplir tous les champs", Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    final resultat = await ApiService.login(tel, pin);
    setState(() => _isLoading = false);
    print("===== RÉPONSE DE FASTAPI =====");
    print(resultat);
    print("==============================");

    if (resultat != null) {
      _afficherMessage("Connexion réussie !", Colors.green);

      int? memberId;
      String? userRole;
      if (resultat.containsKey('user') && resultat['user'] != null) {
        memberId = resultat['user']['id'];
        userRole = resultat['user']['role'];
      }
      else if (resultat.containsKey('id') || resultat.containsKey('role')) {
        memberId = resultat['id'] ?? resultat['membre_id'] ?? resultat['user_id'];
        userRole = resultat['role'];
      }
      else if (resultat.containsKey('access_token')) {
         memberId = resultat['membre_id'] ?? resultat['user_id'] ?? 1;
         userRole = resultat['role'] ?? 'admin_sys';
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              membreId: memberId != null ? int.parse(memberId.toString()) : 1,
              role: userRole ?? 'admin_sys',
            ),
          ),
        );
      }
    } else {
      _afficherMessage("Erreur : Identifiants incorrects ou serveur indisponible.", Colors.red);
    }
  }

  void _afficherMessage(String message, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. L'image de fond centrée avec opacité réduite (effet filigrane)
          Center(
            child: Opacity(
              opacity: 0.08, // Ajustez entre 0.05 et 0.10 selon vos préférences de lisibilité
              child: Image.asset(
                'assets/images/la_confiance.png',
                width: MediaQuery.of(context).size.width * 0.85,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 2. Le Contenu du Formulaire et le pied de page
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),

                        // Titre mis à jour avec le Bleu du Logo
                        Text(
                          'SACCO CONNECT',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: logoBlue,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 50),

                        // Champ Téléphone relié à son contrôleur historique
                        TextField(
                          controller: _telephoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Champ Code PIN relié à sa logique d'affichage dynamique
                        TextField(
                          controller: _pinController,
                          obscureText: _obscurePin,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Code PIN',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Lien d'inscription vers InscriptionScreen
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const InscriptionScreen()),
                            );
                          },
                          child: const Text("Vous n'avez pas de compte ? Devenir Membre"),
                        ),
                        const SizedBox(height: 30),

                        // Bouton mis à jour en Bleu Logo avec loader géré
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: logoBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isLoading ? null : _validerConnexion,
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Accéder au Système',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Pied de page (Copyright) avec fond Bleu Logo
                Container(
                  width: double.infinity,
                  color: logoBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: const Text(
                    '© copyright - Sacco FinTech 2024-2026 - L\'avenir pour tous au Burundi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}