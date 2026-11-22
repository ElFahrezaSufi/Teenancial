import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/services/connectivity_service.dart';
import 'package:teenancial/widgets/home/initial_balance_onboarding_sheet.dart';

void main() {
  group('InitialBalanceOnboardingHelper.shouldShowOnboarding', () {
    final defaultWallet = DompetItem.initialWallet();
    const newProfile = UserModel(
      uid: 'u_new',
      email: 'baru@example.com',
      name: 'Rani',
      initialBalanceOnboardingDone: false,
    );

    test('mengembalikan true hanya untuk pengguna baru dengan dompet d1 Rp 0 tanpa transaksi', () {
      expect(
        InitialBalanceOnboardingHelper.shouldShowOnboarding(
          profile: newProfile,
          dompets: [defaultWallet],
          transactions: const [],
          isLocalDismissed: false,
        ),
        isTrue,
      );
    });

    test('mengembalikan false untuk pengguna lama, sudah dismissed lokal, sudah punya transaksi, atau saldo > 0', () {
      // Pengguna lama (initialBalanceOnboardingDone == true)
      expect(
        InitialBalanceOnboardingHelper.shouldShowOnboarding(
          profile: newProfile.copyWith(initialBalanceOnboardingDone: true),
          dompets: [defaultWallet],
          transactions: const [],
          isLocalDismissed: false,
        ),
        isFalse,
      );

      // Sudah diselesaikan secara lokal di perangkat
      expect(
        InitialBalanceOnboardingHelper.shouldShowOnboarding(
          profile: newProfile,
          dompets: [defaultWallet],
          transactions: const [],
          isLocalDismissed: true,
        ),
        isFalse,
      );

      // Sudah memiliki transaksi di perangkat lain
      expect(
        InitialBalanceOnboardingHelper.shouldShowOnboarding(
          profile: newProfile,
          dompets: [defaultWallet],
          transactions: [
            TransactionModel(
              id: 't1',
              title: 'Jajan',
              amount: 10000,
              date: DateTime(2026, 11, 20),
              categoryId: 'c3',
              type: TransactionType.expense,
              dompetId: 'd1',
            ),
          ],
          isLocalDismissed: false,
        ),
        isFalse,
      );

      // Saldo Dompet Tunai sudah bukan 0
      expect(
        InitialBalanceOnboardingHelper.shouldShowOnboarding(
          profile: newProfile,
          dompets: [defaultWallet.copyWith(jumlah: 50000)],
          transactions: const [],
          isLocalDismissed: false,
        ),
        isFalse,
      );

      // Sudah memiliki lebih dari 1 dompet
      expect(
        InitialBalanceOnboardingHelper.shouldShowOnboarding(
          profile: newProfile,
          dompets: [
            defaultWallet,
            const DompetItem(
              id: 'd2',
              jenis: JenisDompet.accounts,
              nama: 'Dana',
              jumlah: 0,
            ),
          ],
          transactions: const [],
          isLocalDismissed: false,
        ),
        isFalse,
      );
    });
  });

  group('InitialBalanceOnboardingSheet Widget Test', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required Future<void> Function(InitialBalanceSetupInput) onSave,
      required Future<void> Function() onSkip,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<bool>(
                    context: ctx,
                    isScrollControlled: true,
                    isDismissible: false,
                    enableDrag: false,
                    backgroundColor: Colors.transparent,
                    builder: (_) => InitialBalanceOnboardingSheet(
                      displayName: 'Rani Putri',
                      onSave: onSave,
                      onSkip: onSkip,
                    ),
                  ),
                  child: const Text('Buka Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Sheet'));
      await tester.pumpAndSettle();
    }

    testWidgets('tombol Mulai dari Rp 0 / Lewati memanggil onSkip dan menutup sheet', (tester) async {
      bool skipped = false;
      await pumpSheet(
        tester,
        onSave: (_) async {},
        onSkip: () async => skipped = true,
      );

      expect(find.text('Atur Saldo Awalmu, Rani!'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('onboarding_skip_button')));
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();

      expect(skipped, isTrue);
      expect(find.text('Atur Saldo Awalmu, Rani!'), findsNothing);
    });

    testWidgets(
      'mengisi saldo Dompet Tunai + dompet digital opsional memvalidasi nama kosong dan mengirimkan payload akurat',
      (tester) async {
        InitialBalanceSetupInput? captured;
        await pumpSheet(
          tester,
          onSave: (input) async => captured = input,
          onSkip: () async {},
        );

        await tester.enterText(
          find.byKey(const Key('onboarding_cash_balance_field')),
          '50000',
        );
        await tester.pump();

        // Aktifkan toggle dompet kedua
        await tester.ensureVisible(
          find.byKey(const Key('onboarding_extra_wallet_switch')),
        );
        await tester.tap(find.byKey(const Key('onboarding_extra_wallet_switch')));
        await tester.pumpAndSettle();

        // Simpan tanpa nama dompet tambahan -> muncul error inline, sheet tidak tertutup
        await tester.ensureVisible(find.byKey(const Key('onboarding_save_button')));
        await tester.tap(find.byKey(const Key('onboarding_save_button')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Nama dompet tambahan wajib diisi'), findsOneWidget);
        expect(captured, isNull);

        // Isi nama & saldo dompet kedua -> sukses
        await tester.enterText(
          find.byKey(const Key('onboarding_extra_name_field')),
          'Dana',
        );
        await tester.enterText(
          find.byKey(const Key('onboarding_extra_balance_field')),
          '100000',
        );
        await tester.pump();

        await tester.ensureVisible(find.byKey(const Key('onboarding_save_button')));
        await tester.tap(find.byKey(const Key('onboarding_save_button')));
        await tester.pumpAndSettle();

        expect(captured, isNotNull);
        expect(captured!.cashInitialBalance, 50000);
        expect(captured!.extraWallet, isNotNull);
        expect(captured!.extraWallet!.nama, 'Dana');
        expect(captured!.extraWallet!.jenis, JenisDompet.accounts);
        expect(captured!.extraWallet!.jumlah, 100000);
        expect(find.text('Atur Saldo Awalmu, Rani!'), findsNothing);
      },
    );

    testWidgets(
      'saat onSave melempar OfflineException, pesan error muncul di dalam sheet dan nominal input tetap utuh',
      (tester) async {
        await pumpSheet(
          tester,
          onSave: (_) async => throw const OfflineException(
            'Tidak ada koneksi internet. Hubungkan ke internet untuk menyimpan saldo awal.',
          ),
          onSkip: () async {},
        );

        final cashField = find.byKey(const Key('onboarding_cash_balance_field'));
        await tester.enterText(cashField, '150000');
        await tester.pump();

        await tester.ensureVisible(find.byKey(const Key('onboarding_save_button')));
        await tester.tap(find.byKey(const Key('onboarding_save_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Tidak ada koneksi internet'), findsOneWidget);
        expect(find.text('Atur Saldo Awalmu, Rani!'), findsOneWidget);
        final fieldWidget = tester.widget<TextField>(cashField);
        expect(fieldWidget.controller?.text, 'Rp 150.000');
      },
    );
  });
}
