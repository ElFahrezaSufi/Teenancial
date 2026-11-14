import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../models/dompet_model.dart';
import '../models/recurring_model.dart';
import '../models/target_model.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';
import '../providers/auth_provider.dart';
import '../services/local_storage_service.dart';
import 'app_transitions.dart';

import '../screens/buat_berulang_screen.dart';
import '../screens/buat_target_screen.dart';
import '../screens/daftar_pinjaman_screen.dart';
import '../screens/dompet_screen.dart';
import '../screens/ekspor_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/get_started.dart';
import '../screens/home_screen.dart';
import '../screens/kategori_screen.dart';
import '../screens/laporan_screen.dart';
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
import '../screens/transaksi_berulang_screen.dart';
import '../screens/transfer_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  refreshListenable: Listenable.merge([
    GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    AuthProvider.bootstrapListenable,
    LocalStorageService.instance.onboardingListenable,
  ]),
  redirect: (BuildContext context, GoRouterState state) {
    if (AuthProvider.bootstrapListenable.value) return null;

    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

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
      pageBuilder: (context, state) {
        final tx = state.extra is TransactionModel
            ? state.extra as TransactionModel
            : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: PinjamanScreen(loanToEdit: tx),
        );
      },
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
      pageBuilder: (context, state) {
        final tx = state.extra is TransactionModel
            ? state.extra as TransactionModel
            : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: TransferScreen(transactionToEdit: tx),
        );
      },
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
      pageBuilder: (context, state) {
        final target =
            state.extra is TargetItem ? state.extra as TargetItem : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: BuatTargetScreen(targetToEdit: target),
        );
      },
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
        final extra = state.extra;
        late final int filterIndex;
        late final bool autoFocusSearch;
        if (extra is SemuaAktivitasArgs) {
          filterIndex = extra.filterIndex;
          autoFocusSearch = extra.autoFocusSearch;
        } else if (extra is int) {
          filterIndex = extra;
          autoFocusSearch = false;
        } else {
          filterIndex = LocalStorageService.instance.riwayatFilterIndex;
          autoFocusSearch = false;
        }
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: SemuaAktivitasScreen(
            filterIndex: filterIndex,
            autoFocusSearch: autoFocusSearch,
          ),
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
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.kategori,
      pageBuilder: (context, state) {
        final initialType = state.extra is TransactionType
            ? state.extra as TransactionType
            : TransactionType.expense;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: KategoriScreen(initialType: initialType),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.laporan,
      pageBuilder: (context, state) {
        final initialMonth =
            state.extra is DateTime ? state.extra as DateTime : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: LaporanScreen(initialMonth: initialMonth),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.transaksiBerulang,
      pageBuilder: (context, state) {
        final initialType = state.extra is TransactionType
            ? state.extra as TransactionType
            : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: TransaksiBerulangScreen(initialType: initialType),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.buatBerulang,
      pageBuilder: (context, state) {
        final extra = state.extra;
        RecurringModel? itemToEdit;
        TransactionType? initialType;
        if (extra is BuatBerulangArgs) {
          itemToEdit = extra.itemToEdit;
          initialType = extra.initialType;
        } else if (extra is RecurringModel) {
          itemToEdit = extra;
        } else if (extra is TransactionType) {
          initialType = extra;
        }
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: BuatBerulangScreen(
            itemToEdit: itemToEdit,
            initialType: initialType,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.ekspor,
      pageBuilder: (context, state) {
        final filter = state.extra is TransactionFilter
            ? state.extra as TransactionFilter
            : null;
        return AppTransitions.slideHorizontal(
          key: state.pageKey,
          child: EksporScreen(initialFilter: filter),
        );
      },
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
