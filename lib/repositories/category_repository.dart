import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/category_catalog.dart';
import '../data/category_icons.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class CategoryRepository {
  final FirestoreService _firestoreService;

  static const int maxNameLength = 20;
  static const int maxCustomPerType = 20;

  CategoryRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  /// Memvalidasi nama kategori kustom terhadap batas karakter, keunikan
  /// terhadap kategori bawaan dan kustom pada jenis transaksi yang sama, serta
  /// kuota maksimal per jenis transaksi.
  static String validateCategoryName({
    required String name,
    required TransactionType type,
    required Iterable<CategoryModel> existingCustom,
    String? editingCategoryId,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Nama kategori tidak boleh kosong.');
    }
    if (trimmed.length > maxNameLength) {
      throw Exception(
        'Nama kategori maksimal $maxNameLength karakter.',
      );
    }

    final lower = trimmed.toLowerCase();
    final builtIns = CategoryCatalog.getByType(type);
    final duplicateBuiltIn = builtIns.any(
      (c) => c.name.trim().toLowerCase() == lower,
    );
    if (duplicateBuiltIn) {
      throw Exception(
        'Nama "$trimmed" sudah digunakan oleh kategori bawaan.',
      );
    }

    final customForType =
        existingCustom.where((c) => c.type == type).toList(growable: false);
    final duplicateCustom = customForType.any(
      (c) =>
          c.id != editingCategoryId && c.name.trim().toLowerCase() == lower,
    );
    if (duplicateCustom) {
      throw Exception(
        'Kategori "$trimmed" sudah ada pada jenis transaksi ini.',
      );
    }

    if (editingCategoryId == null && customForType.length >= maxCustomPerType) {
      throw Exception(
        'Maksimal $maxCustomPerType kategori kustom untuk jenis transaksi ini.',
      );
    }

    return trimmed;
  }

  Future<List<CategoryModel>> getCategories(String uid) async {
    final snapshot = await _firestoreService.categoriesCol(uid).get();
    final items = snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = aDate.compareTo(bDate);
      if (cmp != 0) return cmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  Future<CategoryModel> addCategory({
    required String uid,
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final existing = await getCategories(uid);
    final validatedName = validateCategoryName(
      name: name,
      type: type,
      existingCustom: existing,
    );

    final docRef = _firestoreService.categoriesCol(uid).doc();
    final resolvedIconKey =
        CategoryIcons.icons.containsKey(iconKey) ? iconKey : 'category';
    final created = CategoryModel(
      id: docRef.id,
      name: validatedName,
      type: type,
      icon: CategoryIcons.iconForKey(resolvedIconKey),
      iconKey: resolvedIconKey,
      colorValue: colorValue,
      isCustom: true,
      createdAt: DateTime.now(),
    );

    await docRef.set(created.toMap());
    return created;
  }

  Future<CategoryModel> updateCategory({
    required String uid,
    required String categoryId,
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final existing = await getCategories(uid);
    final index = existing.indexWhere((c) => c.id == categoryId);
    if (index == -1) {
      throw Exception('Kategori yang akan diubah tidak ditemukan.');
    }

    final validatedName = validateCategoryName(
      name: name,
      type: type,
      existingCustom: existing,
      editingCategoryId: categoryId,
    );

    final resolvedIconKey =
        CategoryIcons.icons.containsKey(iconKey) ? iconKey : 'category';
    final updated = existing[index].copyWith(
      name: validatedName,
      type: type,
      iconKey: resolvedIconKey,
      colorValue: colorValue,
    );

    await _firestoreService.categoriesCol(uid).doc(categoryId).update({
      'name': validatedName,
      'type': type.name,
      'iconKey': resolvedIconKey,
      'colorValue': colorValue,
    });

    return updated;
  }

  /// Menghitung berapa banyak transaksi atau jadwal berulang yang memakai
  /// `categoryId`.
  Future<int> countUsages(String uid, String categoryId) async {
    final txSnap = await _firestoreService
        .transactionsCol(uid)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    final recSnap = await _firestoreService
        .recurringCol(uid)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    return txSnap.docs.length + recSnap.docs.length;
  }

  /// Menghapus kategori kustom dan memindahkan seluruh transaksi/templat
  /// berulang yang memakainya ke kategori bawaan "Lainnya" pada jenis yang sama
  /// (dipecah per 400 dokumen per WriteBatch agar selalu di bawah batas 500
  /// operasi Firestore).
  Future<int> deleteCategory({
    required String uid,
    required String categoryId,
    required TransactionType type,
  }) async {
    final fallbackId = CategoryCatalog.defaultCategoryIdForType(type);

    final txSnap = await _firestoreService
        .transactionsCol(uid)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    final recSnap = await _firestoreService
        .recurringCol(uid)
        .where('categoryId', isEqualTo: categoryId)
        .get();

    final refsToUpdate = <DocumentReference<Map<String, dynamic>>>[
      ...txSnap.docs.map((d) => d.reference),
      ...recSnap.docs.map((d) => d.reference),
    ];

    const int chunkSize = 400;
    for (int i = 0; i < refsToUpdate.length; i += chunkSize) {
      final batch = _firestoreService.batch();
      final end = (i + chunkSize < refsToUpdate.length)
          ? i + chunkSize
          : refsToUpdate.length;
      for (int j = i; j < end; j++) {
        batch.update(refsToUpdate[j], {'categoryId': fallbackId});
      }
      await batch.commit();
    }

    await _firestoreService.categoriesCol(uid).doc(categoryId).delete();
    return refsToUpdate.length;
  }
}
