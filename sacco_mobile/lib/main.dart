import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_router.dart';
import 'providers/auth_notifier.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final authNotifier = AuthNotifier();
  await authNotifier.checkAuthStatus();

  _initConnectivityListener();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr', 'FR'), // Français
        Locale('rn', 'BI'), // Kirundi (Burundi)
      ],
      path: 'assets/locales',
      fallbackLocale: const Locale('fr', 'FR'),
      useOnlyLangCode: true, // Utilise fr.json et rn.json directement
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => authNotifier),
        ],
        child: const SaccoConnectApp(),
      ),
    ),
  );
}

/// Écoute en arrière-plan le réseau et lance la synchronisation dès qu'Internet revient
void _initConnectivityListener() {
  // 1. Vérification initiale au démarrage
  Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    bool isConnected = result == ConnectivityResult.mobile ||
                       result == ConnectivityResult.wifi ||
                       result == ConnectivityResult.ethernet;

    if (isConnected) {
      debugPrint("📶 Connecté au démarrage ! Lancement de la synchronisation automatique...");
      ApiService.syncPendingRequests();
    }
  });

  // 2. Écoute des changements de connexion en temps réel
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    bool isConnected = result == ConnectivityResult.mobile ||
                       result == ConnectivityResult.wifi ||
                       result == ConnectivityResult.ethernet;

    if (isConnected) {
      debugPrint("📶 Connexion Internet rétablie. Lancement de la synchronisation automatique...");
      ApiService.syncPendingRequests();
    } else {
      debugPrint("📴 Appareil hors-ligne. Les données seront stockées localement.");
    }
  });
}

class SaccoConnectApp extends StatelessWidget {
  const SaccoConnectApp({super.key});

  static const Color primaryBlue = Color(0xFF1A56A3);
  static const Color accentOrange = Color(0xFFF3811F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SACCO CONNECT',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: accentOrange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}