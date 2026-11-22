import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/models/contact_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/providers/contact_provider.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/repositories/contact_repository.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/screens/buat_berulang_screen.dart';
import 'package:teenancial/screens/detail_kontak_screen.dart';
import 'package:teenancial/screens/kontak_screen.dart';
import 'package:teenancial/screens/transfer_screen.dart';
import 'package:teenancial/utils/currency_formatter.dart';
import 'package:teenancial/widgets/transaction/contact_selection_autocomplete.dart';
import 'package:teenancial/widgets/transaction/dompet_selection_dropdown.dart';
import 'package:teenancial/widgets/transaction/loan_card.dart';
import 'package:teenancial/widgets/transaction/transaction_form_screen.dart';

class _StubDompetRepo extends DompetRepository {
  final List<DompetItem> wallets;
  _StubDompetRepo(this.wallets);

  @override
  Future<List<DompetItem>> getDompets(String uid) async => wallets;
}

class _StubContactRepo extends ContactRepository {
  final List<ContactModel> items;
  _StubContactRepo(this.items);

  @override
  Future<List<ContactModel>> getContacts(String uid) async {
    final copy = List<ContactModel>.from(items);
    copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return copy;
  }
}

class _StubTxRepo extends TransactionRepository {
  final List<TransactionModel> items;
  _StubTxRepo(this.items);

  @override
  Future<List<TransactionModel>> getTransactions(String uid) async => items;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ContactSelectionAutocomplete (3-State Context-Aware Checkbox)', () {
    const sampleContacts = [
      ContactModel(id: 'c1', name: 'Budi', note: 'Teman kelas'),
      ContactModel(id: 'c2', name: 'Siti', note: 'GoPay 0812'),
    ];

