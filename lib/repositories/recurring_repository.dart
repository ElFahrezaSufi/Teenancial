import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dompet_model.dart';
import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../utils/date_helper.dart';

class RecurringCatchUpResult {
  final int generatedCount;
  final int skippedCount;
  final List<TransactionModel> generatedTransactions;
  final List<String> skippedReasons;

  const RecurringCatchUpResult({
    this.generatedCount = 0,
    this.skippedCount = 0,
    this.generatedTransactions = const [],
    this.skippedReasons = const [],
  });

  bool get hasChanges => generatedCount > 0 || skippedCount > 0;
}

class RecurringRepository {
  final FirestoreService _firestoreService;

  RecurringRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  static void validateTemplate(RecurringModel item) {
    if (item.title.trim().isEmpty) {
      throw Exception('Judul transaksi berulang tidak boleh kosong');
    }
    if (item.amount <= 0) {
      throw Exception('Nominal transaksi berulang harus lebih dari Rp 0');
    }
    if (item.dompetId.trim().isEmpty) {
      throw Exception('Pilih dompet sumber terlebih dahulu');
    }
    if (item.type != TransactionType.income &&
        item.type != TransactionType.expense &&
        item.type != TransactionType.transfer) {
      throw Exception(
        'Transaksi berulang hanya mendukung Pemasukan, Pengeluaran, dan Transfer',
      );
    }
    if (item.isInternalTransfer &&
        item.dompetId.trim() == item.destinationDompetId!.trim()) {
      throw Exception('Dompet asal dan dompet tujuan tidak boleh sama');
    }
    if (item.intervalCount < 1) {
      throw Exception('Interval pengulangan minimal 1');
    }
    if (item.endDate != null &&
        RecurrenceRule.dateOnly(item.endDate!)
            .isBefore(RecurrenceRule.dateOnly(item.startDate))) {
      throw Exception(
        'Tanggal berakhir tidak boleh sebelum tanggal mulai',
      );
    }
  }

