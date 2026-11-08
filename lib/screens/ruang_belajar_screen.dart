import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/belajar_model.dart';
import '../providers/belajar_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/belajar/level_section.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/skeleton.dart';

class RuangBelajarScreen extends StatelessWidget {
  const RuangBelajarScreen({super.key});

  int _completedCount(LevelData level) =>
      level.modules.where((m) => m.status == ModuleStatus.completed).length;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BelajarProvider>();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(title: 'Ruang Belajar', showBackButton: false),
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
                  children: provider.levels
                      .asMap()
                      .entries
                      .map(
                        (entry) => LevelSection(
                          levelIndex: entry.key,
                          level: entry.value,
                          completedCount: _completedCount(entry.value),
                          onToggleExpand: (mi) => context
                              .read<BelajarProvider>()
                              .toggleExpand(entry.key, mi),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: double.infinity, height: 100),
            const SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 60),
            const SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 60),
            const SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 60),
            const SizedBox(height: 24),
            Skeleton(width: double.infinity, height: 100),
            const SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 60),
            const SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 60),
          ],
        ),
      ),
    );
  }
}