    testWidgets(
      'berpindah dinamis antar 3 kondisi: kosong -> nama baru (checkbox) -> cocok kontak (indikator) -> nama baru lagi',
      (WidgetTester tester) async {
        final controller = TextEditingController();
        bool saveToList = false;
        int manageTapped = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ContactSelectionAutocomplete(
                      label: 'Untuk',
                      hint: 'Nama teman',
                      controller: controller,
                      contacts: sampleContacts,
                      showSaveToListOption: true,
                      saveToListValue: saveToList,
                      onSaveToListChanged: (val) =>
                          setState(() => saveToList = val),
                      onManageContacts: () => manageTapped++,
                    ),
                  ),
                ),
              );
            },
          ),
        );

        // 1. Kosong -> sembunyikan checkbox maupun indikator tersimpan
        expect(find.byKey(const Key('contact_save_checkbox')), findsNothing);
        expect(
          find.byKey(const Key('contact_already_saved_indicator')),
          findsNothing,
        );

        // Pintasan Kelola Kontak selalu tersedia
        await tester.tap(find.byKey(const Key('contact_manage_shortcut')));
        expect(manageTapped, 1);

        // 2. Ketik nama baru -> muncul checkbox Simpan ke daftar kontak
        await tester.enterText(find.byType(TextFormField), 'Andi');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('contact_save_checkbox')), findsOneWidget);
        expect(find.text('Simpan ke daftar kontak'), findsOneWidget);

        await tester.tap(find.byKey(const Key('contact_save_checkbox')));
        await tester.pump();
        expect(saveToList, isTrue);

        // 3. Ketik nama kontak yang sudah ada (beda kapital) -> ganti jadi indikator
        await tester.enterText(find.byType(TextFormField), 'budi');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('contact_save_checkbox')), findsNothing);
        expect(
          find.byKey(const Key('contact_already_saved_indicator')),
          findsOneWidget,
        );
        expect(find.text('Tersimpan di daftar kontak'), findsOneWidget);

        // 4. Ubah jadi nama baru -> checkbox muncul kembali
        await tester.enterText(find.byType(TextFormField), 'Budi Baru');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('contact_save_checkbox')), findsOneWidget);
        expect(
          find.byKey(const Key('contact_already_saved_indicator')),
          findsNothing,
        );

        controller.dispose();
      },
    );

    testWidgets(
      'prefill nama kontak tersimpan langsung menampilkan indikator tanpa error fase build',
      (WidgetTester tester) async {
        final controller = TextEditingController(text: 'Siti');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ContactSelectionAutocomplete(
                  label: 'Untuk',
                  hint: 'Nama teman',
                  controller: controller,
                  contacts: sampleContacts,
                  showSaveToListOption: true,
                  saveToListValue: false,
                  onSaveToListChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('contact_already_saved_indicator')),
          findsOneWidget,
        );
        expect(find.text('Siti'), findsOneWidget);

        controller.dispose();
      },
    );

    testWidgets(
      'saran kontak tidak muncul saat field kosong, baru muncul saat mengetik, dan membuka ke atas saat optionsViewOpenDirection.up',
      (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: ContactSelectionAutocomplete(
                    label: 'Untuk',
                    hint: 'Nama teman',
                    controller: controller,
                    contacts: sampleContacts,
                    optionsViewOpenDirection: OptionsViewOpenDirection.up,
                  ),
                ),
              ),
            ),
          ),
        );

        // Fokus saat kosong -> tidak memunculkan dropdown saran
        await tester.tap(find.byType(TextFormField));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('contact_autocomplete_options')),
          findsNothing,
        );

        // Mulai mengetik 'bu' -> dropdown muncul di atas TextFormField
        await tester.enterText(find.byType(TextFormField), 'bu');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('contact_autocomplete_options')),
          findsOneWidget,
        );
        expect(find.text('Budi'), findsOneWidget);
        expect(find.text('Siti'), findsNothing);

        final optionsRect = tester.getRect(
          find.byKey(const Key('contact_autocomplete_options')),
        );
        final fieldRect = tester.getRect(find.byType(TextFormField));
        expect(optionsRect.bottom, lessThanOrEqualTo(fieldRect.top));

        controller.dispose();
      },
    );
  });

  group('DompetSelectionDropdown (Info Saldo & Peringatan Live)', () {
    const wallets = [
      DompetItem(
        id: 'd1',
        jenis: JenisDompet.cash,
        nama: 'Dompet Saku',
        jumlah: 50000,
      ),
      DompetItem(
        id: 'd2',
        jenis: JenisDompet.accounts,
        nama: 'GoPay',
        jumlah: 100000,
      ),
    ];

    test('evaluateWalletBalance menghitung shortfall, batas edit, dan advisory',
        () {
      final neutral = DompetSelectionDropdown.evaluateWalletBalance(
        walletBalance: 50000,
        enteredAmount: 200000,
        checkSufficiency: false,
      );
      expect(neutral.isInsufficient, isFalse);
      expect(neutral.shortfall, 0);

      final sufficient = DompetSelectionDropdown.evaluateWalletBalance(
        walletBalance: 50000,
        enteredAmount: 50000,
        checkSufficiency: true,
      );
      expect(sufficient.isInsufficient, isFalse);

      final insufficient = DompetSelectionDropdown.evaluateWalletBalance(
        walletBalance: 50000,
        enteredAmount: 75000,
        checkSufficiency: true,
      );
      expect(insufficient.isInsufficient, isTrue);
      expect(insufficient.shortfall, 25000);
      expect(insufficient.isAdvisoryOnly, isFalse);

      // Mode edit pada dompet sama: saldo 20k + refund 50k = 70k
      final editSafe = DompetSelectionDropdown.evaluateWalletBalance(
        walletBalance: 20000,
        enteredAmount: 60000,
        checkSufficiency: true,
        editRefundAllowance: 50000,
      );
      expect(editSafe.availableBalance, 70000);
      expect(editSafe.isInsufficient, isFalse);

      final editOver = DompetSelectionDropdown.evaluateWalletBalance(
        walletBalance: 20000,
        enteredAmount: 80000,
        checkSufficiency: true,
        editRefundAllowance: 50000,
      );
      expect(editOver.isInsufficient, isTrue);
      expect(editOver.shortfall, 10000);

      // Jadwal berulang masa depan -> advisory
      final futureAdvisory = DompetSelectionDropdown.evaluateWalletBalance(
        walletBalance: 50000,
        enteredAmount: 75000,
        checkSufficiency: true,
        isFutureSchedule: true,
      );
      expect(futureAdvisory.isInsufficient, isTrue);
      expect(futureAdvisory.isAdvisoryOnly, isTrue);
    });

    testWidgets(
      'menampilkan saldo di bawah dropdown dan peringatan 2 baris saat saldo kurang, lalu hilang saat ganti dompet cukup',
      (WidgetTester tester) async {
        String? selectedId = 'd1';
        double? enteredAmount = 30000;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DompetSelectionDropdown(
                          label: 'Sumber Uang',
                          hint: 'Pilih dompet',
                          dompets: wallets,
                          selectedDompetId: selectedId,
                          showBalanceInfo: true,
                          checkSufficiency: true,
                          enteredAmount: enteredAmount,
                          onChanged: (val) => setState(() => selectedId = val),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              setState(() => enteredAmount = 75000),
                          child: const Text('Set 75k'),
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() => selectedId = 'd2'),
                          child: const Text('Pilih GoPay'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );

        // Saldo Rp 50.000, nominal Rp 30.000 -> tampil saldo tanpa peringatan
        expect(find.byKey(const Key('dompet_balance_info')), findsOneWidget);
        expect(find.text('Saldo tersedia'), findsOneWidget);
        expect(find.text('Rp 50.000'), findsOneWidget);
        expect(find.byKey(const Key('dompet_balance_warning')), findsNothing);

        // Nominal naik ke Rp 75.000 -> peringatan kurang Rp 25.000 muncul
        await tester.tap(find.text('Set 75k'));
        await tester.pump();
        expect(find.byKey(const Key('dompet_balance_warning')), findsOneWidget);
        expect(
          find.text('Saldo tidak mencukupi (kurang Rp 25.000)'),
          findsOneWidget,
        );

        // Ganti ke GoPay (Rp 100.000) -> peringatan hilang dan saldo berubah
        await tester.tap(find.text('Pilih GoPay'));
        await tester.pump();
        expect(find.text('Rp 100.000'), findsOneWidget);
        expect(find.byKey(const Key('dompet_balance_warning')), findsNothing);
      },
    );

    testWidgets(
      'mode jadwal masa depan menampilkan pesan advisory halus tanpa pesan error keras',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DompetSelectionDropdown(
                  label: 'Sumber Uang',
                  hint: 'Pilih dompet',
                  dompets: wallets,
                  selectedDompetId: 'd1',
                  showBalanceInfo: true,
                  checkSufficiency: true,
                  enteredAmount: 75000,
                  isFutureSchedule: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(
          find.text(
            'Saldo saat ini belum cukup. Pastikan saldo cukup saat jadwal berjalan.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TransactionFormScreen Pengeluaran bereaksi live terhadap input nominal, sedangkan Pemasukan selalu netral',
      (WidgetTester tester) async {
        final dompetProvider = DompetProvider(
          repository: _StubDompetRepo(wallets),
        )..updateUser('u1');
        final txProvider = TransactionProvider(
          repository: _StubTxRepo(const []),
        );

        // 1. Pengeluaran
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
              home: TransactionFormScreen(type: TransactionType.expense),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Saldo tersedia'), findsOneWidget);
        expect(find.text('Rp 50.000'), findsOneWidget);
        expect(find.byKey(const Key('dompet_balance_warning')), findsNothing);

        await tester.enterText(find.byType(TextField).first, '75000');
        await tester.pump();
        expect(
          find.text('Saldo tidak mencukupi (kurang Rp 25.000)'),
          findsOneWidget,
        );

        // 2. Pemasukan -> info saldo tetap tampil, peringatan tidak muncul
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

        await tester.enterText(find.byType(TextField).first, '500000');
        await tester.pump();
        expect(find.text('Rp 50.000'), findsOneWidget);
        expect(find.byKey(const Key('dompet_balance_warning')), findsNothing);
      },
    );

    testWidgets(
      'DompetSelectionDropdown mengurutkan item sesuai jenis Tunai -> Rekening & E-Wallet -> Kartu lalu waktu dibuat',
      (WidgetTester tester) async {
        final mixedWallets = [
          DompetItem(
            id: 'w_card',
            jenis: JenisDompet.card,
            nama: 'Mandiri',
            jumlah: 100000,
            createdAt: DateTime(2026, 1, 2),
          ),
          DompetItem(
            id: 'w_acc_new',
            jenis: JenisDompet.accounts,
            nama: 'LinkAja',
            jumlah: 40000,
            createdAt: DateTime(2026, 1, 6),
          ),
          DompetItem(
            id: 'w_acc_old',
            jenis: JenisDompet.accounts,
            nama: 'SeaBank',
            jumlah: 80000,
            createdAt: DateTime(2026, 1, 1),
          ),
          const DompetItem(
            id: 'd1',
            jenis: JenisDompet.cash,
            nama: 'Dompet Utama',
            jumlah: 50000,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DompetSelectionDropdown(
                  label: 'Sumber Uang',
                  hint: 'Pilih dompet',
                  dompets: mixedWallets,
                  selectedDompetId: 'd1',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        final yCash = tester.getTopLeft(find.text('Dompet Utama (Tunai)').last).dy;
        final ySeaBank = tester
            .getTopLeft(find.text('SeaBank (Rekening & E-Wallet)').last)
            .dy;
        final yLinkAja = tester
            .getTopLeft(find.text('LinkAja (Rekening & E-Wallet)').last)
            .dy;
        final yMandiri = tester.getTopLeft(find.text('Mandiri (Kartu)').last).dy;

        expect(yCash, lessThan(ySeaBank));
        expect(ySeaBank, lessThan(yLinkAja));
        expect(yLinkAja, lessThan(yMandiri));
      },
    );
  });

  group('KontakScreen & DetailKontakScreen Widget Test', () {
    const budi = ContactModel(id: 'c1', name: 'Budi', note: 'Teman sekelas');
    const rina = ContactModel(id: 'c2', name: 'Rina', note: 'GoPay 0812');

    final txs = [
      TransactionModel(
        id: 't1',
        title: 'Transfer ke Budi',
        amount: 35000,
        date: DateTime(2026, 11, 22),
        categoryId: 'c10',
        type: TransactionType.transfer,
        dompetId: 'd1',
        contactId: 'c1',
        counterpartyName: 'Budi',
      ),
      TransactionModel(
        id: 't2',
        title: 'Piutang ke Budi',
        amount: 60000,
        date: DateTime(2026, 11, 21),
        categoryId: 'c12',
        type: TransactionType.receivable,
        dompetId: 'd1',
        contactId: 'c1',
        counterpartyName: 'Budi',
      ),
    ];

    testWidgets(
      'KontakScreen menampilkan daftar kontak A-Z, ringkasan transaksi, dan pencarian live',
      (WidgetTester tester) async {
        final contactProvider = ContactProvider(
          repository: _StubContactRepo(const [rina, budi]),
        )..updateUser('u1');
        final txProvider = TransactionProvider(
          repository: _StubTxRepo(txs),
        )..updateUser('u1');

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ContactProvider>.value(
                value: contactProvider,
              ),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
            ],
            child: const MaterialApp(home: KontakScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Daftar Kontak'), findsOneWidget);
        expect(find.byTooltip('Tambah Kontak'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Budi'), findsOneWidget);
        expect(find.text('Rina'), findsOneWidget);
        expect(find.text('2 transaksi'), findsOneWidget);
        expect(find.text('Piutang Rp 60.000'), findsOneWidget);
        expect(find.textContaining('—'), findsNothing);
        expect(find.textContaining('•'), findsNothing);

        // Cari berdasarkan catatan
        await tester.enterText(
          find.byKey(const Key('kontak_search_field')),
          'GoPay',
        );
        await tester.pumpAndSettle();
        expect(find.text('Rina'), findsOneWidget);
        expect(find.text('Budi'), findsNothing);
      },
    );

    testWidgets(
      'DetailKontakScreen menampilkan ringkasan, tombol aksi cepat, dan filter riwayat',
      (WidgetTester tester) async {
        final contactProvider = ContactProvider(
          repository: _StubContactRepo(const [budi]),
        )..updateUser('u1');
        final txProvider = TransactionProvider(
          repository: _StubTxRepo(txs),
        )..updateUser('u1');

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ContactProvider>.value(
                value: contactProvider,
              ),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
            ],
            child: const MaterialApp(
              home: DetailKontakScreen(contactId: 'c1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Budi'), findsOneWidget);
        expect(find.text('Teman sekelas'), findsOneWidget);
        expect(find.byKey(const Key('contact_quick_transfer_btn')), findsOneWidget);
        expect(find.byKey(const Key('contact_quick_loan_btn')), findsOneWidget);
        expect(find.text('Total Transfer'), findsOneWidget);
        expect(find.text('Hutang Aktif'), findsOneWidget);
        expect(find.text('Piutang Aktif'), findsOneWidget);
        expect(find.text('Transfer ke Budi'), findsOneWidget);
        expect(find.text('Piutang ke Budi'), findsOneWidget);
        expect(find.textContaining('—'), findsNothing);
        expect(find.textContaining('•'), findsNothing);

        // Filter khusus Piutang
        await tester.tap(find.text('Piutang'));
        await tester.pumpAndSettle();
        expect(find.text('Piutang ke Budi'), findsOneWidget);
        expect(find.text('Transfer ke Budi'), findsNothing);

        // Filter Hutang -> empty state khusus filter
        await tester.tap(find.text('Hutang'));
        await tester.pumpAndSettle();
        expect(
          find.text('Tidak ada transaksi untuk filter ini'),
          findsOneWidget,
        );
      },
    );
  });

  group('Transfer/Berulang Default & LoanCard Bayar Penuh Widget Test', () {
    const wallets = [
      DompetItem(
        id: 'd1',
        jenis: JenisDompet.cash,
        nama: 'Dompet Utama',
        jumlah: 100000,
      ),
      DompetItem(
        id: 'd2',
        jenis: JenisDompet.accounts,
        nama: 'Go-Pay',
        jumlah: 50000,
      ),
    ];

    testWidgets(
      'TransferScreen berpindah mulus Eksternal <-> Internal dan BuatBerulangScreen default Eksternal',
      (WidgetTester tester) async {
        final dompetProvider = DompetProvider(
          repository: _StubDompetRepo(wallets),
        )..updateUser('u1');
        final contactProvider = ContactProvider(
          repository: _StubContactRepo(const []),
        )..updateUser('u1');
        final txProvider = TransactionProvider(
          repository: _StubTxRepo(const []),
        )..updateUser('u1');

        // 1. TransferScreen default Eksternal -> toggle ke Internal
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<DompetProvider>.value(
                value: dompetProvider,
              ),
              ChangeNotifierProvider<ContactProvider>.value(
                value: contactProvider,
              ),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
            ],
            child: const MaterialApp(home: TransferScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sumber Uang'), findsOneWidget);
        expect(find.text('Untuk'), findsOneWidget);
        expect(find.text('Ke'), findsNothing);

        await tester.tap(find.text('Transfer ke diri sendiri'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Dari'), findsOneWidget);
        expect(find.text('Ke'), findsOneWidget);
        expect(find.text('Sumber Uang'), findsNothing);
        expect(find.text('Untuk'), findsNothing);

        // 2. BuatBerulangScreen Transfer default Eksternal (seragam dengan TransferScreen)
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<DompetProvider>.value(
                value: dompetProvider,
              ),
              ChangeNotifierProvider<ContactProvider>.value(
                value: contactProvider,
              ),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
            ],
            child: const MaterialApp(
              home: BuatBerulangScreen(initialType: TransactionType.transfer),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sumber Uang'), findsOneWidget);
        expect(find.text('Untuk'), findsOneWidget);
        expect(find.text('Ke Dompet'), findsNothing);
      },
    );

    testWidgets(
      'LoanCard menampilkan Bayar Penuh untuk pelunasan langsung 1x dan Nx cicilan untuk cicilan bertahap',
      (WidgetTester tester) async {
        final contactProvider = ContactProvider(
          repository: _StubContactRepo(const []),
        )..updateUser('u1');
        final today = DateTime(2026, 11, 22);

        final baseLoan = TransactionModel(
          id: 'l1',
          title: 'Hutang dari Budi',
          amount: 50000,
          date: today,
          categoryId: 'c11',
          type: TransactionType.debt,
          dompetId: 'd1',
          counterpartyName: 'Budi',
        );
        final directFull = baseLoan.withPayment(
          LoanPayment(id: 'p1', amount: 50000, date: today, dompetId: 'd1'),
        );
        final partial = baseLoan.copyWith(id: 'l2').withPayment(
          LoanPayment(id: 'p2', amount: 20000, date: today, dompetId: 'd1'),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<ContactProvider>.value(
            value: contactProvider,
            child: MaterialApp(
              home: Scaffold(
                body: ListView(
                  children: [
                    LoanCard(
                      item: directFull,
                      formatCurrency: Formatters.rupiah,
                      onMarkPaid: () {},
                      onShowHistory: () {},
                    ),
                    LoanCard(
                      item: partial,
                      formatCurrency: Formatters.rupiah,
                      onMarkPaid: () {},
                      onShowHistory: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bayar Penuh'), findsOneWidget);
        expect(find.text('1x cicilan'), findsOneWidget);
      },
    );
  });
}