  Future<List<RecurringModel>> getRecurringTemplates(String uid) async {
    final col = _firestoreService.recurringCol(uid);
    final snapshot = await col.get();
    if (snapshot.docs.isEmpty) return [];

    final items = snapshot.docs
        .map((doc) => RecurringModel.fromMap(doc.data(), docId: doc.id))
        .toList();

    items.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }
      final dateCmp = a.nextRunDate.compareTo(b.nextRunDate);
      if (dateCmp != 0) return dateCmp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return items;
  }

  Future<RecurringModel> addRecurring(String uid, RecurringModel item) async {
    validateTemplate(item);
    final col = _firestoreService.recurringCol(uid);
    final docRef = item.id.isEmpty ? col.doc() : col.doc(item.id);
    final toSave = item.copyWith(
      id: docRef.id,
      startDate: RecurrenceRule.dateOnly(item.startDate),
      nextRunDate: RecurrenceRule.dateOnly(item.nextRunDate),
      createdAt: item.createdAt ?? DateTime.now(),
    );
    await docRef.set(toSave.toMap());
    return toSave;
  }

  Future<RecurringModel> updateRecurring(
    String uid,
    RecurringModel item,
  ) async {
    if (item.id.trim().isEmpty) {
      throw Exception('ID jadwal transaksi berulang tidak valid');
    }
    validateTemplate(item);
    final docRef = _firestoreService.recurringCol(uid).doc(item.id);
    final toSave = item.copyWith(
      startDate: RecurrenceRule.dateOnly(item.startDate),
      nextRunDate: RecurrenceRule.dateOnly(item.nextRunDate),
    );
    await docRef.set(toSave.toMap());
    return toSave;
  }

  Future<void> toggleActive(String uid, String id, bool isActive) async {
    final docRef = _firestoreService.recurringCol(uid).doc(id);
    await docRef.update({'isActive': isActive});
  }

  Future<void> deleteRecurring(String uid, String id) async {
    await _firestoreService.recurringCol(uid).doc(id).delete();
  }

  /// Mengeksekusi seluruh jadwal transaksi berulang yang sudah jatuh tempo
  /// (`nextRunDate <= today`) secara idempoten dengan ID deterministik
  /// `rec_{templateId}_{yyyyMMdd}` dan memperbarui saldo dompet terkait.
  Future<RecurringCatchUpResult> processDue(
    String uid, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final today = RecurrenceRule.dateOnly(effectiveNow);

    final col = _firestoreService.recurringCol(uid);
    final snapshot = await col.where('isActive', isEqualTo: true).get();
    if (snapshot.docs.isEmpty) {
      return const RecurringCatchUpResult();
    }

    final dueTemplates = snapshot.docs
        .map((doc) => RecurringModel.fromMap(doc.data(), docId: doc.id))
        .where((t) => !RecurrenceRule.dateOnly(t.nextRunDate).isAfter(today))
        .toList();

    if (dueTemplates.isEmpty) {
      return const RecurringCatchUpResult();
    }

    int totalGenerated = 0;
    int totalSkipped = 0;
    final List<TransactionModel> allGeneratedTxs = [];
    final List<String> allSkippedReasons = [];

    for (final candidate in dueTemplates) {
      final recRef = col.doc(candidate.id);
      final walletsCol = _firestoreService.walletsCol(uid);
      final txCol = _firestoreService.transactionsCol(uid);

      await _firestoreService.runTransaction((fsTx) async {
        // 1. BACA SEMUA DOKUMEN TERLEBIH DAHULU (syarat transaksi Firestore)
        final recSnap = await fsTx.get(recRef);
        if (!recSnap.exists || recSnap.data() == null) return;

        final tpl = RecurringModel.fromMap(recSnap.data()!, docId: recSnap.id);
        if (!tpl.isActive) return;

        final plan = RecurrenceRule.collectDueOccurrences(
          anchorDate: tpl.startDate,
          nextRunDate: tpl.nextRunDate,
          frequency: tpl.frequency,
          intervalCount: tpl.intervalCount,
          endDate: tpl.endDate,
          upToDate: today,
        );

        if (plan.dueDates.isEmpty) {
          if (plan.shouldDeactivate) {
            fsTx.set(
              recRef,
              tpl.copyWith(isActive: false, nextRunDate: plan.nextRunDate).toMap(),
            );
          }
          return;
        }

        final sourceWalletRef = walletsCol.doc(tpl.dompetId);
        final sourceWalletSnap = await fsTx.get(sourceWalletRef);

        DocumentReference<Map<String, dynamic>>? destWalletRef;
        DocumentSnapshot<Map<String, dynamic>>? destWalletSnap;
        if (tpl.isInternalTransfer &&
            tpl.destinationDompetId != tpl.dompetId) {
          destWalletRef = walletsCol.doc(tpl.destinationDompetId!);
          destWalletSnap = await fsTx.get(destWalletRef);
        }

        final Map<DateTime, DocumentSnapshot<Map<String, dynamic>>>
            existingTxSnaps = {};
        for (final d in plan.dueDates) {
          final detId = RecurrenceRule.deterministicTransactionId(tpl.id, d);
          existingTxSnaps[d] = await fsTx.get(txCol.doc(detId));
        }

        // 2. VALIDASI KEBERADAAN DOMPET
        if (!sourceWalletSnap.exists || sourceWalletSnap.data() == null) {
          final reason =
              'Jadwal "${tpl.title}" dijeda karena dompet sumber tidak ditemukan.';
          allSkippedReasons.add(reason);
          totalSkipped += plan.dueDates.length;
          fsTx.set(
            recRef,
            tpl
                .copyWith(
                  isActive: false,
                  skippedCount: tpl.skippedCount + plan.dueDates.length,
                  lastSkipReason: reason,
                )
                .toMap(),
          );
          return;
        }

        if (tpl.isInternalTransfer &&
            (destWalletSnap == null ||
                !destWalletSnap.exists ||
                destWalletSnap.data() == null)) {
          final reason =
              'Jadwal "${tpl.title}" dijeda karena dompet tujuan tidak ditemukan.';
          allSkippedReasons.add(reason);
          totalSkipped += plan.dueDates.length;
          fsTx.set(
            recRef,
            tpl
                .copyWith(
                  isActive: false,
                  skippedCount: tpl.skippedCount + plan.dueDates.length,
                  lastSkipReason: reason,
                )
                .toMap(),
          );
          return;
        }

        final sourceWallet = DompetItem.fromMap(
          sourceWalletSnap.data()!,
          docId: sourceWalletSnap.id,
        );
        double runningSourceBalance = sourceWallet.jumlah;

        DompetItem? destWallet;
        double runningDestBalance = 0.0;
        if (tpl.isInternalTransfer && destWalletSnap != null) {
          destWallet = DompetItem.fromMap(
            destWalletSnap.data()!,
            docId: destWalletSnap.id,
          );
          runningDestBalance = destWallet.jumlah;
        }

        // 3. PROSES SETIAP TANGGAL JATUH TEMPO & TULIS KE FIRESTORE
        int localGenerated = 0;
        int localSkipped = 0;
        DateTime? lastExecutedDate = tpl.lastRunDate;
        String? latestSkipReason = tpl.lastSkipReason;
        final List<TransactionModel> batchCreatedTxs = [];

        for (final dueDate in plan.dueDates) {
          final detId =
              RecurrenceRule.deterministicTransactionId(tpl.id, dueDate);
          final txSnap = existingTxSnaps[dueDate]!;

          // Guard idempoten: bila dokumen sudah ada, lewati tanpa mendebit/kredit ulang
          if (txSnap.exists) {
            lastExecutedDate = dueDate;
            continue;
          }

          final bool isOutflow = tpl.type == TransactionType.expense ||
              tpl.type == TransactionType.transfer;

          if (isOutflow && runningSourceBalance + 0.0001 < tpl.amount) {
            localSkipped++;
            latestSkipReason =
                'Saldo dompet "${sourceWallet.nama}" tidak cukup untuk "${tpl.title}" (${DateHelper.formatShort(dueDate)}).';
            allSkippedReasons.add(latestSkipReason);
            continue;
          }

          if (tpl.type == TransactionType.income) {
            runningSourceBalance += tpl.amount;
          } else if (tpl.type == TransactionType.expense) {
            runningSourceBalance -= tpl.amount;
          } else if (tpl.type == TransactionType.transfer) {
            runningSourceBalance -= tpl.amount;
            if (tpl.isInternalTransfer) {
              runningDestBalance += tpl.amount;
            }
          }

          final occurrenceDateTime = DateTime(
            dueDate.year,
            dueDate.month,
            dueDate.day,
            9,
            0,
          );

          final newTx = TransactionModel(
            id: detId,
            title: tpl.title,
            amount: tpl.amount,
            date: occurrenceDateTime,
            notes: tpl.notes,
            categoryId: tpl.categoryId,
            type: tpl.type,
            dompetId: tpl.dompetId,
            destinationDompetId:
                tpl.isInternalTransfer ? tpl.destinationDompetId : null,
            contactId: tpl.contactId,
            counterpartyName: tpl.counterpartyName,
            recurringId: tpl.id,
          );

          fsTx.set(txCol.doc(detId), newTx.toMap());
          batchCreatedTxs.add(newTx);
          localGenerated++;
          lastExecutedDate = dueDate;
        }

        if (localGenerated > 0) {
          fsTx.set(
            sourceWalletRef,
            sourceWallet.copyWith(jumlah: runningSourceBalance).toMap(),
          );
          if (tpl.isInternalTransfer &&
              destWalletRef != null &&
              destWallet != null) {
            fsTx.set(
              destWalletRef,
              destWallet.copyWith(jumlah: runningDestBalance).toMap(),
            );
          }
        }

        final updatedTemplate = tpl.copyWith(
          nextRunDate: plan.nextRunDate,
          isActive: plan.shouldDeactivate ? false : tpl.isActive,
          lastRunDate: lastExecutedDate,
          generatedCount: tpl.generatedCount + localGenerated,
          skippedCount: tpl.skippedCount + localSkipped,
          lastSkipReason: localSkipped > 0 ? latestSkipReason : null,
          clearLastSkipReason: localSkipped == 0 && localGenerated > 0,
        );

        fsTx.set(recRef, updatedTemplate.toMap());

        totalGenerated += localGenerated;
        totalSkipped += localSkipped;
        allGeneratedTxs.addAll(batchCreatedTxs);
      });
    }

    return RecurringCatchUpResult(
      generatedCount: totalGenerated,
      skippedCount: totalSkipped,
      generatedTransactions: List<TransactionModel>.unmodifiable(
        allGeneratedTxs,
      ),
      skippedReasons: List<String>.unmodifiable(allSkippedReasons),
    );
  }
}
