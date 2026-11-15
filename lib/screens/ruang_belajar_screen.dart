import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/feen_catalog.dart';
import '../models/belajar_model.dart';
import '../providers/belajar_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/belajar/level_section.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/skeleton.dart';
import '../widgets/feen/feen_avatar.dart';

class RuangBelajarScreen extends StatelessWidget {
  const RuangBelajarScreen({super.key});

  int _completedCount(LevelData level) =>
      level.modules.where((m) => m.status == ModuleStatus.completed).length;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BelajarProvider>();
    final user = context.watch<UserProvider>();
    final nextModule = provider.currentModule;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(title: 'Ruang Belajar'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),
          if (provider.isLoading)
            _buildLoading()
          else if (provider.errorMessage != null)
            ErrorStateView(
              errorMessage: provider.errorMessage!,
              onRetry: () => context.read<BelajarProvider>().loadAll(),
            )
          else if (provider.levels.isEmpty)
            const EmptyStateView(
              icon: Icons.school_outlined,
              title: 'Belum ada materi',
              subtitle: 'Konten Ruang Belajar sedang disiapkan.',
            )
          else
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomCard(
                      backgroundColor: appBarBg,
                      borderRadius: 16,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          FeenAvatar(
                            level: user.level,
                            pose: FeenPose.learning,
                            equipped: user.feenEquipped,
                            size: 56,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nextModule != null
                                      ? 'Yuk lanjut belajar!'
                                      : 'Keren banget!',
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nextModule != null
                                      ? 'Berikutnya: ${nextModule.module.title}'
                                      : 'Semua materi keuangan sudah kamu selesaikan!',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: primaryGreen.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...provider.levels.asMap().entries.map(
                          (entry) => LevelSection(
                            levelIndex: entry.key,
                            level: entry.value,
                            completedCount: _completedCount(entry.value),
                            onToggleExpand: (mi) => context
                                .read<BelajarProvider>()
                                .toggleExpand(entry.key, mi),
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: double.infinity, height: 100),
            SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 60),
            SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 60),
            SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 60),
            SizedBox(height: 24),
            Skeleton(width: double.infinity, height: 100),
            SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 60),
            SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 60),
          ],
        ),
      ),
    );
  }
}
