import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/contact_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/repositories/contact_repository.dart';
import 'package:teenancial/utils/contact_analytics.dart';

void main() {
  group('ContactModel', () {
    test('initials menghasilkan 1-2 huruf kapital untuk berbagai format nama',
        () {
      expect(const ContactModel(id: 'c1', name: 'Budi').initials, 'B');
      expect(
        const ContactModel(id: 'c2', name: 'Budi Santoso').initials,
        'BS',
      );
      expect(
        const ContactModel(id: 'c3', name: 'Siti Nur Haliza').initials,
        'SN',
      );
      expect(const ContactModel(id: 'c4', name: '   ').initials, '?');
    });

    test('toMap, fromMap, dan copyWith menjaga kompatibilitas catatan opsional',
        () {
      const contact = ContactModel(
        id: 'c1',
        name: 'Budi',
        note: 'Teman sekelas',
      );
      final mapped = contact.toMap();
      expect(mapped['name'], 'Budi');
      expect(mapped['note'], 'Teman sekelas');

      final restored = ContactModel.fromMap(mapped, docId: 'c1');
      expect(restored.id, 'c1');
      expect(restored.name, 'Budi');
      expect(restored.note, 'Teman sekelas');

      // Data kontak lama tanpa field `note` tetap ter-parse mulus
      final legacy = ContactModel.fromMap(
        {'id': 'c_old', 'name': 'Andi'},
        docId: 'c_old',
      );
      expect(legacy.name, 'Andi');
      expect(legacy.note, isNull);

      // Catatan spasi kosong dinormalisasi ke null
      final blankNote = ContactModel.fromMap(
        {'id': 'c_blank', 'name': 'Rina', 'note': '   '},
        docId: 'c_blank',
      );
      expect(blankNote.note, isNull);

      final cleared = restored.copyWith(clearNote: true);
      expect(cleared.note, isNull);
    });
  });

  group('ContactRepository.renameLinkedTitle', () {
    test('memperbarui judul baku Transfer, Hutang, dan Piutang saat rename',
        () {
      expect(
        ContactRepository.renameLinkedTitle(
          'Transfer ke Budi',
          oldName: 'Budi',
          newName: 'Budi Santoso',
          type: TransactionType.transfer,
        ),
        'Transfer ke Budi Santoso',
      );
      expect(
        ContactRepository.renameLinkedTitle(
          'Hutang dari budi',
          oldName: 'Budi',
          newName: 'Budi Santoso',
          type: TransactionType.debt,
        ),
        'Hutang dari Budi Santoso',
      );
      expect(
        ContactRepository.renameLinkedTitle(
          'Piutang ke Budi',
          oldName: 'Budi',
          newName: 'Budi Santoso',
          type: TransactionType.receivable,
        ),
        'Piutang ke Budi Santoso',
      );
    });

    test('mempertahankan judul kustom atau jenis non-kontak apa adanya', () {
      expect(
        ContactRepository.renameLinkedTitle(
          'Patungan Makan Siang',
          oldName: 'Budi',
          newName: 'Budi Santoso',
          type: TransactionType.transfer,
        ),
        'Patungan Makan Siang',
      );
      expect(
        ContactRepository.renameLinkedTitle(
          'Transfer ke Budi',
          oldName: 'Budi',
          newName: 'Budi Santoso',
          type: TransactionType.expense,
        ),
        'Transfer ke Budi',
      );
    });
  });

  group('ContactAnalytics', () {
    const budi = ContactModel(id: 'c_budi', name: 'Budi', note: 'Teman SMP');
    const rina = ContactModel(id: 'c_rina', name: 'Rina');

    final transactions = <TransactionModel>[
      // 1. Transfer keluar terhubung via contactId
      TransactionModel(
        id: 't1',
        title: 'Transfer ke Budi',
        amount: 50000,
        date: DateTime(2026, 11, 20),
        categoryId: 'c10',
        type: TransactionType.transfer,
        dompetId: 'd1',
        contactId: 'c_budi',
        counterpartyName: 'Budi',
      ),
      // 2. Transfer keluar legacy tanpa contactId (cocok via nama case-insensitive)
      TransactionModel(
        id: 't2',
        title: 'Transfer ke budi',
        amount: 25000,
        date: DateTime(2026, 11, 22),
        categoryId: 'c10',
        type: TransactionType.transfer,
        dompetId: 'd1',
      ),
      // 3. Transfer internal -> harus diabaikan meski judul mirip
      TransactionModel(
        id: 't3',
        title: 'Transfer Internal',
        amount: 100000,
        date: DateTime(2026, 11, 21),
        categoryId: 'c10',
        type: TransactionType.transfer,
        dompetId: 'd1',
        destinationDompetId: 'd2',
        contactId: 'c_budi',
      ),
      // 4. Hutang aktif sebagian sudah dicicil (total 80k, bayar 30k -> sisa 50k)
      TransactionModel(
        id: 't4',
        title: 'Hutang dari Budi',
        amount: 80000,
        date: DateTime(2026, 11, 18),
        categoryId: 'c11',
        type: TransactionType.debt,
        dompetId: 'd1',
        contactId: 'c_budi',
        counterpartyName: 'Budi',
        payments: [
          LoanPayment(
            id: 'p1',
            amount: 30000,
            date: DateTime(2026, 11, 19),
            dompetId: 'd1',
          ),
        ],
      ),
      // 5. Piutang aktif belum dibayar (40k)
      TransactionModel(
        id: 't5',
        title: 'Piutang ke Budi',
        amount: 40000,
        date: DateTime(2026, 11, 17),
        categoryId: 'c12',
        type: TransactionType.receivable,
        dompetId: 'd1',
        contactId: 'c_budi',
        counterpartyName: 'Budi',
      ),
      // 6. Hutang yang sudah lunas -> tetap masuk riwayat, tidak dihitung aktif
      TransactionModel(
        id: 't6',
        title: 'Hutang dari Budi',
        amount: 60000,
        date: DateTime(2026, 11, 10),
        categoryId: 'c11',
        type: TransactionType.debt,
        dompetId: 'd1',
        contactId: 'c_budi',
        counterpartyName: 'Budi',
        isPaid: true,
      ),
      // 7. Penyesuaian saldo -> tidak pernah dihitung ke kontak
      TransactionModel(
        id: 't7',
        title: 'Penyesuaian Saldo (Dompet Tunai)',
        amount: 10000,
        date: DateTime(2026, 11, 16),
        categoryId: 'c19',
        type: TransactionType.income,
        dompetId: 'd1',
        isAdjustment: true,
      ),
      // 8. Transaksi milik kontak lain (Rina)
      TransactionModel(
        id: 't8',
        title: 'Piutang ke Rina',
        amount: 15000,
        date: DateTime(2026, 11, 19),
        categoryId: 'c12',
        type: TransactionType.receivable,
        dompetId: 'd1',
        contactId: 'c_rina',
        counterpartyName: 'Rina',
      ),
    ];

    test('summarize menghitung total transfer dan sisa hutang/piutang aktif',
        () {
      final summary = ContactAnalytics.summarize(budi, transactions);

      expect(summary.transactionCount, 5);
      expect(summary.totalTransferOut, 75000);
      expect(summary.activeDebtCount, 1);
      expect(summary.activeDebtRemaining, 50000);
      expect(summary.activeReceivableCount, 1);
      expect(summary.activeReceivableRemaining, 40000);
      expect(summary.hasActiveLoans, isTrue);

      // Urutan transaksi terbaru di atas
      expect(summary.transactions.first.id, 't2');
      expect(summary.transactions.last.id, 't6');
    });

    test('transactionsForContact memfilter menurut jenis transaksi', () {
      final transfers = ContactAnalytics.transactionsForContact(
        budi,
        transactions,
        typeFilter: TransactionType.transfer,
      );
      expect(transfers.map((t) => t.id).toList(), ['t2', 't1']);

      final debts = ContactAnalytics.transactionsForContact(
        budi,
        transactions,
        typeFilter: TransactionType.debt,
      );
      expect(debts.map((t) => t.id).toList(), ['t4', 't6']);

      final receivables = ContactAnalytics.transactionsForContact(
        budi,
        transactions,
        typeFilter: TransactionType.receivable,
      );
      expect(receivables.map((t) => t.id).toList(), ['t5']);
    });

    test('summarizeAll memetakan seluruh kontak dengan benar', () {
      final map = ContactAnalytics.summarizeAll([budi, rina], transactions);
      expect(map.keys, containsAll(['c_budi', 'c_rina']));
      expect(map['c_rina']!.transactionCount, 1);
      expect(map['c_rina']!.activeReceivableRemaining, 15000);
      expect(map['c_rina']!.totalTransferOut, 0);
    });
  });
}
