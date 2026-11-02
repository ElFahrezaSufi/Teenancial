import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../services/legacy_seed_service.dart';

class TransactionRepository {
  final FirestoreService _firestoreService;

  TransactionRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<List<TransactionModel>> getTransactions(String uid) async {
    await LegacySeedService.instance.ensureFinanceSeeded(uid);
    final snapshot = await _firestoreService.transactionsCol(uid).get();
    final items = snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<void> addTransaction(String uid, TransactionModel transaction) async {
    final deltas = transaction.walletEffects();
    final walletsRef = _firestoreService.walletsCol(uid);
    final txRef = _firestoreService.transactionsCol(uid).doc(transaction.id);

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
      fsTx.set(txRef, transaction.toMap());
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

  Future<void> markAsPaid(
    String uid,
    String transactionId,
    String paidDompetId,
  ) async {
    final txRef = _firestoreService.transactionsCol(uid).doc(transactionId);
    final walletRef = _firestoreService.walletsCol(uid).doc(paidDompetId);

    await _firestoreService.runTransaction((fsTx) async {
      // Phase 1: Read transaction and settlement wallet
      final txSnap = await fsTx.get(txRef);
      if (!txSnap.exists || txSnap.data() == null) {
        throw Exception('Data pinjaman tidak ditemukan');
      }

      final item = TransactionModel.fromMap(txSnap.data()!, docId: txSnap.id);
      if (item.type != TransactionType.debt &&
          item.type != TransactionType.receivable) {
        throw Exception('Transaksi ini bukan pinjaman');
      }
      if (item.isPaid) {
        throw Exception('Pinjaman ini sudah lunas');
      }

      final walletSnap = await fsTx.get(walletRef);
      if (!walletSnap.exists || walletSnap.data() == null) {
        throw Exception('Dompet tidak ditemukan');
      }

      final dompet =
          DompetItem.fromMap(walletSnap.data()!, docId: walletSnap.id);
      final double delta =
          item.type == TransactionType.debt ? -item.amount : item.amount;
      final double updatedBalance = dompet.jumlah + delta;

      if (delta < 0 && updatedBalance < 0) {
        throw Exception('Saldo tidak mencukupi di dompet ${dompet.nama}');
      }

      final updatedTx = item.copyWith(
        isPaid: true,
        paidDompetId: paidDompetId,
      );

      // Phase 2: Write updated wallet balance and paid transaction
      fsTx.update(walletRef, {'jumlah': updatedBalance});
      fsTx.set(txRef, updatedTx.toMap());
    });
  }
}
