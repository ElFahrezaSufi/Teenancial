import '../data/category_catalog.dart';
import '../data/feen_catalog.dart';
import '../data/mission_catalog.dart';
import '../models/belajar_model.dart';
import '../models/dompet_model.dart';
import '../models/mission_model.dart';
import '../models/recurring_model.dart';
import '../models/target_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../providers/belajar_provider.dart';
import '../providers/category_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/mission_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/target_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import 'currency_formatter.dart';
import 'date_helper.dart';
import 'loan_helper.dart';
import 'report_calculator.dart';
import 'saving_planner.dart';
import 'weekly_balance_forecaster.dart';

/// Ringkasan terisolasi progres Misi & XP agar pembacaan `MissionProvider`
/// tetap aman, dinamis mengikuti `MissionCatalog`, dan mudah disesuaikan.
class FeenGamificationSnapshot {
  final int streakCount;
  final int streakBonusPercent;
  final int claimableCount;
  final int completedDailyCount;
  final int totalDailyCount;
  final List<String> activeMissionLines;

  const FeenGamificationSnapshot({
    this.streakCount = 0,
    this.streakBonusPercent = 0,
    this.claimableCount = 0,
    this.completedDailyCount = 0,
    this.totalDailyCount = 0,
    this.activeMissionLines = const [],
  });

  factory FeenGamificationSnapshot.fromMissionProvider(
    MissionProvider missionProvider,
  ) {
    final dailyMissions = MissionCatalog.byPeriod(MissionPeriod.daily);
    final completedDaily = dailyMissions
        .where(
          (m) => missionProvider.statusOf(m) != MissionClaimStatus.inProgress,
        )
        .length;

    final List<String> activeLines = [];
    for (final m in MissionCatalog.all) {
      final status = missionProvider.statusOf(m);
      if (status == MissionClaimStatus.claimed) continue;
      final progress = missionProvider.currentProgress(m);
      final xp = missionProvider.effectiveXpReward(m);
      final statusTag =
          status == MissionClaimStatus.claimable ? 'siap diklaim' : 'berjalan';
      activeLines.add(
        '${m.title} (${m.period.label}): $progress/${m.targetCount} ($statusTag, +$xp XP)',
      );
      if (activeLines.length >= 4) break;
    }

    return FeenGamificationSnapshot(
      streakCount: missionProvider.streakCount,
      streakBonusPercent: missionProvider.streakBonusPercent,
      claimableCount: missionProvider.claimableCount,
      completedDailyCount: completedDaily,
      totalDailyCount: dailyMissions.length,
      activeMissionLines: List<String>.unmodifiable(activeLines),
    );
  }
}

/// Snapshot read-only kondisi keuangan & belajar pengguna saat ini.
///
/// Sengaja TIDAK memuat `uid`, `email`, maupun URL foto profil demi minimisasi
/// data pribadi (PII) sebelum dikirim ke Gemini API.
class FeenLiveSnapshot {
  final String displayName;
  final String? occupationStatus;
  final FeenTone feenTone;
  final int level;
  final int xp;
  final int xpIntoLevel;
  final int xpNeededForNext;
  final List<DompetItem> dompets;
  final List<TransactionModel> transactions;
  final List<TargetItem> targets;
  final List<RecurringModel> recurringItems;
  final int completedModulesCount;
  final int completedQuizzesCount;
  final String? currentModuleTitle;
  final String? currentLevelTitle;
  final FeenGamificationSnapshot gamification;
  final CategoryResolver? categoryResolver;
  final DateTime now;

  FeenLiveSnapshot({
    required this.displayName,
    this.occupationStatus,
    this.feenTone = FeenTone.casual,
    this.level = 1,
    this.xp = 0,
    this.xpIntoLevel = 0,
    this.xpNeededForNext = 100,
    List<DompetItem> dompets = const [],
    List<TransactionModel> transactions = const [],
    List<TargetItem> targets = const [],
    List<RecurringModel> recurringItems = const [],
    this.completedModulesCount = 0,
    this.completedQuizzesCount = 0,
    this.currentModuleTitle,
    this.currentLevelTitle,
    this.gamification = const FeenGamificationSnapshot(),
    this.categoryResolver,
    DateTime? now,
  })  : dompets = List<DompetItem>.unmodifiable(dompets),
        transactions = List<TransactionModel>.unmodifiable(transactions),
        targets = List<TargetItem>.unmodifiable(targets),
        recurringItems = List<RecurringModel>.unmodifiable(recurringItems),
        now = now ?? DateTime.now();

