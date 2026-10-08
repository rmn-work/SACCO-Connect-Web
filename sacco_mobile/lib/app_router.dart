import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_notifier.dart';
import 'screens/combined_auth_screen.dart';
import 'screens/dashboard_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: authNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = authNotifier.isAuthenticated;
    final bool isLoggingIn = state.matchedLocation == '/login';

    print("DEBUG REDIRECT: Authenticated = $loggedIn, Location = ${state.matchedLocation}");

    if (!loggedIn && !isLoggingIn) {
      return '/login';
    }

    if (loggedIn && isLoggingIn) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const CombinedAuthScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) {
        final extra = state.extra as Map?;
        final int membreId = extra?['membre_id'] ?? extra?['id'] ?? 1;
        final String role = extra?['role'] ?? 'membre';

        return DashboardScreen(
          membreId: membreId,
          role: role,
        );
      },
    ),
  ],
);