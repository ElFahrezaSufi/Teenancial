import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/belajar_model.dart';
import '../services/firestore_service.dart';

class BelajarRepository {
  final FirestoreService _firestoreService;

  BelajarRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<BelajarProgressModel> getProgress(String uid) async {
    final doc = await _firestoreService.userDoc(uid).get();
    return BelajarProgressModel.fromMap(doc.data());
  }

  Future<void> saveProgress(String uid, BelajarProgressModel progress) async {
    await _firestoreService.userDoc(uid).set(
          progress.toMap(),
          SetOptions(merge: true),
        );
  }
}
