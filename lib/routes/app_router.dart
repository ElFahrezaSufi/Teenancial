import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../providers/auth_provider.dart' show registrationInProgress;
import '../services/local_storage_service.dart';
import 'app_transitions.dart';

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
      pageBuilder: (context, state) => AppTransitions.fade(
        key: state.pageKey,
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.getStarted,
      pageBuilder: (context, state) => AppTransitions.fade(
        key: state.pageKey,
        child: const GetStarted(),
      ),
    ),
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (context, state) => AppTransitions.slideUp(
        key: state.pageKey,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.signup,
      pageBuilder: (context, state) => AppTransitions.slideUp(
        key: state.pageKey,
        child: const SignUpScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      pageBuilder: (context, state) => AppTransitions.slideUp(
        key: state.pageKey,
        child: const ForgotPasswordScreen(),
      ),
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
              pageBuilder: (context, state) => AppTransitions.fade(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.dompet,
              pageBuilder: (context, state) => AppTransitions.fade(
                key: state.pageKey,
                child: const DompetScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.riwayat,
              pageBuilder: (context, state) => AppTransitions.fade(
                key: state.pageKey,
                child: const RiwayatScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              pageBuilder: (context, state) => AppTransitions.fade(
                key: state.pageKey,
                child: const ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pemasukan,
      pageBuilder: (context, state) {
        final tx = state.extra is TransactionModel
            ? state.extra as TransactionModel
            : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: PemasukanScreen(transactionToEdit: tx),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pengeluaran,
      pageBuilder: (context, state) {
        final tx = state.extra is TransactionModel
            ? state.extra as TransactionModel
            : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: PengeluaranScreen(transactionToEdit: tx),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pinjaman,
      pageBuilder: (context, state) => AppTransitions.slideHorizontal(
        key: state.pageKey,
        child: const PinjamanScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.daftarPinjaman,
      pageBuilder: (context, state) => AppTransitions.slideHorizontal(
        key: state.pageKey,
        child: const DaftarPinjamanScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.transfer,
      pageBuilder: (context, state) => AppTransitions.slideHorizontal(
        key: state.pageKey,
        child: const TransferScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.tambahDompet,
      pageBuilder: (context, state) {
        final item =
            state.extra is DompetItem ? state.extra as DompetItem : null;
        return AppTransitions.slideHorizontal<bool>(
          key: state.pageKey,
          child: TambahDompetScreen(itemToEdit: item),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.targetMenabung,
      pageBuilder: (context, state) => AppTransitions.slideHorizontal(
        key: state.pageKey,
        child: const TargetMenabungScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.buatTarget,
      pageBuilder: (context, state) => AppTransitions.slideHorizontal(
        key: state.pageKey,
        child: const BuatTargetScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.ruangBelajar,
      pageBuilder: (context, state) => AppTransitions.slideHorizontal(
        key: state.pageKey,
        child: const RuangBelajarScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.semuaAktivitas,
      pageBuilder: (context, state) {
        final filterIndex = state.extra is int
            ? state.extra as int
            : LocalStorageService.instance.riwayatFilterIndex;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: SemuaAktivitasScreen(filterIndex: filterIndex),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.tanyaFeen,
      pageBuilder: (context, state) => AppTransitions.slideHorizontal(
        key: state.pageKey,
        child: const TanyaFeenScreen(),
      ),
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
