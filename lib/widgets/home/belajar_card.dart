import 'package:flutter/material.dart';
import '../../data/belajar_data.dart';
import '../../theme/app_colors.dart';
import '../common/custom_card.dart';

class BelajarCard extends StatelessWidget {
  BelajarCard({super.key});

  final _data = BelajarData.instance;

  @override
  Widget build(BuildContext context) {
    final current = _data.currentModule;

    final String judulModul = current?.module.title ?? 'Semua modul selesai!';
    final String labelTingkat =
        current != null ? 'Tingkat: ${current.level.tingkat}' : '';
    final double progress = current?.levelProgress ?? 1.0;

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
                color: lightGreen, borderRadius: BorderRadius.circular(12)),
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
                            fontWeight: FontWeight.w800),
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
                            fontWeight: FontWeight.w600),
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
                      minHeight: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
