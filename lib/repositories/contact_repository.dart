import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class ContactRepository {
  final FirestoreService _firestoreService;

  ContactRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  static String? _normalizeNote(String? rawNote) {
    final trimmed = rawNote?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Memperbarui judul transaksi/jadwal berulang standar saat nama kontak
  /// diganti (mis. "Transfer ke Budi" -> "Transfer ke Budi Santoso").
  /// Judul kustom yang tidak memakai pola standar dipertahankan apa adanya.
  @visibleForTesting
  static String renameLinkedTitle(
    String currentTitle, {
    required String oldName,
    required String newName,
    required TransactionType type,
  }) {
    final trimmedTitle = currentTitle.trim();
    final trimmedOld = oldName.trim();
    final trimmedNew = newName.trim();
    if (trimmedOld.isEmpty ||
        trimmedNew.isEmpty ||
        trimmedOld.toLowerCase() == trimmedNew.toLowerCase()) {
      return currentTitle;
    }

    final List<String> prefixes;
    switch (type) {
      case TransactionType.transfer:
        prefixes = const ['Transfer ke '];
        break;
      case TransactionType.debt:
        prefixes = const ['Hutang dari '];
        break;
      case TransactionType.receivable:
        prefixes = const ['Piutang ke '];
        break;
      case TransactionType.income:
      case TransactionType.expense:
        return currentTitle;
    }

    final lowerTitle = trimmedTitle.toLowerCase();
    final lowerOld = trimmedOld.toLowerCase();
    for (final prefix in prefixes) {
      if (lowerTitle == '${prefix.toLowerCase()}$lowerOld') {
        return '$prefix$trimmedNew';
      }
    }
    return currentTitle;
  }

  Future<List<ContactModel>> getContacts(String uid) async {
    final snapshot = await _firestoreService.getQuerySnapshot(
      _firestoreService.contactsCol(uid),
    );
    final items = snapshot.docs
        .map((doc) => ContactModel.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return items;
  }

  Future<ContactModel> addContact(
    String uid,
    String name, {
    String? note,
    bool rejectDuplicate = false,
  }) async {
    _firestoreService.ensureOnline(actionLabel: 'menambahkan kontak');
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Nama kontak tidak boleh kosong');
    }

    final existing = await getContacts(uid);
    final matchIndex = existing.indexWhere(
      (c) => c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (matchIndex != -1) {
      if (rejectDuplicate) {
        throw Exception('Kontak "$trimmedName" sudah ada di daftar.');
      }
      return existing[matchIndex];
    }

    final docRef = _firestoreService.contactsCol(uid).doc();
    final newContact = ContactModel(
      id: docRef.id,
      name: trimmedName,
      note: _normalizeNote(note),
    );

    await docRef.set(newContact.toMap());
    return newContact;
  }

  Future<ContactModel> updateContact(String uid, ContactModel updated) async {
    _firestoreService.ensureOnline(actionLabel: 'memperbarui kontak');
    final trimmedName = updated.name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Nama kontak tidak boleh kosong');
    }

    final existing = await getContacts(uid);
    final currentIndex = existing.indexWhere((c) => c.id == updated.id);
    if (currentIndex == -1) {
      throw Exception('Kontak tidak ditemukan.');
    }
    final oldContact = existing[currentIndex];

    final hasDuplicate = existing.any(
      (c) =>
          c.id != updated.id &&
          c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (hasDuplicate) {
      throw Exception('Kontak "$trimmedName" sudah ada di daftar.');
    }

    final normalized = ContactModel(
      id: updated.id,
      name: trimmedName,
      note: _normalizeNote(updated.note),
    );

    final contactRef = _firestoreService.contactsCol(uid).doc(normalized.id);
    final bool nameChanged = oldContact.name.trim() != trimmedName;

    if (!nameChanged) {
      await contactRef.set(normalized.toMap());
      return normalized;
    }

    final [txSnap, recSnap] = await Future.wait([
      _firestoreService
          .transactionsCol(uid)
          .where('contactId', isEqualTo: normalized.id)
          .get(),
      _firestoreService
          .recurringCol(uid)
          .where('contactId', isEqualTo: normalized.id)
          .get(),
    ]);

    final ops = <void Function(WriteBatch)>[
      (batch) => batch.set(contactRef, normalized.toMap()),
    ];

    for (final doc in txSnap.docs) {
      final data = doc.data();
      final rawType = (data['type'] as String?) ?? TransactionType.transfer.name;
      final txType = TransactionType.values.firstWhere(
        (t) => t.name == rawType,
        orElse: () => TransactionType.transfer,
      );
      final oldTitle = (data['title'] as String?) ?? '';
      final nextTitle = renameLinkedTitle(
        oldTitle,
        oldName: oldContact.name,
        newName: trimmedName,
        type: txType,
      );
      final updates = <String, dynamic>{
        'counterpartyName': trimmedName,
        if (nextTitle != oldTitle) 'title': nextTitle,
      };
      ops.add((batch) => batch.update(doc.reference, updates));
    }

    for (final doc in recSnap.docs) {
      final data = doc.data();
      final rawType = (data['type'] as String?) ?? TransactionType.transfer.name;
      final recType = TransactionType.values.firstWhere(
        (t) => t.name == rawType,
        orElse: () => TransactionType.transfer,
      );
      final oldTitle = (data['title'] as String?) ?? '';
      final nextTitle = renameLinkedTitle(
        oldTitle,
        oldName: oldContact.name,
        newName: trimmedName,
        type: recType,
      );
      final updates = <String, dynamic>{
        'counterpartyName': trimmedName,
        if (nextTitle != oldTitle) 'title': nextTitle,
      };
      ops.add((batch) => batch.update(doc.reference, updates));
    }

    await _commitChunked(ops);
    return normalized;
  }

  /// Menghapus kontak dari daftar tanpa menghapus riwayat transaksi/pinjaman.
  /// Field `contactId` pada transaksi & jadwal berulang terkait dibersihkan,
  /// sementara `counterpartyName` dipastikan tetap menyimpan nama terakhirnya.
  Future<void> deleteContact(String uid, String contactId) async {
    _firestoreService.ensureOnline(actionLabel: 'menghapus kontak');
    final contactRef = _firestoreService.contactsCol(uid).doc(contactId);

    final contactSnap = await contactRef.get();
    final lastKnownName =
        ((contactSnap.data()?['name'] as String?) ?? '').trim();

    final [txSnap, recSnap] = await Future.wait([
      _firestoreService
          .transactionsCol(uid)
          .where('contactId', isEqualTo: contactId)
          .get(),
      _firestoreService
          .recurringCol(uid)
          .where('contactId', isEqualTo: contactId)
          .get(),
    ]);

    final ops = <void Function(WriteBatch)>[
      (batch) => batch.delete(contactRef),
    ];

    for (final doc in txSnap.docs) {
      final existingName = ((doc.data()['counterpartyName'] as String?) ?? '')
          .trim();
      final updates = <String, dynamic>{
        'contactId': null,
        if (existingName.isEmpty && lastKnownName.isNotEmpty)
          'counterpartyName': lastKnownName,
      };
      ops.add((batch) => batch.update(doc.reference, updates));
    }

    for (final doc in recSnap.docs) {
      final existingName = ((doc.data()['counterpartyName'] as String?) ?? '')
          .trim();
      final updates = <String, dynamic>{
        'contactId': null,
        if (existingName.isEmpty && lastKnownName.isNotEmpty)
          'counterpartyName': lastKnownName,
      };
      ops.add((batch) => batch.update(doc.reference, updates));
    }

    await _commitChunked(ops);
  }

  Future<void> _commitChunked(List<void Function(WriteBatch)> ops) async {
    const int chunkSize = 400;
    for (int i = 0; i < ops.length; i += chunkSize) {
      final end = (i + chunkSize < ops.length) ? i + chunkSize : ops.length;
      final batch = _firestoreService.batch();
      for (int j = i; j < end; j++) {
        ops[j](batch);
      }
      await batch.commit();
    }
  }
}
