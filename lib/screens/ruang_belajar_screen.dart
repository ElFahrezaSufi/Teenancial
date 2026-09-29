import 'package:flutter/material.dart';
import '../data/belajar_data.dart';
import '../widgets/common/custom_card.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);
const Color _cardBg = Color(0xFFF8FFE8);
const Color _lightGreen = Color(0xFFCADCA4);

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
      backgroundColor: _scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: _appBarBg,
            border: Border(
              bottom: BorderSide(color: _primaryGreen, width: 1.5),
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
                      color: _primaryGreen,
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
                        color: _primaryGreen, size: 20),
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
            color: _scaffoldBg,
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
                    .map((entry) => _LevelSection(
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

// ─── Level Section ────────────────────────────────────────────────────────────

class _LevelSection extends StatelessWidget {
  final int levelIndex;
  final LevelData level;
  final int completedCount;
  final void Function(int li, int mi) onCompleteModule;
  final void Function(int li, int mi) onCompleteQuiz;
  final void Function(int mi) onToggleExpand;

  const _LevelSection({
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
            backgroundColor: _cardBg,
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
                        color: _lightGreen.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        levelLocked
                            ? Icons.lock_outline
                            : Icons.school_outlined,
                        color: _primaryGreen,
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
                              color: _primaryGreen,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$completedCount/${level.modules.length} modul selesai',
                            style: const TextStyle(
                              color: _primaryGreen,
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
                    backgroundColor: _lightGreen,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  level.subtitle,
                  style: const TextStyle(
                    color: _primaryGreen,
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
                (e) => _ModuleCard(
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

// ─── Module Card ──────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final int levelIndex;
  final int moduleIndex;
  final ModuleData module;
  final void Function(int li, int mi) onCompleteModule;
  final void Function(int li, int mi) onCompleteQuiz;
  final VoidCallback onToggleExpand;

  const _ModuleCard({
    required this.levelIndex,
    required this.moduleIndex,
    required this.module,
    required this.onCompleteModule,
    required this.onCompleteQuiz,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final bool locked = module.status == ModuleStatus.locked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: locked ? null : onToggleExpand,
        child: CustomCard(
          backgroundColor: _cardBg,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _lightGreen.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        locked
                            ? Icons.lock_outline
                            : module.status == ModuleStatus.completed
                                ? Icons.check_circle_outline
                                : Icons.menu_book_outlined,
                        color: _primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        module.title,
                        style: const TextStyle(
                          color: _primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!locked)
                      Icon(
                        module.isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: _primaryGreen,
                        size: 20,
                      ),
                  ],
                ),
              ),
              if (!locked && module.isExpanded) ...[
                const Divider(height: 1, thickness: 1, color: _lightGreen),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '"${module.description}"',
                        style: const TextStyle(
                          color: _primaryGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _QuizBadge(quiz: module.quiz)),
                          const SizedBox(width: 10),
                          _ActionButton(
                            module: module,
                            onCompleteModule: () =>
                                onCompleteModule(levelIndex, moduleIndex),
                            onCompleteQuiz: () =>
                                onCompleteQuiz(levelIndex, moduleIndex),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quiz Badge ───────────────────────────────────────────────────────────────

class _QuizBadge extends StatelessWidget {
  final QuizData quiz;

  const _QuizBadge({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final bool quizLocked = quiz.status == ModuleStatus.locked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _lightGreen.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primaryGreen, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            quizLocked ? Icons.lock_outline : Icons.quiz_outlined,
            size: 14,
            color: _primaryGreen,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              quiz.label,
              style: const TextStyle(
                color: _primaryGreen,
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final ModuleData module;
  final VoidCallback onCompleteModule;
  final VoidCallback onCompleteQuiz;

  const _ActionButton({
    required this.module,
    required this.onCompleteModule,
    required this.onCompleteQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final bool moduleAvailable = module.status == ModuleStatus.available;
    final bool moduleCompleted = module.status == ModuleStatus.completed;
    final bool quizAvailable = module.quiz.status == ModuleStatus.available;
    final bool quizCompleted = module.quiz.status == ModuleStatus.completed;

    String label;
    VoidCallback? onTap;
    bool isOutlined = false;

    if (moduleAvailable) {
      label = 'Selesaikan Modul';
      onTap = () => _confirmComplete(
            context,
            title: 'Selesaikan Modul?',
            body: 'Tandai modul ini sebagai selesai dan buka kuis?',
            onConfirm: onCompleteModule,
          );
    } else if (moduleCompleted && quizAvailable) {
      label = 'Mulai Kuis';
      onTap = () => _confirmComplete(
            context,
            title: 'Mulai Kuis?',
            body: 'Kerjakan kuis untuk menyelesaikan modul ini sepenuhnya?',
            onConfirm: onCompleteQuiz,
          );
    } else if (moduleCompleted && quizCompleted) {
      label = 'Selesai ✓';
      onTap = null;
      isOutlined = true;
    } else {
      label = 'Terkunci';
      onTap = null;
      isOutlined = true;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : _primaryGreen,
          borderRadius: BorderRadius.circular(8),
          border:
              isOutlined ? Border.all(color: _primaryGreen, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isOutlined ? _primaryGreen : Colors.white,
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _confirmComplete(
    BuildContext context, {
    required String title,
    required String body,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: _primaryGreen,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(
            color: _primaryGreen,
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: _primaryGreen,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'Ya, Lanjutkan',
              style: TextStyle(
                color: _primaryGreen,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
