import 'dart:io';
import '../models/target_model.dart';
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
    final snapshot = await _firestoreService.targetsCol(uid).get();
    final items = snapshot.docs
        .map((doc) => TargetItem.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort((a, b) {
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
  }) async {
    final secureUrl = await _cloudinaryService.uploadImage(imageFile);
    final docRef = _firestoreService.targetsCol(uid).doc();
    final item = TargetItem(
      id: docRef.id,
      nama: nama.trim(),
      targetAmount: targetAmount,
      savedAmount: 0.0,
      imageUrl: secureUrl,
      isPinned: isPinned,
    );

    await docRef.set(item.toMap());

    return item;
  }

  Future<void> updateSavedAmount({
    required String uid,
    required String targetId,
    required double savedAmount,
  }) async {
    await _firestoreService
        .targetsCol(uid)
        .doc(targetId)
        .update({'savedAmount': savedAmount});
  }

  Future<void> togglePinTarget({
    required String uid,
    required String targetId,
    required bool shouldPin,
  }) async {
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
    await _firestoreService.targetsCol(uid).doc(targetId).delete();
  }
}
