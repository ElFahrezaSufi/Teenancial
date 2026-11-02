import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/common/skeleton.dart';
import '../widgets/transaction/transaction_group.dart';
import '../widgets/transaction/trend_chart_painter.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  static DateTime cutoffForFilter(int filterIndex) {
    final now = DateTime.now();
    if (filterIndex == 0) {
      return now.subtract(const Duration(days: 7));
    } else if (filterIndex == 1) {
      return now.subtract(const Duration(days: 30));
    }
    return now.subtract(const Duration(days: 365));
  }

  static List<TransactionGroupData> buildFilteredGroups(
    List<TransactionModel> allTransactions,
    int filterIndex,
  ) {
    final cutoff = cutoffForFilter(filterIndex);
    final filtered =
        allTransactions.where((t) => t.date.isAfter(cutoff)).toList();
    if (filtered.isEmpty) return [];

    final Map<String, List<TransactionModel>> groups = {};
    for (final t in filtered) {
      final dateStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(t.date);
      groups.putIfAbsent(dateStr, () => []).add(t);
    }

    final result = groups.entries
        .map((e) => TransactionGroupData(dateLabel: e.key, items: e.value))
        .toList();
    result.sort((a, b) => b.items.first.date.compareTo(a.items.first.date));
    return result;
  }

  static String formatCurrency(double amount) {
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

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  int _selectedFilter = 0; // 0: Mingguan, 1: Bulanan, 2: Tahunan

  @override
  void initState() {
    super.initState();
    _selectedFilter = LocalStorageService.instance.riwayatFilterIndex;
  }

  void _setFilter(int index) {
    if (_selectedFilter == index) return;
    setState(() => _selectedFilter = index);
    LocalStorageService.instance.setRiwayatFilterIndex(index);
  }

  Future<void> _deleteTransaction(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Transaksi',
          style: TextStyle(color: primaryGreen),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus data ini? Aksi ini tidak dapat dibatalkan.',
        ),
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

    if (confirm != true || !mounted) return;

    try {
      await context.read<TransactionProvider>().deleteTransaction(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data berhasil dihapus!'),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Gagal menghapus: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editTransaction(TransactionModel item) async {
    if (item.type != TransactionType.income &&
        item.type != TransactionType.expense) {
      return;
    }
    final route = item.type == TransactionType.income
        ? AppRoutes.pemasukan
        : AppRoutes.pengeluaran;
    await context.push(route, extra: item);
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

  Widget _buildError(String errorMessage) {
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () =>
                  context.read<TransactionProvider>().loadTransactions(),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.white),
              ),
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
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: primaryGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada transaksi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
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
    final txProvider = context.watch<TransactionProvider>();
    final allTransactions = txProvider.transactions;
    final filteredGroups =
        RiwayatScreen.buildFilteredGroups(allTransactions, _selectedFilter);
    final visibleGroups = filteredGroups.take(2).toList();

    final cutoff = RiwayatScreen.cutoffForFilter(_selectedFilter);
    final filteredAsc =
        allTransactions.where((t) => t.date.isAfter(cutoff)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    double balance = 0.0;
    final List<double> trendData = [];
    for (final t in filteredAsc) {
      if (t.type == TransactionType.income || t.type == TransactionType.debt) {
        balance += t.amount;
      } else if (t.type == TransactionType.transfer &&
          t.destinationDompetId != null) {
        // Transfer internal antar dompet tidak mengubah total saldo
      } else {
        balance -= t.amount;
      }
      trendData.add(balance);
    }
    if (trendData.isEmpty) trendData.add(0.0);

    final double totalIncome = filteredAsc
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final String maxLabel = '+ ${RiwayatScreen.formatCurrency(totalIncome)}';

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
          if (txProvider.isLoading && allTransactions.isEmpty)
            _buildLoading()
          else if (txProvider.errorMessage != null && allTransactions.isEmpty)
            _buildError(txProvider.errorMessage!)
          else
            SafeArea(
              child: RefreshIndicator(
                color: primaryGreen,
                backgroundColor: scaffoldBg,
                onRefresh: () => context
                    .read<TransactionProvider>()
                    .loadTransactions(silent: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CustomFilterChip(
                            label: 'Mingguan',
                            selected: _selectedFilter == 0,
                            onTap: () => _setFilter(0),
                          ),
                          const SizedBox(width: 8),
                          CustomFilterChip(
                            label: 'Bulanan',
                            selected: _selectedFilter == 1,
                            onTap: () => _setFilter(1),
                          ),
                          const SizedBox(width: 8),
                          CustomFilterChip(
                            label: 'Tahunan',
                            selected: _selectedFilter == 2,
                            onTap: () => _setFilter(2),
                          ),
                        ],
                      ),
                      if (filteredGroups.isEmpty)
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
                                maxLabel,
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
                                  painter: TrendChartPainter(trendData),
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
                            GestureDetector(
                              onTap: () => context.push(
                                AppRoutes.semuaAktivitas,
                                extra: _selectedFilter,
                              ),
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
                            formatCurrency: RiwayatScreen.formatCurrency,
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
            ),
        ],
      ),
    );
  }
}
