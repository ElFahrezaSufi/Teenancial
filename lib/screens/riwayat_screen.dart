import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/transaction_model.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/confirm_dialog.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
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

  static double _netWalletDelta(TransactionModel t) {
    return t.walletEffects().values.fold(0.0, (sum, delta) => sum + delta);
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
    final bool confirm = await showConfirmDialog(
      context,
      title: 'Hapus Transaksi',
      message:
          'Apakah Anda yakin ingin menghapus data ini? Aksi ini tidak dapat dibatalkan.',
    );

    if (!confirm || !mounted) return;

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
              '❌ Gagal menghapus: ${ErrorMapper.message(e)}',
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
    final dompetProvider = context.watch<DompetProvider>();
    final allTransactions = txProvider.transactions;
    final filteredGroups =
        RiwayatScreen.buildFilteredGroups(allTransactions, _selectedFilter);
    final visibleGroups = filteredGroups.take(5).toList();

    final cutoff = RiwayatScreen.cutoffForFilter(_selectedFilter);
    final filteredAsc =
        allTransactions.where((t) => t.date.isAfter(cutoff)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final double currentTotalSaldo = dompetProvider.totalSaldo;
    final double periodNetDelta = filteredAsc.fold(
      0.0,
      (sum, t) => sum + RiwayatScreen._netWalletDelta(t),
    );
    final double openingBalance = currentTotalSaldo - periodNetDelta;

    double runningBalance = openingBalance;
    final List<double> trendData = [openingBalance];
    for (final t in filteredAsc) {
      runningBalance += RiwayatScreen._netWalletDelta(t);
      trendData.add(runningBalance);
    }

    final bool isNetPositive = periodNetDelta >= 0;
    final String netDeltaLabel =
        '${isNetPositive ? '+' : '-'} ${Formatters.rupiah(periodNetDelta.abs())}';

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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Saldo: ${Formatters.rupiah(currentTotalSaldo)}',
                                    style: const TextStyle(
                                      color: primaryGreen,
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    netDeltaLabel,
                                    style: TextStyle(
                                      color: isNetPositive
                                          ? primaryGreen
                                          : Colors.redAccent,
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
                            formatCurrency: Formatters.rupiah,
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
