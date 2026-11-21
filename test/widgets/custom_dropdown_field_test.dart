import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/utils/currency_formatter.dart';
import 'package:teenancial/widgets/common/custom_dropdown_field.dart';
import 'package:teenancial/widgets/home/total_saldo_card.dart';
import 'package:teenancial/widgets/transaction/transaction_card.dart';
import 'package:teenancial/widgets/transaction/transaction_form_screen.dart';

class _StubDompetRepository extends DompetRepository {
  @override
  Future<List<DompetItem>> getDompets(String uid) async {
    return const [
      DompetItem(
        id: 'd1',
        jenis: JenisDompet.cash,
        nama: 'Dompet Saku',
        jumlah: 250000,
      ),
    ];
  }
}

class _StubTransactionRepository extends TransactionRepository {
  @override
  Future<List<TransactionModel>> getTransactions(String uid) async => const [];
}

void main() {
  group('CustomDropdownField (Regresi H6)', () {
    testWidgets(
      'tidak crash saat daftar items dan value berubah dinamis (simulasi pindah tab Hutang <-> Piutang)',
      (WidgetTester tester) async {
        const debtItems = ['Pinjam Teman', 'Kebutuhan Sekolah'];
        const receivableItems = ['Pinjami Teman', 'Talangan'];

        String? selectedValue = debtItems.first;
        List<String> currentItems = debtItems;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      CustomDropdownField(
                        label: 'Kategori',
                        hint: 'Pilih kategori',
                        items: currentItems,
                        value: selectedValue,
                        onChanged: (val) => setState(() => selectedValue = val),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentItems = receivableItems;
                            selectedValue = receivableItems.first;
                          });
                        },
                        child: const Text('Ganti Tab'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        expect(find.text('Pinjam Teman'), findsOneWidget);

        await tester.tap(find.text('Ganti Tab'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Pinjami Teman'), findsOneWidget);
      },
    );
  });

  group('TransactionFormScreen Widget Test', () {
    testWidgets(
      'menampilkan form Pemasukan dan memformat input nominal ke format Rupiah bertitik',
      (WidgetTester tester) async {
        final dompetProvider = DompetProvider(
          repository: _StubDompetRepository(),
        )..updateUser('user_test');
        final txProvider = TransactionProvider(
          repository: _StubTransactionRepository(),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<DompetProvider>.value(
                value: dompetProvider,
              ),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
            ],
            child: const MaterialApp(
              home: TransactionFormScreen(type: TransactionType.income),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pemasukan'), findsOneWidget);

        final nominalField = find.byType(TextField).first;
        await tester.enterText(nominalField, '150000');
        await tester.pump();

        expect(find.text('Rp 150.000'), findsOneWidget);
      },
    );
  });

  group('TransactionCard Widget Test (Opsi 2A & 3A)', () {
    testWidgets(
      'menampilkan 1 baris nama kategori jika tidak ada catatan, dan Kategori di atas + Catatan di bawah jika ada catatan',
      (WidgetTester tester) async {
        final txWithoutNote = TransactionModel(
          id: 'tx1',
          title: 'Hiburan',
          amount: 50000,
          date: DateTime(2026, 11, 14),
          notes: '',
          categoryId: 'c5', // Hiburan
          type: TransactionType.expense,
          dompetId: 'd1',
        );

        final txWithDuplicateOldNote = TransactionModel(
          id: 'tx2',
          title: 'Beli Kopi',
          amount: 25000,
          date: DateTime(2026, 11, 14),
          notes: 'Beli Kopi',
          categoryId: 'c3', // Makanan
          type: TransactionType.expense,
          dompetId: 'd1',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TransactionCard(
                    item: txWithoutNote,
                    formatCurrency: Formatters.rupiah,
                    onEdit: (_) {},
                    onDelete: (_) {},
                  ),
                  TransactionCard(
                    item: txWithDuplicateOldNote,
                    formatCurrency: Formatters.rupiah,
                    onEdit: (_) {},
                    onDelete: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        // txWithoutNote hanya menampilkan 'Hiburan' 1 kali (tidak kembar)
        expect(find.text('Hiburan'), findsOneWidget);
        // txWithDuplicateOldNote menampilkan 'Makanan' (di atas) dan 'Beli Kopi' 1 kali (di bawah)
        expect(find.text('Makanan'), findsOneWidget);
        expect(find.text('Beli Kopi'), findsOneWidget);
      },
    );

    testWidgets(
      'transaksi pembelian target menampilkan nama kategori dan badge Target tanpa simbol titik pemisah',
      (WidgetTester tester) async {
        final txTargetSettlement = TransactionModel(
          id: 'tx_target_1',
          title: 'Sepatu Lari',
          amount: 450000,
          date: DateTime(2026, 11, 21),
          notes: '',
          categoryId: 'c4', // Belanja
          type: TransactionType.expense,
          dompetId: 'd1',
          targetId: 'target_1',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransactionCard(
                item: txTargetSettlement,
                formatCurrency: Formatters.rupiah,
                onEdit: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Sepatu Lari'), findsOneWidget);
        expect(find.text('Target'), findsOneWidget);
        expect(find.textContaining('•'), findsNothing);
      },
    );
  });

  group('TotalSaldoCard Anti-Overflow Test', () {
    testWidgets(
      'nominal besar pada layar sempit (320px) tidak menyebabkan RenderFlex overflow',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TotalSaldoCard(
                    totalSaldoReal: 99999999999,
                    perkiraanMingguanReal: 99999999999,
                    xpProgress: 0.5,
                    currentXP: 50,
                    maxXP: 100,
                    level: 2,
                    formatRupiah: Formatters.rupiah,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Rp 99.999.999.999'), findsNWidgets(2));
      },
    );
  });
}
