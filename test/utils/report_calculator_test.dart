import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/data/category_catalog.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/utils/currency_formatter.dart';
import 'package:teenancial/utils/report_calculator.dart';

void main() {
  group('ReportCalculator', () {
    final nov2026 = DateTime(2026, 11, 1);

    test(
      'mengklasifikasikan pemasukan dan pengeluaran sesuai aturan K10 & K11',
      () {
        final txs = <TransactionModel>[
          // 1. Pemasukan normal -> dihitung
          TransactionModel(
            id: 't1',
            title: 'Uang Saku',
            amount: 500000,
            date: DateTime(2026, 11, 5),
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'w1',
          ),
          // 2. Pengeluaran normal -> dihitung
          TransactionModel(
            id: 't2',
            title: 'Makan Siang',
            amount: 120000,
            date: DateTime(2026, 11, 6),
            categoryId: 'c4',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
          // 3. Transfer keluar ke orang lain (destinationDompetId == null) -> dihitung pengeluaran
          TransactionModel(
            id: 't3',
            title: 'Transfer ke Budi',
            amount: 80000,
            date: DateTime(2026, 11, 8),
            categoryId: 'c26',
            type: TransactionType.transfer,
            dompetId: 'w1',
            counterpartyName: 'Budi',
          ),
          // 4. Transfer internal antar dompet -> DIKECUALIKAN
          TransactionModel(
            id: 't4',
            title: 'Transfer Internal',
            amount: 250000,
            date: DateTime(2026, 11, 9),
            categoryId: 'c7',
            type: TransactionType.transfer,
            dompetId: 'w1',
            destinationDompetId: 'w2',
          ),
          // 5. Hutang & Piutang -> DIKECUALIKAN
          TransactionModel(
            id: 't5',
            title: 'Hutang dari Rina',
            amount: 100000,
            date: DateTime(2026, 11, 10),
            categoryId: 'c8',
            type: TransactionType.debt,
            dompetId: 'w1',
          ),
          TransactionModel(
            id: 't6',
            title: 'Piutang ke Andi',
            amount: 75000,
            date: DateTime(2026, 11, 11),
            categoryId: 'c9',
            type: TransactionType.receivable,
            dompetId: 'w1',
          ),
          // 6. Penyesuaian saldo (flag baru & catatan lama) -> DIKECUALIKAN
          TransactionModel(
            id: 't7',
            title: 'Penyesuaian Saldo (BCA)',
            amount: 300000,
            date: DateTime(2026, 11, 12),
            categoryId: 'c19',
            type: TransactionType.income,
            dompetId: 'w1',
            isAdjustment: true,
          ),
          TransactionModel(
            id: 't8',
            title: 'Penyesuaian Saldo (Tunai)',
            amount: 50000,
            date: DateTime(2026, 11, 13),
            notes: 'Penyesuaian saldo otomatis saat edit dompet',
            categoryId: 'c6',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
          // 7. Transaksi bulan sebelumnya (Oktober 2026)
          TransactionModel(
            id: 't9',
            title: 'Pengeluaran Oktober',
            amount: 160000,
            date: DateTime(2026, 10, 15),
            categoryId: 'c4',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
        ];

        final summary = ReportCalculator.calculateMonthlySummary(txs, nov2026);
        expect(summary.totalIncome, 500000);
        expect(summary.totalExpense, 200000); // 120000 + 80000
        expect(summary.netCashflow, 300000);
        expect(summary.previousExpense, 160000);
        expect(summary.expenseChangePercent, closeTo(25.0, 0.01));
        expect(summary.transactionCount, 3);
      },
    );

    test(
      'mengelompokkan >5 kategori menjadi 5 teratas + Kategori Lainnya pada irisan donat namun mempertahankan daftar lengkap',
      () {
        final categoryIds = ['c4', 'c13', 'c5', 'c14', 'c15', 'c16', 'c17'];
        final amounts = [
          200000.0,
          150000.0,
          120000.0,
          90000.0,
          60000.0,
          40000.0,
          20000.0,
        ];

        final txs = <TransactionModel>[
          for (int i = 0; i < categoryIds.length; i++)
            TransactionModel(
              id: 'tx_$i',
              title: 'Item $i',
              amount: amounts[i],
              date: DateTime(2026, 11, i + 1),
              categoryId: categoryIds[i],
              type: TransactionType.expense,
              dompetId: 'w1',
            ),
        ];

        final breakdown = ReportCalculator.calculateCategoryBreakdown(
          txs,
          nov2026,
          ReportFlowType.expense,
        );

        expect(breakdown.totalAmount, 680000.0);
        // Daftar rincian di bawah grafik tetap menampilkan seluruh 7 kategori
        expect(breakdown.fullItems.length, 7);
        expect(breakdown.fullItems.first.categoryId, 'c4');
        expect(breakdown.fullItems.last.categoryId, 'c17');

        // Irisan visual grafik donat: 5 kategori terbesar + 1 Kategori Lainnya
        expect(breakdown.chartSlices.length, 6);
        final groupedSlice = breakdown.chartSlices.last;
        expect(groupedSlice.isGroupedOther, isTrue);
        expect(
          groupedSlice.categoryName,
          ReportCalculator.groupedOtherCategoryName,
        );
        expect(groupedSlice.amount, 60000.0); // 40000 + 20000
        expect(groupedSlice.transactionCount, 2);
      },
    );

    test(
      'menghitung tren 6 bulan melintasi pergantian tahun dengan benar',
      () {
        final feb2026 = DateTime(2026, 2, 1);
        final txs = <TransactionModel>[
          TransactionModel(
            id: 'sep',
            title: 'Sep 2025',
            amount: 100000,
            date: DateTime(2025, 9, 10),
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'w1',
          ),
          TransactionModel(
            id: 'dec',
            title: 'Des 2025',
            amount: 250000,
            date: DateTime(2025, 12, 20),
            categoryId: 'c4',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
          TransactionModel(
            id: 'feb',
            title: 'Feb 2026',
            amount: 400000,
            date: DateTime(2026, 2, 5),
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'w1',
          ),
        ];

        final points = ReportCalculator.calculateSixMonthTrend(txs, feb2026);
        expect(points.length, 6);
        expect(points.first.month, DateTime(2025, 9, 1));
        expect(points.first.shortLabel, 'Sep');
        expect(points.first.income, 100000);
        expect(points[3].month, DateTime(2025, 12, 1));
        expect(points[3].expense, 250000);
        expect(points.last.month, DateTime(2026, 2, 1));
        expect(points.last.income, 400000);
      },
    );

    test(
      'generateInsight menampilkan 4 poin lengkap (kategori terbesar, rata-rata harian, rasio tabungan, dan tren bulan lalu) serta warna asli kategori',
      () {
        final txs = <TransactionModel>[
          TransactionModel(
            id: 'in1',
            title: 'Uang Jajan',
            amount: 500000,
            date: DateTime(2026, 11, 2),
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'w1',
          ),
          TransactionModel(
            id: 'ex1',
            title: 'Hiburan',
            amount: 150000,
            date: DateTime(2026, 11, 5),
            categoryId: 'c5', // Hiburan
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
          TransactionModel(
            id: 'prev1',
            title: 'Makanan Okt',
            amount: 100000,
            date: DateTime(2026, 10, 10),
            categoryId: 'c3',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
        ];

        final summary = ReportCalculator.calculateMonthlySummary(txs, nov2026);
        final expBreakdown = ReportCalculator.calculateCategoryBreakdown(
          txs,
          nov2026,
          ReportFlowType.expense,
        );
        final incBreakdown = ReportCalculator.calculateCategoryBreakdown(
          txs,
          nov2026,
          ReportFlowType.income,
        );

        // Warna di breakdown mengikuti warna asli kategori bawaan c5 (Hiburan)
        expect(
          expBreakdown.fullItems.first.color,
          CategoryCatalog.getById('c5').color,
        );

        final insight = ReportCalculator.generateInsight(
          summary: summary,
          expenseBreakdown: expBreakdown,
          incomeBreakdown: incBreakdown,
          formatCurrency: Formatters.rupiah,
          now: DateTime(2026, 11, 15),
        );

        expect(insight.highlights.length, 4);
        expect(insight.highlights[0], contains('Hiburan'));
        expect(insight.highlights[1], contains('Rata-rata pengeluaran harian'));
        expect(insight.highlights[1], contains('Rp 10.000')); // 150.000 / 15 hari
        expect(insight.highlights[2], contains('Rasio tabungan'));
        expect(insight.highlights[2], contains('70%')); // 350.000 / 500.000
        expect(insight.highlights[3], contains('dibandingkan bulan lalu'));
      },
    );
  });
}
