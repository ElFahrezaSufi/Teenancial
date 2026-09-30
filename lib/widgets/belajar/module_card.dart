import 'package:flutter/material.dart';
import '../../data/belajar_data.dart';
import '../../theme/app_colors.dart';
import '../common/custom_card.dart';

class ModuleCard extends StatelessWidget {
  final int levelIndex;
  final int moduleIndex;
  final ModuleData module;
  final void Function(int li, int mi) onCompleteModule;
  final void Function(int li, int mi) onCompleteQuiz;
  final VoidCallback onToggleExpand;

  const ModuleCard({
    super.key,
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

  void _confirmComplete(
    BuildContext context, {
    required String title,
    required String body,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: primaryGreen,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(
            color: primaryGreen,
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
                color: primaryGreen,
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
                color: primaryGreen,
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
