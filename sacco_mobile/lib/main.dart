import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart'; // Importation conservée pour votre navigation future

void main() {
  // Assure que les services Flutter sont bien initialisés avant le lancement de l'application
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaccoConnectApp());
}

class SaccoConnectApp extends StatelessWidget {
  const SaccoConnectApp({Key? key}) : super(key: key);

  // Définition de la couleur bleue officielle de la Sacco FinTech
  static const Color primaryBlue = Color(0xFF1A56A3);
  static const Color accentOrange = Color(0xFFF3811F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SACCO CONNECT',
      debugShowCheckedModeBanner: false,

      // Configuration du thème global unifié
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Fond clair moderne

        // Palette de couleurs globale de l'application
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: accentOrange,
        ),

        // Configuration de la barre d'application (AppBar)
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        // Configuration automatique et complète de tous les ElevatedButtons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue, // Couleur de fond du bouton
            foregroundColor: Colors.white, // Couleur du texte/icône
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // Optionnel: pour des boutons légèrement arrondis et modernes
            ),
          ),
        ),
      ),

      // Point d'entrée de l'application
      home: const LoginScreen(),
    );
  }
}