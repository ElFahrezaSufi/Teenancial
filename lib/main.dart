import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/belajar_provider.dart';
import 'providers/category_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/dompet_provider.dart';
import 'providers/mission_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/target_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_router.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await LocalStorageService.instance.init();
  await NotificationService.instance.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Teenancial',
      debugShowCheckedModeBanner: false,
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
    );
  }
}
