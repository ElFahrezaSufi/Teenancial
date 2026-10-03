import 'package:flutter/material.dart';
import '../../data/belajar_data.dart';
import '../../theme/app_colors.dart';
import '../common/custom_card.dart';
import 'module_card.dart';

class LevelSection extends StatelessWidget {
  final int levelIndex;
  final LevelData level;
  final int completedCount;
  final void Function(int li, int mi) onCompleteModule;
  final void Function(int li, int mi) onCompleteQuiz;
  final void Function(int mi) onToggleExpand;

  const LevelSection({
    super.key,
    required this.levelIndex,
    required this.level,
    required this.completedCount,
    required this.onCompleteModule,
    required this.onCompleteQuiz,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final bool levelLocked = level.modules.first.status == ModuleStatus.locked;
    final double progress =
        level.modules.isEmpty ? 0 : completedCount / level.modules.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomCard(
            backgroundColor: cardBg,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: lightGreen.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        levelLocked
                            ? Icons.lock_outline
                            : Icons.school_outlined,
                        color: primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tingkat: ${level.tingkat}',
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$completedCount/${level.modules.length} modul selesai',
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: lightGreen,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  level.subtitle,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Module cards ───────────────────────────────────────────────────
          ...level.modules.asMap().entries.map(
                (e) => ModuleCard(
                  levelIndex: levelIndex,
                  moduleIndex: e.key,
                  module: e.value,
                  onCompleteModule: onCompleteModule,
                  onCompleteQuiz: onCompleteQuiz,
                  onToggleExpand: () => onToggleExpand(e.key),
                ),
              ),
        ],
      ),
    );
  }
}
