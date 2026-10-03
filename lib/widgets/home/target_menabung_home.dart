import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/target_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/custom_card.dart';

class TargetMenabungHome extends StatelessWidget {
  final TargetItem? currentTarget;
  final double totalSaldoReal;
  final String Function(double) formatRupiah;
  final VoidCallback onTambahTarget;

  const TargetMenabungHome({
    super.key,
    required this.currentTarget,
    required this.totalSaldoReal,
    required this.formatRupiah,
    required this.onTambahTarget,
  });

  @override
  Widget build(BuildContext context) {
    if (currentTarget != null) {
      final double progress = currentTarget!.targetAmount > 0
          ? (totalSaldoReal / currentTarget!.targetAmount).clamp(0.0, 1.0)
          : 0.0;

      return Column(
        children: [
          CustomCard(
            backgroundColor: cardBg,
            borderRadius: 20,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  child: Image.file(
                    File(currentTarget!.imageUrl),
                    height: 167,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                        height: 167,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currentTarget!.nama, style: AppTextStyles.sectionTitle),
                      Text(
                        '${formatRupiah(totalSaldoReal)}/ ${formatRupiah(currentTarget!.targetAmount)}',
                        style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: lightGreen,
                      color: primaryGreen,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTambahTarget,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16, color: Color(0xFFDAB62C)),
                  SizedBox(width: 4),
                  Text(
                    'Buat Target Baru',
                    style: TextStyle(
                      color: Color(0xFFDAB62C),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return CustomCard(
        backgroundColor: cardBg,
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: primaryGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text('Belum ada target impian nih!', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 4),
            const Text(
              'Yuk mulai tabung uangmu untuk beli barang impianmu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Inter'),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onTambahTarget,
              child: CustomCard(
                borderRadius: 100,
                backgroundColor: primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Buat Target Baru',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      );
    }
  }
}
