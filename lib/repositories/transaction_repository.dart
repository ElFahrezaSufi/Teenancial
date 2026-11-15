import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class TransactionRepository {
  final FirestoreService _firestoreService;

  TransactionRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<List<TransactionModel>> getTransactions(String uid) async {
    final snapshot = await _firestoreService.transactionsCol(uid).get();
    final items = snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<void> addTransaction(String uid, TransactionModel transaction) async {
    final walletsRef = _firestoreService.walletsCol(uid);
    final txCol = _firestoreService.transactionsCol(uid);
    final txRef =
        transaction.id.isEmpty ? txCol.doc() : txCol.doc(transaction.id);
    final txToSave = transaction.copyWith(id: txRef.id);
    final deltas = txToSave.walletEffects();

    await _firestoreService.runTransaction((fsTx) async {
      // Phase 1: Read all affected wallets
      final walletSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final walletId in deltas.keys) {
        walletSnaps[walletId] = await fsTx.get(walletsRef.doc(walletId));
      }

      // Validate balances
      final newBalances = <String, double>{};
      for (final entry in deltas.entries) {
        final snap = walletSnaps[entry.key]!;
        if (!snap.exists || snap.data() == null) {
          throw Exception('Dompet tidak ditemukan');
        }
        final dompet = DompetItem.fromMap(snap.data()!, docId: snap.id);
        final updatedBalance = dompet.jumlah + entry.value;
        if (entry.value < 0 && updatedBalance < 0) {
          throw Exception('Saldo tidak mencukupi di dompet ${dompet.nama}');
        }
        newBalances[entry.key] = updatedBalance;
      }

      // Phase 2: Write updated wallet balances and new transaction
      for (final entry in newBalances.entries) {
        fsTx.update(walletsRef.doc(entry.key), {'jumlah': entry.value});
      }
      fsTx.set(txRef, txToSave.toMap());
    });
  }

  Future<void> updateTransaction(
    String uid,
    TransactionModel updated,
  ) async {
    final walletsRef = _firestoreService.walletsCol(uid);
    final txRef = _firestoreService.transactionsCol(uid).doc(updated.id);

    await _firestoreService.runTransaction((fsTx) async {
      // Phase 1: Read existing transaction first, then affected wallets
      final txSnap = await fsTx.get(txRef);
      if (!txSnap.exists || txSnap.data() == null) {
        throw Exception('Data transaksi tidak ditemukan');
      }

      final oldTx = TransactionModel.fromMap(txSnap.data()!, docId: txSnap.id);
      final oldEffects = oldTx.walletEffects();
      final newEffects = updated.walletEffects();

      final allWalletIds = <String>{
        ...oldEffects.keys,
        ...newEffects.keys,
      };

      final netDeltas = <String, double>{};
      for (final walletId in allWalletIds) {
        final delta =
            (newEffects[walletId] ?? 0.0) - (oldEffects[walletId] ?? 0.0);
        if (delta != 0) {
          netDeltas[walletId] = delta;
        }
      }

      final requiredNewWalletIds = <String>{
        updated.dompetId,
        if (updated.destinationDompetId != null) updated.destinationDompetId!,
        ...updated.payments.map((p) => p.dompetId),
      };

      final walletIdsToRead = <String>{
        ...netDeltas.keys,
        ...requiredNewWalletIds,
      };

      final walletSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final walletId in walletIdsToRead) {
        walletSnaps[walletId] = await fsTx.get(walletsRef.doc(walletId));
      }

      for (final reqId in requiredNewWalletIds) {
        final snap = walletSnaps[reqId];
        if (snap == null || !snap.exists) {
          throw Exception('Dompet yang dipilih tidak ditemukan');
        }
      }

      final newBalances = <String, double>{};
      for (final entry in netDeltas.entries) {
        final snap = walletSnaps[entry.key]!;
        if (!snap.exists || snap.data() == null) {
          continue;
        }
        final dompet = DompetItem.fromMap(snap.data()!, docId: snap.id);
        final updatedBalance = dompet.jumlah + entry.value;
        if (entry.value < 0 && updatedBalance < 0) {
          throw Exception('Saldo tidak mencukupi di dompet ${dompet.nama}');
        }
        newBalances[entry.key] = updatedBalance;
      }

      // Phase 2: Write wallet updates and updated transaction
      for (final entry in newBalances.entries) {
        fsTx.update(walletsRef.doc(entry.key), {'jumlah': entry.value});
      }
      fsTx.set(txRef, updated.toMap());
    });
  }

  Future<void> deleteTransaction(String uid, String transactionId) async {
    final walletsRef = _firestoreService.walletsCol(uid);
    final txRef = _firestoreService.transactionsCol(uid).doc(transactionId);

    await _firestoreService.runTransaction((fsTx) async {
      // Phase 1: Read transaction & affected wallets
      final txSnap = await fsTx.get(txRef);
      if (!txSnap.exists || txSnap.data() == null) {
        return;
      }

      final oldTx = TransactionModel.fromMap(txSnap.data()!, docId: txSnap.id);
      final oldEffects = oldTx.walletEffects();

      final walletSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final walletId in oldEffects.keys) {
        walletSnaps[walletId] = await fsTx.get(walletsRef.doc(walletId));
      }

      final newBalances = <String, double>{};
      for (final entry in oldEffects.entries) {
        final reversalDelta = -entry.value;
        if (reversalDelta == 0) continue;

        final snap = walletSnaps[entry.key]!;
        if (!snap.exists || snap.data() == null) {
          // Dompet sudah dihapus sebelumnya; izinkan penghapusan riwayat transaksi.
          continue;
        }

        final dompet = DompetItem.fromMap(snap.data()!, docId: snap.id);
        final updatedBalance = dompet.jumlah + reversalDelta;
        if (reversalDelta < 0 && updatedBalance < 0) {
          throw Exception(
            'Saldo di dompet ${dompet.nama} tidak mencukupi untuk membatalkan transaksi ini',
          );
        }
        newBalances[entry.key] = updatedBalance;
      }

      // Phase 2: Write reversed wallet balances and delete transaction
      for (final entry in newBalances.entries) {
        fsTx.update(walletsRef.doc(entry.key), {'jumlah': entry.value});
      }
      fsTx.delete(txRef);
    });
  }

  /// Mencatat pembayaran cicilan (parsial maupun pelunasan penuh) pada pinjaman.
  Future<void> addLoanPayment(
    String uid,
    String transactionId,
    LoanPayment payment,
  ) async {
    final txRef = _firestoreService.transactionsCol(uid).doc(transactionId);
    final walletRef = _firestoreService.walletsCol(uid).doc(payment.dompetId);

    await _firestoreService.runTransaction((fsTx) async {
      // Phase 1: Read loan transaction and settlement wallet
      final txSnap = await fsTx.get(txRef);
      if (!txSnap.exists || txSnap.data() == null) {
        throw Exception('Data pinjaman tidak ditemukan');
      }

      final item = TransactionModel.fromMap(txSnap.data()!, docId: txSnap.id);
      if (item.type != TransactionType.debt &&
          item.type != TransactionType.receivable) {
        throw Exception('Transaksi ini bukan pinjaman');
      }
      if (item.isPaid || item.remainingAmount <= 0.0001) {
        throw Exception('Pinjaman ini sudah lunas');
      }

      final walletSnap = await fsTx.get(walletRef);
      if (!walletSnap.exists || walletSnap.data() == null) {
        throw Exception('Dompet tidak ditemukan');
      }

      final String paymentId = payment.id.isNotEmpty
          ? payment.id
          : 'pay_${DateTime.now().microsecondsSinceEpoch}';
      final updatedTx = item.withPayment(payment.copyWith(id: paymentId));
      final appliedPayment =
          updatedTx.payments.firstWhere((p) => p.id == paymentId);

      final dompet =
          DompetItem.fromMap(walletSnap.data()!, docId: walletSnap.id);
      final double delta = item.type == TransactionType.debt
          ? -appliedPayment.amount
          : appliedPayment.amount;
      final double updatedBalance = dompet.jumlah + delta;

      if (delta < 0 && updatedBalance < 0) {
        throw Exception('Saldo tidak mencukupi di dompet ${dompet.nama}');
      }

      // Phase 2: Write updated wallet balance and loan document
      fsTx.update(walletRef, {'jumlah': updatedBalance});
      fsTx.set(txRef, updatedTx.toMap());
    });
  }

  /// Membatalkan satu cicilan yang pernah dicatat pada pinjaman dan membalik
  /// efek saldonya pada dompet terkait.
  Future<void> removeLoanPayment(
    String uid,
    String transactionId,
    String paymentId,
  ) async {
    final txRef = _firestoreService.transactionsCol(uid).doc(transactionId);
    final walletsRef = _firestoreService.walletsCol(uid);

    await _firestoreService.runTransaction((fsTx) async {
      // Phase 1: Read loan transaction and payment wallet
      final txSnap = await fsTx.get(txRef);
      if (!txSnap.exists || txSnap.data() == null) {
        throw Exception('Data pinjaman tidak ditemukan');
      }

      final item = TransactionModel.fromMap(txSnap.data()!, docId: txSnap.id);
      final paymentIndex = item.payments.indexWhere((p) => p.id == paymentId);
      if (paymentIndex == -1) {
        throw Exception('Data cicilan tidak ditemukan');
      }
      final targetPayment = item.payments[paymentIndex];
      final walletRef = walletsRef.doc(targetPayment.dompetId);
      final walletSnap = await fsTx.get(walletRef);

      final updatedTx = item.withoutPayment(paymentId);

      double? updatedBalance;
      if (walletSnap.exists && walletSnap.data() != null) {
        final dompet =
            DompetItem.fromMap(walletSnap.data()!, docId: walletSnap.id);
        final double reversalDelta = item.type == TransactionType.debt
            ? targetPayment.amount
            : -targetPayment.amount;
        final double nextBalance = dompet.jumlah + reversalDelta;
        if (reversalDelta < 0 && nextBalance < 0) {
          throw Exception(
            'Saldo di dompet ${dompet.nama} tidak mencukupi untuk membatalkan cicilan ini',
          );
        }
        updatedBalance = nextBalance;
      }

      // Phase 2: Write wallet update and updated loan document
      if (updatedBalance != null) {
        fsTx.update(walletRef, {'jumlah': updatedBalance});
      }
      fsTx.set(txRef, updatedTx.toMap());
    });
  }

  /// Melunasi seluruh sisa tagihan pinjaman sekaligus.
  /// Direfaktor agar melewati jalur logika yang sama dengan [addLoanPayment].
  Future<void> markAsPaid(
    String uid,
    String transactionId,
    String paidDompetId,
  ) async {
    final txRef = _firestoreService.transactionsCol(uid).doc(transactionId);
    final walletRef = _firestoreService.walletsCol(uid).doc(paidDompetId);

    await _firestoreService.runTransaction((fsTx) async {
      final txSnap = await fsTx.get(txRef);
      if (!txSnap.exists || txSnap.data() == null) {
        throw Exception('Data pinjaman tidak ditemukan');
      }

      final item = TransactionModel.fromMap(txSnap.data()!, docId: txSnap.id);
      if (item.type != TransactionType.debt &&
          item.type != TransactionType.receivable) {
        throw Exception('Transaksi ini bukan pinjaman');
      }
      if (item.isPaid || item.remainingAmount <= 0.0001) {
        throw Exception('Pinjaman ini sudah lunas');
      }

      final walletSnap = await fsTx.get(walletRef);
      if (!walletSnap.exists || walletSnap.data() == null) {
        throw Exception('Dompet tidak ditemukan');
      }

      final double settleAmount = item.remainingAmount;
      final payment = LoanPayment(
        id: 'pay_${DateTime.now().microsecondsSinceEpoch}',
        amount: settleAmount,
        date: DateTime.now(),
        dompetId: paidDompetId,
      );
      final updatedTx = item.withPayment(payment);

      final dompet =
          DompetItem.fromMap(walletSnap.data()!, docId: walletSnap.id);
      final double delta =
          item.type == TransactionType.debt ? -settleAmount : settleAmount;
      final double updatedBalance = dompet.jumlah + delta;

      if (delta < 0 && updatedBalance < 0) {
        throw Exception('Saldo tidak mencukupi di dompet ${dompet.nama}');
      }

      fsTx.update(walletRef, {'jumlah': updatedBalance});
      fsTx.set(txRef, updatedTx.toMap());
    });
  }
}
