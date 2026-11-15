import '../models/target_model.dart';
import 'currency_formatter.dart';
import 'date_helper.dart';

/// Satuan waktu saran menabung adaptif berdasarkan sisa hari menuju tenggat.
enum SavingPeriodUnit {
  monthly('bulan'),
  weekly('minggu'),
  daily('hari');

  final String label;
  const SavingPeriodUnit(this.label);
}

/// Hasil perhitungan tenggat dan saran tabungan untuk satu [TargetItem].
class SavingPlan {
  /// Tanggal tenggat terformat ringkas (mis. `31 Des 2026`).
  final String deadlineLabel;

  /// Lencana sisa waktu untuk ditampilkan di ujung kanan baris tenggat
  /// (mis. `52 hari lagi`, `Hari ini`, `Lewat 3 hari`, atau `Tercapai`).
  final String badgeText;

  /// Selisih hari kalender dari hari ini ke tenggat (`< 0` berarti lewat).
  final int daysLeft;

  /// Sisa dana yang masih perlu dikumpulkan (`max(0, targetAmount - savedAmount)`).
  final double remainingAmount;

  /// Satuan periode saran (`monthly`, `weekly`, `daily`), atau `null` bila
  /// target sudah tercapai, jatuh tempo hari ini, atau sudah melewati tenggat.
  final SavingPeriodUnit? unit;

  /// Jumlah periode utuh yang tersisa sesuai [unit].
  final int? periodCount;

  /// Nominal saran tabungan per periode (dibulatkan ke atas ke kelipatan Rp 1.000,
  /// tidak melebihi [remainingAmount]).
  final double? recommendedPerPeriod;

  /// Teks saran lengkap untuk halaman Target Menabung
  /// (mis. `Tabung ±Rp 150.000 / minggu`), atau `null` bila target sudah tercapai.
  final String? suggestionText;

  /// Teks saran ringkas untuk kartu Beranda
  /// (mis. `±Rp 150.000/minggu`), atau `null` bila target sudah tercapai.
  final String? shortSuggestionText;

  /// Bernilai `true` jika tenggat sudah lewat dan target belum tercapai.
  final bool isOverdue;

  /// Bernilai `true` jika tenggat tinggal ≤ 7 hari lagi (termasuk hari ini) dan
  /// target belum tercapai.
  final bool isUrgent;

  const SavingPlan({
    required this.deadlineLabel,
    required this.badgeText,
    required this.daysLeft,
    required this.remainingAmount,
    this.unit,
    this.periodCount,
    this.recommendedPerPeriod,
    this.suggestionText,
    this.shortSuggestionText,
    this.isOverdue = false,
    this.isUrgent = false,
  });
}

class SavingPlanner {
  SavingPlanner._();

  /// Satu bulan didefinisikan sebagai 30 hari kalender untuk perhitungan saran.
  static const int daysPerMonth = 30;
  static const int daysPerWeek = 7;

  /// Menghitung rencana & saran menabung untuk [target].
  /// Mengembalikan `null` jika [target.deadline] bernilai `null`.
  static SavingPlan? plan(TargetItem target, {DateTime? now}) {
    final deadline = target.deadline;
    if (deadline == null) return null;

    final current = now ?? DateTime.now();
    final daysLeft = DateHelper.daysBetween(current, deadline);
    final deadlineLabel = DateHelper.formatShort(deadline);
    final double remaining =
        (target.targetAmount - target.savedAmount).clamp(0.0, double.infinity);

    if (target.isAchieved || remaining <= 0) {
      return SavingPlan(
        deadlineLabel: deadlineLabel,
        badgeText: 'Tercapai',
        daysLeft: daysLeft,
        remainingAmount: 0,
      );
    }

    if (daysLeft < 0) {
      final remStr = Formatters.rupiah(remaining);
      return SavingPlan(
        deadlineLabel: deadlineLabel,
        badgeText: 'Lewat ${-daysLeft} hari',
        daysLeft: daysLeft,
        remainingAmount: remaining,
        suggestionText: 'Tenggat terlewat, sisa $remStr. Ubah tenggat?',
        shortSuggestionText: 'Tenggat terlewat',
        isOverdue: true,
      );
    }

    if (daysLeft == 0) {
      final remStr = Formatters.rupiah(remaining);
      return SavingPlan(
        deadlineLabel: deadlineLabel,
        badgeText: 'Hari ini',
        daysLeft: 0,
        remainingAmount: remaining,
        suggestionText: 'Jatuh tempo hari ini, sisa $remStr',
        shortSuggestionText: 'Sisa $remStr',
        isUrgent: true,
      );
    }

    late final SavingPeriodUnit unit;
    late final int periods;
    if (daysLeft >= 60) {
      unit = SavingPeriodUnit.monthly;
      periods = daysLeft ~/ daysPerMonth;
    } else if (daysLeft >= 14) {
      unit = SavingPeriodUnit.weekly;
      periods = daysLeft ~/ daysPerWeek;
    } else {
      unit = SavingPeriodUnit.daily;
      periods = daysLeft;
    }

    final int rawPerPeriod = (remaining / periods).ceil();
    final int roundedThousands = ((rawPerPeriod + 999) ~/ 1000) * 1000;
    final double finalPerPeriod = roundedThousands > remaining
        ? remaining.ceilToDouble()
        : roundedThousands.toDouble();

    final amountStr = Formatters.rupiah(finalPerPeriod);
    return SavingPlan(
      deadlineLabel: deadlineLabel,
      badgeText: '$daysLeft hari lagi',
      daysLeft: daysLeft,
      remainingAmount: remaining,
      unit: unit,
      periodCount: periods,
      recommendedPerPeriod: finalPerPeriod,
      suggestionText: 'Tabung ±$amountStr / ${unit.label}',
      shortSuggestionText: '±$amountStr/${unit.label}',
      isUrgent: daysLeft <= 7,
    );
  }
}
