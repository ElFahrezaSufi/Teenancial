import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/custom_card.dart';

class TotalSaldoCard extends StatelessWidget {
  final double totalSaldoReal;
  final double perkiraanMingguanReal;
  final double xpProgress;
  final int currentXP;
  final int maxXP;
  final int level;
  final String Function(double) formatRupiah;
  final VoidCallback onTap;

  const TotalSaldoCard({
    super.key,
    required this.totalSaldoReal,
    required this.perkiraanMingguanReal,
    required this.xpProgress,
    required this.currentXP,
    required this.maxXP,
    required this.level,
    required this.formatRupiah,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomCard(
        backgroundColor: cardBg,
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Saldo', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 4),
            Text(formatRupiah(totalSaldoReal), style: AppTextStyles.balanceText),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: xpProgress,
                backgroundColor: lightGreen,
                color: primaryGreen,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$currentXP/$maxXP xp menuju level ${level + 1}',
              style: AppTextStyles.captionGreen,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/perkiraan.png',
                        width: 16,
                        height: 16,
                        color: iconLightGreen,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Perkiraan Minggu Depan',
                        style: TextStyle(
                          color: iconLightGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formatRupiah(perkiraanMingguanReal),
                    style: const TextStyle(
                      color: iconLightGreen,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
