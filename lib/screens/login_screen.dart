import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'get_started.dart';
import 'signup_screen.dart';
import 'main_screen.dart';
import '../data/mock_auth.dart';

const Color _primaryGreen = Color(0xFF637932);
const Color _darkGreen = Color(0xFF415020);
const Color _fieldBg = Color(0xFFF8FFE8);
const Color _scaffoldBg = Color(0xFFEDEFE2);

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

  void _goToGetStarted() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GetStarted(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const beginOffset = Offset(0.0, -1.0);
          const endOffset = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var slideTween = Tween(
            begin: beginOffset,
            end: endOffset,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      final status = await MockAuth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (status == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil Masuk!'),
            backgroundColor: _primaryGreen,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else if (status == 'email_not_found') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Email tidak terdaftar. Silakan daftar terlebih dahulu!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (status == 'wrong_password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password salah! Coba lagi.'),
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
                                            alpha: 0.5),
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
                                            color: _primaryGreen),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Selamat datang kembali!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _primaryGreen,
                                    fontSize: 22,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Masuk untuk melanjutkan progresmu',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _primaryGreen,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 32),
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
                                    onPressed: () {
                                      setState(() =>
                                          _obscurePassword = !_obscurePassword);
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
                                          top: 8, bottom: 16),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {},
                                    child: const Text(
                                      'Lupa Password?',
                                      style: TextStyle(
                                          color: _primaryGreen,
                                          fontSize: 13,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryGreen,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
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
                                            'Masuk',
                                            style: TextStyle(
                                                color: _fieldBg,
                                                fontSize: 16,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Atau masuk dengan',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: _primaryGreen,
                                      fontSize: 13,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _SocialButton(
                                        icon: Icons.g_mobiledata, onTap: () {}),
                                    const SizedBox(width: 12),
                                    _SocialButton(
                                        icon: Icons.apple, onTap: () {}),
                                    const SizedBox(width: 12),
                                    _SocialButton(
                                        icon: Icons.facebook, onTap: () {}),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const SignUpScreen()),
                                      );
                                    },
                                    child: const Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                              text: 'Belum punya akun? ',
                                              style: TextStyle(
                                                  color: _primaryGreen,
                                                  fontSize: 14,
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w600)),
                                          TextSpan(
                                              text: 'Daftar',
                                              style: TextStyle(
                                                  color: _darkGreen,
                                                  fontSize: 14,
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w800)),
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
                  onChanged: (value) {
                    state.didChange(value);
                  },
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
              color: _primaryGreen, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFFF8FFE8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryGreen, width: 2)),
            alignment: Alignment.center,
            child: Icon(icon, color: _primaryGreen, size: 28),
          ),
        ),
      ),
    );
  }
}
