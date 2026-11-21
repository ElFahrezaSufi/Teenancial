import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
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
  bool _isCanceling = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  bool get _isBusy => _isChecking || _isLoggingOut || _isCanceling;

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
    if (state == AppLifecycleState.resumed && !_isBusy) {
      _handleCheckVerification(silent: true);
    }
  }

  Future<void> _handleCheckVerification({bool silent = false}) async {
    if (_isBusy) return;
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
    if (_cooldown > 0 || _isBusy) return;

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
    if (_isBusy) return;
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

  Future<String?> _promptPasswordForCancel() async {
    String typedPassword = '';
    bool obscure = true;
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: appBarBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Verifikasi Password',
            style: TextStyle(
              color: primaryGreen,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesi masukmu sudah agak lama. Masukkan password yang kamu pakai saat mendaftar untuk membatalkan pendaftaran ini.',
                style: TextStyle(
                  color: primaryGreen.withValues(alpha: 0.85),
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: obscure,
                autofocus: true,
                onChanged: (val) {
                  typedPassword = val;
                  if (errorText != null && val.trim().isNotEmpty) {
                    setDialogState(() => errorText = null);
                  }
                },
                style: const TextStyle(
                  color: primaryGreen,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Masukkan password pendaftaran',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primaryGreen),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: primaryGreen,
                      size: 18,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: primaryGreen.withValues(alpha: 0.7),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              onPressed: () {
                if (typedPassword.trim().isEmpty) {
                  setDialogState(() => errorText = 'Password wajib diisi');
                  return;
                }
                Navigator.of(ctx).pop(typedPassword.trim());
              },
              child: const Text(
                'Batalkan Pendaftaran',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancelRegistration(String email) async {
    if (_isBusy) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appBarBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Batalkan Pendaftaran?',
          style: TextStyle(
            color: primaryGreen,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Pendaftaran untuk "$email" akan dihapus agar kamu bisa mendaftar ulang dengan alamat email yang benar.',
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.85),
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Kembali',
              style: TextStyle(
                color: primaryGreen.withValues(alpha: 0.7),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    setState(() => _isCanceling = true);

    try {
      try {
        await authProvider.cancelUnverifiedRegistration();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;
        if (!mounted) return;
        setState(() => _isCanceling = false);

        final password = await _promptPasswordForCancel();
        if (password == null || password.isEmpty || !mounted) return;

        setState(() => _isCanceling = true);
        await authProvider.cancelUnverifiedRegistration(password: password);
      }

      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Pendaftaran dibatalkan. Silakan daftar ulang dengan email yang benar.',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      appRouter.go(AppRoutes.signup);
    } on AccountAlreadyVerifiedException {
      await authProvider.refreshVerificationStatus();
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Emailmu sudah terverifikasi! Selamat datang di Teenancial.',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      appRouter.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCanceling = false);
      final String message = (e is FirebaseAuthException &&
              (e.code == 'wrong-password' || e.code == 'invalid-credential'))
          ? 'Password yang kamu masukkan salah.'
          : ErrorMapper.message(
              e,
              fallback: 'Gagal membatalkan pendaftaran. Coba lagi nanti.',
            );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
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
                        email,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryGreen,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _isBusy
                            ? null
                            : () => _handleCancelRegistration(email),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isCanceling
                              ? 'Membatalkan pendaftaran...'
                              : 'Salah email? Batalkan pendaftaran',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            decoration: _isCanceling
                                ? TextDecoration.none
                                : TextDecoration.underline,
                            decorationColor: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Periksa alamat email di atas. Klik link verifikasi di inbox atau folder spam untuk mengaktifkan akunmu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryGreen.withValues(alpha: 0.75),
                        fontFamily: 'Inter',
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _isBusy ? null : _handleCheckVerification,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _isBusy
                              ? primaryGreen.withValues(alpha: 0.7)
                              : primaryGreen,
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
                      onPressed:
                          (_cooldown > 0 || _isBusy) ? null : _handleResendEmail,
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
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _isBusy ? null : _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.redAccent.withValues(alpha: 0.65),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Keluar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
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
