import 'dart:async';
import 'dart:ui';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'config/app_routes.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/belajar_provider.dart';
import 'providers/category_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/dompet_provider.dart';
import 'providers/feen_chat_provider.dart';
import 'providers/mission_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/target_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_router.dart';
import 'services/connectivity_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'utils/error_mapper.dart';
import 'widgets/common/app_fallback_views.dart';
import 'widgets/common/offline_banner.dart';
import 'widgets/common/responsive_app_shell.dart';

bool _dateFormattingReady = false;
bool _localStorageReady = false;
bool _notificationReady = false;
bool _connectivityReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error boundary: menangkap error widget & error async tak tertangkap
  // agar aplikasi tidak menampilkan layar abu-abu/merah mentah.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      RenderErrorFallbackView(details: details);

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  await _bootstrapAndRunApp();
}

Future<void> _bootstrapAndRunApp() async {
  try {
    if (!_dateFormattingReady) {
      await initializeDateFormatting('id_ID', null);
      _dateFormattingReady = true;
    }
    if (!_localStorageReady) {
      await LocalStorageService.instance.init();
      _localStorageReady = true;
    }
    if (!_notificationReady) {
      try {
        await NotificationService.instance.init();
      } catch (e) {
        debugPrint('Inisialisasi notifikasi dilewati: $e');
      }
      _notificationReady = true;
    }
    if (!_connectivityReady) {
      await ConnectivityService.instance.init();
      _connectivityReady = true;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    runApp(_buildRootApp());
  } catch (e, stack) {
    debugPrint('Gagal memulai aplikasi: $e\n$stack');
    runApp(
      StartupErrorApp(
        errorMessage: ErrorMapper.message(
          e,
          fallback:
              'Terjadi gangguan saat menyiapkan layanan aplikasi. Pastikan koneksi & perangkat siap lalu coba lagi.',
        ),
        onRetry: _bootstrapAndRunApp,
      ),
    );
  }
}

Widget _buildRootApp() {
  return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ConnectivityService.instance),
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: false),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, provider) =>
              (provider ?? UserProvider())..updateUser(auth.activeUid),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, UserProvider,
            MissionProvider>(
          create: (_) => MissionProvider(),
          update: (_, auth, userProvider, provider) =>
              (provider ?? MissionProvider())
                ..bindDependencies(auth.activeUid, userProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DompetProvider>(
          create: (_) => DompetProvider(),
          update: (_, auth, provider) =>
              (provider ?? DompetProvider())..updateUser(auth.activeUid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ContactProvider>(
          create: (_) => ContactProvider(),
          update: (_, auth, provider) =>
              (provider ?? ContactProvider())..updateUser(auth.activeUid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CategoryProvider>(
          create: (_) => CategoryProvider(),
          update: (_, auth, provider) =>
              (provider ?? CategoryProvider())..updateUser(auth.activeUid),
        ),
        ChangeNotifierProxyProvider3<AuthProvider, DompetProvider,
            MissionProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, auth, dompetProvider, missionProvider, provider) =>
              (provider ?? TransactionProvider())
                ..bindDependencies(
                  auth.activeUid,
                  dompetProvider,
                  missionProvider,
                ),
        ),
        ChangeNotifierProxyProvider3<AuthProvider, DompetProvider,
            TransactionProvider, RecurringProvider>(
          create: (_) => RecurringProvider(),
          update: (_, auth, dompetProvider, txProvider, provider) =>
              (provider ?? RecurringProvider())
                ..bindDependencies(auth.activeUid, dompetProvider, txProvider),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, MissionProvider,
            TargetProvider>(
          create: (_) => TargetProvider(),
          update: (_, auth, missionProvider, provider) =>
              (provider ?? TargetProvider())
                ..bindDependencies(auth.activeUid, missionProvider),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, MissionProvider,
            BelajarProvider>(
          create: (_) => BelajarProvider(),
          update: (_, auth, missionProvider, provider) =>
              (provider ?? BelajarProvider())
                ..bindDependencies(auth.activeUid, missionProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, FeenChatProvider>(
          create: (_) => FeenChatProvider(),
          update: (_, auth, provider) =>
              (provider ?? FeenChatProvider())..updateUser(auth.activeUid),
        ),
      ],
      child: const _ConnectivitySyncCoordinator(child: MyApp()),
  );
}

/// Menyelaraskan ulang seluruh provider secara senyap begitu koneksi berubah
/// dari offline kembali ke online (auto-sync Dukungan Offline Tingkatan A).
class _ConnectivitySyncCoordinator extends StatefulWidget {
  final Widget child;

  const _ConnectivitySyncCoordinator({required this.child});

  @override
  State<_ConnectivitySyncCoordinator> createState() =>
      _ConnectivitySyncCoordinatorState();
}

class _ConnectivitySyncCoordinatorState
    extends State<_ConnectivitySyncCoordinator> with WidgetsBindingObserver {
  late bool _wasOffline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasOffline = ConnectivityService.instance.isOffline;
    ConnectivityService.instance.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ConnectivityService.instance.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ConnectivityService.instance.setAppForeground(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ConnectivityService.instance.setAppForeground(false);
    }
  }

  void _onConnectivityChanged() {
    final isOffline = ConnectivityService.instance.isOffline;
    final reconnected = _wasOffline && !isOffline;
    _wasOffline = isOffline;

    if (!reconnected || !mounted) return;
    final activeUid = context.read<AuthProvider>().activeUid;
    if (activeUid == null) return;

    final userProvider = context.read<UserProvider>();
    final dompetProvider = context.read<DompetProvider>();
    final txProvider = context.read<TransactionProvider>();
    final targetProvider = context.read<TargetProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final contactProvider = context.read<ContactProvider>();
    final missionProvider = context.read<MissionProvider>();
    final recurringProvider = context.read<RecurringProvider>();
    final belajarProvider = context.read<BelajarProvider>();
    final feenChatProvider = context.read<FeenChatProvider>();

    unawaited(
      Future.wait([
        userProvider
            .syncPendingOnboardingFlagIfNeeded()
            .then((_) => userProvider.loadProfile(silent: true)),
        dompetProvider.loadDompets(silent: true),
        txProvider.loadTransactions(silent: true),
        targetProvider.loadTargets(silent: true),
        categoryProvider.loadCategories(silent: true),
        contactProvider.loadContacts(),
        missionProvider.loadMissions(),
        recurringProvider.runCatchUpAndLoad(silent: true),
        belajarProvider.levels.isEmpty
            ? belajarProvider.loadAll(silent: true)
            : belajarProvider.loadProgress(silent: true),
        feenChatProvider.loadSessions(silent: true),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Teenancial',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ResponsiveAppShell(
          child: _GlobalOfflineBannerShell(child: child),
        );
      },
    );
  }
}

/// Membungkus subtree router dengan [OfflineBanner] global sambil menghindari
/// pemanggilan `setState()` sinkron saat `GoRouterDelegate` mengirim notifikasi
/// pada fase build awal (`_RouterState.didChangeDependencies`).
class _GlobalOfflineBannerShell extends StatefulWidget {
  final Widget child;

  const _GlobalOfflineBannerShell({required this.child});

  @override
  State<_GlobalOfflineBannerShell> createState() =>
      _GlobalOfflineBannerShellState();
}

class _GlobalOfflineBannerShellState extends State<_GlobalOfflineBannerShell> {
  late bool _isSplash;
  late bool _isOffline;

  @override
  void initState() {
    super.initState();
    _isSplash = _readIsSplash();
    _isOffline = ConnectivityService.instance.isOffline;
    ConnectivityService.instance.addListener(_handleStateChange);
    appRouter.routerDelegate.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_handleStateChange);
    appRouter.routerDelegate.removeListener(_handleStateChange);
    super.dispose();
  }

  bool _readIsSplash() {
    final path = appRouter.routerDelegate.currentConfiguration.uri.path;
    return path.isEmpty || path == AppRoutes.splash;
  }

  void _handleStateChange() {
    final nextSplash = _readIsSplash();
    final nextOffline = ConnectivityService.instance.isOffline;
    if (nextSplash == _isSplash && nextOffline == _isOffline) return;

    void apply() {
      if (!mounted) return;
      setState(() {
        _isSplash = nextSplash;
        _isOffline = nextOffline;
      });
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBannerShowing = !_isSplash && _isOffline;
    return Column(
      children: [
        OfflineBanner(visible: !_isSplash),
        Expanded(
          child: isBannerShowing
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: widget.child,
                )
              : widget.child,
        ),
      ],
    );
  }
}
