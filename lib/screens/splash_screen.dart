import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'get_started.dart';
import 'main_screen.dart';
import '../data/mock_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showIcon = false;
  bool _showText = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showIcon = true);
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showText = true);
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final Widget nextScreen =
          MockAuth.isLoggedIn ? const MainScreen() : const GetStarted();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(
            milliseconds: 400,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFE2),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SvgPicture.asset('assets/images/bg_curve.svg', fit: BoxFit.cover),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: _showIcon ? 1.0 : 0.0,
                duration: const Duration(seconds: 3),
                curve: Curves.easeIn,
                child: SvgPicture.asset(
                  'assets/images/logo_teenancial.svg',
                  width: 200,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _showText ? 1.0 : 0.0,
                duration: const Duration(seconds: 1),
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
