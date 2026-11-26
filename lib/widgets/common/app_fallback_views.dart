import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../config/app_routes.dart';
import '../../data/feen_catalog.dart';
import '../../theme/app_colors.dart';
import '../feen/feen_avatar.dart';

/// Halaman fallback 404 bergaya Teenancial untuk [GoRouter.errorBuilder]
/// ketika rute tidak dikenal atau gagal ditemukan.
class NotFoundScreen extends StatelessWidget {
  final String? location;
  final VoidCallback? onGoHome;

  const NotFoundScreen({
    super.key,
    this.location,
    this.onGoHome,
  });

  void _handleGoHome(BuildContext context) {
    if (onGoHome != null) {
      onGoHome!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(AppRoutes.home);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FeenAvatar(
                      level: 1,
                      pose: FeenPose.alert,
                      size: 112,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        '404',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Halaman Tidak Ditemukan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 20,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Halaman yang kamu tuju tidak tersedia atau sudah dipindahkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.78),
                        fontSize: 13.5,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (kDebugMode &&
                        location != null &&
                        location!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        location!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _handleGoHome(context),
                      icon: const Icon(Icons.home_rounded, size: 18),
                      label: const Text(
                        'Kembali ke Beranda',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback aman untuk [ErrorWidget.builder] agar kesalahan render tak terduga
/// tidak menampilkan layar abu-abu kosong atau layar merah mentah di perangkat
/// pengguna. Sengaja tidak bergantung pada Provider atau Theme agar tidak
/// memicu error lanjutan.
class RenderErrorFallbackView extends StatelessWidget {
  final FlutterErrorDetails? details;

  const RenderErrorFallbackView({
    super.key,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryGreen, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: orangeText,
                size: 40,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tampilan Sedang Bermasalah',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 15,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Terjadi gangguan saat memuat bagian ini. Coba kembali atau muat ulang halaman.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
              if (kDebugMode && details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10.5,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Aplikasi pemulihan mandiri ketika inisialisasi awal di `main()` (misalnya
/// Firebase atau penyimpanan lokal) gagal sehingga pengguna tidak terjebak
/// di layar putih/splash tanpa aksi.
class StartupErrorApp extends StatefulWidget {
  final String errorMessage;
  final Future<void> Function() onRetry;

  const StartupErrorApp({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teenancial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FeenAvatar(
                    level: 1,
                    pose: FeenPose.alert,
                    size: 112,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gagal Memulai Aplikasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 20,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.78),
                      fontSize: 13.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isRetrying ? null : _handleRetry,
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _isRetrying ? 'Mencoba ulang...' : 'Coba Lagi',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
