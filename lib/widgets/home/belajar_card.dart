import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/belajar_provider.dart';
import '../../theme/app_colors.dart';
import '../common/custom_card.dart';

class BelajarCard extends StatelessWidget {
  const BelajarCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BelajarProvider>();
    final current = provider.currentModule;

    late final String judulModul;
    late final String labelTingkat;
    late final double progress;

    if (provider.isLoading) {
      judulModul = 'Memuat materi belajar...';
      labelTingkat = '';
      progress = 0.0;
    } else if (provider.levels.isEmpty) {
      judulModul = 'Ketuk untuk memuat materi belajar';
      labelTingkat = '';
      progress = 0.0;
    } else if (current != null) {
      judulModul = current.module.title;
      labelTingkat = 'Tingkat: ${current.level.tingkat}';
      progress = current.levelProgress;
    } else {
      judulModul = 'Semua modul selesai!';
      labelTingkat = '';
      progress = 1.0;
    }

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book, color: primaryGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        judulModul,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (labelTingkat.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        labelTingkat,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 11,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: lightGreen,
                    color: primaryGreen,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
