import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
        Locale('fr'),
        Locale('rn'),
      ],
      path: 'assets/locales',
      fallbackLocale: const Locale('fr'),
      saveLocale: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => authNotifier),
        ],
        child: const SaccoConnectApp(),
      ),
    ),
  );
}

void _initConnectivityListener() {
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
    final currentLang = context.locale.languageCode;
    final materialLocale = currentLang == 'rn' ? const Locale('fr') : context.locale;

    return MaterialApp.router(
      title: 'Sacco Connect',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      key: ValueKey(currentLang),

      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: materialLocale,

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },

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