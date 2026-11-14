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
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/transaction_actions.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/common/skeleton.dart';
import '../widgets/transaction/transaction_group.dart';
import '../widgets/transaction/trend_chart_painter.dart';
import 'semua_aktivitas_screen.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  static DateTime cutoffForFilter(int filterIndex) {
    return DateHelper.periodStartForFilter(filterIndex);
  }

  static List<TransactionGroupData> buildFilteredGroups(
    List<TransactionModel> allTransactions,
    int filterIndex,
  ) {
    final cutoff = cutoffForFilter(filterIndex);
    final filtered =
        allTransactions.where((t) => !t.date.isBefore(cutoff)).toList();
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

  Widget _buildEmpty() {
    return const EmptyStateView(
      icon: Icons.receipt_long_outlined,
      title: 'Belum ada transaksi',
      subtitle:
          'Coba ubah filter atau catat pemasukan dan pengeluaran pertamamu!',
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
    final periodEvents = <({DateTime date, double delta})>[];
    for (final t in allTransactions) {
      for (final ev in t.balanceEvents()) {
        if (!ev.date.isBefore(cutoff)) {
          periodEvents.add(ev);
        }
      }
    }
    periodEvents.sort((a, b) => a.date.compareTo(b.date));

    final double currentTotalSaldo = dompetProvider.totalSaldo;
    final double periodNetDelta = periodEvents.fold(
      0.0,
      (sum, ev) => sum + ev.delta,
    );
    final double openingBalance = currentTotalSaldo - periodNetDelta;

    double runningBalance = openingBalance;
    final List<double> trendData = [openingBalance];
    for (final ev in periodEvents) {
      runningBalance += ev.delta;
      trendData.add(runningBalance);
    }

    final bool isNetPositive = periodNetDelta >= 0;
    final String netDeltaLabel =
        '${isNetPositive ? '+' : '-'} ${Formatters.rupiah(periodNetDelta.abs())}';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(
        title: 'Riwayat',
        showBackButton: false,
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
          if (txProvider.isLoading && allTransactions.isEmpty)
            _buildLoading()
          else if (txProvider.errorMessage != null && allTransactions.isEmpty)
            ErrorStateView(
              errorMessage: txProvider.errorMessage!,
              onRetry: () =>
                  context.read<TransactionProvider>().loadTransactions(),
            )
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
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => context.push(
                          AppRoutes.semuaAktivitas,
                          extra: SemuaAktivitasArgs(
                            filterIndex: _selectedFilter,
                            autoFocusSearch: true,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: primaryGreen,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cari transaksi, kategori, atau nominal...',
                                  style: TextStyle(
                                    color: primaryGreen.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.tune_rounded,
                                color: primaryGreen,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (filteredGroups.isEmpty) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => context.push(AppRoutes.laporan),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.donut_large_rounded,
                                  size: 15,
                                  color: orangeText,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Laporan Keuangan ›',
                                  style: TextStyle(
                                    color: orangeText,
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: _buildEmpty(),
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tren Saldo',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.laporan),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.donut_large_rounded,
                                    size: 15,
                                    color: orangeText,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Laporan Keuangan ›',
                                    style: TextStyle(
                                      color: orangeText,
                                      fontSize: 13,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                            onEdit: (item) =>
                                TransactionActions.edit(context, item),
                            onDelete: (id) =>
                                TransactionActions.delete(context, id),
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
