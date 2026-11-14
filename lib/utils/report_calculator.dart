import 'package:flutter/material.dart';
import '../data/category_catalog.dart';
import '../models/transaction_model.dart';

enum ReportFlowType { expense, income }

class MonthlyReportSummary {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final double previousIncome;
  final double previousExpense;
  final int transactionCount;

  const MonthlyReportSummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.previousIncome,
    required this.previousExpense,
    required this.transactionCount,
  });

  double get netCashflow => totalIncome - totalExpense;
  double get previousNetCashflow => previousIncome - previousExpense;

  bool get isEmpty =>
      transactionCount == 0 && totalIncome == 0 && totalExpense == 0;

  /// Persentase perubahan pemasukan dibanding bulan lalu (`null` bila bulan lalu Rp 0).
  double? get incomeChangePercent {
    if (previousIncome <= 0) return null;
    return ((totalIncome - previousIncome) / previousIncome) * 100.0;
  }

  /// Persentase perubahan pengeluaran dibanding bulan lalu (`null` bila bulan lalu Rp 0).
  double? get expenseChangePercent {
    if (previousExpense <= 0) return null;
    return ((totalExpense - previousExpense) / previousExpense) * 100.0;
  }

  /// Persentase rasio tabungan terhadap total pemasukan (`null` bila pemasukan Rp 0).
  double? get savingsRatePercent {
    if (totalIncome <= 0) return null;
    return ((netCashflow / totalIncome) * 100.0).clamp(-999.0, 100.0);
  }

  /// Rata-rata pengeluaran per hari (dibagi jumlah hari berjalan jika bulan ini,
  /// atau jumlah hari penuh dalam bulan tersebut jika bulan yang sudah lewat).
  double dailyAverageExpense({DateTime? now}) {
    if (totalExpense <= 0) return 0.0;
    final ref = now ?? DateTime.now();
    final int daysDivisor;
    if (ref.year == month.year && ref.month == month.month) {
      daysDivisor = ref.day < 1 ? 1 : ref.day;
    } else {
      daysDivisor = DateTime(month.year, month.month + 1, 0).day;
    }
    return totalExpense / daysDivisor;
  }
}

class CategoryBreakdownItem {
  final String categoryId;
  final String categoryName;
  final IconData icon;
  final Color color;
  final double amount;
  final double percentage;
  final int transactionCount;
  final bool isGroupedOther;

  const CategoryBreakdownItem({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    this.isGroupedOther = false,
  });
}

class CategoryBreakdownResult {
  final ReportFlowType flowType;
  final double totalAmount;

  /// Daftar lengkap seluruh kategori yang memiliki nominal > 0 (urut dari terbesar),
  /// ditampilkan secara utuh pada daftar rincian di bawah grafik donat.
  final List<CategoryBreakdownItem> fullItems;

  /// Irisan visual untuk grafik donat: maksimal 5 kategori terbesar + 1 irisan
  /// gabungan `"Kategori Lainnya"` apabila jumlah kategori > 5.
  final List<CategoryBreakdownItem> chartSlices;

  const CategoryBreakdownResult({
    required this.flowType,
    required this.totalAmount,
    required this.fullItems,
    required this.chartSlices,
  });

  bool get isEmpty => fullItems.isEmpty || totalAmount <= 0;
}

class MonthlyTrendPoint {
  final DateTime month;
  final String shortLabel;
  final double income;
  final double expense;

