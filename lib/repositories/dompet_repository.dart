import 'package:flutter/foundation.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class DompetRepository {
  final FirestoreService _firestoreService;

  DompetRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  /// ID deterministik untuk entri transaksi Saldo Awal tiap dompet agar
  /// percobaan ulang (retry) saat onboarding tidak pernah membuat duplikat.
  static String initialBalanceTxId(String walletId) => 'init_$walletId';

  /// Membuat model transaksi Saldo Awal standar (`isAdjustment: true`,
  /// `isInitialBalance: true`) agar tercatat di Riwayat namun tidak
  /// dihitung sebagai pemasukan baru di Laporan Keuangan maupun Misi.
  static TransactionModel buildInitialBalanceTransaction({
    required String walletId,
    required String walletName,
    required double amount,
    DateTime? date,
  }) {
    return TransactionModel(
      id: initialBalanceTxId(walletId),
      title: 'Saldo Awal ($walletName)',
      amount: amount,
      date: date ?? DateTime.now(),
      notes: TransactionModel.initialBalanceNote,
      categoryId: 'c19',
      type: TransactionType.income,
      dompetId: walletId,
      isAdjustment: true,
      isInitialBalance: true,
    );
  }

  /// Mengembalikan `true` bila daftar transaksi pada suatu dompet memuat
  /// minimal 1 transaksi selain entri Saldo Awal (sehingga dompet tidak boleh
  /// dihapus demi menjaga keutuhan riwayat).
  @visibleForTesting
  static bool hasBlockingTransactions(
    Iterable<TransactionModel> dompetTransactions,
  ) {
    return dompetTransactions.any((tx) => !tx.isInitialBalance);
  }

  Future<List<DompetItem>> getDompets(String uid) async {
    final walletsRef = _firestoreService.walletsCol(uid);
    final snapshot = await _firestoreService.getQuerySnapshot(walletsRef);

    if (snapshot.docs.isEmpty) {
      return [];
    }

    final items = snapshot.docs
        .map((doc) => DompetItem.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        final cmp = a.createdAt!.compareTo(b.createdAt!);
        if (cmp != 0) return cmp;
      } else if (a.createdAt == null && b.createdAt != null) {
        return -1;
      } else if (a.createdAt != null && b.createdAt == null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
    return items;
  }

  Future<void> addDompet(String uid, DompetItem item) async {
    _firestoreService.ensureOnline(actionLabel: 'menambahkan dompet');
    final walletsRef = _firestoreService.walletsCol(uid);
    final txColRef = _firestoreService.transactionsCol(uid);
    final docRef =
        item.id.isEmpty ? walletsRef.doc() : walletsRef.doc(item.id);
    final now = item.createdAt ?? DateTime.now();
    final double safeBalance = item.jumlah < 0 ? 0.0 : item.jumlah;
    final toSave = item.copyWith(
      id: docRef.id,
      jumlah: safeBalance,
      createdAt: now,
    );

    final batch = _firestoreService.batch();
    batch.set(docRef, toSave.toMap());
    if (safeBalance > 0.0001) {
      final initialTx = buildInitialBalanceTransaction(
        walletId: toSave.id,
        walletName: toSave.nama,
        amount: safeBalance,
        date: now,
      );
      batch.set(txColRef.doc(initialTx.id), initialTx.toMap());
    }
    await batch.commit();
  }

  /// Mengatur saldo awal dompet (misalnya `Dompet Tunai` `d1` saat onboarding)
  /// sekaligus mencatat entri "Saldo Awal" di Riwayat bila nominal > 0.
  Future<void> setInitialWalletBalance(
    String uid,
    String dompetId,
    double initialBalance,
  ) async {
    _firestoreService.ensureOnline(actionLabel: 'menyimpan saldo awal');
    final double safeBalance = initialBalance < 0 ? 0.0 : initialBalance;
    final walletRef = _firestoreService.walletsCol(uid).doc(dompetId);
    final txColRef = _firestoreService.transactionsCol(uid);

    await _firestoreService.runTransaction(
      (fsTx) async {
        final walletSnap = await fsTx.get(walletRef);
        if (!walletSnap.exists || walletSnap.data() == null) {
          throw Exception('Dompet tidak ditemukan');
        }
        final existingWallet =
            DompetItem.fromMap(walletSnap.data()!, docId: walletSnap.id);
        fsTx.update(walletRef, {'jumlah': safeBalance});

        if (safeBalance > 0.0001) {
          final initialTx = buildInitialBalanceTransaction(
            walletId: existingWallet.id,
            walletName: existingWallet.nama,
            amount: safeBalance,
            date: DateTime.now(),
          );
          fsTx.set(txColRef.doc(initialTx.id), initialTx.toMap());
        }
      },
      actionLabel: 'menyimpan saldo awal',
    );
  }

  Future<void> updateDompet(String uid, DompetItem item) async {
    final walletRef = _firestoreService.walletsCol(uid).doc(item.id);
    final txColRef = _firestoreService.transactionsCol(uid);

    await _firestoreService.runTransaction(
      (fsTx) async {
      final walletSnap = await fsTx.get(walletRef);
      if (!walletSnap.exists || walletSnap.data() == null) {
        throw Exception('Dompet tidak ditemukan');
      }

      final oldDompet =
          DompetItem.fromMap(walletSnap.data()!, docId: walletSnap.id);
      final double delta = item.jumlah - oldDompet.jumlah;

      final updatedDompet = item.copyWith(
        createdAt: item.createdAt ?? oldDompet.createdAt,
      );
      fsTx.set(walletRef, updatedDompet.toMap());

      if (delta.abs() > 0.0001) {
        final bool isPositive = delta > 0;
        final txDocRef = txColRef.doc();
        final adjustmentTx = TransactionModel(
          id: txDocRef.id,
          title: 'Penyesuaian Saldo (${item.nama})',
          amount: delta.abs(),
          date: DateTime.now(),
          notes: 'Penyesuaian saldo otomatis saat edit dompet',
          categoryId: isPositive ? 'c19' : 'c6',
          type: isPositive ? TransactionType.income : TransactionType.expense,
          dompetId: item.id,
          isAdjustment: true,
        );
        fsTx.set(txDocRef, adjustmentTx.toMap());
      }
      },
      actionLabel: 'memperbarui dompet',
    );
  }

  Future<void> deleteDompet(String uid, String dompetId) async {
    _firestoreService.ensureOnline(actionLabel: 'menghapus dompet');
    final walletsRef = _firestoreService.walletsCol(uid);
    final walletsSnap = await walletsRef.get();
    final remainingCount =
        walletsSnap.docs.where((doc) => doc.id != dompetId).length;
    if (remainingCount == 0) {
      throw Exception('Tidak dapat menghapus satu-satunya dompet yang tersisa.');
    }

    final txCol = _firestoreService.transactionsCol(uid);
    final recCol = _firestoreService.recurringCol(uid);
    final [
      dompetTxSnap,
      destTxSnap,
      paidTxSnap,
      recSrcSnap,
      recDstSnap,
    ] = await Future.wait([
      txCol.where('dompetId', isEqualTo: dompetId).get(),
      txCol.where('destinationDompetId', isEqualTo: dompetId).limit(1).get(),
      txCol.where('paidDompetId', isEqualTo: dompetId).limit(1).get(),
      recCol.where('dompetId', isEqualTo: dompetId).limit(1).get(),
      recCol.where('destinationDompetId', isEqualTo: dompetId).limit(1).get(),
    ]);

    final bool hasOtherReferences = destTxSnap.docs.isNotEmpty ||
        paidTxSnap.docs.isNotEmpty ||
        recSrcSnap.docs.isNotEmpty ||
        recDstSnap.docs.isNotEmpty;

    final dompetTransactions = dompetTxSnap.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), docId: doc.id))
        .toList();

    if (hasOtherReferences || hasBlockingTransactions(dompetTransactions)) {
      throw Exception(
        'Dompet tidak dapat dihapus karena masih memiliki riwayat transaksi, pinjaman, atau jadwal transaksi berulang.',
      );
    }

    // Hapus dompet beserta entri Saldo Awal miliknya secara atomik.
    final batch = _firestoreService.batch();
    for (final doc in dompetTxSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(walletsRef.doc(dompetId));
    await batch.commit();
  }
}
