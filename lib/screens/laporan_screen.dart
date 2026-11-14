import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/report_calculator.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';

class LaporanScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const LaporanScreen({
    super.key,
    this.initialMonth,
  });

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  late DateTime _selectedMonth;
  ReportFlowType _selectedFlow = ReportFlowType.expense;
  int _touchedSliceIndex = -1;

  @override
  void initState() {
    super.initState();
    _selectedMonth =
        ReportCalculator.normalizeMonth(widget.initialMonth ?? DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final txProvider = context.read<TransactionProvider>();
      if (txProvider.transactions.isEmpty && !txProvider.isLoading) {
        txProvider.loadTransactions(silent: true);
      }
      final catProvider = Provider.of<CategoryProvider?>(
        context,
        listen: false,
      );
      if (catProvider != null &&
          catProvider.customCategories.isEmpty &&
          !catProvider.isLoading) {
        catProvider.loadCategories(silent: true);
      }
    });
  }

  bool get _canGoNextMonth {
    final nowMonth = ReportCalculator.normalizeMonth(DateTime.now());
    return _selectedMonth.isBefore(nowMonth);
  }

  void _changeMonth(int deltaMonths) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + deltaMonths, 1);
    final nowMonth = ReportCalculator.normalizeMonth(DateTime.now());
    if (next.isAfter(nowMonth)) return;
    setState(() {
      _selectedMonth = next;
      _touchedSliceIndex = -1;
    });
  }

  static String _compactRupiah(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.', ',')}M';
    }
    if (abs >= 1000000) {
      final jt = value / 1000000;
      final formatted = jt == jt.roundToDouble()
          ? jt.toStringAsFixed(0)
          : jt.toStringAsFixed(1).replaceAll('.', ',');
      return '${formatted}jt';
    }
    if (abs >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}rb';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final catProvider = Provider.of<CategoryProvider?>(context);
    final List<TransactionModel> allTransactions = txProvider.transactions;

    final summary = ReportCalculator.calculateMonthlySummary(
      allTransactions,
      _selectedMonth,
    );
    final expenseBreakdown = ReportCalculator.calculateCategoryBreakdown(
      allTransactions,
      _selectedMonth,
      ReportFlowType.expense,
      categoryResolver: catProvider?.resolve,
    );
    final incomeBreakdown = ReportCalculator.calculateCategoryBreakdown(
      allTransactions,
      _selectedMonth,
      ReportFlowType.income,
      categoryResolver: catProvider?.resolve,
    );
    final activeBreakdown = _selectedFlow == ReportFlowType.expense
        ? expenseBreakdown
        : incomeBreakdown;
    final trendPoints = ReportCalculator.calculateSixMonthTrend(
      allTransactions,
      _selectedMonth,
    );
    final insight = ReportCalculator.generateInsight(
      summary: summary,
      expenseBreakdown: expenseBreakdown,
      incomeBreakdown: incomeBreakdown,
      formatCurrency: Formatters.rupiah,
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(
        title: 'Laporan Keuangan',
        backIcon: Icons.arrow_back_ios_new,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: primaryGreen,
              backgroundColor: scaffoldBg,
              onRefresh: () => context
                  .read<TransactionProvider>()
                  .loadTransactions(silent: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMonthSelector(),
                    const SizedBox(height: 16),
                    _buildSummarySection(summary),
                    const SizedBox(height: 20),
                    _buildInsightCard(insight),
                    const SizedBox(height: 20),
                    _buildCategoryDonutCard(activeBreakdown),
                    const SizedBox(height: 20),
                    _buildSixMonthBarCard(trendPoints),
                    const SizedBox(height: 16),
                    Text(
                      'Catatan: Transfer antar-dompet sendiri, pencatatan hutang/piutang, dan penyesuaian saldo otomatis tidak dihitung sebagai pemasukan maupun pengeluaran pada laporan ini.',
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: primaryGreen, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded, color: primaryGreen),
            visualDensity: VisualDensity.compact,
            tooltip: 'Bulan Sebelumnya',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                ReportCalculator.monthTitle(_selectedMonth),
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 15,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _canGoNextMonth ? () => _changeMonth(1) : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _canGoNextMonth
                  ? primaryGreen
                  : primaryGreen.withValues(alpha: 0.25),
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Bulan Berikutnya',
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(MonthlyReportSummary summary) {
    final bool isNetPositive = summary.netCashflow >= 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryMetricCard(
                label: 'Pemasukan',
                amountText: '+ ${Formatters.rupiah(summary.totalIncome)}',
                amountColor: primaryGreen,
                icon: Icons.south_west_rounded,
                changePercent: summary.incomeChangePercent,
                positiveIsGood: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryMetricCard(
                label: 'Pengeluaran',
                amountText: '- ${Formatters.rupiah(summary.totalExpense)}',
                amountColor: const Color(0xFFC62828),
                icon: Icons.north_east_rounded,
                changePercent: summary.expenseChangePercent,
                positiveIsGood: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CustomCard(
          backgroundColor: cardBg,
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selisih Bersih',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.netCashflow > 0
                        ? 'Surplus bulan ini'
                        : (summary.netCashflow < 0
                            ? 'Defisit bulan ini'
                            : 'Arus kas seimbang'),
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '${isNetPositive ? '+' : '-'} ${Formatters.rupiah(summary.netCashflow.abs())}',
                style: TextStyle(
                  color: isNetPositive ? primaryGreen : const Color(0xFFC62828),
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(ReportInsight insight) {
    return CustomCard(
      backgroundColor: const Color(0xFFF8FFE8),
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: orangeText.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: orangeText,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight.headline,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (insight.highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...insight.highlights.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: orangeText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryDonutCard(CategoryBreakdownResult breakdown) {
    final slices = breakdown.chartSlices;
    final hasValidTouch =
        _touchedSliceIndex >= 0 && _touchedSliceIndex < slices.length;
    final CategoryBreakdownItem? activeSlice =
        hasValidTouch ? slices[_touchedSliceIndex] : null;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Proporsi Kategori',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 15,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: scaffoldBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: primaryGreen, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFlowToggleButton(
                      label: 'Pengeluaran',
                      flow: ReportFlowType.expense,
                    ),
                    _buildFlowToggleButton(
                      label: 'Pemasukan',
                      flow: ReportFlowType.income,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (breakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(
                    Icons.pie_chart_outline_rounded,
                    size: 46,
                    color: primaryGreen.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFlow == ReportFlowType.expense
                        ? 'Belum ada pengeluaran tercatat pada bulan ini.'
                        : 'Belum ada pemasukan tercatat pada bulan ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2.5,
                      centerSpaceRadius: 58,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedSliceIndex = -1;
                              return;
                            }
                            _touchedSliceIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: List.generate(slices.length, (i) {
                        final item = slices[i];
                        final isTouched = i == _touchedSliceIndex;
                        return PieChartSectionData(
                          color: item.color,
                          value: item.amount,
                          radius: isTouched ? 42 : 34,
                          showTitle: item.percentage >= 9,
                          title: '${item.percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 108,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeSlice != null
                              ? activeSlice.categoryName
                              : (_selectedFlow == ReportFlowType.expense
                                  ? 'Total Keluar'
                                  : 'Total Masuk'),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryGreen.withValues(alpha: 0.75),
                            fontSize: 10,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.rupiah(
                            activeSlice != null
                                ? activeSlice.amount
                                : breakdown.totalAmount,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (activeSlice != null)
                          Text(
                            '${activeSlice.percentage.toStringAsFixed(1).replaceAll('.', ',')}%',
                            style: const TextStyle(
                              color: orangeText,
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (breakdown.fullItems.length >
                ReportCalculator.maxPrimaryDonutSlices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Lingkaran menampilkan 5 kategori terbesar dan menggabungkan sisanya sebagai "${ReportCalculator.groupedOtherCategoryName}". Seluruh rincian kategori ditampilkan di bawah.',
                  style: TextStyle(
                    color: primaryGreen.withValues(alpha: 0.65),
                    fontSize: 10.5,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const Divider(color: primaryGreen, height: 20, thickness: 0.6),
            ...breakdown.fullItems.map(
              (item) => _buildCategoryBreakdownRow(item),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlowToggleButton({
    required String label,
    required ReportFlowType flow,
  }) {
    final isSelected = _selectedFlow == flow;
    return GestureDetector(
      onTap: () {
        if (_selectedFlow == flow) return;
        setState(() {
          _selectedFlow = flow;
          _touchedSliceIndex = -1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryGreen,
            fontSize: 11,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownRow(CategoryBreakdownItem item) {
    final pctString =
        '${item.percentage.toStringAsFixed(1).replaceAll('.', ',')}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
              const SizedBox(width: 8),
              Icon(item.icon, size: 17, color: primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 13,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: scaffoldBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${item.transactionCount}x',
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.75),
                          fontSize: 10,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupiah(item.amount),
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 12.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    pctString,
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: (item.percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: scaffoldBg,
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSixMonthBarCard(List<MonthlyTrendPoint> points) {
    double maxVal = 0.0;
    for (final p in points) {
      maxVal = math.max(maxVal, math.max(p.income, p.expense));
    }
    final double maxY = maxVal <= 0 ? 100000.0 : maxVal * 1.25;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Perbandingan 6 Bulan Terakhir',
            style: TextStyle(
              color: primaryGreen,
              fontSize: 15,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendIndicator(
                color: primaryGreen,
                label: 'Pemasukan',
              ),
              const SizedBox(width: 16),
              _buildLegendIndicator(
                color: orangeText,
                label: 'Pengeluaran',
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: primaryGreen.withValues(alpha: 0.12),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => primaryGreen,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final point = points[group.x.toInt()];
                      final kind = rodIndex == 0 ? 'Masuk' : 'Keluar';
                      return BarTooltipItem(
                        '${point.shortLabel} ($kind)\n${Formatters.rupiah(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) {
                          return const Text(
                            '0',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }
                        return Text(
                          _compactRupiah(value),
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 10,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            points[idx].shortLabel,
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 11,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(points.length, (i) {
                  final p = points[i];
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: p.income,
                        color: primaryGreen,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: p.expense,
                        color: orangeText,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: primaryGreen,
            fontSize: 11.5,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String label;
  final String amountText;
  final Color amountColor;
  final IconData icon;
  final double? changePercent;
  final bool positiveIsGood;

  const _SummaryMetricCard({
    required this.label,
    required this.amountText,
    required this.amountColor,
    required this.icon,
    required this.changePercent,
    required this.positiveIsGood,
  });

  @override
  Widget build(BuildContext context) {
    String? badgeText;
    Color? badgeColor;

    if (changePercent != null) {
      final isUp = changePercent! >= 0;
      final sign = isUp ? '+' : '';
      badgeText = '$sign${changePercent!.toStringAsFixed(0)}% vs bln lalu';
      final isGood = positiveIsGood ? isUp : !isUp;
      badgeColor = isGood ? primaryGreen : const Color(0xFFC62828);
    }

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: amountColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: amountColor,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
            ),
          ),
          if (badgeText != null && badgeColor != null) ...[
            const SizedBox(height: 4),
            Text(
              badgeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10.5,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
