import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/legacy_finance_catalog.dart';
import '../models/contact_model.dart';
import 'firestore_service.dart';

class LegacySeedService {
  LegacySeedService._();
  static final LegacySeedService instance = LegacySeedService._();

  final FirestoreService _firestoreService = FirestoreService.instance;
  final Set<String> _completedUids = <String>{};
  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};

  static const Set<String> _legacyExtraWalletIds = {'d2', 'd3', 'd4', 'd5', 'd6'};

  /// Menjalankan seeding satu kali untuk riwayat transaksi dummy lama (t1..t20),
  /// pinjaman dummy (p1..p4), dan kontak dummy (c1..c4) HANYA pada akun lama.
  /// Akun baru (termasuk akun baru yang sudah dibuat sebelumnya) dijamin
  /// terdeteksi dan dilewati tanpa seeding.
  Future<void> ensureFinanceSeeded(String uid) async {
    if (uid.isEmpty || _completedUids.contains(uid)) return;

    final existingFuture = _inFlight[uid];
    if (existingFuture != null) {
      await existingFuture;
      return;
    }

    final future = _runSeed(uid);
    _inFlight[uid] = future;
    try {
      await future;
    } finally {
      _inFlight.remove(uid);
    }
  }

  Future<void> _runSeed(String uid) async {
    final userDocRef = _firestoreService.userDoc(uid);
    final userSnap = await userDocRef.get();
    final userData = userSnap.data();

    if (userData?['legacyFinanceSeeded'] == true) {
      _completedUids.add(uid);
      return;
    }

    final walletsSnap = await _firestoreService.walletsCol(uid).get();

    // Deteksi ketat apakah ini Akun Lama vs Akun Baru:
    // - Akun lama memiliki dompet legacy (d2..d6 atau d1 bernama 'Dompet Utama'),
    //   ATAU belum pernah di-seed dompetnya sama sekali (walletSeeded != true).
    // - Akun baru yang dibuat melalui SignUp / Google baru selalu memiliki
    //   walletSeeded == true dan dompet awal d1 bernama 'Dompet Tunai' (tanpa d2..d6).
    final bool hasLegacyWallets = walletsSnap.docs.any(
      (doc) =>
          _legacyExtraWalletIds.contains(doc.id) ||
          (doc.id == 'd1' && doc.data()['nama'] == 'Dompet Utama'),
    );
    final bool isUnseededLegacyUser =
        walletsSnap.docs.isEmpty && userData?['walletSeeded'] != true;
    final bool isLegacyAccount = hasLegacyWallets || isUnseededLegacyUser;

    if (!isLegacyAccount) {
      if (userSnap.exists) {
        await userDocRef.set(
          {'legacyFinanceSeeded': true},
          SetOptions(merge: true),
        );
      }
      _completedUids.add(uid);
      return;
    }

    final contactsRef = _firestoreService.contactsCol(uid);
    final txRef = _firestoreService.transactionsCol(uid);

    final results = await Future.wait([
      contactsRef.get(),
      txRef.get(),
    ]);
    final existingContactsSnap = results[0];
    final existingTxSnap = results[1];

    final existingContactsByName = <String, String>{};
    for (final doc in existingContactsSnap.docs) {
      final contact = ContactModel.fromMap(doc.data(), docId: doc.id);
      if (contact.name.trim().isNotEmpty) {
        existingContactsByName[contact.name.trim().toLowerCase()] = contact.id;
      }
    }

    final existingTxIds = existingTxSnap.docs.map((d) => d.id).toSet();
    final availableWalletIds = walletsSnap.docs.map((d) => d.id).toSet();

    final batch = _firestoreService.batch();
    final contactIdBySeedId = <String, String>{};

    for (final seedContact
        in LegacyFinanceCatalog.buildExistingUserSeedContacts()) {
      final key = seedContact.name.trim().toLowerCase();
      final existingId = existingContactsByName[key];
      if (existingId != null) {
        contactIdBySeedId[seedContact.id] = existingId;
      } else {
        contactIdBySeedId[seedContact.id] = seedContact.id;
        batch.set(contactsRef.doc(seedContact.id), seedContact.toMap());
      }
    }

    final seedTransactions =
        LegacyFinanceCatalog.buildExistingUserSeedTransactions(
      contactIdBySeedId: contactIdBySeedId,
      availableWalletIds: availableWalletIds,
    );

    for (final tx in seedTransactions) {
      if (!existingTxIds.contains(tx.id)) {
        batch.set(txRef.doc(tx.id), tx.toMap());
      }
    }

    batch.set(
      userDocRef,
      {'legacyFinanceSeeded': true},
      SetOptions(merge: true),
    );

    await batch.commit();
    _completedUids.add(uid);
  }
}

