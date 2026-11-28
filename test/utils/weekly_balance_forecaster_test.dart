import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/recurring_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/utils/weekly_balance_forecaster.dart';

void main() {
  group('WeeklyBalanceForecaster', () {
    final today = DateTime(2026, 11, 20);

    test(
      'akun baru tanpa riwayat dan jadwal rutin menghasilkan perkiraan sama dengan saldo saat ini (tanpa dummy +2%)',
      () {
        final result = WeeklyBalanceForecaster.forecast(
          currentBalance: 200000,
          transactions: const [],
          recurringItems: const [],
          now: today,
        );

        expect(result.projectedBalance, 200000);
        expect(result.scheduledRecurringCount, 0);
        expect(result.estimatedDailyExpense, 0);
        expect(result.hasProjectionData, isFalse);
      },
    );

    test(
      'menggabungkan jadwal rutin 7 hari (kecuali transfer internal) dan rata-rata pengeluaran non-rutin tanpa hitung ganda',
      () {
        final recurring = <RecurringModel>[
          // Pemasukan rutin mingguan jatuh tempo 2 hari lagi (+150.000)
          RecurringModel(
            id: 'r_in',
            title: 'Uang Saku Mingguan',
            amount: 150000,
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'd1',
            frequency: RecurrenceFrequency.weekly,
            startDate: DateTime(2026, 11, 15),
            nextRunDate: DateTime(2026, 11, 22),
          ),
          // Langganan jatuh tempo 5 hari lagi (-50.000)
          RecurringModel(
            id: 'r_exp',
            title: 'Paket Internet',
            amount: 50000,
            categoryId: 'c4',
            type: TransactionType.expense,
            dompetId: 'd1',
            frequency: RecurrenceFrequency.monthly,
            startDate: DateTime(2026, 10, 25),
            nextRunDate: DateTime(2026, 11, 25),
          ),
          // Transfer internal -> tidak mengubah total saldo
          RecurringModel(
            id: 'r_int',
            title: 'Pindah ke E-Wallet',
            amount: 100000,
            categoryId: 'c7',
            type: TransactionType.transfer,
            dompetId: 'd1',
            destinationDompetId: 'd2',
            frequency: RecurrenceFrequency.weekly,
            startDate: DateTime(2026, 11, 1),
            nextRunDate: DateTime(2026, 11, 21),
          ),
          // Jadwal nonaktif -> diabaikan
          RecurringModel(
            id: 'r_off',
            title: 'Jadwal Nonaktif',
            amount: 999999,
            categoryId: 'c4',
            type: TransactionType.expense,
            dompetId: 'd1',
            frequency: RecurrenceFrequency.weekly,
            startDate: DateTime(2026, 11, 1),
            nextRunDate: DateTime(2026, 11, 21),
            isActive: false,
          ),
        ];

        // 10 hari riwayat (11 Nov sampai 20 Nov = 10 hari), total pengeluaran non-rutin Rp 100.000
        // -> rata-rata Rp 10.000/hari -> 7 hari = Rp 70.000
        final txs = <TransactionModel>[
          TransactionModel(
            id: 't1',
            title: 'Makan',
            amount: 60000,
            date: DateTime(2026, 11, 11),
            categoryId: 'c3',
            type: TransactionType.expense,
            dompetId: 'd1',
          ),
          TransactionModel(
            id: 't2',
            title: 'Transport',
            amount: 40000,
            date: DateTime(2026, 11, 18),
            categoryId: 'c4',
            type: TransactionType.expense,
            dompetId: 'd1',
          ),
          // Pengeluaran dari recurring -> DIKECUALIKAN agar tidak dobel hitung
          TransactionModel(
            id: 't_rec',
            title: 'Paket Internet Bulan Lalu',
            amount: 50000,
            date: DateTime(2026, 11, 12),
            categoryId: 'c4',
            type: TransactionType.expense,
            dompetId: 'd1',
            recurringId: 'r_exp',
          ),
        ];

        final result = WeeklyBalanceForecaster.forecast(
          currentBalance: 300000,
          transactions: txs,
          recurringItems: recurring,
          now: today,
        );

        expect(result.scheduledRecurringIncome, 150000);
        expect(result.scheduledRecurringExpense, 50000);
        expect(result.scheduledRecurringCount, 2);
        expect(result.lookbackDays, 10);
        expect(result.estimatedDailyExpense, closeTo(10000, 0.01));
        expect(result.estimatedWeeklyNonRecurringExpense, 70000);
        // 300.000 + 150.000 - 50.000 - 70.000 = 330.000
        expect(result.projectedBalance, 330000);
        expect(result.netChange, 30000);
        expect(result.hasProjectionData, isTrue);
      },
    );
  });
}
