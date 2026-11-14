import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/recurring_model.dart';
import 'package:teenancial/models/transaction_model.dart';

void main() {
  group('RecurrenceRule & RecurringModel', () {
    test(
      'bulanan dari tanggal 31 Januari tetap kembali ke 31 Maret dan 30 April (tidak terkunci di 28)',
      () {
        final anchor = DateTime(2026, 1, 31);
        final feb = RecurrenceRule.advanceFromAnchor(
          anchorDate: anchor,
          currentRunDate: anchor,
          frequency: RecurrenceFrequency.monthly,
        );
        expect(feb, DateTime(2026, 2, 28));

        final mar = RecurrenceRule.advanceFromAnchor(
          anchorDate: anchor,
          currentRunDate: feb,
          frequency: RecurrenceFrequency.monthly,
        );
        expect(mar, DateTime(2026, 3, 31));

        final apr = RecurrenceRule.advanceFromAnchor(
          anchorDate: anchor,
          currentRunDate: mar,
          frequency: RecurrenceFrequency.monthly,
        );
        expect(apr, DateTime(2026, 4, 30));
      },
    );

    test(
      'tahunan dari 29 Februari (tahun kabisat) jatuh pada 28 Februari di tahun biasa dan kembali ke 29 Februari di kabisat berikutnya',
      () {
        final leapAnchor = DateTime(2024, 2, 29);
        final y2025 = RecurrenceRule.advanceFromAnchor(
          anchorDate: leapAnchor,
          currentRunDate: leapAnchor,
          frequency: RecurrenceFrequency.yearly,
        );
        expect(y2025, DateTime(2025, 2, 28));

        final y2028 = RecurrenceRule.advanceFromAnchor(
          anchorDate: leapAnchor,
          currentRunDate: DateTime(2027, 2, 28),
          frequency: RecurrenceFrequency.yearly,
        );
        expect(y2028, DateTime(2028, 2, 29));
      },
    );

    test(
      'mendukung interval kustom (Setiap N Hari / Minggu / Bulan) dan menonaktifkan jadwal saat melewati endDate',
      () {
        final anchor = DateTime(2026, 11, 1);
        final plan = RecurrenceRule.collectDueOccurrences(
          anchorDate: anchor,
          nextRunDate: anchor,
          frequency: RecurrenceFrequency.weekly,
          intervalCount: 2, // Setiap 2 Minggu
          endDate: DateTime(2026, 11, 20),
          upToDate: DateTime(2026, 11, 30),
        );

        expect(plan.dueDates, [
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 15),
        ]);
        expect(plan.nextRunDate, DateTime(2026, 11, 29));
        expect(plan.shouldDeactivate, isTrue);
        expect(
          RecurrenceRule.describe(RecurrenceFrequency.weekly, 2),
          'Setiap 2 Minggu',
        );
      },
    );

    test(
      'membatasi catch-up maksimal 31 kejadian per batch dan menghasilkan ID deterministik rec_{id}_{yyyyMMdd}',
      () {
        final anchor = DateTime(2026, 1, 1);
        final plan = RecurrenceRule.collectDueOccurrences(
          anchorDate: anchor,
          nextRunDate: anchor,
          frequency: RecurrenceFrequency.daily,
          upToDate: DateTime(2026, 3, 15),
        );

        expect(
          plan.dueDates.length,
          RecurrenceRule.maxCatchUpOccurrencesPerBatch,
        );
        expect(plan.dueDates.first, DateTime(2026, 1, 1));
        expect(plan.dueDates.last, DateTime(2026, 1, 31));
        expect(plan.nextRunDate, DateTime(2026, 2, 1));
        expect(
          RecurrenceRule.deterministicTransactionId(
            'tpl1',
            DateTime(2026, 11, 5),
          ),
          'rec_tpl1_20261105',
        );
      },
    );

    test('serialisasi RecurringModel mendukung transfer internal dan eksternal', () {
      final model = RecurringModel(
        id: 'r1',
        title: 'Tabungan Rutin',
        amount: 200000,
        categoryId: 'c7',
        type: TransactionType.transfer,
        dompetId: 'w1',
        destinationDompetId: 'w2',
        frequency: RecurrenceFrequency.monthly,
        intervalCount: 1,
        startDate: DateTime(2026, 11, 1),
        nextRunDate: DateTime(2026, 12, 1),
      );

      final restored = RecurringModel.fromMap(model.toMap(), docId: 'r1');
      expect(restored.isInternalTransfer, isTrue);
      expect(restored.destinationDompetId, 'w2');
      expect(restored.scheduleLabel, 'Setiap Bulan');
    });
  });
}