  factory FeenLiveSnapshot.fromProviders({
    required UserProvider userProvider,
    required DompetProvider dompetProvider,
    required TransactionProvider transactionProvider,
    required TargetProvider targetProvider,
    required BelajarProvider belajarProvider,
    required MissionProvider missionProvider,
    RecurringProvider? recurringProvider,
    CategoryProvider? categoryProvider,
    DateTime? now,
  }) {
    final currentMod = belajarProvider.currentModule;
    final profile = userProvider.profile;

    int completedModules = profile?.completedModules.length ?? 0;
    int completedQuizzes = profile?.completedQuizzes.length ?? 0;
    if (belajarProvider.levels.isNotEmpty) {
      int modCount = 0;
      int quizCount = 0;
      for (final lv in belajarProvider.levels) {
        for (final m in lv.modules) {
          if (m.status == ModuleStatus.completed) modCount++;
          if (m.quiz.status == ModuleStatus.completed) quizCount++;
        }
      }
      completedModules = modCount;
      completedQuizzes = quizCount;
    }

    return FeenLiveSnapshot(
      displayName: userProvider.displayName,
      occupationStatus: userProvider.occupationStatus,
      feenTone: userProvider.feenTone,
      level: userProvider.level,
      xp: userProvider.xp,
      xpIntoLevel: userProvider.xpIntoLevel,
      xpNeededForNext: userProvider.xpNeededForNext,
      dompets: dompetProvider.items,
      transactions: transactionProvider.transactions,
      targets: targetProvider.items,
      recurringItems: recurringProvider?.activeItems ?? const [],
      completedModulesCount: completedModules,
      completedQuizzesCount: completedQuizzes,
      currentModuleTitle: currentMod?.module.title,
      currentLevelTitle: currentMod?.level.tingkat,
      gamification:
          FeenGamificationSnapshot.fromMissionProvider(missionProvider),
      categoryResolver: categoryProvider?.resolve,
      now: now,
    );
  }
}

/// Merakit blok konteks terstruktur yang ringkas & hemat token untuk Gemini API
/// serta menghasilkan chip saran pertanyaan dinamis sesuai kondisi akun.
class FeenContextBuilder {
  const FeenContextBuilder._();

  static String _firstName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Pengguna';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  /// Menghitung dana bersih yang disisihkan ke Target Menabung pada [month].
  static double computeMonthlyTargetSavings(
    List<TransactionModel> transactions,
    DateTime month,
  ) =>
      ReportCalculator.calculateMonthlyTargetSavings(transactions, month);

