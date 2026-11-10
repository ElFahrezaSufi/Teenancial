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

  group('Cicilan Pinjaman (LoanPayment, withPayment, withoutPayment, balanceEvents)', () {
    final loanDate = DateTime(2026, 11, 1, 10, 0);

    test('cicilan bertahap memperbarui paidAmount, remainingAmount, walletEffects, dan otomatis lunas saat penuh', () {
      final debt = TransactionModel(
        id: 'loan_debt_1',
        title: 'Hutang dari Budi',
        amount: 100000,
        date: loanDate,
        categoryId: 'c11',
        type: TransactionType.debt,
        dompetId: 'd_cash',
      );

      expect(debt.paidAmount, 0);
      expect(debt.remainingAmount, 100000);
      expect(debt.isPaid, isFalse);

      // Cicilan 1: Rp 40.000 dari d_cash
      final afterFirst = debt.withPayment(
        LoanPayment(
          id: 'p1',
          amount: 40000,
          date: DateTime(2026, 11, 3, 12, 0),
          dompetId: 'd_cash',
        ),
      );
      expect(afterFirst.paidAmount, 40000);
      expect(afterFirst.remainingAmount, 60000);
      expect(afterFirst.isPaid, isFalse);
      expect(afterFirst.walletEffects(), {'d_cash': 60000.0});

      // Cicilan 2: Rp 60.000 dari d_bank (melunasi sisa)
      final afterSecond = afterFirst.withPayment(
        LoanPayment(
          id: 'p2',
          amount: 60000,
          date: DateTime(2026, 11, 5, 15, 0),
          dompetId: 'd_bank',
        ),
      );
      expect(afterSecond.paidAmount, 100000);
      expect(afterSecond.remainingAmount, 0);
      expect(afterSecond.isPaid, isTrue);
      expect(afterSecond.paidDompetId, 'd_bank');
      expect(afterSecond.walletEffects(), {
        'd_cash': 60000.0,
        'd_bank': -60000.0,
      });

      // Membatalkan cicilan ke-2 membuka kembali status lunas
      final reverted = afterSecond.withoutPayment('p2');
      expect(reverted.isPaid, isFalse);
      expect(reverted.paidAmount, 40000);
      expect(reverted.remainingAmount, 60000);
      expect(reverted.paidDompetId, isNull);
    });

    test('withPayment menolak cicilan yang melebihi sisa tagihan', () {
      final receivable = TransactionModel(
        id: 'loan_rec_1',
        title: 'Piutang ke Rina',
        amount: 50000,
        date: loanDate,
        categoryId: 'c15',
        type: TransactionType.receivable,
        dompetId: 'd1',
      );

      expect(
        () => receivable.withPayment(
          LoanPayment(
            id: 'p_over',
            amount: 60000,
            date: DateTime(2026, 11, 2),
            dompetId: 'd1',
          ),
        ),
        throwsException,
      );
    });

    test('balanceEvents memisahkan tanggal pokok pinjaman dan tanggal cicilan', () {
      final p1Date = DateTime(2026, 11, 4, 9, 0);
      final loan = TransactionModel(
        id: 'loan_ev',
        title: 'Hutang dari Andi',
        amount: 80000,
        date: loanDate,
        categoryId: 'c11',
        type: TransactionType.debt,
        dompetId: 'd1',
      ).withPayment(
        LoanPayment(
          id: 'p1',
          amount: 30000,
          date: p1Date,
          dompetId: 'd1',
        ),
      );

      final events = loan.balanceEvents();
      expect(events.length, 2);
      expect(events[0].date, loanDate);
      expect(events[0].delta, 80000);
      expect(events[1].date, p1Date);
      expect(events[1].delta, -30000);
    });

    test('isEditable bernilai true untuk transaksi reguler dan pinjaman belum lunas, false untuk pinjaman lunas', () {
      final transfer = TransactionModel(
        id: 'tr_1',
        title: 'Transfer',
        amount: 20000,
        date: loanDate,
        categoryId: 'c10',
        type: TransactionType.transfer,
        dompetId: 'd1',
      );
      expect(transfer.isEditable, isTrue);

      final unpaidLoan = TransactionModel(
        id: 'ln_1',
        title: 'Hutang',
        amount: 50000,
        date: loanDate,
        categoryId: 'c11',
        type: TransactionType.debt,
        dompetId: 'd1',
        isPaid: false,
      );
      expect(unpaidLoan.isEditable, isTrue);

      final paidLoan = unpaidLoan.copyWith(isPaid: true);
      expect(paidLoan.isEditable, isFalse);
    });
  });
}
