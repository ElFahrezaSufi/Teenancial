import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/utils/saving_planner.dart';

void main() {
  group('SavingPlanner', () {
    final now = DateTime(2026, 11, 10, 10, 0);

    TargetItem buildTarget({
      double targetAmount = 1200000,
      double savedAmount = 0,
      DateTime? deadline,
    }) {
      return TargetItem(
        id: 'tg_1',
        nama: 'Sepeda Lipat',
        targetAmount: targetAmount,
        savedAmount: savedAmount,
        imageUrl: 'https://example.com/bike.jpg',
        deadline: deadline,
      );
    }

    test('mengembalikan null jika target tidak memiliki tenggat', () {
      final target = buildTarget(deadline: null);
      expect(SavingPlanner.plan(target, now: now), isNull);
    });

    test('satuan per bulan untuk sisa waktu >= 60 hari', () {
      // 90 hari = 3 bulan, sisa Rp 1.000.000 -> ceil(333.333,33) -> dibulatkan ke Rp 334.000
      final target = buildTarget(
        targetAmount: 1000000,
        savedAmount: 0,
        deadline: now.add(const Duration(days: 90)),
      );
      final plan = SavingPlanner.plan(target, now: now);

      expect(plan, isNotNull);
      expect(plan!.unit, SavingPeriodUnit.monthly);
      expect(plan.periodCount, 3);
      expect(plan.recommendedPerPeriod, 334000);
      expect(plan.badgeText, '90 hari lagi');
      expect(plan.suggestionText, 'Tabung ±Rp 334.000 / bulan');
      expect(plan.shortSuggestionText, '±Rp 334.000/bulan');
      expect(plan.isUrgent, isFalse);
      expect(plan.isOverdue, isFalse);
    });

    test('batas tepat 60 hari memakai satuan bulan (2 bulan)', () {
      final target = buildTarget(
        targetAmount: 800000,
        savedAmount: 200000,
        deadline: now.add(const Duration(days: 60)),
      );
      final plan = SavingPlanner.plan(target, now: now)!;

      expect(plan.unit, SavingPeriodUnit.monthly);
      expect(plan.periodCount, 2);
      expect(plan.recommendedPerPeriod, 300000);
    });

    test('satuan per minggu untuk sisa waktu 14 - 59 hari', () {
      // 28 hari = 4 minggu, sisa Rp 500.000 -> Rp 125.000 / minggu
      final target = buildTarget(
        targetAmount: 600000,
        savedAmount: 100000,
        deadline: now.add(const Duration(days: 28)),
      );
      final plan = SavingPlanner.plan(target, now: now)!;

      expect(plan.unit, SavingPeriodUnit.weekly);
      expect(plan.periodCount, 4);
      expect(plan.recommendedPerPeriod, 125000);
      expect(plan.suggestionText, 'Tabung ±Rp 125.000 / minggu');
      expect(plan.shortSuggestionText, '±Rp 125.000/minggu');
    });

    test('satuan per hari untuk sisa waktu 1 - 13 hari dan isUrgent <= 7 hari', () {
      final target10d = buildTarget(
        targetAmount: 250000,
        savedAmount: 0,
        deadline: now.add(const Duration(days: 10)),
      );
      final plan10d = SavingPlanner.plan(target10d, now: now)!;
      expect(plan10d.unit, SavingPeriodUnit.daily);
      expect(plan10d.periodCount, 10);
      expect(plan10d.recommendedPerPeriod, 25000);
      expect(plan10d.isUrgent, isFalse);

      final target5d = buildTarget(
        targetAmount: 100000,
        savedAmount: 0,
        deadline: now.add(const Duration(days: 5)),
      );
      final plan5d = SavingPlanner.plan(target5d, now: now)!;
      expect(plan5d.unit, SavingPeriodUnit.daily);
      expect(plan5d.isUrgent, isTrue);
      expect(plan5d.suggestionText, 'Tabung ±Rp 20.000 / hari');
    });

    test('pembulatan ke atas Rp 1.000 tidak pernah melebihi sisa nominal kecil', () {
      final target = buildTarget(
        targetAmount: 10000,
        savedAmount: 9500, // sisa Rp 500
        deadline: now.add(const Duration(days: 3)),
      );
      final plan = SavingPlanner.plan(target, now: now)!;
      expect(plan.recommendedPerPeriod, 500);
    });

    test('jatuh tempo hari ini dan lewat tenggat menghasilkan pesan khusus', () {
      final dueToday = buildTarget(
        targetAmount: 300000,
        savedAmount: 100000,
        deadline: now,
      );
      final todayPlan = SavingPlanner.plan(dueToday, now: now)!;
      expect(todayPlan.daysLeft, 0);
      expect(todayPlan.isUrgent, isTrue);
      expect(todayPlan.badgeText, 'Hari ini');
      expect(todayPlan.suggestionText, 'Jatuh tempo hari ini, sisa Rp 200.000');

      final overdue = buildTarget(
        targetAmount: 300000,
        savedAmount: 100000,
        deadline: now.subtract(const Duration(days: 4)),
      );
      final overduePlan = SavingPlanner.plan(overdue, now: now)!;
      expect(overduePlan.daysLeft, -4);
      expect(overduePlan.isOverdue, isTrue);
      expect(overduePlan.badgeText, 'Lewat 4 hari');
      expect(
        overduePlan.suggestionText,
        'Tenggat terlewat, sisa Rp 200.000. Ubah tenggat?',
      );
    });

    test('target yang sudah tercapai tidak menampilkan saran tabungan', () {
      final achieved = buildTarget(
        targetAmount: 500000,
        savedAmount: 500000,
        deadline: now.add(const Duration(days: 20)),
      );
      final plan = SavingPlanner.plan(achieved, now: now)!;
      expect(plan.badgeText, 'Tercapai');
      expect(plan.suggestionText, isNull);
      expect(plan.shortSuggestionText, isNull);
    });
  });
}
