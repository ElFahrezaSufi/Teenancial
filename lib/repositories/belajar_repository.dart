import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/belajar_model.dart';
import '../services/connectivity_service.dart';
import '../services/firestore_service.dart';

class BelajarRepository {
  final FirestoreService _fs;

  BelajarRepository({FirestoreService? firestoreService})
      : _fs = firestoreService ?? FirestoreService.instance;

  // ─── Progress ───────────────────────────────────────────────────────────────

  Future<BelajarProgressModel> getProgress(String uid) async {
    try {
      final doc = await _fs.getDocumentSnapshot(_fs.userDoc(uid));
      return BelajarProgressModel.fromMap(doc.data());
    } on OfflineException {
      return const BelajarProgressModel();
    }
  }

  Future<void> saveProgress(String uid, BelajarProgressModel progress) async {
    _fs.ensureOnline(actionLabel: 'menyimpan progres belajar');
    await _fs.userDoc(uid).set(
          progress.toMap(),
          SetOptions(merge: true),
        );
  }

  // ─── Konten dari Firestore ───────────────────────────────────────────────────

  Future<List<LevelData>> getLevels() async {
    final snap =
        await _fs.getQuerySnapshot(_fs.belajarLevelsCol.orderBy('order'));
    return snap.docs
        .map((doc) => LevelData.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<ModuleData>> getAllModules() async {
    final snap =
        await _fs.getQuerySnapshot(_fs.belajarModulesCol.orderBy('order'));
    return snap.docs
        .map((doc) => ModuleData.fromMap(doc.data(), docId: doc.id))
        .toList();
  }
}
