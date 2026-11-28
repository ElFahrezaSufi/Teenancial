import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import 'date_helper.dart';
import 'report_calculator.dart';

/// Hasil proyeksi saldo deterministik untuk 7 hari ke depan berdasarkan
/// saldo saat ini, jadwal transaksi berulang aktif, dan rata-rata pengeluaran
/// harian non-berulang hingga 30 hari terakhir.
class WeeklyBalanceForecast {
  final double currentBalance;
  final double scheduledRecurringIncome;
  final double scheduledRecurringExpense;
  final int scheduledRecurringCount;
  final double estimatedDailyExpense;
  final double estimatedWeeklyNonRecurringExpense;
  final int lookbackDays;
  final double projectedBalance;

  const WeeklyBalanceForecast({
    required this.currentBalance,
    required this.scheduledRecurringIncome,
    required this.scheduledRecurringExpense,
    required this.scheduledRecurringCount,
    required this.estimatedDailyExpense,
    required this.estimatedWeeklyNonRecurringExpense,
    required this.lookbackDays,
    required this.projectedBalance,
  });

  double get scheduledNet =>
      scheduledRecurringIncome - scheduledRecurringExpense;

  double get netChange => projectedBalance - currentBalance;

  bool get hasProjectionData =>
      scheduledRecurringCount > 0 || estimatedDailyExpense > 0;
}

class WeeklyBalanceForecaster {
  const WeeklyBalanceForecaster._();

  static const int forecastHorizonDays = 7;
  static const int maxLookbackDays = 30;

  static WeeklyBalanceForecast forecast({
    required double currentBalance,
    required List<TransactionModel> transactions,
    List<RecurringModel> recurringItems = const [],
    DateTime? now,
  }) {
    final today = RecurrenceRule.dateOnly(now ?? DateTime.now());
    final horizonEnd = DateTime(
      today.year,
      today.month,
      today.day + forecastHorizonDays,
    );

    double recurringIncome = 0.0;
    double recurringExpense = 0.0;
    int recurringOccurrences = 0;

    for (final item in recurringItems) {
      if (!item.isActive || item.isCompleted || item.amount <= 0) continue;
      if (item.isInternalTransfer) continue;

      final plan = RecurrenceRule.collectDueOccurrences(
        anchorDate: item.startDate,
        nextRunDate: item.nextRunDate,
        frequency: item.frequency,
        intervalCount: item.intervalCount,
        endDate: item.endDate,
        upToDate: horizonEnd,
        maxCount: 14,
      );

      final upcomingDates = plan.dueDates.where((d) {
        final date = RecurrenceRule.dateOnly(d);
        return !date.isBefore(today) && !date.isAfter(horizonEnd);
      }).toList();

      if (upcomingDates.isEmpty) continue;
      recurringOccurrences += upcomingDates.length;
      final totalForSchedule = item.amount * upcomingDates.length;

      if (item.type == TransactionType.income) {
        recurringIncome += totalForSchedule;
      } else if (item.type == TransactionType.expense ||
          item.type == TransactionType.transfer) {
        recurringExpense += totalForSchedule;
      }
    }

    final windowStart = DateTime(
      today.year,
      today.month,
      today.day - (maxLookbackDays - 1),
    );

    double totalNonRecurringExpense = 0.0;
    DateTime? earliestRelevantDate;

    for (final tx in transactions) {
      final txDate = RecurrenceRule.dateOnly(tx.date);
      if (txDate.isAfter(today)) continue;

      if (earliestRelevantDate == null ||
          txDate.isBefore(earliestRelevantDate)) {
        earliestRelevantDate = txDate;
      }

      if (txDate.isBefore(windowStart)) continue;
      if (!ReportCalculator.isReportExpense(tx)) continue;
      final isFromRecurring =
          tx.recurringId != null && tx.recurringId!.trim().isNotEmpty;
      if (isFromRecurring) continue;

      totalNonRecurringExpense += tx.amount;
    }

    int lookbackDays = 0;
    double estimatedDaily = 0.0;
    double estimatedWeekly = 0.0;

    if (totalNonRecurringExpense > 0 && earliestRelevantDate != null) {
      final clampedStart = earliestRelevantDate.isBefore(windowStart)
          ? windowStart
          : earliestRelevantDate;
      lookbackDays =
          (DateHelper.daysBetween(clampedStart, today) + 1).clamp(
        1,
        maxLookbackDays,
      );
      estimatedDaily = totalNonRecurringExpense / lookbackDays;
      estimatedWeekly =
          (estimatedDaily * forecastHorizonDays).roundToDouble();
    }

    final projected = (currentBalance +
            recurringIncome -
            recurringExpense -
            estimatedWeekly)
        .roundToDouble();

    return WeeklyBalanceForecast(
      currentBalance: currentBalance,
      scheduledRecurringIncome: recurringIncome,
      scheduledRecurringExpense: recurringExpense,
      scheduledRecurringCount: recurringOccurrences,
      estimatedDailyExpense: estimatedDaily,
      estimatedWeeklyNonRecurringExpense: estimatedWeekly,
      lookbackDays: lookbackDays,
      projectedBalance: projected,
    );
  }
}
