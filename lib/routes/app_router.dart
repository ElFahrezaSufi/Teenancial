import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../providers/auth_provider.dart' show registrationInProgress;
import '../services/local_storage_service.dart';

import '../screens/buat_target_screen.dart';
import '../screens/daftar_pinjaman_screen.dart';
import '../screens/dompet_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/get_started.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/pemasukan_screen.dart';
import '../screens/pengeluaran_screen.dart';
import '../screens/pinjaman_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/riwayat_screen.dart';
import '../screens/ruang_belajar_screen.dart';
import '../screens/semua_aktivitas_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/tambah_dompet_screen.dart';
import '../screens/tanya_feen_screen.dart';
import '../screens/target_menabung_screen.dart';
import '../screens/transfer_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  refreshListenable: Listenable.merge([
    GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    registrationInProgress,
    LocalStorageService.instance.onboardingListenable,
  ]),
  redirect: (BuildContext context, GoRouterState state) {
    if (registrationInProgress.value) return null;

    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    if (isLoggedIn && !LocalStorageService.instance.hasSeenGetStarted) {
      unawaited(LocalStorageService.instance.setHasSeenGetStarted(true));
    }

    if (state.matchedLocation == AppRoutes.splash) {
      return null;
    }

    final isAuthRoute = AppRoutes.authRoutes.contains(state.matchedLocation);

    if (isLoggedIn && isAuthRoute) {
      return AppRoutes.home;
    }
    if (!isLoggedIn && !isAuthRoute) {
      return LocalStorageService.instance.hasSeenGetStarted
          ? AppRoutes.login
          : AppRoutes.getStarted;
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
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
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
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pemasukan,
      builder: (context, state) {
        final tx = state.extra is TransactionModel
            ? state.extra as TransactionModel
            : null;
        return PemasukanScreen(transactionToEdit: tx);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pengeluaran,
      builder: (context, state) {
        final tx = state.extra is TransactionModel
            ? state.extra as TransactionModel
            : null;
        return PengeluaranScreen(transactionToEdit: tx);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pinjaman,
      builder: (context, state) => const PinjamanScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.daftarPinjaman,
      builder: (context, state) => const DaftarPinjamanScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.transfer,
      builder: (context, state) => const TransferScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.tambahDompet,
      builder: (context, state) {
        final item =
            state.extra is DompetItem ? state.extra as DompetItem : null;
        return TambahDompetScreen(itemToEdit: item);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.targetMenabung,
      builder: (context, state) => const TargetMenabungScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.buatTarget,
      builder: (context, state) => const BuatTargetScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.ruangBelajar,
      builder: (context, state) => const RuangBelajarScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.semuaAktivitas,
      builder: (context, state) {
        final filterIndex = state.extra is int
            ? state.extra as int
            : LocalStorageService.instance.riwayatFilterIndex;
        return SemuaAktivitasScreen(filterIndex: filterIndex);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.tanyaFeen,
      builder: (context, state) => const TanyaFeenScreen(),
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
