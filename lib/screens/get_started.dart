import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../config/app_routes.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';

class GetStarted extends StatelessWidget {
  const GetStarted({super.key});

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
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxLogoWidth = math.min(
                  270.0,
                  math.max(140.0, constraints.maxWidth - 64.0),
                );
                final double logoWidth = constraints.maxHeight < 620
                    ? math.min(maxLogoWidth, 190.0)
                    : maxLogoWidth;
                final double minContentHeight =
                    math.max(0.0, constraints.maxHeight - 48.0);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minContentHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Kelola Keuangan Anda dan\nWujudkan Target Finansial Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 20,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SvgPicture.asset(
                          'assets/images/logo_teenancial.svg',
                          width: logoWidth,
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            const Text(
                              'Belajar atur uang, bangun kebiasaan\nmenabung, dan wujudkan mimpimu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: () async {
                                await LocalStorageService.instance
                                    .setHasSeenGetStarted(true);
                                if (!context.mounted) return;
                                context.go(AppRoutes.login);
                              },
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 310),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 74,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          height: 68,
                                          decoration: BoxDecoration(
                                            color: primaryGreen,
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          height: 68,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: inputBg,
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            border: Border.all(
                                              width: 2,
                                              color: primaryGreen,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Mulai',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: primaryGreen,
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
