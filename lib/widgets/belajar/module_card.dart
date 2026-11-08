import 'package:flutter/material.dart';
import '../../models/belajar_model.dart';
import '../../screens/materi_screen.dart';
import '../../screens/quiz_screen.dart';
import '../../theme/app_colors.dart';
import '../common/custom_card.dart';

class ModuleCard extends StatelessWidget {
  final int levelIndex;
  final int moduleIndex;
  final ModuleData module;
  final VoidCallback onToggleExpand;

  const ModuleCard({
    super.key,
    required this.levelIndex,
    required this.moduleIndex,
    required this.module,
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
          backgroundColor: cardBg,
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
                        color: lightGreen.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        locked
                            ? Icons.lock_outline
                            : module.status == ModuleStatus.completed
                                ? Icons.check_circle_outline
                                : Icons.menu_book_outlined,
                        color: primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        module.title,
                        style: const TextStyle(
                          color: primaryGreen,
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
                        color: primaryGreen,
                        size: 20,
                      ),
                  ],
                ),
              ),
              if (!locked && module.isExpanded) ...[
                const Divider(height: 1, thickness: 1, color: lightGreen),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '"${module.description}"',
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (module.status == ModuleStatus.completed) ...[
                        _QuizBadge(quiz: module.quiz),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ReviewAction(
                                label: 'Baca Lagi',
                                icon: Icons.menu_book_outlined,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MateriScreen(
                                      levelIndex: levelIndex,
                                      moduleIndex: moduleIndex,
                                      module: module,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ReviewAction(
                                label:
                                    module.quiz.status == ModuleStatus.completed
                                        ? 'Ulangi Kuis'
                                        : 'Mulai Kuis',
                                icon: Icons.quiz_outlined,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QuizScreen(
                                      levelIndex: levelIndex,
                                      moduleIndex: moduleIndex,
                                      module: module,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(child: _QuizBadge(quiz: module.quiz)),
                            const SizedBox(width: 10),
                            _ActionButton(
                              levelIndex: levelIndex,
                              moduleIndex: moduleIndex,
                              module: module,
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
        color: lightGreen.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            quizLocked ? Icons.lock_outline : Icons.quiz_outlined,
            size: 14,
            color: primaryGreen,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              quiz.label,
              style: const TextStyle(
                color: primaryGreen,
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

class _ReviewAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ReviewAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: primaryGreen, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: primaryGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final int levelIndex;
  final int moduleIndex;
  final ModuleData module;

  const _ActionButton({
    required this.levelIndex,
    required this.moduleIndex,
    required this.module,
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
      label = 'Baca Materi';
      onTap = () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MateriScreen(
                levelIndex: levelIndex,
                moduleIndex: moduleIndex,
                module: module,
              ),
            ),
          );
    } else if (moduleCompleted && quizAvailable) {
      label = 'Mulai Kuis';
      onTap = () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizScreen(
                levelIndex: levelIndex,
                moduleIndex: moduleIndex,
                module: module,
              ),
            ),
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
          color: isOutlined ? Colors.transparent : primaryGreen,
          borderRadius: BorderRadius.circular(8),
          border:
              isOutlined ? Border.all(color: primaryGreen, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isOutlined ? primaryGreen : Colors.white,
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
