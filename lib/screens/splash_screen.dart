import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../config/app_routes.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showIcon = false;
  bool _showText = false;
  Timer? _iconTimer;
  Timer? _textTimer;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Mulai urutan animasi hanya setelah frame pertama selesai dirender dan
    // gambar logo sudah di-decode ke memori (penting saat Cold Start agar
    // animasi logo & teks tidak terlewat selama transisi native splash).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await precacheImage(
        const AssetImage('assets/images/logo_teenancial.png'),
        context,
      );
      if (!mounted) return;

      _iconTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _showIcon = true);
      });

      _textTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _showText = true);
      });

      _navTimer = Timer(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        context.go(AppRoutes.home);
      });
    });
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _textTimer?.cancel();
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SvgPicture.asset('assets/images/bg_curve.svg', fit: BoxFit.cover),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: _showIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: Image.asset(
                  'assets/images/logo_teenancial.png',
                  width: 200,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _showText ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeIn,
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'teen',
                        style: TextStyle(
                          color: Color(0xFF366030),
                          fontSize: 36,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: 'ancial',
                        style: TextStyle(
                          color: Color(0xFFDAB62C),
                          fontSize: 36,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
