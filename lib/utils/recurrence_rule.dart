import 'dart:math' as math;

enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  String get unitLabel {
    switch (this) {
      case RecurrenceFrequency.daily:
        return 'Hari';
      case RecurrenceFrequency.weekly:
        return 'Minggu';
      case RecurrenceFrequency.monthly:
        return 'Bulan';
      case RecurrenceFrequency.yearly:
        return 'Tahun';
    }
  }
}

class RecurrenceCatchUpPlan {
  final List<DateTime> dueDates;
  final DateTime nextRunDate;
  final bool shouldDeactivate;

  const RecurrenceCatchUpPlan({
    required this.dueDates,
    required this.nextRunDate,
    required this.shouldDeactivate,
  });
}

class RecurrenceRule {
  RecurrenceRule._();

  static const int maxCatchUpOccurrencesPerBatch = 31;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static String describe(
    RecurrenceFrequency frequency, [
    int intervalCount = 1,
  ]) {
    final normalized = intervalCount < 1 ? 1 : intervalCount;
    if (normalized == 1) {
      return 'Setiap ${frequency.unitLabel}';
    }
    return 'Setiap $normalized ${frequency.unitLabel}';
  }

  /// Menghasilkan ID dokumen transaksi deterministik `rec_{templateId}_{yyyyMMdd}`
  /// sehingga eksekusi catch-up bersifat idempoten dan tidak pernah menggandakan
  /// transaksi untuk tanggal jadwal yang sama.
  static String deterministicTransactionId(
    String templateId,
    DateTime occurrenceDate,
  ) {
    final y = occurrenceDate.year.toString().padLeft(4, '0');
    final m = occurrenceDate.month.toString().padLeft(2, '0');
    final d = occurrenceDate.day.toString().padLeft(2, '0');
    return 'rec_${templateId}_$y$m$d';
  }

  /// Memajukan jadwal berikutnya dari `currentRunDate` dengan tetap menjaga hari
  /// jangkar (`anchorDate.day`) agar jadwal tanggal 31 tidak bergeser permanen
  /// menjadi tanggal 28 setelah melewati bulan Februari.
  static DateTime advanceFromAnchor({
    required DateTime anchorDate,
    required DateTime currentRunDate,
    required RecurrenceFrequency frequency,
    int intervalCount = 1,
  }) {
    final int interval = intervalCount < 1 ? 1 : intervalCount;
    final anchor = dateOnly(anchorDate);
    final current = dateOnly(currentRunDate);

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return DateTime(current.year, current.month, current.day + interval);
      case RecurrenceFrequency.weekly:
        return DateTime(
          current.year,
          current.month,
          current.day + (7 * interval),
        );
      case RecurrenceFrequency.monthly:
        final targetMonthStart = DateTime(
          current.year,
          current.month + interval,
          1,
        );
        final maxDay = daysInMonth(
          targetMonthStart.year,
          targetMonthStart.month,
        );
        final clampedDay = math.min(anchor.day, maxDay);
        return DateTime(
          targetMonthStart.year,
          targetMonthStart.month,
          clampedDay,
        );
      case RecurrenceFrequency.yearly:
        final targetYear = current.year + interval;
        final targetMonth = anchor.month;
        final maxDay = daysInMonth(targetYear, targetMonth);
        final clampedDay = math.min(anchor.day, maxDay);
        return DateTime(targetYear, targetMonth, clampedDay);
    }
  }

  /// Mengumpulkan seluruh tanggal jatuh tempo yang belum dijalankan hingga
  /// `upToDate` (inklusif), dibatasi maksimal `maxCount` per gelombang.
  static RecurrenceCatchUpPlan collectDueOccurrences({
    required DateTime anchorDate,
    required DateTime nextRunDate,
    required RecurrenceFrequency frequency,
    int intervalCount = 1,
    DateTime? endDate,
    required DateTime upToDate,
    int maxCount = maxCatchUpOccurrencesPerBatch,
  }) {
    final anchor = dateOnly(anchorDate);
    DateTime cursor = dateOnly(nextRunDate);
    final limitDate = dateOnly(upToDate);
    final normalizedEnd = endDate != null ? dateOnly(endDate) : null;

    if (normalizedEnd != null && cursor.isAfter(normalizedEnd)) {
      return RecurrenceCatchUpPlan(
        dueDates: const [],
        nextRunDate: cursor,
        shouldDeactivate: true,
      );
    }

    final List<DateTime> dueDates = [];
    bool shouldDeactivate = false;

    while (!cursor.isAfter(limitDate) && dueDates.length < maxCount) {
      if (normalizedEnd != null && cursor.isAfter(normalizedEnd)) {
        shouldDeactivate = true;
        break;
      }
      dueDates.add(cursor);
      cursor = advanceFromAnchor(
        anchorDate: anchor,
        currentRunDate: cursor,
        frequency: frequency,
        intervalCount: intervalCount,
      );
      if (normalizedEnd != null && cursor.isAfter(normalizedEnd)) {
        shouldDeactivate = true;
        break;
      }
    }

    return RecurrenceCatchUpPlan(
      dueDates: List<DateTime>.unmodifiable(dueDates),
      nextRunDate: cursor,
      shouldDeactivate: shouldDeactivate,
    );
  }
}
