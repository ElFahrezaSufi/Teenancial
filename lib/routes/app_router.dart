import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../providers/auth_provider.dart';

// Screens
import '../screens/splash_screen.dart';
import '../screens/main_screen.dart';
import '../screens/home_screen.dart';
import '../screens/dompet_screen.dart';
import '../screens/riwayat_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/get_started.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Membuat router aplikasi. [auth] dipakai sebagai session guard: setiap kali
/// status login berubah, redirect dievaluasi ulang.
GoRouter createAppRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Splash memutuskan tujuan sendiri setelah animasinya selesai.
      if (location == AppRoutes.splash) return null;
      if (!auth.isInitialized) return AppRoutes.splash;

      final loggedIn = auth.isLoggedIn;
      if (!loggedIn && !AppRoutes.publicRoutes.contains(location)) {
        return AppRoutes.getStarted;
      }
      if (loggedIn && AppRoutes.authOnlyRoutes.contains(location)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.getStarted,
        builder: (context, state) => const GetStarted(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignUpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dompet,
                builder: (context, state) => const DompetScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.riwayat,
                builder: (context, state) => const RiwayatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
