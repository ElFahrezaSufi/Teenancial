import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../providers/auth_provider.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import '../utils/error_mapper.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _isLoggingOut = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isChecking && !_isLoggingOut) {
      _handleCheckVerification(silent: true);
    }
  }

  /// Samarkan email: hanya karakter pertama & terakhir bagian lokal yang
  /// tampak, sisanya diganti '*'. Domain tetap ditampilkan.
  String _maskEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email;

    final local = email.substring(0, atIndex);
    final domain = email.substring(atIndex);

    if (local.length <= 2) {
      return '${local[0]}***$domain';
    }

    final first = local[0];
    final last = local[local.length - 1];
    final hiddenCount = local.length - 2;
    final stars = '*' * (hiddenCount < 3 ? 3 : hiddenCount);
    return '$first$stars$last$domain';
  }

  Future<void> _handleCheckVerification({bool silent = false}) async {
    if (_isChecking || _isLoggingOut) return;
    if (!silent) {
      setState(() => _isChecking = true);
    } else {
      _isChecking = true;
    }

    bool verified = false;
    try {
      verified = await context.read<AuthProvider>().refreshVerificationStatus();
    } catch (_) {
      verified = false;
    }

    if (verified) {
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Email berhasil diverifikasi! Selamat datang di Teenancial.',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      if (mounted) {
        setState(() => _isChecking = false);
        context.go(AppRoutes.home);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email belum terverifikasi. Cek inbox atau folder spam kamu.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleResendEmail() async {
    if (_cooldown > 0 || _isChecking || _isLoggingOut) return;

    try {
      await context.read<AuthProvider>().resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verifikasi sudah dikirim ulang.'),
          backgroundColor: primaryGreen,
        ),
      );
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMapper.message(
              e,
              fallback: 'Gagal mengirim ulang email. Coba lagi nanti.',
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await context.read<AuthProvider>().logout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal keluar: ${ErrorMapper.message(e)}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? '-';
    final maskedEmail = _maskEmail(email);
    final mediaPadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_curve.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      mediaPadding.top -
                      mediaPadding.bottom -
                      48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: lightGreen.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          size: 56,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Selesaikan Pendaftaran',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: primaryGreen,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Akunmu belum aktif. Kami sudah mengirim link verifikasi ke:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryGreen,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: primaryGreen, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        maskedEmail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryGreen,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Klik link di email untuk membuktikan email itu benar milikmu. '
                      'Setelah terverifikasi, akunmu terdaftar dan bisa dipakai '
                      'untuk masuk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryGreen.withValues(alpha: 0.7),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _isChecking ? null : _handleCheckVerification,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: _isChecking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Saya Sudah Verifikasi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: (_cooldown > 0 || _isChecking)
                          ? null
                          : _handleResendEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: primaryGreen, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _cooldown > 0
                            ? 'Kirim Ulang (${_cooldown}s)'
                            : 'Kirim Ulang Email',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed:
                            (_isLoggingOut || _isChecking) ? null : _handleLogout,
                        child: Text(
                          _isLoggingOut ? 'Keluar...' : 'Keluar',
                          style: const TextStyle(
                            color: orangeText,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
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
