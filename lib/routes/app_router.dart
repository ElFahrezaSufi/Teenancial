import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import '../screens/transaksi_detail_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: const Color(0xFFEDEFE2),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off, size: 56, color: Color(0xFF627931)),
              const SizedBox(height: 12),
              Text(
                'Halaman "${state.uri}" tidak ditemukan',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF627931), fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF627931)),
                child: const Text('Ke Beranda',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  routes: <RouteBase>[
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/transaksi/:id',
      builder: (context, state) =>
          TransaksiDetailScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/get_started',
      builder: (context, state) => const GetStarted(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dompet',
              builder: (context, state) => const DompetScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/riwayat',
              builder: (context, state) => const RiwayatScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
