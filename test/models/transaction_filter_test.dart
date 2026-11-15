import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/transaction_filter.dart';
import 'package:teenancial/models/transaction_model.dart';

void main() {
  group('TransactionFilter', () {
    final now = DateTime(2026, 11, 10, 14, 0);

    final sampleTransactions = <TransactionModel>[
      TransactionModel(
        id: 't1',
        title: 'Bakso Malang',
        amount: 25000,
        date: DateTime(2026, 11, 10, 12, 0),
        notes: 'Makan siang bareng teman',
        categoryId: 'c3', // Makanan (Expense)
        type: TransactionType.expense,
        dompetId: 'd_cash',
      ),
      TransactionModel(
        id: 't2',
        title: 'Uang Saku Bulanan',
        amount: 500000,
        date: DateTime(2026, 11, 5, 9, 0),
        notes: 'Dari orang tua',
        categoryId: 'c1', // Uang Jajan (Income)
        type: TransactionType.income,
        dompetId: 'd_bank',
      ),
      TransactionModel(
        id: 't3',
        title: 'Transfer Internal',
        amount: 100000,
        date: DateTime(2026, 10, 20, 15, 0),
        notes: 'Isi dompet tunai',
        categoryId: 'c10',
        type: TransactionType.transfer,
        dompetId: 'd_bank',
        destinationDompetId: 'd_cash',
      ),
      TransactionModel(
        id: 't4',
        title: 'Hutang dari Budi',
        amount: 150000,
        date: DateTime(2026, 9, 1, 10, 0),
        notes: 'Pinjam beli buku',
        categoryId: 'c11',
        type: TransactionType.debt,
        dompetId: 'd_cash',
        counterpartyName: 'Budi Santoso',
        payments: [
          LoanPayment(
            id: 'p1',
            amount: 50000,
            date: DateTime(2026, 9, 10),
            dompetId: 'd_ewallet',
          ),
        ],
      ),
    ];

    test('pencarian kata kunci mencocokkan judul, catatan, kategori, lawan transaksi, dan nominal', () {
      // Judul
      expect(
        TransactionFilter(query: 'bakso')
            .apply(sampleTransactions, now: now)
            .map((t) => t.id),
        ['t1'],
      );

      // Nama kategori ('Makanan' untuk c3)
      expect(
        TransactionFilter(query: 'makanan')
            .apply(sampleTransactions, now: now)
            .map((t) => t.id),
        ['t1'],
      );

      // Counterparty
      expect(
        TransactionFilter(query: 'santoso')
            .apply(sampleTransactions, now: now)
            .map((t) => t.id),
        ['t4'],
      );

      // Nominal tanpa titik ('500000') maupun dengan titik ('25.000')
      expect(
        TransactionFilter(query: '500000')
            .apply(sampleTransactions, now: now)
            .map((t) => t.id),
        ['t2'],
      );
      expect(
        TransactionFilter(query: '25.000')
            .apply(sampleTransactions, now: now)
            .map((t) => t.id),
        ['t1'],
      );
    });

    test('filter dompet mencocokkan dompet sumber, tujuan transfer, maupun dompet cicilan', () {
      // d_cash adalah sumber t1 & t4, sekaligus tujuan t3
      final cashMatches = TransactionFilter(dompetIds: {'d_cash'})
          .apply(sampleTransactions, now: now)
          .map((t) => t.id)
          .toList();
      expect(cashMatches, ['t1', 't3', 't4']);

      // d_ewallet hanya dipakai untuk membayar cicilan pada t4
      final ewalletMatches = TransactionFilter(dompetIds: {'d_ewallet'})
          .apply(sampleTransactions, now: now)
          .map((t) => t.id)
          .toList();
      expect(ewalletMatches, ['t4']);
    });

    test('kombinasi filter jenis, kategori, dan rentang tanggal bekerja secara AND', () {
      final filter = TransactionFilter(
        types: {TransactionType.income, TransactionType.expense},
        periodPreset: HistoryPeriodPreset.custom,
        customRange: DateTimeRange(
          start: DateTime(2026, 11, 1),
          end: DateTime(2026, 11, 6),
        ),
      );

      final result = filter.apply(sampleTransactions, now: now);
      expect(result.map((t) => t.id), ['t2']);
      expect(filter.activeFilterCount, 2);
      expect(filter.isActive, isTrue);
      expect(
        filter.signature,
        isNot(equals(filter.copyWith(query: 'saku').signature)),
      );
    });
  });
}
