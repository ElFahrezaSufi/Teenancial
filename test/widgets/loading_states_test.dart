import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/models/contact_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/providers/contact_provider.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/mission_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/providers/user_provider.dart';
import 'package:teenancial/repositories/contact_repository.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/repositories/user_repository.dart';
import 'package:teenancial/screens/daftar_pinjaman_screen.dart';
import 'package:teenancial/screens/semua_aktivitas_screen.dart';
import 'package:teenancial/widgets/common/async_state_view.dart';
import 'package:teenancial/widgets/common/loading_overlay.dart';

class _StubUserRepo extends UserRepository {
  final UserModel profile;
  _StubUserRepo(this.profile);

  @override
  Future<UserModel> getUserProfile(String uid) async => profile;
}

class _StubDompetRepo extends DompetRepository {
  @override
  Future<List<DompetItem>> getDompets(String uid) async => const [
        DompetItem(
          id: 'w1',
          jenis: JenisDompet.cash,
          nama: 'Dompet Utama',
          jumlah: 100000,
        ),
      ];
}

class _StubContactRepo extends ContactRepository {
  @override
  Future<List<ContactModel>> getContacts(String uid) async => const [];
}

class _ControllableTxRepo extends TransactionRepository {
  Completer<List<TransactionModel>>? loadCompleter;
  Completer<void>? deleteCompleter;
  bool shouldFailLoad = false;
  final List<TransactionModel> items;

  _ControllableTxRepo(this.items);

  @override
  Future<List<TransactionModel>> getTransactions(String uid) async {
    if (loadCompleter != null) {
      return loadCompleter!.future;
    }
    if (shouldFailLoad) {
      throw Exception('Simulasi gagal muat transaksi');
    }
    return List<TransactionModel>.from(items);
  }

  @override
  Future<void> deleteTransaction(String uid, String transactionId) async {
    if (deleteCompleter != null) {
      await deleteCompleter!.future;
    }
    items.removeWhere((t) => t.id == transactionId);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('LoadingOverlay & runWithLoadingDialog', () {
    testWidgets(
      'LoadingOverlay menampilkan pesan loading dan memblokir tap saat isLoading true',
      (WidgetTester tester) async {
        int taps = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: LoadingOverlay(
              isLoading: true,
              message: 'Menyimpan data...',
              child: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('Aksi'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Menyimpan data...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.tap(find.text('Aksi'), warnIfMissed: false);
        expect(taps, 0);
      },
    );

    testWidgets(
      'runWithLoadingDialog menampilkan dialog selama aksi berjalan dan menutupnya saat sukses maupun error',
      (WidgetTester tester) async {
        final completer = Completer<String>();
        String? result;
        Object? caught;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        result = await runWithLoadingDialog(
                          context,
                          message: 'Menghapus item...',
                          action: () => completer.future,
                        );
                      },
                      child: const Text('Jalankan Sukses'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await runWithLoadingDialog<void>(
                            context,
                            message: 'Aksi Gagal...',
                            action: () => Future<void>.error(
                              StateError('Simulasi gagal'),
                            ),
                          );
                        } catch (e) {
                          caught = e;
                        }
                      },
                      child: const Text('Jalankan Error'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Jalankan Sukses'));
        await tester.pump();
        expect(find.text('Menghapus item...'), findsOneWidget);

        completer.complete('OK');
        await tester.pumpAndSettle();
        expect(result, 'OK');
        expect(find.text('Menghapus item...'), findsNothing);

        await tester.tap(find.text('Jalankan Error'));
        await tester.pumpAndSettle();
        expect(caught, isA<StateError>());
        expect(find.text('Aksi Gagal...'), findsNothing);
      },
    );
  });

  group('Screen Loading States', () {
    testWidgets(
      'SemuaAktivitasScreen menampilkan spinner saat loading awal, ErrorStateView saat gagal, dan pulih setelah Coba Lagi',
      (WidgetTester tester) async {
        final dompetProvider = DompetProvider(repository: _StubDompetRepo());
        final missionProvider = MissionProvider(
          onLoad: (_) async => <String, dynamic>{},
          onSave: (_, __) async {},
        );
        final loadCompleter = Completer<List<TransactionModel>>();
        final txRepo = _ControllableTxRepo([])..loadCompleter = loadCompleter;
        final txProvider = TransactionProvider(repository: txRepo);

        await tester.runAsync(() async {
          dompetProvider.updateUser('u1');
          txProvider.bindDependencies('u1', dompetProvider, missionProvider);
          await Future<void>.delayed(Duration.zero);
        });

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
            child: const MaterialApp(home: SemuaAktivitasScreen()),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Tidak ada aktivitas tercatat.'), findsNothing);

        // Selesaikan dengan error -> muncul ErrorStateView
        txRepo.loadCompleter = null;
        txRepo.shouldFailLoad = true;
        loadCompleter.completeError(Exception('Timeout'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsOneWidget);

        // Pulihkan -> tap Coba Lagi
        txRepo.shouldFailLoad = false;
        txRepo.items.add(
          TransactionModel(
            id: 'tx1',
            title: 'Jajan Bakso',
            amount: 15000,
            date: DateTime.now(),
            categoryId: 'c1',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
        );
        await tester.tap(find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsNothing);
        expect(find.text('Jajan Bakso'), findsOneWidget);
      },
    );

    testWidgets(
      'DaftarPinjamanScreen menampilkan LoadingOverlay saat menghapus pinjaman',
      (WidgetTester tester) async {
        final userProvider = UserProvider(
          repository: _StubUserRepo(
            const UserModel(uid: 'u1', email: 'a@b.com', name: 'Rani'),
          ),
        );
        final dompetProvider = DompetProvider(repository: _StubDompetRepo());
        final contactProvider = ContactProvider(repository: _StubContactRepo());
        final missionProvider = MissionProvider(
          onLoad: (_) async => <String, dynamic>{},
          onSave: (_, __) async {},
        );
        final deleteCompleter = Completer<void>();
        final txRepo = _ControllableTxRepo([
          TransactionModel(
            id: 'loan_1',
            title: 'Pinjaman Budi',
            amount: 50000,
            date: DateTime(2026, 11, 20),
            categoryId: 'p1',
            type: TransactionType.debt,
            dompetId: 'w1',
            counterpartyName: 'Budi',
          ),
        ])
          ..deleteCompleter = deleteCompleter;
        final txProvider = TransactionProvider(repository: txRepo);

        await tester.runAsync(() async {
          userProvider.updateUser('u1');
          dompetProvider.updateUser('u1');
          contactProvider.updateUser('u1');
          txProvider.bindDependencies('u1', dompetProvider, missionProvider);
          await Future<void>.delayed(Duration.zero);
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
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
            child: const MaterialApp(home: DaftarPinjamanScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Buka menu opsi kartu pinjaman -> Hapus -> Konfirmasi
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Hapus').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
        await tester.pump();

        expect(find.text('Menghapus pinjaman...'), findsOneWidget);

        deleteCompleter.complete();
        await tester.pumpAndSettle();

        expect(find.text('Menghapus pinjaman...'), findsNothing);
      },
    );
  });
}