  static String buildContextBlock(FeenLiveSnapshot snapshot) {
    final now = snapshot.now;
    final resolveCategory = snapshot.categoryResolver ?? CategoryCatalog.getById;
    final totalSaldo =
        snapshot.dompets.fold(0.0, (sum, item) => sum + item.jumlah);
    final currentMonth = ReportCalculator.normalizeMonth(now);
    final summary = ReportCalculator.calculateMonthlySummary(
      snapshot.transactions,
      currentMonth,
    );
    final expenseBreakdown = ReportCalculator.calculateCategoryBreakdown(
      snapshot.transactions,
      currentMonth,
      ReportFlowType.expense,
      categoryResolver: resolveCategory,
    );
    final monthlyTargetSavings = computeMonthlyTargetSavings(
      snapshot.transactions,
      currentMonth,
    );

    final buf = StringBuffer();
    buf.writeln('[DATA PENGGUNA SAAT INI]');
    buf.writeln('Tanggal hari ini: ${DateHelper.formatShort(now)}');
    buf.writeln('Nama panggilan: ${_firstName(snapshot.displayName)}');
    buf.writeln(
      'Status pendidikan/pekerjaan: ${snapshot.occupationStatus ?? 'Belum diisi'}',
    );
    final tier = tierForLevel(snapshot.level);
    buf.writeln(
      'Level Feen: Level ${snapshot.level} (Tier ${tier.label}, ${snapshot.xpIntoLevel}/${snapshot.xpNeededForNext} XP ke level ${snapshot.level + 1})',
    );

    // 1. Dompet & Proyeksi 7 Hari
    final weeklyForecast = WeeklyBalanceForecaster.forecast(
      currentBalance: totalSaldo,
      transactions: snapshot.transactions,
      recurringItems: snapshot.recurringItems,
      now: now,
    );
    buf.writeln('\n[DOMPET]');
    buf.writeln('Total saldo seluruh dompet: ${Formatters.rupiah(totalSaldo)}');
    buf.writeln(
      'Perkiraan saldo 7 hari ke depan: ${Formatters.rupiah(weeklyForecast.projectedBalance)} (jadwal rutin 7 hari: ${weeklyForecast.scheduledNet >= 0 ? '+' : '-'}${Formatters.rupiah(weeklyForecast.scheduledNet.abs())}, estimasi pengeluaran harian 7 hari: ${Formatters.rupiah(weeklyForecast.estimatedWeeklyNonRecurringExpense)})',
    );
    if (snapshot.dompets.isEmpty) {
      buf.writeln('- Belum ada dompet terdaftar.');
    } else {
      for (final d in snapshot.dompets) {
        buf.writeln(
          '- ${d.nama} (${d.jenis.label}): ${Formatters.rupiah(d.jumlah)}',
        );
      }
    }

    // 2. Ringkasan Laporan Bulan Ini
    buf.writeln(
      '\n[LAPORAN BULAN ${ReportCalculator.monthTitle(currentMonth).toUpperCase()}]',
    );
    buf.writeln('Pemasukan bulan ini: ${Formatters.rupiah(summary.totalIncome)}');
    buf.writeln(
      'Pengeluaran bulan ini: ${Formatters.rupiah(summary.totalExpense)}',
    );
    buf.writeln(
      'Selisih bersih: ${summary.netCashflow >= 0 ? '+' : '-'}${Formatters.rupiah(summary.netCashflow.abs())}',
    );
    if (summary.totalExpense > 0) {
      buf.writeln(
        'Rata-rata pengeluaran harian: ${Formatters.rupiah(summary.dailyAverageExpense(now: now))}/hari',
      );
    }
    if (summary.previousExpense > 0) {
      final changePct = summary.expenseChangePercent;
      final changeText = changePct != null
          ? ' (${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(0)}%)'
          : '';
      buf.writeln(
        'Pengeluaran bulan lalu: ${Formatters.rupiah(summary.previousExpense)}$changeText',
      );
    }
    if (monthlyTargetSavings > 0) {
      final pctText = summary.totalIncome > 0
          ? ' (${((monthlyTargetSavings / summary.totalIncome) * 100).round()}% dari pemasukan)'
          : '';
      buf.writeln(
        'Alokasi tabungan target bulan ini: ${Formatters.rupiah(monthlyTargetSavings)}$pctText',
      );
    }
    if (expenseBreakdown.fullItems.isNotEmpty) {
      buf.writeln('Kategori pengeluaran teratas bulan ini:');
      for (final item in expenseBreakdown.fullItems.take(5)) {
        buf.writeln(
          '- ${item.categoryName}: ${Formatters.rupiah(item.amount)} (${item.percentage.toStringAsFixed(0)}%, ${item.transactionCount} transaksi)',
        );
      }
    }

    // 3. Transaksi Terbaru (maks 10)
    final recentTxs = List<TransactionModel>.from(snapshot.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    buf.writeln('\n[TRANSAKSI TERBARU (MAKS 10)]');
    if (recentTxs.isEmpty) {
      buf.writeln('- Belum ada transaksi tercatat.');
    } else {
      for (final tx in recentTxs.take(10)) {
        final cat = resolveCategory(tx.categoryId, fallbackType: tx.type);
        final typeLabel = _txTypeLabel(tx);
        final dateStr = DateHelper.formatShort(tx.date);
        final cleanTitle = tx.title.trim().isNotEmpty ? tx.title.trim() : cat.name;
        buf.writeln(
          '- $dateStr | $typeLabel | ${cat.name} | ${Formatters.rupiah(tx.amount)} | $cleanTitle',
        );
      }
    }

    // 4. Target Menabung
    final activeTargets =
        snapshot.targets.where((t) => !t.isSettled).toList(growable: false);
    final settledCount = snapshot.targets.length - activeTargets.length;
    buf.writeln('\n[TARGET MENABUNG]');
    if (activeTargets.isEmpty) {
      buf.writeln(
        settledCount > 0
            ? '- Tidak ada target aktif saat ini ($settledCount target sudah selesai).'
            : '- Belum ada target menabung.',
      );
    } else {
      for (final t in activeTargets.take(5)) {
        final pct = (t.progress * 100).round();
        final plan = SavingPlanner.plan(t, now: now);
        final planNote = plan != null
            ? ', tenggat ${plan.deadlineLabel} (${plan.badgeText})${plan.suggestionText != null ? ', saran: ${plan.suggestionText}' : ''}'
            : '';
        buf.writeln(
          '- ${t.nama}: terkumpul ${Formatters.rupiah(t.savedAmount)} / ${Formatters.rupiah(t.targetAmount)} ($pct%, sisa ${Formatters.rupiah(t.remainingAmount)}$planNote)',
        );
      }
    }

    // 5. Pinjaman Aktif (Hutang & Piutang)
    final unpaidDebts = snapshot.transactions
        .where((t) => t.type == TransactionType.debt && !t.isPaid)
        .toList(growable: false);
    final unpaidReceivables = snapshot.transactions
        .where((t) => t.type == TransactionType.receivable && !t.isPaid)
        .toList(growable: false);
    buf.writeln('\n[PINJAMAN BELUM LUNAS]');
    if (unpaidDebts.isEmpty && unpaidReceivables.isEmpty) {
      buf.writeln('- Tidak ada hutang atau piutang aktif.');
    } else {
      final totalDebt =
          unpaidDebts.fold(0.0, (sum, t) => sum + t.remainingAmount);
      final totalRec =
          unpaidReceivables.fold(0.0, (sum, t) => sum + t.remainingAmount);
      buf.writeln(
        'Total sisa hutang: ${Formatters.rupiah(totalDebt)} (${unpaidDebts.length} pinjaman)',
      );
      buf.writeln(
        'Total sisa piutang: ${Formatters.rupiah(totalRec)} (${unpaidReceivables.length} pinjaman)',
      );
      final upcoming = [...unpaidDebts, ...unpaidReceivables]
        ..sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      for (final loan in upcoming.take(4)) {
        final kind = loan.type == TransactionType.debt ? 'Hutang' : 'Piutang';
        final party = LoanHelper.counterpartyName(loan);
        final dueInfo = loan.dueDate != null
            ? ', jatuh tempo ${DateHelper.formatShort(loan.dueDate!)}'
            : '';
        buf.writeln(
          '- $kind ($party): sisa ${Formatters.rupiah(loan.remainingAmount)} dari ${Formatters.rupiah(loan.amount)}$dueInfo',
        );
      }
    }

    // 6. Transaksi Berulang Aktif
    final activeRec =
        snapshot.recurringItems.where((r) => r.isActive).toList(growable: false);
    if (activeRec.isNotEmpty) {
      buf.writeln('\n[TRANSAKSI BERULANG AKTIF]');
      for (final r in activeRec.take(5)) {
        final kind = r.type == TransactionType.income
            ? 'Pemasukan'
            : (r.type == TransactionType.expense ? 'Pengeluaran' : 'Transfer');
        buf.writeln(
          '- ${r.title} ($kind, ${r.scheduleLabel}): ${Formatters.rupiah(r.amount)}, jadwal berikutnya ${DateHelper.formatShort(r.nextRunDate)}',
        );
      }
    }

    // 7. Ruang Belajar
    buf.writeln('\n[RUANG BELAJAR]');
    buf.writeln(
      'Modul selesai: ${snapshot.completedModulesCount}, Kuis lulus: ${snapshot.completedQuizzesCount}',
    );
    if (snapshot.currentModuleTitle != null) {
      buf.writeln(
        'Materi aktif selanjutnya: ${snapshot.currentModuleTitle}${snapshot.currentLevelTitle != null ? ' (${snapshot.currentLevelTitle})' : ''}',
      );
    }

    // 8. Misi & Gamifikasi (Dinamis dari katalog & provider)
    _appendGamificationSummary(buf, snapshot);

    return buf.toString().trim();
  }

  static void _appendGamificationSummary(
    StringBuffer buf,
    FeenLiveSnapshot snapshot,
  ) {
    final g = snapshot.gamification;
    buf.writeln('\n[MISI, STREAK, & HADIAH FEEN]');
    buf.writeln(
      'Streak harian: ${g.streakCount} hari (bonus XP periodik: +${g.streakBonusPercent}%)',
    );
    buf.writeln(
      'Misi harian hari ini: ${g.completedDailyCount}/${g.totalDailyCount} selesai, total misi siap diklaim: ${g.claimableCount}',
    );
    if (g.activeMissionLines.isNotEmpty) {
      buf.writeln('Contoh misi aktif saat ini:');
      for (final line in g.activeMissionLines) {
        buf.writeln('- $line');
      }
    }
    final nextRewards = feenCatalog
        .where((a) => a.unlockLevel > snapshot.level)
        .toList()
      ..sort((a, b) => a.unlockLevel.compareTo(b.unlockLevel));
    if (nextRewards.isNotEmpty) {
      final upcoming = nextRewards
          .take(2)
          .map((a) => '${a.name} (${a.slot.label}, Lv.${a.unlockLevel})')
          .join(', ');
      buf.writeln('Hadiah Lemari Feen terdekat: $upcoming');
    }
  }

  static String _txTypeLabel(TransactionModel tx) {
    if (tx.targetId != null && tx.isAdjustment) {
      return tx.type == TransactionType.expense
          ? 'Tabung Target'
          : 'Tarik Target';
    }
    switch (tx.type) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.transfer:
        return (tx.destinationDompetId != null &&
                tx.destinationDompetId!.trim().isNotEmpty)
            ? 'Transfer Internal'
            : 'Transfer Keluar';
      case TransactionType.debt:
        return 'Hutang';
      case TransactionType.receivable:
        return 'Piutang';
    }
  }

