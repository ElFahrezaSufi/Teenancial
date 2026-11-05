import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../providers/auth_provider.dart';
import '../services/local_storage_service.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/custom_text_field.dart';

const Color _primaryGreen = Color(0xFF637932);
const Color _darkGreen = Color(0xFF415020);
const Color _fieldBg = Color(0xFFF8FFE8);
const Color _scaffoldBg = Color(0xFFEDEFE2);

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  static const Map<String, String> _commonDomainTypos = {
    'gmai.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'outlok.com': 'outlook.com',
    'hotmial.com': 'hotmail.com',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToGetStarted() {
    context.go(AppRoutes.getStarted);
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        await context.read<AuthProvider>().register(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              name: _nameController.text.trim(),
              age: _ageController.text.trim(),
              gender: _selectedGender ?? '',
            );
        await LocalStorageService.instance.setHasSeenGetStarted(true);

        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Akun berhasil dibuat! Selamat datang.'),
            backgroundColor: _primaryGreen,
          ),
        );

        context.go(AppRoutes.home);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        String errorMessage = 'Gagal mendaftar. Terjadi kesalahan sistem.';
        if (e.code == 'email-already-in-use') {
          errorMessage =
              'Email ini sudah terdaftar! Silakan gunakan email lain atau langsung Masuk.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Format email tidak valid.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: _scaffoldBg,
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
                      _goToGetStarted();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _primaryGreen,
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
                        color: _fieldBg,
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
                                    onTap: _goToGetStarted,
                                    child: Container(
                                      width: 80,
                                      height: 5,
                                      margin: const EdgeInsets.only(bottom: 24),
                                      decoration: BoxDecoration(
                                        color: _primaryGreen.withValues(
                                          alpha: 0.5,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  'Yuk, buat akunmu!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _primaryGreen,
                                    fontSize: 30,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                CustomTextField(
                                  label: 'Nama Lengkap',
                                  hint: 'Masukkan nama lengkap',
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: _primaryGreen,
                                  ),
                                  controller: _nameController,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Nama wajib diisi'
                                          : null,
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: CustomTextField(
                                        label: 'Umur',
                                        hint: '15',
                                        prefixIcon: const Icon(
                                          Icons.cake_outlined,
                                          color: _primaryGreen,
                                        ),
                                        keyboardType: TextInputType.number,
                                        controller: _ageController,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Isi umur';
                                          }
                                          final age =
                                              int.tryParse(value.trim());
                                          if (age == null) {
                                            return 'Harus angka';
                                          }
                                          if (age < 10 || age > 100) {
                                            return '10 - 100 thn';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: CustomDropdownField(
                                        label: 'Jenis Kelamin',
                                        hint: 'Pilih Gender',
                                        value: _selectedGender,
                                        items: const ['Laki-Laki', 'Perempuan'],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedGender = value;
                                          });
                                        },
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                                ? 'Pilih kelamin'
                                                : null,
                                      ),
                                    ),
                                  ],
                                ),
                                CustomTextField(
                                  label: 'Email',
                                  hint: 'eg.nama@gmail.com',
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: _primaryGreen,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  controller: _emailController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email wajib diisi';
                                    }

                                    final email = value.trim().toLowerCase();
                                    final emailRegex = RegExp(
                                      r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$',
                                    );
                                    if (!emailRegex.hasMatch(email)) {
                                      return 'Format email salah (contoh: nama@gmail.com)';
                                    }

                                    final parts = email.split('@');
                                    if (parts.length == 2) {
                                      final domain = parts[1];
                                      final suggestion =
                                          _commonDomainTypos[domain];
                                      if (suggestion != null) {
                                        return 'Domain tidak dikenal, maksudmu @$suggestion?';
                                      }
                                    }

                                    return null;
                                  },
                                ),
                                CustomTextField(
                                  label: 'Password',
                                  hint: '********',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: _primaryGreen,
                                  ),
                                  obscureText: _obscurePassword,
                                  controller: _passwordController,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _primaryGreen,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password wajib diisi';
                                    }
                                    if (value.length < 6) {
                                      return 'Password minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                CustomTextField(
                                  label: 'Konfirmasi Password',
                                  hint: '********',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: _primaryGreen,
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  controller: _confirmPasswordController,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _primaryGreen,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Konfirmasi password wajib diisi';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Password tidak cocok dengan di atas';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _handleSignUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryGreen,
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
                                              color: _fieldBg,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Daftar Sekarang',
                                            style: TextStyle(
                                              color: _fieldBg,
                                              fontSize: 16,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      context.go(AppRoutes.login);
                                    },
                                    child: const Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Sudah punya akun? ',
                                            style: TextStyle(
                                              color: _primaryGreen,
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Masuk',
                                            style: TextStyle(
                                              color: _darkGreen,
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
