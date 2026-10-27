import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(AppConfig.locale, null);

  final storage = await StorageService.create();
  final auth = AuthProvider(AuthService(storage));
  await auth.init();

  runApp(MyApp(storage: storage, auth: auth));
}

class MyApp extends StatelessWidget {
  final StorageService storage;
  final AuthProvider auth;

  const MyApp({super.key, required this.storage, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
          useMaterial3: true,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
