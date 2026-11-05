import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/belajar_model.dart';
import '../providers/belajar_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/belajar/level_section.dart';

class RuangBelajarScreen extends StatelessWidget {
  const RuangBelajarScreen({super.key});

  int _completedCount(LevelData level) =>
      level.modules.where((m) => m.status == ModuleStatus.completed).length;

  @override
  Widget build(BuildContext context) {
    final belajarProvider = context.watch<BelajarProvider>();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Center(
                  child: Text(
                    'Ruang Belajar',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 25,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: primaryGreen,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
