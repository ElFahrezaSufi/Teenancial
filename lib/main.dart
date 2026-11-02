import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/belajar_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/dompet_provider.dart';
import 'providers/target_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_router.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
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
        ChangeNotifierProxyProvider2<AuthProvider, DompetProvider,
            TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, auth, dompetProvider, provider) =>
              (provider ?? TransactionProvider())
                ..bindDependencies(auth.activeUid, dompetProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TargetProvider>(
          create: (_) => TargetProvider(),
          update: (_, auth, provider) =>
              (provider ?? TargetProvider())..updateUser(auth.activeUid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BelajarProvider>(
          create: (_) => BelajarProvider(),
          update: (_, auth, provider) =>
              (provider ?? BelajarProvider())..updateUser(auth.activeUid),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
