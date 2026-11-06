import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/transaction_model.dart';

void main() {
  group('TransactionModel.walletEffects()', () {
    final baseDate = DateTime(2026, 11, 6, 12, 0);

    test('income menambah saldo dompet sumber sebesar amount', () {
      final tx = TransactionModel(
        id: 't1',
        title: 'Uang Saku',
        amount: 150000,
        date: baseDate,
        categoryId: 'c1',
        type: TransactionType.income,
        dompetId: 'd1',
      );

      expect(tx.walletEffects(), {'d1': 150000.0});
    });

    test('expense mengurangi saldo dompet sumber sebesar amount', () {
      final tx = TransactionModel(
        id: 't2',
        title: 'Makan Siang',
        amount: 25000,
        date: baseDate,
        categoryId: 'c4',
        type: TransactionType.expense,
        dompetId: 'd1',
      );

      expect(tx.walletEffects(), {'d1': -25000.0});
    });

    test('transfer sesama dompet mengurangi dompet asal dan menambah tujuan', () {
      final tx = TransactionModel(
        id: 't3',
        title: 'Pindah Saldo',
        amount: 50000,
        date: baseDate,
        categoryId: 'c16',
        type: TransactionType.transfer,
        dompetId: 'd1',
        destinationDompetId: 'd2',
      );

      expect(tx.walletEffects(), {
        'd1': -50000.0,
        'd2': 50000.0,
      });
    });

    test('transfer ke pihak luar hanya mengurangi dompet asal', () {
      final tx = TransactionModel(
        id: 't4',
        title: 'Transfer ke Budi',
        amount: 75000,
        date: baseDate,
        categoryId: 'c16',
        type: TransactionType.transfer,
        dompetId: 'd1',
      );

      expect(tx.walletEffects(), {'d1': -75000.0});
    });

    test('debt belum lunas menambah dompet sumber, saat lunas mengurangi paidDompetId', () {
      final unpaidDebt = TransactionModel(
        id: 't5',
        title: 'Hutang dari Andi',
        amount: 40000,
        date: baseDate,
        categoryId: 'c10',
        type: TransactionType.debt,
        dompetId: 'd1',
        isPaid: false,
      );
      expect(unpaidDebt.walletEffects(), {'d1': 40000.0});

      final paidSameWallet = unpaidDebt.copyWith(
        isPaid: true,
        paidDompetId: 'd1',
      );
      expect(paidSameWallet.walletEffects(), {'d1': 0.0});

      final paidDifferentWallet = unpaidDebt.copyWith(
        isPaid: true,
        paidDompetId: 'd2',
      );
      expect(paidDifferentWallet.walletEffects(), {
        'd1': 40000.0,
        'd2': -40000.0,
      });
    });

    test('receivable belum lunas mengurangi dompet sumber, saat lunas menambah paidDompetId', () {
      final unpaidReceivable = TransactionModel(
        id: 't6',
        title: 'Piutang ke Siti',
        amount: 60000,
        date: baseDate,
        categoryId: 'c13',
        type: TransactionType.receivable,
        dompetId: 'd1',
        isPaid: false,
      );
      expect(unpaidReceivable.walletEffects(), {'d1': -60000.0});

      final paidDifferentWallet = unpaidReceivable.copyWith(
        isPaid: true,
        paidDompetId: 'd2',
      );
      expect(paidDifferentWallet.walletEffects(), {
        'd1': -60000.0,
        'd2': 60000.0,
      });
    });
  });

  group('TransactionModel serialization & copyWith', () {
    test('toMap dan fromMap mempertahankan seluruh field termasuk counterpartyName', () {
      final date = DateTime(2026, 11, 6, 8, 30);
      final dueDate = DateTime(2026, 11, 15);
      final original = TransactionModel(
        id: 'tx_100',
        title: 'Hutang dari Rina',
        amount: 120000,
        date: date,
        notes: 'Pinjam untuk beli buku',
        categoryId: 'c10',
        type: TransactionType.debt,
        dompetId: 'd1',
        dueDate: dueDate,
        contactId: 'contact_1',
        counterpartyName: 'Rina',
        isPaid: true,
        paidDompetId: 'd2',
      );

      final map = original.toMap();
      expect(map['date'], isA<Timestamp>());
      expect(map['dueDate'], isA<Timestamp>());

      final restored = TransactionModel.fromMap(map, docId: 'tx_100');
      expect(restored.id, 'tx_100');
      expect(restored.title, 'Hutang dari Rina');
      expect(restored.amount, 120000);
      expect(restored.date, date);
      expect(restored.dueDate, dueDate);
      expect(restored.counterpartyName, 'Rina');
      expect(restored.isPaid, isTrue);
      expect(restored.paidDompetId, 'd2');
    });

    test('fromMap memberikan fallback categoryId sesuai TransactionType jika kosong', () {
      final restored = TransactionModel.fromMap({
        'title': 'Transfer Tanpa Kategori',
        'amount': 10000,
        'type': 'transfer',
        'dompetId': 'd1',
      }, docId: 'tx_fallback');

      expect(restored.type, TransactionType.transfer);
      expect(restored.categoryId, 'c10');
    });

    test('copyWith dapat menghapus field opsional menggunakan flag clear*', () {
      final tx = TransactionModel(
        id: 'tx_clear',
        title: 'Test Clear',
        amount: 50000,
        date: DateTime(2026, 11, 6),
        categoryId: 'c16',
        type: TransactionType.transfer,
        dompetId: 'd1',
        destinationDompetId: 'd2',
        dueDate: DateTime(2026, 11, 10),
        contactId: 'c_1',
        counterpartyName: 'Budi',
        paidDompetId: 'd1',
      );

      final cleared = tx.copyWith(
        clearDestinationDompetId: true,
        clearDueDate: true,
        clearContactId: true,
        clearCounterpartyName: true,
        clearPaidDompetId: true,
      );

      expect(cleared.destinationDompetId, isNull);
      expect(cleared.dueDate, isNull);
      expect(cleared.contactId, isNull);
      expect(cleared.counterpartyName, isNull);
      expect(cleared.paidDompetId, isNull);
    });
  });
}
