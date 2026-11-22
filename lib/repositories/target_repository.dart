import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dompet_model.dart';
import '../models/target_model.dart';
import '../models/transaction_model.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';

class TargetRepository {
  final FirestoreService _firestoreService;
  final CloudinaryService _cloudinaryService;

  TargetRepository({
    FirestoreService? firestoreService,
    CloudinaryService? cloudinaryService,
  })  : _firestoreService = firestoreService ?? FirestoreService.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService.instance;

  Future<List<TargetItem>> getTargets(String uid) async {
    final snapshot = await _firestoreService.getQuerySnapshot(
      _firestoreService.targetsCol(uid),
    );
    final items = snapshot.docs
        .map((doc) => TargetItem.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort((a, b) {
      if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }

  Future<TargetItem> createTarget({
    required String uid,
    required String nama,
    required double targetAmount,
    required File imageFile,
    bool isPinned = false,
    DateTime? deadline,
  }) async {
    _firestoreService.ensureOnline(actionLabel: 'membuat target menabung');
    final secureUrl = await _cloudinaryService.uploadImage(imageFile);
    final docRef = _firestoreService.targetsCol(uid).doc();
    final item = TargetItem(
      id: docRef.id,
      nama: nama.trim(),
      targetAmount: targetAmount,
      savedAmount: 0.0,
      imageUrl: secureUrl,
      isPinned: isPinned,
      deadline: deadline,
    );

    await docRef.set(item.toMap());

    return item;
  }

  Future<void> updateTarget({
    required String uid,
    required String targetId,
    required String nama,
    required double targetAmount,
    File? newImageFile,
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    _firestoreService.ensureOnline(actionLabel: 'memperbarui target menabung');
    String? newImageUrl;
    if (newImageFile != null) {
      newImageUrl = await _cloudinaryService.uploadImage(newImageFile);
    }

    final data = <String, dynamic>{
      'nama': nama.trim(),
      'targetAmount': targetAmount,
      if (newImageUrl != null) 'imageUrl': newImageUrl,
      if (clearDeadline)
        'deadline': FieldValue.delete()
      else if (deadline != null)
        'deadline': Timestamp.fromDate(deadline),
    };

    await _firestoreService.targetsCol(uid).doc(targetId).update(data);
  }

  Future<void> updateSavedAmount({
    required String uid,
    required String targetId,
    required double savedAmount,
  }) async {
    _firestoreService.ensureOnline(actionLabel: 'memperbarui dana target');
    await _firestoreService
        .targetsCol(uid)
        .doc(targetId)
        .update({'savedAmount': savedAmount});
  }

  Future<void> markSettled({
    required String uid,
    required String targetId,
    required bool isSettled,
  }) async {
    _firestoreService.ensureOnline(actionLabel: 'menyelesaikan target');
    await _firestoreService.targetsCol(uid).doc(targetId).update({
      'isSettled': isSettled,
      if (isSettled) 'isPinned': false,
    });
  }

  /// Memindahkan dana secara atomik antara dompet dan target menabung,
  /// sekaligus mencatat transaksi penyesuaian (`isAdjustment: true`) di Riwayat
  /// dalam satu `runTransaction` Firestore.
  Future<TransactionModel> allocateFundsWithWallet({
    required String uid,
    required String targetId,
    required String walletId,
    required double amountDelta,
    double? maxWithdrawable,
  }) async {
    if (amountDelta == 0) {
      throw Exception('Nominal tidak boleh Rp 0.');
    }

    final targetRef = _firestoreService.targetsCol(uid).doc(targetId);
    final walletRef = _firestoreService.walletsCol(uid).doc(walletId);
    final txRef = _firestoreService.transactionsCol(uid).doc();
    final bool isDeposit = amountDelta > 0;
    final double absAmount = amountDelta.abs();

    late TransactionModel createdTx;

    await _firestoreService.runTransaction((fsTx) async {
      final targetSnap = await fsTx.get(targetRef);
      if (!targetSnap.exists || targetSnap.data() == null) {
        throw Exception('Target menabung tidak ditemukan.');
      }
      final walletSnap = await fsTx.get(walletRef);
      if (!walletSnap.exists || walletSnap.data() == null) {
        throw Exception('Dompet tidak ditemukan.');
      }

      final target =
          TargetItem.fromMap(targetSnap.data()!, docId: targetSnap.id);
      if (target.isSettled) {
        throw Exception('Target ini sudah diselesaikan.');
      }

      final wallet =
          DompetItem.fromMap(walletSnap.data()!, docId: walletSnap.id);

      late final double newSavedAmount;
      late final double newWalletBalance;

      if (isDeposit) {
        final remainingNeeded = (target.targetAmount - target.savedAmount)
            .clamp(0.0, double.infinity);
        if (absAmount > remainingNeeded + 0.0001) {
          throw Exception('Nominal melebihi sisa target yang dibutuhkan.');
        }
        if (wallet.jumlah + 0.0001 < absAmount) {
          throw Exception('Saldo tidak mencukupi di dompet ${wallet.nama}.');
        }
        newSavedAmount =
            (target.savedAmount + absAmount).clamp(0.0, target.targetAmount);
        newWalletBalance =
            (wallet.jumlah - absAmount).clamp(0.0, double.infinity);
      } else {
        final allowedWithdraw = maxWithdrawable != null
            ? (maxWithdrawable < target.savedAmount
                ? maxWithdrawable
                : target.savedAmount)
            : target.savedAmount;
        if (absAmount > allowedWithdraw + 0.0001) {
          throw Exception(
            'Nominal penarikan melebihi dana yang dapat ditarik dari target ini.',
          );
        }
        newSavedAmount =
            (target.savedAmount - absAmount).clamp(0.0, target.targetAmount);
        newWalletBalance = wallet.jumlah + absAmount;
      }

      createdTx = TransactionModel(
        id: txRef.id,
        title: isDeposit
            ? 'Tabungan: ${target.nama}'
            : 'Tarik Tabungan: ${target.nama}',
        amount: absAmount,
        date: DateTime.now(),
        notes: isDeposit
            ? 'Alokasi ke target menabung'
            : 'Penarikan dari target menabung',
        categoryId: isDeposit ? 'c6' : 'c19',
        type: isDeposit ? TransactionType.expense : TransactionType.income,
        dompetId: wallet.id,
        isAdjustment: true,
        targetId: target.id,
      );

      fsTx.update(targetRef, {'savedAmount': newSavedAmount});
      fsTx.update(walletRef, {'jumlah': newWalletBalance});
      fsTx.set(txRef, createdTx.toMap());
    });

    return createdTx;
  }

  /// Menyelesaikan target secara atomik: mencatat pengeluaran pembelian target
  /// (`skipWalletEffect: true`) dan menandai `isSettled: true` + `isPinned: false`
  /// dalam satu `runTransaction` Firestore agar tidak pernah tercatat ganda.
  Future<TransactionModel> settleTargetWithExpense({
    required String uid,
    required String targetId,
    required String walletId,
    String categoryId = 'c6',
  }) async {
    final targetRef = _firestoreService.targetsCol(uid).doc(targetId);
    final txRef = _firestoreService.transactionsCol(uid).doc();
    final resolvedCategoryId =
        categoryId.trim().isNotEmpty ? categoryId.trim() : 'c6';

    late TransactionModel createdTx;

    await _firestoreService.runTransaction((fsTx) async {
      final targetSnap = await fsTx.get(targetRef);
      if (!targetSnap.exists || targetSnap.data() == null) {
        throw Exception('Target menabung tidak ditemukan.');
      }

      final target =
          TargetItem.fromMap(targetSnap.data()!, docId: targetSnap.id);
      if (target.isSettled) {
        throw Exception('Target ini sudah diselesaikan sebelumnya.');
      }
      if (!target.isAchieved || target.savedAmount <= 0) {
        throw Exception('Target belum mencapai 100% untuk diselesaikan.');
      }

      createdTx = TransactionModel(
        id: txRef.id,
        title: target.nama,
        amount: target.savedAmount,
        date: DateTime.now(),
        notes: 'Pembelian dari dana target menabung',
        categoryId: resolvedCategoryId,
        type: TransactionType.expense,
        dompetId: walletId,
        targetId: target.id,
        skipWalletEffect: true,
      );

      fsTx.set(txRef, createdTx.toMap());
      fsTx.update(targetRef, {
        'isSettled': true,
        'isPinned': false,
      });
    });

    return createdTx;
  }

  Future<void> togglePinTarget({
    required String uid,
    required String targetId,
    required bool shouldPin,
  }) async {
    _firestoreService.ensureOnline(actionLabel: 'menyematkan target menabung');
    final colRef = _firestoreService.targetsCol(uid);
    final snapshot = await colRef.get();
    final batch = _firestoreService.batch();

    for (final doc in snapshot.docs) {
      final bool desiredPin = shouldPin && doc.id == targetId;
      final bool currentPin = doc.data()['isPinned'] == true;
      if (currentPin != desiredPin) {
        batch.update(doc.reference, {'isPinned': desiredPin});
      }
    }

    await batch.commit();
  }

  Future<void> deleteTarget(String uid, String targetId) async {
    _firestoreService.ensureOnline(actionLabel: 'menghapus target menabung');
    await _firestoreService.targetsCol(uid).doc(targetId).delete();
  }
}