  const MonthlyTrendPoint({
    required this.month,
    required this.shortLabel,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

class ReportInsight {
  final String headline;
  final List<String> highlights;
  final Map<String, dynamic> structuredContext;

  const ReportInsight({
    required this.headline,
    required this.highlights,
    required this.structuredContext,
  });
}

class ReportCalculator {
  ReportCalculator._();

  static const int maxPrimaryDonutSlices = 5;
  static const String groupedOtherCategoryId = '_grouped_other';
  static const String groupedOtherCategoryName = 'Kategori Lainnya';

  static const Color groupedOtherColor = Color(0xFF78909C);

  static const List<String> _monthNamesId = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _monthShortId = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static DateTime normalizeMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime previousMonth(DateTime month) =>
      DateTime(month.year, month.month - 1, 1);

  static DateTime nextMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 1);

  static bool isInMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  static String monthTitle(DateTime month) =>
      '${_monthNamesId[month.month - 1]} ${month.year}';

  static String monthShortLabel(DateTime month) =>
      _monthShortId[month.month - 1];

  /// Aturan K10: Pemasukan laporan adalah `income` yang bukan penyesuaian saldo otomatis.
  static bool isReportIncome(TransactionModel tx) {
    if (tx.isBalanceAdjustment) return false;
    return tx.type == TransactionType.income && tx.amount > 0;
  }

  /// Aturan K10: Pengeluaran laporan mencakup `expense` (non-penyesuaian) serta
  /// `transfer` keluar ke orang lain (`destinationDompetId == null` atau kosong).
  /// Transfer internal antar-dompet dan hutang/piutang dikecualikan.
  static bool isReportExpense(TransactionModel tx) {
    if (tx.isBalanceAdjustment) return false;
    if (tx.amount <= 0) return false;
    if (tx.type == TransactionType.expense) return true;
    if (tx.type == TransactionType.transfer) {
      return tx.destinationDompetId == null ||
          tx.destinationDompetId!.trim().isEmpty;
    }
    return false;
  }

  static MonthlyReportSummary calculateMonthlySummary(
    List<TransactionModel> transactions,
    DateTime month,
  ) {
    final targetMonth = normalizeMonth(month);
    final prevMonth = previousMonth(targetMonth);

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    double prevIncome = 0.0;
    double prevExpense = 0.0;
    int txCount = 0;

    for (final tx in transactions) {
      if (isInMonth(tx.date, targetMonth)) {
        if (isReportIncome(tx)) {
          totalIncome += tx.amount;
          txCount++;
        } else if (isReportExpense(tx)) {
          totalExpense += tx.amount;
          txCount++;
        }
      } else if (isInMonth(tx.date, prevMonth)) {
        if (isReportIncome(tx)) {
          prevIncome += tx.amount;
        } else if (isReportExpense(tx)) {
          prevExpense += tx.amount;
        }
      }
    }

    return MonthlyReportSummary(
      month: targetMonth,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      previousIncome: prevIncome,
      previousExpense: prevExpense,
      transactionCount: txCount,
    );
  }

  static CategoryBreakdownResult calculateCategoryBreakdown(
    List<TransactionModel> transactions,
    DateTime month,
    ReportFlowType flowType, {
    CategoryResolver? categoryResolver,
  }) {
    final targetMonth = normalizeMonth(month);
    final resolve = categoryResolver ?? CategoryCatalog.getById;

    final Map<String, ({double amount, int count, TransactionType sampleType})>
        buckets = {};
    double totalAmount = 0.0;

    for (final tx in transactions) {
      if (!isInMonth(tx.date, targetMonth)) continue;
      final matchesFlow = flowType == ReportFlowType.income
          ? isReportIncome(tx)
          : isReportExpense(tx);
      if (!matchesFlow) continue;

      totalAmount += tx.amount;
      final current = buckets[tx.categoryId];
      if (current == null) {
        buckets[tx.categoryId] = (
          amount: tx.amount,
          count: 1,
          sampleType: tx.type,
        );
      } else {
        buckets[tx.categoryId] = (
          amount: current.amount + tx.amount,
          count: current.count + 1,
          sampleType: current.sampleType,
        );
      }
    }

    if (buckets.isEmpty || totalAmount <= 0) {
      return CategoryBreakdownResult(
        flowType: flowType,
        totalAmount: 0.0,
        fullItems: const [],
        chartSlices: const [],
      );
    }

    final sortedEntries = buckets.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.amount.compareTo(a.value.amount);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

    final List<CategoryBreakdownItem> fullItems = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final cat = resolve(entry.key, fallbackType: entry.value.sampleType);
      final Color itemColor = cat.color;
      final double pct = (entry.value.amount / totalAmount) * 100.0;

      fullItems.add(
        CategoryBreakdownItem(
          categoryId: cat.id,
          categoryName: cat.name,
          icon: cat.icon,
          color: itemColor,
          amount: entry.value.amount,
          percentage: pct,
          transactionCount: entry.value.count,
        ),
      );
    }

    final List<CategoryBreakdownItem> chartSlices;
    if (fullItems.length <= maxPrimaryDonutSlices) {
      chartSlices = List<CategoryBreakdownItem>.unmodifiable(fullItems);
    } else {
      final topSlices = fullItems.sublist(0, maxPrimaryDonutSlices);
      final restSlices = fullItems.sublist(maxPrimaryDonutSlices);
      final double restAmount =
          restSlices.fold(0.0, (double sum, item) => sum + item.amount);
      final int restCount =
          restSlices.fold(0, (int sum, item) => sum + item.transactionCount);
      final double restPct = (restAmount / totalAmount) * 100.0;

      chartSlices = List<CategoryBreakdownItem>.unmodifiable([
        ...topSlices,
        CategoryBreakdownItem(
          categoryId: groupedOtherCategoryId,
          categoryName: groupedOtherCategoryName,
          icon: Icons.more_horiz_rounded,
          color: groupedOtherColor,
          amount: restAmount,
          percentage: restPct,
          transactionCount: restCount,
          isGroupedOther: true,
        ),
      ]);
    }

    return CategoryBreakdownResult(
      flowType: flowType,
      totalAmount: totalAmount,
      fullItems: List<CategoryBreakdownItem>.unmodifiable(fullItems),
      chartSlices: chartSlices,
    );
  }

  /// Menghitung seri 6 bulan berturut-turut yang berakhir pada `anchorMonth` (inklusif).
  static List<MonthlyTrendPoint> calculateSixMonthTrend(
    List<TransactionModel> transactions,
    DateTime anchorMonth,
  ) {
    final normalizedAnchor = normalizeMonth(anchorMonth);
    final List<DateTime> months = List<DateTime>.generate(
      6,
      (index) => DateTime(
        normalizedAnchor.year,
        normalizedAnchor.month - (5 - index),
        1,
      ),
    );

    final Map<int, ({double income, double expense})> totalsByKey = {
      for (final m in months) m.year * 100 + m.month: (income: 0.0, expense: 0.0),
    };

    for (final tx in transactions) {
      final key = tx.date.year * 100 + tx.date.month;
      final current = totalsByKey[key];
      if (current == null) continue;

      if (isReportIncome(tx)) {
        totalsByKey[key] = (
          income: current.income + tx.amount,
          expense: current.expense,
        );
      } else if (isReportExpense(tx)) {
        totalsByKey[key] = (
          income: current.income,
          expense: current.expense + tx.amount,
        );
      }
    }

    return months.map((m) {
      final key = m.year * 100 + m.month;
      final bucket = totalsByKey[key]!;
      return MonthlyTrendPoint(
        month: m,
        shortLabel: monthShortLabel(m),
        income: bucket.income,
        expense: bucket.expense,
      );
    }).toList(growable: false);
  }

  /// Menghasilkan wawasan singkat berbasis aturan beserta konteks terstruktur
  /// yang siap diteruskan ke Tanya Feen (Gemini AI) di masa depan.
  static ReportInsight generateInsight({
    required MonthlyReportSummary summary,
    required CategoryBreakdownResult expenseBreakdown,
    required CategoryBreakdownResult incomeBreakdown,
    required String Function(double) formatCurrency,
    DateTime? now,
  }) {
    final periodTitle = monthTitle(summary.month);

    if (summary.isEmpty) {
      return ReportInsight(
        headline: 'Belum ada arus kas di $periodTitle',
        highlights: const [
          'Catat pemasukan atau pengeluaranmu bulan ini untuk melihat proporsi kategori dan tren bulanan.',
        ],
        structuredContext: {
          'period': periodTitle,
          'totalIncome': 0.0,
          'totalExpense': 0.0,
          'netCashflow': 0.0,
          'dailyAverageExpense': 0.0,
          'savingsRatePercent': null,
          'topExpenseCategory': null,
          'topIncomeCategory': null,
        },
      );
    }

    final String headline;
    if (summary.netCashflow > 0) {
      headline =
          'Surplus ${formatCurrency(summary.netCashflow)} pada $periodTitle';
    } else if (summary.netCashflow < 0) {
      headline =
          'Defisit ${formatCurrency(summary.netCashflow.abs())} pada $periodTitle';
    } else {
      headline = 'Pemasukan dan pengeluaran seimbang pada $periodTitle';
    }

    final List<String> highlights = [];
    final double dailyAvg = summary.dailyAverageExpense(now: now);
    final double? savingRate = summary.savingsRatePercent;

    // 1. Kategori pengeluaran terbesar
    if (expenseBreakdown.fullItems.isNotEmpty) {
      final topExpense = expenseBreakdown.fullItems.first;
      highlights.add(
        'Pengeluaran terbesar ada pada kategori ${topExpense.categoryName} sebesar ${formatCurrency(topExpense.amount)} (${topExpense.percentage.toStringAsFixed(0)}% dari total pengeluaran).',
      );
    } else {
      highlights.add('Belum ada pengeluaran tercatat pada bulan ini.');
    }

    // 2. Rata-rata pengeluaran harian
    if (summary.totalExpense > 0) {
      highlights.add(
        'Rata-rata pengeluaran harian: ${formatCurrency(dailyAvg)} per hari.',
      );
    }

    // 3. Rasio tabungan
    if (savingRate != null) {
      if (savingRate >= 0) {
        highlights.add(
          'Rasio tabungan: kamu menyisihkan ${savingRate.toStringAsFixed(0)}% dari pemasukan bulan ini (${formatCurrency(summary.netCashflow)}).',
        );
      } else {
        highlights.add(
          'Rasio tabungan: 0% (pengeluaran melebihi pemasukan sebesar ${formatCurrency(summary.netCashflow.abs())}).',
        );
      }
    } else {
      highlights.add(
        'Rasio tabungan: belum dapat dihitung karena belum ada pemasukan tercatat bulan ini.',
      );
    }

    // 4. Tren dibanding bulan lalu
    final expenseChange = summary.expenseChangePercent;
    if (expenseChange != null) {
      if (expenseChange > 5) {
        highlights.add(
          'Total pengeluaran naik ${expenseChange.toStringAsFixed(0)}% dibandingkan bulan lalu (${formatCurrency(summary.previousExpense)}).',
        );
      } else if (expenseChange < -5) {
        highlights.add(
          'Hemat! Total pengeluaran turun ${expenseChange.abs().toStringAsFixed(0)}% dibandingkan bulan lalu (${formatCurrency(summary.previousExpense)}).',
        );
      } else {
        highlights.add(
          'Pengeluaran bulan ini relatif stabil dibandingkan bulan lalu (${formatCurrency(summary.previousExpense)}).',
        );
      }
    } else {
      highlights.add(
        'Tren bulanan: belum ada data pengeluaran pada bulan sebelumnya sebagai pembanding.',
      );
    }

    return ReportInsight(
      headline: headline,
      highlights: List<String>.unmodifiable(highlights),
      structuredContext: {
        'period': periodTitle,
        'totalIncome': summary.totalIncome,
        'totalExpense': summary.totalExpense,
        'netCashflow': summary.netCashflow,
        'dailyAverageExpense': dailyAvg,
        'savingsRatePercent': savingRate,
        'expenseChangePercent': summary.expenseChangePercent,
        'incomeChangePercent': summary.incomeChangePercent,
        'topExpenseCategory': expenseBreakdown.fullItems.isNotEmpty
            ? expenseBreakdown.fullItems.first.categoryName
            : null,
        'topIncomeCategory': incomeBreakdown.fullItems.isNotEmpty
            ? incomeBreakdown.fullItems.first.categoryName
            : null,
      },
    );
  }
}
