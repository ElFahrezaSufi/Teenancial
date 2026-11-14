import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/transaction_filter.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/utils/pdf_report_builder.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('PdfReportBuilder', () {
    test(
      'sanitizePdfText menghapus emoji agar tidak memunculkan simbol kotak kosong (tofu) pada PDF',
      () {
        expect(
          PdfReportBuilder.sanitizePdfText('Makan Bakso 🍜🔥 Rp 25.000 ✅'),
          'Makan Bakso Rp 25.000',
        );
      },
    );

    test(
      'generatePdfBytes menghasilkan dokumen PDF valid (%PDF-) dengan ringkasan dan riwayat transaksi',
      () async {
        const dompets = [
          DompetItem(
            id: 'w1',
            nama: 'BCA',
            jenis: JenisDompet.accounts,
            jumlah: 750000,
          ),
        ];

        final txs = [
          TransactionModel(
            id: 't1',
            title: 'Uang Saku Bulanan',
            amount: 1000000,
            date: DateTime(2026, 11, 1, 9, 0),
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'w1',
          ),
          TransactionModel(
            id: 't2',
            title: 'Beli Buku Kuliah 📚',
            amount: 250000,
            date: DateTime(2026, 11, 5, 14, 30),
            notes: 'Semester 5',
            categoryId: 'c5',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
        ];

        final bytes = await PdfReportBuilder.generatePdfBytes(
          transactions: txs,
          dompets: dompets,
          filter: TransactionFilter(periodPreset: HistoryPeriodPreset.monthly),
          generatedAt: DateTime(2026, 11, 14, 16, 0),
        );

        expect(bytes.length, greaterThan(500));
        final headerSignature = ascii.decode(bytes.sublist(0, 5));
        expect(headerSignature, '%PDF-');
      },
    );
  });
}
