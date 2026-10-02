import 'package:flutter/material.dart';
import '../data/sim_settings.dart';
import 'package:intl/intl.dart';
import '../data/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/common/skeleton.dart';
import '../widgets/transaction/transaction_group.dart';
import '../widgets/transaction/trend_chart_painter.dart';
import 'pemasukan_screen.dart';
import 'pengeluaran_screen.dart';
import 'semua_aktivitas_screen.dart';

enum _LoadState { loading, success, error, empty }

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
  List<TransactionGroupData> _filteredGroups = [];
  List<double> _trendData = [];
  String _maxLabel = '';

  @override
  void initState() {
    super.initState();
    SimSettings.forceError.addListener(_onSimChanged);
    _loadData();
  }

  @override
  void dispose() {
    SimSettings.forceError.removeListener(_onSimChanged);
    super.dispose();
  }

  void _onSimChanged() {
    if (mounted) _loadData();
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
      final dateStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(t.date);
      if (!groups.containsKey(dateStr)) groups[dateStr] = [];
      groups[dateStr]!.add(t);
    }

    _filteredGroups = groups.entries.map((e) => TransactionGroupData(dateLabel: e.key, items: e.value)).toList();
    _filteredGroups.sort((a, b) => b.items.first.date.compareTo(a.items.first.date));

    // Trend calculation
    filtered.sort((a, b) => a.date.compareTo(b.date));
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

    // Max Label
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi', style: TextStyle(color: primaryGreen)),
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

    setState(() => _loadState = _LoadState.loading);
    try {
      await TransactionRepository.instance.deleteTransaction(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Data berhasil dihapus!'), backgroundColor: primaryGreen),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
      _loadData();
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
          color: appBarBg,
          border: Border(
            bottom: BorderSide(color: primaryGreen, width: 1.5),
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              'Riwayat',
              style: TextStyle(
                color: primaryGreen,
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
                (i) => const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Skeleton(width: 80, height: 34, radius: 20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Skeleton(width: 100, height: 16),
            const SizedBox(height: 10),
            const Skeleton(width: double.infinity, height: 180),
            const SizedBox(height: 24),
            const Skeleton(width: 130, height: 16),
            const SizedBox(height: 12),
            const Skeleton(width: double.infinity, height: 72),
            const SizedBox(height: 10),
            const Skeleton(width: double.infinity, height: 72),
            const SizedBox(height: 10),
            const Skeleton(width: double.infinity, height: 72),
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
            const Text(
              'Oops, terjadi kesalahan!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
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
                backgroundColor: primaryGreen,
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
            Icon(Icons.receipt_long_outlined, size: 80, color: primaryGreen.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Belum ada transaksi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
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
    const Color orangeText = Color(0xFFE18151);

    return Scaffold(
      backgroundColor: scaffoldBg,
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
                        CustomFilterChip(
                          label: 'Mingguan',
                          selected: _selectedFilter == 0,
                          onTap: () {
                            setState(() => _selectedFilter = 0);
                            _processData();
                          },
                        ),
                        const SizedBox(width: 8),
                        CustomFilterChip(
                          label: 'Bulanan',
                          selected: _selectedFilter == 1,
                          onTap: () {
                            setState(() => _selectedFilter = 1);
                            _processData();
                          },
                        ),
                        const SizedBox(width: 8),
                        CustomFilterChip(
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
                          color: primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CustomCard(
                        backgroundColor: cardBg,
                        borderRadius: 16,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _maxLabel,
                              style: const TextStyle(
                                color: primaryGreen,
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 150,
                              child: CustomPaint(
                                painter: TrendChartPainter(_trendData),
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
                              color: primaryGreen,
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
                                    builder: (_) => SemuaAktivitasScreen(
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
                                  color: orangeText,
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
                        (group) => TransactionGroupList(
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
