import 'package:flutter/material.dart';
import '../data/category_catalog.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import 'transaction_model.dart';

/// Preset rentang waktu pada filter riwayat transaksi.
enum HistoryPeriodPreset {
  weekly('Mingguan'),
  monthly('Bulanan'),
  yearly('Tahunan'),
  all('Semua Waktu'),
  custom('Rentang Tanggal');

  final String label;
  const HistoryPeriodPreset(this.label);

  static HistoryPeriodPreset fromLegacyIndex(int index) {
    if (index == 0) return HistoryPeriodPreset.weekly;
    if (index == 1) return HistoryPeriodPreset.monthly;
    if (index == 2) return HistoryPeriodPreset.yearly;
    return HistoryPeriodPreset.all;
  }
}

/// Model imutabel untuk pencarian kata kunci dan pemfilteran multi-kriteria
/// pada daftar riwayat transaksi.
class TransactionFilter {
  final String query;
  final Set<TransactionType> types;
  final Set<String> categoryIds;
  final Set<String> dompetIds;
  final HistoryPeriodPreset periodPreset;
  final DateTimeRange? customRange;

  TransactionFilter({
    this.query = '',
    Set<TransactionType> types = const {},
    Set<String> categoryIds = const {},
    Set<String> dompetIds = const {},
    this.periodPreset = HistoryPeriodPreset.all,
    this.customRange,
  })  : types = Set<TransactionType>.unmodifiable(types),
        categoryIds = Set<String>.unmodifiable(categoryIds),
        dompetIds = Set<String>.unmodifiable(dompetIds);

  factory TransactionFilter.fromFilterIndex(int filterIndex) {
    return TransactionFilter(
      periodPreset: HistoryPeriodPreset.fromLegacyIndex(filterIndex),
    );
  }

  /// Jumlah dimensi filter non-default yang sedang aktif (di luar kata kunci).
  /// Digunakan sebagai angka lencana pada tombol Filter.
  int get activeFilterCount {
    int count = 0;
    if (types.isNotEmpty) count++;
    if (categoryIds.isNotEmpty) count++;
    if (dompetIds.isNotEmpty) count++;
    if (periodPreset != HistoryPeriodPreset.all) count++;
    return count;
  }

  /// Bernilai `true` apabila kata kunci pencarian atau minimal satu filter aktif.
  bool get isActive => query.trim().isNotEmpty || activeFilterCount > 0;

  /// Kunci unik representasi state filter & kata kunci untuk mendeteksi
  /// perubahan filter pada komponen paginasi.
  String get signature {
    final sortedTypes = types.map((e) => e.name).toList()..sort();
    final sortedCats = categoryIds.toList()..sort();
    final sortedDompets = dompetIds.toList()..sort();
    final rangeStr = customRange == null
        ? ''
        : '${customRange!.start.millisecondsSinceEpoch}-${customRange!.end.millisecondsSinceEpoch}';
    return '${query.trim().toLowerCase()}|${periodPreset.name}|$rangeStr|${sortedTypes.join(",")}|${sortedCats.join(",")}|${sortedDompets.join(",")}';
  }

  TransactionFilter copyWith({
    String? query,
    Set<TransactionType>? types,
    Set<String>? categoryIds,
    Set<String>? dompetIds,
    HistoryPeriodPreset? periodPreset,
    DateTimeRange? customRange,
    bool clearCustomRange = false,
  }) {
    return TransactionFilter(
      query: query ?? this.query,
      types: types ?? this.types,
      categoryIds: categoryIds ?? this.categoryIds,
      dompetIds: dompetIds ?? this.dompetIds,
      periodPreset: periodPreset ?? this.periodPreset,
      customRange: clearCustomRange ? null : (customRange ?? this.customRange),
    );
  }

  TransactionFilter reset({bool keepQuery = false}) {
    return TransactionFilter(
      query: keepQuery ? query : '',
      periodPreset: HistoryPeriodPreset.all,
    );
  }

  /// Menerapkan seluruh kriteria dengan logika AND dan mengembalikan daftar
  /// transaksi terurut dari yang paling baru ke paling lama.
  List<TransactionModel> apply(
    List<TransactionModel> source, {
    DateTime? now,
    CategoryResolver? categoryResolver,
  }) {
    final trimmedQuery = query.trim().toLowerCase();
    final queryDigits = trimmedQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final bool isNumericSearch =
        queryDigits.isNotEmpty &&
        RegExp(r'^[rp\s0-9.,+-]+$').hasMatch(trimmedQuery);

    final filtered = source.where((t) {
      if (!_matchesPeriod(t.date, now: now)) return false;
      if (types.isNotEmpty && !types.contains(t.type)) return false;
      if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId)) {
        return false;
      }
      if (dompetIds.isNotEmpty && !_matchesDompet(t)) return false;
      if (trimmedQuery.isNotEmpty &&
          !_matchesQuery(
            t,
            trimmedQuery,
            queryDigits,
            isNumericSearch,
            categoryResolver: categoryResolver,
          )) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  bool _matchesPeriod(DateTime txDate, {DateTime? now}) {
    switch (periodPreset) {
      case HistoryPeriodPreset.all:
        return true;
      case HistoryPeriodPreset.weekly:
        final cutoff = DateHelper.periodStartForFilter(0, now: now);
        return !txDate.isBefore(cutoff);
      case HistoryPeriodPreset.monthly:
        final cutoff = DateHelper.periodStartForFilter(1, now: now);
        return !txDate.isBefore(cutoff);
      case HistoryPeriodPreset.yearly:
        final cutoff = DateHelper.periodStartForFilter(2, now: now);
        return !txDate.isBefore(cutoff);
      case HistoryPeriodPreset.custom:
        if (customRange == null) return true;
        final day = DateHelper.dateOnly(txDate);
        final start = DateHelper.dateOnly(customRange!.start);
        final end = DateHelper.dateOnly(customRange!.end);
        return !day.isBefore(start) && !day.isAfter(end);
    }
  }

  bool _matchesDompet(TransactionModel t) {
    if (dompetIds.contains(t.dompetId)) return true;
    if (t.destinationDompetId != null &&
        dompetIds.contains(t.destinationDompetId)) {
      return true;
    }
    if (t.paidDompetId != null && dompetIds.contains(t.paidDompetId)) {
      return true;
    }
    if (t.payments.any((p) => dompetIds.contains(p.dompetId))) {
      return true;
    }
    return false;
  }

  bool _matchesQuery(
    TransactionModel t,
    String lowerQuery,
    String queryDigits,
    bool isNumericSearch, {
    CategoryResolver? categoryResolver,
  }) {
    if (t.title.toLowerCase().contains(lowerQuery)) return true;
    if (t.notes.toLowerCase().contains(lowerQuery)) return true;
    if (t.counterpartyName != null &&
        t.counterpartyName!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    final resolver = categoryResolver ?? CategoryCatalog.getById;
    final cat = resolver(t.categoryId, fallbackType: t.type);
    if (cat.name.toLowerCase().contains(lowerQuery)) return true;

    final formattedAmount = Formatters.rupiah(t.amount).toLowerCase();
    if (formattedAmount.contains(lowerQuery)) return true;

    if (isNumericSearch) {
      final amountDigits = t.amount.round().toString();
      if (amountDigits.contains(queryDigits)) return true;
    }

    return false;
  }
}
