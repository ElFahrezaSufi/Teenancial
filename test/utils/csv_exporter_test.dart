import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/utils/csv_exporter.dart';

void main() {
  group('CsvExporter', () {
    test(
      'escapeCell mencegah CSV formula injection (=, +, -, @) dan mengutip delimiter ; serta tanda kutip ganda',
      () {
        expect(CsvExporter.escapeCell('=SUM(A1:A10)'), "'=SUM(A1:A10)");
        expect(CsvExporter.escapeCell('+62812345'), "'+62812345");
        expect(CsvExporter.escapeCell('-Rp 50.000'), "'-Rp 50.000");
        expect(CsvExporter.escapeCell('@admin'), "'@admin");
        expect(
          CsvExporter.escapeCell('Makan; "Spesial"\nSiang'),
          '"Makan; ""Spesial""\nSiang"',
        );
        // Nilai numerik murni tidak diberi tanda petik tunggal
        expect(CsvExporter.escapeCell('150000', isNumeric: true), '150000');
      },
    );

    test(
      'generateCsvBytes menyertakan UTF-8 BOM di awal dan memisahkan 11 kolom dengan titik koma (;)',
      () {
        const dompets = [
          DompetItem(
            id: 'w1',
            nama: 'BCA',
            jenis: JenisDompet.accounts,
            jumlah: 500000,
          ),
          DompetItem(
            id: 'w2',
            nama: 'Tabungan',
            jenis: JenisDompet.accounts,
            jumlah: 1000000,
          ),
        ];

        final txs = [
          TransactionModel(
            id: 'rec_tpl1_20261114',
            title: 'Tabungan Rutin',
            amount: 200000,
            date: DateTime(2026, 11, 14, 9, 0),
            notes: 'Otomatis; bulanan',
            categoryId: 'c7',
            type: TransactionType.transfer,
            dompetId: 'w1',
            destinationDompetId: 'w2',
            recurringId: 'tpl1',
          ),
        ];

        final bytes = CsvExporter.generateCsvBytes(
          transactions: txs,
          dompets: dompets,
        );

        // Cek 3 byte pertama adalah UTF-8 BOM
        expect(bytes.sublist(0, 3), CsvExporter.utf8Bom);

        final decoded = utf8.decode(bytes.sublist(3));
        final lines = decoded.trim().split(CsvExporter.lineEnding);
        expect(lines.length, 2);
        expect(lines[0].split(';').length, 11);
        expect(lines[1], contains('Transfer Internal'));
        expect(lines[1], contains('BCA;Tabungan'));
        expect(lines[1], contains('"Otomatis; bulanan"'));
        expect(lines[1], endsWith(';Berulang'));
      },
    );
  });
}
