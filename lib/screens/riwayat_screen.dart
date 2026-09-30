import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import 'pemasukan_screen.dart';
import 'pengeluaran_screen.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);
const Color _cardBg = Color(0xFFF7FFE7);
const Color _orangeText = Color(0xFFE18151);
const Color _lightGreen = Color(0xFFCADCA4);

// ─── Data model untuk UI ──────────────────────────────────────────────────────

class TransactionGroup {
  final String dateLabel;
  final List<TransactionModel> items;

  const TransactionGroup({required this.dateLabel, required this.items});
}

// ─── Chart painter ───────────────────────────────────────────────────────────

class _TrendChartPainter extends CustomPainter {
  final List<double> values;

  _TrendChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double minVal = values.reduce(min);
    final double maxVal = values.reduce(max);
    final double range = (maxVal - minVal) == 0 ? 1 : maxVal - minVal;

    final gridPaint = Paint()
      ..color = _lightGreen.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const int gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      final double y = size.height * i / gridLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length == 1) {
      // Just draw a line in the middle if only one value
      final double y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = const Color(0xFFE53935)..strokeWidth = 2);
      canvas.drawCircle(Offset(size.width/2, y), 3, Paint()..color = const Color(0xFFE53935));
      return;
    }

    final List<Offset> points = [];
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * i / (values.length - 1);
      final double normalized = (values[i] - minVal) / range;
      final double y = size.height * (1 - normalized);
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE53935).withValues(alpha: 0.15),
          const Color(0xFFE53935).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter oldDelegate) => true;
}

// ─── Loading state ───────────────────────────────────────────────────────────

enum _LoadState { loading, success, error, empty }

