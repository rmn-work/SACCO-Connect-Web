import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_notifier.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding',
  refreshListenable: authNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = authNotifier.isAuthenticated;
    final String location = state.matchedLocation;
    print("DEBUG REDIRECT: Authenticated = $loggedIn, Location = $location");

    // Autoriser l'accès à l'onboarding sans redirection automatique
    if (location == '/onboarding') {
      return null;
    }

    // Rediriger vers /login si non authentifié
    if (!loggedIn) {
      return '/login';
    }

    // Rediriger vers l'accueil si déjà connecté et qu'on essaie d'aller sur /login
    if (loggedIn && location == '/login') {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(
        membreId: 0,
        role: 'membre',
      ),
    ),
  ],
);