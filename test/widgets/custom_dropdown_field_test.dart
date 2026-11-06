import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/widgets/common/custom_dropdown_field.dart';
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
}
