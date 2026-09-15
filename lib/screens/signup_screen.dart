import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/mock_auth.dart';
import 'login_screen.dart';

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

  // Controller untuk semua data pendaftaran
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      // Mengirim semua data
      final bool success = await MockAuth.register(
        name: _nameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _genderController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun berhasil dibuat! Silakan masuk.'),
            backgroundColor: _primaryGreen,
          ),
        );
        // Jika sukses, lempar user ke halaman Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email sudah terdaftar! Gunakan email lain.'),
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
                      left: 2, top: 6, right: 2, bottom: 0),
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
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Judul Halaman
                              const Text(
                                'Buat Akun Baru',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _primaryGreen,
                                  fontSize: 22,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Lengkapi data dirimu di bawah ini',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _primaryGreen,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Form Nama
                              const _FieldLabel('Nama Lengkap'),
                              const SizedBox(height: 8),
                              _RoundedTextField(
                                controller: _nameController,
                                hintText: 'Masukkan nama lengkap',
                                prefixIcon: Icons.person_outline,
                                validator: (value) =>
                                    value!.isEmpty ? 'Nama wajib diisi' : null,
                              ),
                              const SizedBox(height: 16),

                              // Form Baris: Umur & Gender
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _FieldLabel('Umur'),
                                        const SizedBox(height: 8),
                                        _RoundedTextField(
                                          controller: _ageController,
                                          hintText: '15',
                                          prefixIcon: Icons.cake_outlined,
                                          keyboardType: TextInputType.number,
                                          validator: (value) => value!.isEmpty
                                              ? 'Isi umur'
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _FieldLabel('Jenis Kelamin'),
                                        const SizedBox(height: 8),
                                        _RoundedTextField(
                                          controller: _genderController,
                                          hintText: 'Laki-Laki / Perempuan',
                                          prefixIcon: Icons.wc_outlined,
                                          validator: (value) => value!.isEmpty
                                              ? 'Isi kelamin'
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Form Email
                              const _FieldLabel('Email'),
                              const SizedBox(height: 8),
                              _RoundedTextField(
                                controller: _emailController,
                                hintText: 'eg.nama@gmail.com',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
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
                              const SizedBox(height: 16),

                              // Form Password
                              const _FieldLabel('Password'),
                              const SizedBox(height: 8),
                              _RoundedTextField(
                                controller: _passwordController,
                                hintText: '********',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _primaryGreen,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                validator: (value) => value!.isEmpty
                                    ? 'Password wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 32),

                              // Tombol Daftar
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignUp,
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
                                              strokeWidth: 2.5),
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

                              // Tombol Kembali ke Login
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen()),
                                    );
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
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: _primaryGreen,
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600));
  }
}

class _RoundedTextField extends StatelessWidget {
  const _RoundedTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      initialValue: controller.text,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: state.hasError ? Colors.redAccent : _primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.only(bottom: 2),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FFE8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: state.hasError ? Colors.redAccent : _primaryGreen,
                      width: 2),
                ),
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  onChanged: (value) => state.didChange(value),
                  style: const TextStyle(
                      color: _primaryGreen,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                        color: _primaryGreen.withValues(alpha: 0.5),
                        fontSize: 15,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500),
                    prefixIcon: Icon(prefixIcon,
                        color:
                            state.hasError ? Colors.redAccent : _primaryGreen,
                        size: 22),
                    suffixIcon: suffixIcon,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16),
                child: Text(state.errorText ?? '',
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600)),
              ),
          ],
        );
      },
    );
  }
}
