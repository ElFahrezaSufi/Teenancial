import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/belajar_model.dart';
import '../services/firestore_service.dart';

class BelajarRepository {
  final FirestoreService _fs;

  BelajarRepository({FirestoreService? firestoreService})
      : _fs = firestoreService ?? FirestoreService.instance;

  // ─── Progress ───────────────────────────────────────────────────────────────

  Future<BelajarProgressModel> getProgress(String uid) async {
    final doc = await _fs.userDoc(uid).get();
    return BelajarProgressModel.fromMap(doc.data());
  }

  Future<void> saveProgress(String uid, BelajarProgressModel progress) async {
    await _fs.userDoc(uid).set(
          progress.toMap(),
          SetOptions(merge: true),
        );
  }

  // ─── Konten dari Firestore ───────────────────────────────────────────────────

  Future<List<LevelData>> getLevels() async {
    final snap = await _fs.belajarLevelsCol.orderBy('order').get();
    return snap.docs
        .map((doc) => LevelData.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<ModuleData>> getModulesByLevel(String levelId) async {
    final snap = await _fs.belajarModulesCol
        .where('levelId', isEqualTo: levelId)
        .orderBy('order')
        .get();
    return snap.docs
        .map((doc) => ModuleData.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<ModuleData>> getAllModules() async {
    final snap = await _fs.belajarModulesCol.orderBy('order').get();
    return snap.docs
        .map((doc) => ModuleData.fromMap(doc.data(), docId: doc.id))
        .toList();
  }
}
