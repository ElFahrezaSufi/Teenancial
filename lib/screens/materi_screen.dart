import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/belajar_model.dart';
import '../providers/belajar_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/skeleton.dart';

class MateriScreen extends StatefulWidget {
  final int levelIndex;
  final int moduleIndex;
  final ModuleData module;

  const MateriScreen({
    super.key,
    required this.levelIndex,
    required this.moduleIndex,
    required this.module,
  });

  @override
  State<MateriScreen> createState() => _MateriScreenState();
}

class _MateriScreenState extends State<MateriScreen> {
  bool _isCompleting = false;

  Future<void> _tandaiSelesai() async {
    setState(() => _isCompleting = true);
    await context
        .read<BelajarProvider>()
        .completeModule(widget.levelIndex, widget.moduleIndex);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final bool isAvailable = module.status == ModuleStatus.available;
    final bool isCompleted = module.status == ModuleStatus.completed;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(
        title: 'Materi',
        showBackButton: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),

          // Konten
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header card
                      CustomCard(
                        backgroundColor: cardBg,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: lightGreen.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.menu_book_outlined,
                                color: primaryGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    module.title,
                                    style: const TextStyle(
                                      color: primaryGreen,
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _StatusBadge(status: module.status),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Deskripsi
                      CustomCard(
                        backgroundColor: cardBg,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tentang Modul Ini',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              module.description,
                              style: const TextStyle(
                                color: primaryGreen,
                                fontSize: 13,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sections materi
                      if (module.sections.isEmpty) ...[
                        const Text(
                          'Memuat materi...',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Skeleton(width: double.infinity, height: 20, radius: 8),
                        const SizedBox(height: 8),
                        const Skeleton(width: double.infinity, height: 80, radius: 8),
                        const SizedBox(height: 8),
                        const Skeleton(width: double.infinity, height: 20, radius: 8),
                        const SizedBox(height: 8),
                        const Skeleton(width: double.infinity, height: 80, radius: 8),
                      ] else ...[
                        ...module.sections.map(
                          (section) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: CustomCard(
                              backgroundColor: cardBg,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (section.heading.isNotEmpty) ...[
                                    Text(
                                      section.heading,
                                      style: const TextStyle(
                                        color: primaryGreen,
                                        fontSize: 15,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Text(
                                    section.body,
                                    style: const TextStyle(
                                      color: primaryGreen,
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                      height: 1.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Referensi
                      if (module.references.isNotEmpty) ...[
                        CustomCard(
                          backgroundColor: cardBg,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📚 Referensi',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...module.references.map(
                                (ref) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '• ',
                                        style: TextStyle(
                                          color: primaryGreen,
                                          fontSize: 13,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          ref,
                                          style: const TextStyle(
                                            color: primaryGreen,
                                            fontSize: 13,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w400,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom button
              if (isAvailable || isCompleted)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  decoration: const BoxDecoration(
                    color: appBarBg,
                    border: Border(
                      top: BorderSide(color: lightGreen, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: isCompleted
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: primaryGreen, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: primaryGreen, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Modul Selesai',
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontSize: 15,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: _isCompleting ? null : _tandaiSelesai,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _isCompleting
                                    ? primaryGreen.withValues(alpha: 0.6)
                                    : primaryGreen,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: _isCompleting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Tandai Selesai & Lanjut',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ModuleStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final IconData icon;

    switch (status) {
      case ModuleStatus.available:
        label = 'Tersedia';
        bg = lightGreen.withValues(alpha: 0.5);
        icon = Icons.play_circle_outline;
      case ModuleStatus.completed:
        label = 'Selesai';
        bg = primaryGreen.withValues(alpha: 0.15);
        icon = Icons.check_circle_outline;
      case ModuleStatus.locked:
        label = 'Terkunci';
        bg = Colors.grey.withValues(alpha: 0.15);
        icon = Icons.lock_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