  /// Menghasilkan hingga 4 saran pertanyaan dinamis yang relevan dengan kondisi
  /// akun saat ini agar pengguna bisa langsung berinteraksi dalam 1 ketukan.
  static List<String> buildSmartSuggestions(FeenLiveSnapshot snapshot) {
    final List<String> suggestions = [];
    void addSuggestion(String text) {
      if (!suggestions.contains(text) && suggestions.length < 4) {
        suggestions.add(text);
      }
    }

    final currentMonth = ReportCalculator.normalizeMonth(snapshot.now);
    final summary = ReportCalculator.calculateMonthlySummary(
      snapshot.transactions,
      currentMonth,
    );

    if (summary.totalExpense > 0) {
      addSuggestion('Evaluasi pengeluaranku bulan ini');
    }

    final activeTargets =
        snapshot.targets.where((t) => !t.isSettled && !t.isAchieved).toList();
    if (activeTargets.isNotEmpty) {
      final pinned = activeTargets.firstWhere(
        (t) => t.isPinned,
        orElse: () => activeTargets.first,
      );
      final shortName = pinned.nama.length > 22
          ? '${pinned.nama.substring(0, 19).trimRight()}...'
          : pinned.nama;
      addSuggestion('Strategi capai target $shortName');
    }

    final hasUnpaidLoans = snapshot.transactions.any(
      (t) =>
          (t.type == TransactionType.debt ||
              t.type == TransactionType.receivable) &&
          !t.isPaid,
    );
    if (hasUnpaidLoans) {
      addSuggestion('Bantu atur pelunasan pinjamanku');
    }

    if (snapshot.gamification.claimableCount > 0 ||
        snapshot.gamification.completedDailyCount <
            snapshot.gamification.totalDailyCount) {
      addSuggestion('Misi apa yang belum kuselesaikan hari ini?');
    }

    // Fallback edukatif untuk akun baru atau slot tersisa
    addSuggestion('Cara bagi uang pakai aturan 50/30/20');
    addSuggestion('Tips hemat uang jajan mingguan');
    addSuggestion('Apa itu dana darurat dan mulai dari berapa?');

    return List<String>.unmodifiable(suggestions);
  }
}
