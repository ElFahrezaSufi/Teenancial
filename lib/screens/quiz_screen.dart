import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/belajar_model.dart';
import '../providers/belajar_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/async_state_view.dart';

class QuizScreen extends StatefulWidget {
  final int levelIndex;
  final int moduleIndex;
  final ModuleData module;

  const QuizScreen({
    super.key,
    required this.levelIndex,
    required this.moduleIndex,
    required this.module,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  bool _showResult = false;
  bool _isClaiming = false;

  List<QuizQuestion> get _questions => widget.module.quiz.questions;
  int get _totalQuestions => _questions.length;

  int get _correctCount {
    int count = 0;
    for (int i = 0; i < _totalQuestions; i++) {
      if (_selectedAnswers[i] == _questions[i].correctIndex) count++;
    }
    return count;
  }

  int get _scorePercent =>
      _totalQuestions == 0 ? 0 : (_correctCount * 100 ~/ _totalQuestions);

  bool get _isLulus => _scorePercent >= widget.module.quiz.passingScore;

  void _pilihJawaban(int optionIndex) {
    if (_showResult) return;
    setState(() => _selectedAnswers[_currentIndex] = optionIndex);
  }

  void _lanjut() {
    if (_currentIndex < _totalQuestions - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _showResult = true);
    }
  }

  void _ulangi() {
    setState(() {
      _currentIndex = 0;
      _selectedAnswers.clear();
      _showResult = false;
    });
  }

  Future<void> _klaimXp() async {
    setState(() => _isClaiming = true);
    await context.read<BelajarProvider>().completeQuiz(
          widget.levelIndex,
          widget.moduleIndex,
          scorePercent: _scorePercent,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    if (!_showResult && _selectedAnswers.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Keluar dari Kuis?',
            style: TextStyle(
              color: primaryGreen,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Progres kuis ini tidak akan tersimpan. Yakin keluar?',
            style: TextStyle(
              color: primaryGreen,
              fontFamily: 'Inter',
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Lanjutkan Kuis',
                  style: TextStyle(
                      color: primaryGreen,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar',
                  style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return confirm ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: CustomAppBar(
          title: widget.module.quiz.label,
          showBackButton: true,
          onBack: () async {
            final canPop = await _onWillPop();
            if (canPop && context.mounted) Navigator.pop(context);
          },
        ),
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
            if (_questions.isEmpty)
              const EmptyStateView(
                icon: Icons.quiz_outlined,
                title: 'Soal belum tersedia',
                subtitle: 'Soal kuis untuk modul ini belum ditambahkan.',
              )
            else if (_showResult)
              _buildHasil()
            else
              _buildSoal(),
          ],
        ),
      ),
    );
  }

  // ─── Tampilan per soal ──────────────────────────────────────────────────────

  Widget _buildSoal() {
    final question = _questions[_currentIndex];
    final selected = _selectedAnswers[_currentIndex];
    final progress = (_currentIndex + 1) / _totalQuestions;

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Soal ${_currentIndex + 1} dari $_totalQuestions',
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: lightGreen.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Soal + pilihan
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card soal
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryGreen, width: 2),
                  ),
                  child: Text(
                    question.question,
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pilihan jawaban
                ...question.options.asMap().entries.map(
                  (entry) {
                    final i = entry.key;
                    final opt = entry.value;
                    final isSelected = selected == i;
                    final labels = ['A', 'B', 'C', 'D'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => _pilihJawaban(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryGreen : cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? primaryGreen : lightGreen,
                              width: isSelected ? 2 : 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : lightGreen.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : primaryGreen,
                                      fontSize: 13,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : primaryGreen,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Tombol lanjut
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: appBarBg,
            border: Border(top: BorderSide(color: lightGreen, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: GestureDetector(
              onTap: selected != null ? _lanjut : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selected != null
                      ? primaryGreen
                      : primaryGreen.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _currentIndex < _totalQuestions - 1
                        ? 'Lanjut →'
                        : 'Lihat Hasil',
                    style: const TextStyle(
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
    );
  }

  // ─── Tampilan hasil ──────────────────────────────────────────────────────────

  Widget _buildHasil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          // Icon hasil
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _isLulus
                  ? lightGreen.withValues(alpha: 0.4)
                  : Colors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isLulus ? Icons.emoji_events_outlined : Icons.replay_outlined,
              size: 48,
              color: _isLulus ? primaryGreen : Colors.orange,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _isLulus ? 'Selamat! Kamu Lulus 🎉' : 'Belum Lulus, Coba Lagi!',
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 20,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            '$_correctCount dari $_totalQuestions soal benar',
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 15,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nilai: $_scorePercent% (minimal ${widget.module.quiz.passingScore}%)',
            style: TextStyle(
              color: primaryGreen.withValues(alpha: 0.7),
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),

          // Progress skor
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _scorePercent / 100,
              minHeight: 10,
              backgroundColor: lightGreen.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(
                _isLulus ? primaryGreen : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Review soal
          ...List.generate(_totalQuestions, (i) {
            final q = _questions[i];
            final userAns = _selectedAnswers[i];
            final isCorrect = userAns == q.correctIndex;
            final labels = ['A', 'B', 'C', 'D'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCorrect ? primaryGreen : Colors.red.shade300,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle
                              : Icons.cancel_outlined,
                          color: isCorrect ? primaryGreen : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Soal ${i + 1}: ${q.question}',
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (userAns != null && !isCorrect)
                      Text(
                        'Jawaban kamu: ${labels[userAns]}. ${q.options[userAns]}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    Text(
                      'Jawaban benar: ${labels[q.correctIndex]}. ${q.options[q.correctIndex]}',
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '💡 ${q.explanation}',
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Tombol aksi
          if (_isLulus)
            GestureDetector(
              onTap: _isClaiming ? null : _klaimXp,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isClaiming
                      ? primaryGreen.withValues(alpha: 0.6)
                      : primaryGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _isClaiming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Selesai',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _ulangi,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: primaryGreen, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    '🔄 Ulangi Kuis',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
