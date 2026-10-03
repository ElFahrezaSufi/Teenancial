import 'package:flutter/material.dart';
import '../data/belajar_data.dart';
import '../theme/app_colors.dart';
import '../widgets/belajar/level_section.dart';

class RuangBelajarScreen extends StatefulWidget {
  const RuangBelajarScreen({super.key});

  @override
  State<RuangBelajarScreen> createState() => _RuangBelajarScreenState();
}

class _RuangBelajarScreenState extends State<RuangBelajarScreen> {
  final _data = BelajarData.instance;

  void _completeModule(int levelIndex, int moduleIndex) {
    setState(() => _data.completeModule(levelIndex, moduleIndex));
  }

  void _completeQuiz(int levelIndex, int moduleIndex) {
    setState(() => _data.completeQuiz(levelIndex, moduleIndex));
  }

  int _completedCount(LevelData level) =>
      level.modules.where((m) => m.status == ModuleStatus.completed).length;

  @override
  Widget build(BuildContext context) {
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
                    icon: const Icon(Icons.arrow_back_ios,
                        color: primaryGreen, size: 20),
                    onPressed: () => Navigator.pop(context),
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
                children: _data.levels
                    .asMap()
                    .entries
                    .map((entry) => LevelSection(
                          levelIndex: entry.key,
                          level: entry.value,
                          completedCount: _completedCount(entry.value),
                          onCompleteModule: _completeModule,
                          onCompleteQuiz: _completeQuiz,
                          onToggleExpand: (mi) => setState(() {
                            entry.value.modules[mi].isExpanded =
                                !entry.value.modules[mi].isExpanded;
                          }),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
