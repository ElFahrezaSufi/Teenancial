import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../providers/auth_provider.dart';
import '../routes/app_router.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/auth_scaffold.dart';
import '../widgets/common/custom_text_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  static const Map<String, String> _commonDomainTypos = {
    'gmai.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'outlok.com': 'outlook.com',
    'hotmial.com': 'hotmail.com',
    'iclod.com': 'icloud.com',
    'iclud.com': 'icloud.com',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        await context.read<AuthProvider>().register(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              name: _nameController.text.trim(),
            );
        await LocalStorageService.instance.setHasSeenGetStarted(true);

        rootScaffoldMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Akun dibuat! Verifikasi email untuk menyelesaikan pendaftaran.',
              ),
              backgroundColor: primaryGreen,
            ),
          );

        if (!mounted) return;
        setState(() => _isLoading = false);
        context.go(AppRoutes.verifyEmail);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMapper.message(
                e,
                fallback: 'Gagal mendaftar. Terjadi kesalahan sistem.',
              ),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMapper.message(
                e,
                fallback: 'Terjadi kesalahan sistem, silakan coba lagi.',
              ),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      formKey: _formKey,
      children: [
        const SizedBox(height: 28),
        const Text(
          'Yuk, buat akunmu!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryGreen,
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
            color: primaryGreen,
          ),
          controller: _nameController,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Nama wajib diisi' : null,
        ),
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
              final suggestion = _commonDomainTypos[domain];
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
            onPressed: () => setState(
              () => _obscurePassword = !_obscurePassword,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password wajib diisi';
            }
            if (value.length < 8) {
              return 'Password minimal 8 karakter';
            }
            return null;
          },
        ),
        CustomTextField(
          label: 'Konfirmasi Password',
          hint: '********',
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: primaryGreen,
          ),
          obscureText: _obscureConfirmPassword,
          controller: _confirmPasswordController,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: primaryGreen,
              size: 20,
            ),
            onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
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
            onPressed: _isLoading ? null : _handleSignUp,
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
                    'Daftar Sekarang',
                    style: TextStyle(
                      color: inputBg,
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
                      color: primaryGreen,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: 'Masuk',
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
    );
  }
}
