import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class DompetRepository {
  final FirestoreService _firestoreService;

  DompetRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<List<DompetItem>> getDompets(String uid) async {
    final walletsRef = _firestoreService.walletsCol(uid);
    final snapshot = await walletsRef.get();

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
    final walletsRef = _firestoreService.walletsCol(uid);
    final docRef =
        item.id.isEmpty ? walletsRef.doc() : walletsRef.doc(item.id);
    final toSave = item.copyWith(
      id: docRef.id,
      createdAt: item.createdAt ?? DateTime.now(),
    );
    await docRef.set(toSave.toMap());
  }

  Future<void> updateDompet(String uid, DompetItem item) async {
    final walletRef = _firestoreService.walletsCol(uid).doc(item.id);
    final txColRef = _firestoreService.transactionsCol(uid);

    await _firestoreService.runTransaction((fsTx) async {
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
    });
  }

  Future<void> deleteDompet(String uid, String dompetId) async {
    final walletsRef = _firestoreService.walletsCol(uid);
    final walletsSnap = await walletsRef.get();
    final remainingCount =
        walletsSnap.docs.where((doc) => doc.id != dompetId).length;
    if (remainingCount == 0) {
      throw Exception('Tidak dapat menghapus satu-satunya dompet yang tersisa.');
    }

    final txCol = _firestoreService.transactionsCol(uid);
    final results = await Future.wait([
      txCol.where('dompetId', isEqualTo: dompetId).limit(1).get(),
      txCol.where('destinationDompetId', isEqualTo: dompetId).limit(1).get(),
      txCol.where('paidDompetId', isEqualTo: dompetId).limit(1).get(),
    ]);

    final bool hasReferencedTransactions =
        results.any((snap) => snap.docs.isNotEmpty);
    if (hasReferencedTransactions) {
      throw Exception(
        'Dompet tidak dapat dihapus karena masih memiliki riwayat transaksi atau pinjaman.',
      );
    }

    await walletsRef.doc(dompetId).delete();
  }
}
