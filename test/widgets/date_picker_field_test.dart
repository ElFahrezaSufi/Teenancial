import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/utils/currency_formatter.dart';
import 'package:teenancial/widgets/common/date_picker_field.dart';
import 'package:teenancial/widgets/transaction/paged_transaction_list.dart';

void main() {
  group('DatePickerField', () {
    testWidgets('menampilkan nilai awal, tombol hapus saat clearable, dan validasi', (
      tester,
    ) async {
      DateTime? currentDate = DateTime(2026, 12, 31);
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: formKey,
                  child: DatePickerField(
                    label: 'Tenggat',
                    hint: 'Pilih tanggal',
                    value: currentDate,
                    clearable: true,
                    onChanged: (val) => setState(() => currentDate = val),
                    validator: (val) =>
                        val == null ? 'Tanggal wajib diisi' : null,
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Tenggat'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(formKey.currentState!.validate(), isTrue);

      // Tekan tombol hapus (X)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(currentDate, isNull);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Tanggal wajib diisi'), findsOneWidget);
    });
  });

  group('PagedTransactionList', () {
    final thirtyItems = List<TransactionModel>.generate(
      30,
      (i) => TransactionModel(
        id: 'tx_$i',
        title: 'Transaksi Ke-$i',
        amount: 10000 + i * 1000,
        date: DateTime(2026, 11, 10).subtract(Duration(days: i ~/ 5)),
        notes: '',
        categoryId: 'c3',
        type: TransactionType.expense,
        dompetId: 'd1',
      ),
    );

    testWidgets(
      'menampilkan 20 item pertama, tombol Muat Lebih Banyak (10 lagi), dan mereset ke 20 saat filterKey berubah',
      (tester) async {
        String filterKey = 'all';

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  appBar: AppBar(
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => filterKey = 'monthly'),
                        child: const Text('Ganti Filter'),
                      ),
                    ],
                  ),
                  body: PagedTransactionList(
                    transactions: thirtyItems,
                    filterKey: filterKey,
                    formatCurrency: Formatters.rupiah,
                    onEdit: (_) {},
                    onDelete: (_) {},
                  ),
                );
              },
            ),
          ),
        );

        // Gulir ke bagian paling bawah batch pertama (20 item)
        await tester.scrollUntilVisible(
          find.text('Menampilkan 20 dari 30 transaksi'),
          300,
        );

        expect(find.text('Menampilkan 20 dari 30 transaksi'), findsOneWidget);
        expect(find.text('Muat Lebih Banyak (10 lagi)'), findsOneWidget);

        // Ketuk tombol Muat Lebih Banyak
        await tester.tap(find.text('Muat Lebih Banyak (10 lagi)'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Menampilkan 30 dari 30 transaksi'),
          300,
        );
        expect(find.text('Menampilkan 30 dari 30 transaksi'), findsOneWidget);
        expect(find.textContaining('Muat Lebih Banyak'), findsNothing);

        // Ubah filterKey -> harus ter-reset kembali ke 20 transaksi pertama
        await tester.tap(find.text('Ganti Filter'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Menampilkan 20 dari 30 transaksi'),
          300,
        );
        expect(find.text('Menampilkan 20 dari 30 transaksi'), findsOneWidget);
      },
    );
  });
}
