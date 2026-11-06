import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/legacy_wallet_catalog.dart';
import '../models/dompet_model.dart';
import '../services/firestore_service.dart';

class DompetRepository {
  final FirestoreService _firestoreService;

  DompetRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<List<DompetItem>> getDompets(String uid) async {
    final walletsRef = _firestoreService.walletsCol(uid);
    final snapshot = await walletsRef.get();

    if (snapshot.docs.isEmpty) {
      final userDocRef = _firestoreService.userDoc(uid);
      final userSnap = await userDocRef.get();
      final bool walletSeeded = userSnap.data()?['walletSeeded'] == true;

      if (!walletSeeded) {
        final seedWallets = LegacyWalletCatalog.buildExistingUserSeedWallets();
        final batch = _firestoreService.batch();

        for (final wallet in seedWallets) {
          batch.set(walletsRef.doc(wallet.id), wallet.toMap());
        }
        batch.set(
          userDocRef,
          {'walletSeeded': true},
          SetOptions(merge: true),
        );

        await batch.commit();
        return seedWallets;
      }
      return [];
    }

    final items = snapshot.docs
        .map((doc) => DompetItem.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort((a, b) => a.id.compareTo(b.id));
    return items;
  }

  Future<void> addDompet(String uid, DompetItem item) async {
    await _firestoreService
        .walletsCol(uid)
        .doc(item.id)
        .set(item.toMap());
  }

  Future<void> updateDompet(String uid, DompetItem item) async {
    await _firestoreService
        .walletsCol(uid)
        .doc(item.id)
        .set(item.toMap());
  }

  Future<void> deleteDompet(String uid, String dompetId) async {
    await _firestoreService.walletsCol(uid).doc(dompetId).delete();
  }
}
