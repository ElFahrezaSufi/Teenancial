import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/belajar_model.dart';
import '../providers/belajar_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/belajar/level_section.dart';
import '../widgets/common/custom_app_bar.dart';

class RuangBelajarScreen extends StatelessWidget {
  const RuangBelajarScreen({super.key});

  int _completedCount(LevelData level) =>
      level.modules.where((m) => m.status == ModuleStatus.completed).length;

  @override
  Widget build(BuildContext context) {
    final belajarProvider = context.watch<BelajarProvider>();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(title: 'Ruang Belajar'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: scaffoldBg,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_curve.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: belajarProvider.levels
                    .asMap()
                    .entries
                    .map(
                      (entry) => LevelSection(
                        levelIndex: entry.key,
                        level: entry.value,
                        completedCount: _completedCount(entry.value),
                        onCompleteModule: (li, mi) =>
                            context.read<BelajarProvider>().completeModule(li, mi),
                        onCompleteQuiz: (li, mi) =>
                            context.read<BelajarProvider>().completeQuiz(li, mi),
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
}
