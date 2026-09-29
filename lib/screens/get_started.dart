import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart'; // Import go_router

class GetStarted extends StatelessWidget {
  const GetStarted({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFE2),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFFEDEFE2),
            child: SvgPicture.asset(
              'assets/images/bg_curve.svg',
              fit: BoxFit.cover,
              placeholderBuilder: (context) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Kelola Keuangan Anda dan\nWujudkan Target Finansial Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF627931),
                      fontSize: 20,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/images/logo_teenancial.svg',
                    width: 270,
                  ),
                  Column(
                    children: [
                      const Text(
                        'Belajar atur uang, bangun kebiasaan\nmenabung, dan wujudkan mimpimu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF627931),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () {
                          // Menggunakan go_router untuk pindah ke halaman login
                          context.go('/login');
                        },
                        child: SizedBox(
                          width: 310,
                          height: 74,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 310,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF637932),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 310,
                                  height: 68,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FFE8),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      width: 2,
                                      color: const Color(0xFF637932),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Mulai',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF637932),
                                        fontSize: 18,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
