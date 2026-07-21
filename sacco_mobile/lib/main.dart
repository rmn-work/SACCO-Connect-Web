import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_router.dart';
import 'providers/auth_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authNotifier = AuthNotifier();
  await authNotifier.checkAuthStatus();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authNotifier),
      ],
      child: const SaccoConnectApp(),
    ),
  );
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