// ─── Screen ──────────────────────────────────────────────────────────────────

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  int _selectedFilter = 0; // 0: Mingguan, 1: Bulanan, 2: Tahunan
  _LoadState _loadState = _LoadState.loading;
  String _errorMessage = '';
  
  List<TransactionModel> _allTransactions = [];
  List<TransactionGroup> _filteredGroups = [];
  List<double> _trendData = [];
  String _maxLabel = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool simulateError = false}) async {
    setState(() => _loadState = _LoadState.loading);
    try {
      final data = await TransactionRepository.instance.getTransactions(simulateError: simulateError);
      _allTransactions = data;
      _processData();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loadState = _LoadState.error;
      });
    }
  }

  void _processData() {
    if (_allTransactions.isEmpty) {
      setState(() {
        _loadState = _LoadState.empty;
        _filteredGroups = [];
        _trendData = [];
      });
      return;
    }

    final now = DateTime.now();
    DateTime cutoff;
    if (_selectedFilter == 0) {
      cutoff = now.subtract(const Duration(days: 7));
    } else if (_selectedFilter == 1) {
      cutoff = now.subtract(const Duration(days: 30));
    } else {
      cutoff = now.subtract(const Duration(days: 365));
    }

    final filtered = _allTransactions.where((t) => t.date.isAfter(cutoff)).toList();
    
    if (filtered.isEmpty) {
      setState(() {
        _loadState = _LoadState.empty;
        _filteredGroups = [];
        _trendData = [];
      });
      return;
    }

    // Grouping
    final Map<String, List<TransactionModel>> groups = {};
    for (var t in filtered) {
      // Create date label like "Rabu, 08 Juli 2026"
      final dateStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(t.date);
      if (!groups.containsKey(dateStr)) groups[dateStr] = [];
      groups[dateStr]!.add(t);
    }

    _filteredGroups = groups.entries.map((e) => TransactionGroup(dateLabel: e.key, items: e.value)).toList();
    // Sort groups descending
    _filteredGroups.sort((a, b) => b.items.first.date.compareTo(a.items.first.date));

    // Trend calculation (Cumulative balance over the period, reversed so chronological)
    filtered.sort((a, b) => a.date.compareTo(b.date)); // chronological
    double balance = 0.0;
    _trendData = [];
    for (var t in filtered) {
      if (t.type == TransactionType.income) {
        balance += t.amount;
      } else {
        balance -= t.amount;
      }
      _trendData.add(balance);
    }
    if (_trendData.isEmpty) _trendData = [0.0];

    // Max Label calculation (just total income in that period for simplicity)
    double totalIncome = filtered.where((t) => t.type == TransactionType.income).fold(0, (sum, t) => sum + t.amount);
    _maxLabel = '+ ${_formatCurrency(totalIncome)}';

    setState(() {
      _loadState = _LoadState.success;
    });
  }

  String _formatCurrency(double amount) {
    final parts = amount.abs().toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
      count++;
    }
    final reversed = buffer.toString().split('').reversed.join();
    return 'Rp $reversed,00';
  }

  Future<void> _deleteTransaction(String id) async {
    // Tampilkan Dialog Konfirmasi Destruktif
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi', style: TextStyle(color: _primaryGreen)),
        content: const Text('Apakah Anda yakin ingin menghapus data ini? Aksi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Proses delete
    setState(() => _loadState = _LoadState.loading);
    try {
      await TransactionRepository.instance.deleteTransaction(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Data berhasil dihapus!'), backgroundColor: _primaryGreen),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
      _loadData(); // reload anyway to reset loading state
    }
  }

  Future<void> _editTransaction(TransactionModel item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => item.type == TransactionType.income 
          ? PemasukanScreen(transactionToEdit: item) 
          : PengeluaranScreen(transactionToEdit: item),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: Container(
        decoration: const BoxDecoration(
          color: _appBarBg,
          border: Border(
            bottom: BorderSide(color: _primaryGreen, width: 1.5),
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              'Riwayat',
              style: TextStyle(
                color: _primaryGreen,
                fontSize: 25,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
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
            Row(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Skeleton(width: 80, height: 34, radius: 20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Skeleton(width: 100, height: 16),
            const SizedBox(height: 10),
            _Skeleton(width: double.infinity, height: 180),
            const SizedBox(height: 24),
            _Skeleton(width: 130, height: 16),
            const SizedBox(height: 12),
            _Skeleton(width: double.infinity, height: 72),
            const SizedBox(height: 10),
            _Skeleton(width: double.infinity, height: 72),
            const SizedBox(height: 10),
            _Skeleton(width: double.infinity, height: 72),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Oops, terjadi kesalahan!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryGreen),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              ),
              onPressed: () => _loadData(),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: _primaryGreen.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Belum ada transaksi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryGreen),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coba ubah filter atau catat pemasukan dan pengeluaran pertamamu!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups = _filteredGroups.take(2).toList();

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: _buildAppBar(),
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
          if (_loadState == _LoadState.loading) _buildLoading(),
          if (_loadState == _LoadState.error) _buildError(),
          if (_loadState == _LoadState.success || _loadState == _LoadState.empty)
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _FilterChip(
                          label: 'Mingguan',
                          selected: _selectedFilter == 0,
                          onTap: () {
                            setState(() => _selectedFilter = 0);
                            _processData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Bulanan',
                          selected: _selectedFilter == 1,
                          onTap: () {
                            setState(() => _selectedFilter = 1);
                            _processData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Tahunan',
                          selected: _selectedFilter == 2,
                          onTap: () {
                            setState(() => _selectedFilter = 2);
                            _processData();
                          },
                        ),
                      ],
                    ),
                    
                    if (_loadState == _LoadState.empty)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: _buildEmpty(),
                      )
                    else ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Tren Saldo',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _primaryGreen, width: 2),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _maxLabel,
                              style: const TextStyle(
                                color: _primaryGreen,
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 150,
                              child: CustomPaint(
                                painter: _TrendChartPainter(_trendData),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aktivitas Terbaru',
                            style: TextStyle(
                              color: _primaryGreen,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_filteredGroups.isNotEmpty)
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _SemuaAktivitasScreen(
                                      groups: _filteredGroups,
                                      formatCurrency: _formatCurrency,
                                      onEdit: _editTransaction,
                                      onDelete: _deleteTransaction,
                                    ),
                                  ),
                                );
                                if (result == true) _loadData();
                              },
                              child: const Text(
                                'Lihat semua',
                                style: TextStyle(
                                  color: _orangeText,
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...visibleGroups.map(
                        (group) => _TransactionGroup(
                          group: group,
                          formatCurrency: _formatCurrency,
                          onEdit: _editTransaction,
                          onDelete: _deleteTransaction,
                        ),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Semua Aktivitas screen ───────────────────────────────────────────────────

class _SemuaAktivitasScreen extends StatelessWidget {
  final List<TransactionGroup> groups;
  final String Function(double) formatCurrency;
  final Function(TransactionModel) onEdit;
  final Function(String) onDelete;

  const _SemuaAktivitasScreen({
    required this.groups,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

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
                    'Semua Aktivitas',
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
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: _primaryGreen, size: 20),
                    onPressed: () => Navigator.pop(context, true), // signal refresh
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
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...groups.map(
                    (group) => _TransactionGroup(
                      group: group,
                      formatCurrency: formatCurrency,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryGreen, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _primaryGreen,
            fontSize: 13,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Transaction group ────────────────────────────────────────────────────────

class _TransactionGroup extends StatelessWidget {
  final TransactionGroup group;
  final String Function(double) formatCurrency;
  final Function(TransactionModel) onEdit;
  final Function(String) onDelete;

  const _TransactionGroup({
    required this.group,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.dateLabel,
          style: const TextStyle(
            color: _orangeText,
            fontSize: 13,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...group.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TransactionCard(
              item: item,
              formatCurrency: formatCurrency,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Transaction card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final TransactionModel item;
  final String Function(double) formatCurrency;
  final Function(TransactionModel) onEdit;
  final Function(String) onDelete;

  const _TransactionCard({
    required this.item,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = TransactionRepository.instance.getCategoryById(item.categoryId);
    final bool isExpense = item.type == TransactionType.expense;

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 4, top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryGreen, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _lightGreen.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(cat.icon, color: _primaryGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.notes.isNotEmpty ? item.notes : cat.name,
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            (isExpense ? '- ' : '+ ') + formatCurrency(item.amount),
            style: TextStyle(
              color: isExpense ? Colors.red : _primaryGreen,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _primaryGreen, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit(item);
              } else if (value == 'delete') {
                onDelete(item.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: _primaryGreen),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: _primaryGreen)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton widget ──────────────────────────────────────────────────────────

class _Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _Skeleton({
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _lightGreen.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
