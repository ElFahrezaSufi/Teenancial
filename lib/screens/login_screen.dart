import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../providers/auth_provider.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        await context.read<AuthProvider>().login(
              _emailController.text.trim(),
              _passwordController.text,
            );
        await LocalStorageService.instance.setHasSeenGetStarted(true);

        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil Masuk!'),
            backgroundColor: primaryGreen,
          ),
        );
        context.go(AppRoutes.home);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        String errorMessage = 'Login gagal. Terjadi kesalahan jaringan.';
        if (e.code == 'user-not-found') {
          errorMessage =
              'Email tidak ditemukan. Silakan daftar terlebih dahulu.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Password yang kamu masukkan salah.';
        } else if (e.code == 'invalid-credential') {
          errorMessage = 'Email belum terdaftar atau Password salah.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Format email tidak valid.';
        } else if (e.code == 'too-many-requests') {
          errorMessage = 'Terlalu banyak percobaan. Coba lagi nanti.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan sistem, silakan coba lagi.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final bool signedIn =
          await context.read<AuthProvider>().signInWithGoogle();

      if (signedIn) {
        await LocalStorageService.instance.setHasSeenGetStarted(true);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (signedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil masuk dengan Google!'),
            backgroundColor: primaryGreen,
          ),
        );
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal masuk dengan Google, silakan coba lagi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: scaffoldBg,
            child: SvgPicture.asset(
              'assets/images/bg_curve.svg',
              fit: BoxFit.cover,
              placeholderBuilder: (context) => const SizedBox.shrink(),
            ),
          ),
          Column(
            children: [
              const SafeArea(
                bottom: false,
                child: SizedBox(height: 24),
              ),
              Expanded(
                child: GestureDetector(
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 100) {
                      context.go(AppRoutes.getStarted);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.only(
                      left: 2,
                      top: 6,
                      right: 2,
                      bottom: 0,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(26),
                          topRight: Radius.circular(26),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: GestureDetector(
                                    onTap: () =>
                                        context.go(AppRoutes.getStarted),
                                    child: Container(
                                      width: 80,
                                      height: 5,
                                      margin: const EdgeInsets.only(bottom: 24),
                                      decoration: BoxDecoration(
                                        color: primaryGreen.withValues(
                                          alpha: 0.5,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: SvgPicture.asset(
                                    'assets/images/logo_teenancial.svg',
                                    height: 120,
                                    placeholderBuilder: (context) =>
                                        const SizedBox(
                                      height: 120,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Selamat datang kembali!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontSize: 25,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Masuk untuk melanjutkan progresmu',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                CustomTextField(
                                  label: 'Email',
                                  hint: 'eg.nama@gmail.com',
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: primaryGreen,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  controller: _emailController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email wajib diisi';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                                CustomTextField(
                                  label: 'Password',
                                  hint: '********',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: primaryGreen,
                                  ),
                                  obscureText: _obscurePassword,
                                  controller: _passwordController,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: primaryGreen,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password wajib diisi';
                                    }
                                    return null;
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.only(
                                        top: 0,
                                        bottom: 16,
                                      ),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () =>
                                        context.go(AppRoutes.forgotPassword),
                                    child: const Text(
                                      'Lupa Password?',
                                      style: TextStyle(
                                        color: primaryGreen,
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryGreen,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: inputBg,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Masuk',
                                            style: TextStyle(
                                              color: inputBg,
                                              fontSize: 16,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: primaryGreen.withValues(
                                          alpha: 0.3,
                                        ),
                                        thickness: 1.5,
                                        endIndent: 12,
                                      ),
                                    ),
                                    const Text(
                                      'Atau masuk dengan',
                                      style: TextStyle(
                                        color: primaryGreen,
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: primaryGreen.withValues(
                                          alpha: 0.3,
                                        ),
                                        thickness: 1.5,
                                        indent: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _GoogleLoginButton(
                                  onTap:
                                      _isLoading ? () {} : _handleGoogleLogin,
                                ),
                                const SizedBox(height: 32),
                                Center(
                                  child: GestureDetector(
                                    onTap: () => context.go(AppRoutes.signup),
                                    child: const Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Belum punya akun? ',
                                            style: TextStyle(
                                              color: primaryGreen,
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Daftar',
                                            style: TextStyle(
                                              color: darkGreen,
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoogleLoginButton extends StatelessWidget {
  const _GoogleLoginButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: CustomCard(
          borderRadius: 12,
          padding: EdgeInsets.zero,
          backgroundColor: inputBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/google_icon.svg',
                height: 24,
                width: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Google',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
