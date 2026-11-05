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
